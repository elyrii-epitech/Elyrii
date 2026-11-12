import '../../../../core/config/api_config.dart';
import '../../../../core/diagnostics/app_diagnostics.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/json_response.dart';
import '../domain/journey.dart';
import 'journey_parser.dart';
import 'journey_repository.dart';

/// Real accounts use server acknowledgements; demo progress stays local.
class ConnectedJourneyRepository extends JourneyRepository {
  final ApiClient _client;
  final _catalogs = <String, List<JourneyPath>>{};
  final _readOnly = <String>{};
  final _deleted = <String>{};
  ConnectedJourneyRepository({required this._client, required super.cipher});

  @override
  bool get isRemote => true;
  @override
  List<JourneyPath> catalogFor(String? owner) => _catalogs[owner] ?? catalog;
  @override
  bool canWriteFor(String owner) => !_readOnly.contains(owner);
  @override
  String? loadWarning(String owner) => _readOnly.contains(owner)
      ? 'Tu consultes la progression enregistrée sur cet appareil. Actualise avec une connexion pour enregistrer de nouvelles étapes.'
      : null;

  Future<int> _session(String owner) async {
    final generation = _client.sessionGeneration;
    if (_deleted.contains(owner) || await _client.currentUserId != owner) {
      throw const ApiException(
        statusCode: 0,
        message: 'Session modifiée.',
        kind: ApiFailureKind.cancelled,
      );
    }
    _client.ensureSession(generation);
    return generation;
  }

  void _ensure(int generation, String owner) {
    _client.ensureSession(generation);
    if (_deleted.contains(owner)) {
      throw const ApiException(
        statusCode: 0,
        message: 'Compte supprimé.',
        kind: ApiFailureKind.cancelled,
      );
    }
  }

  Future<void> _cache(String owner, JourneyEnrollment current) async {
    try {
      await cacheConfirmedProgress(owner, current);
    } catch (error) {
      // A cache failure must not turn a confirmed remote mutation into failure.
      AppDiagnostics.record('coach_cache_write_failed', error);
    }
  }

  @override
  Future<JourneyEnrollment?> load(String owner) async {
    if (owner == 'demo') return super.load(owner);
    final generation = await _session(owner);
    try {
      final results = await Future.wait([
        _client.get(ApiConfig.coachCatalogUrl),
        _client.get(ApiConfig.coachJourneyUrl),
      ]);
      _ensure(generation, owner);
      final paths = decodeListResponse(results[0], parseJourneyPath);
      var current = decodeResponse(
        results[1],
        (json) => JourneyDocument.fromJson(json, owner: owner).current,
      );
      if (current == null) {
        final local = await super.load(owner);
        _ensure(generation, owner);
        if (local != null) {
          final imported = await _client.post(
            '${ApiConfig.coachJourneyUrl}/import',
            body: journeyEnrollmentToJson(local),
          );
          _ensure(generation, owner);
          current = decodeResponse(
            imported,
            (json) => parseJourneyEnrollment(json['current']),
          );
        }
      }
      _catalogs[owner] = List.unmodifiable(paths);
      _readOnly.remove(owner);
      if (current != null) await _cache(owner, current);
      _ensure(generation, owner);
      return current;
    } on ApiException catch (error) {
      _ensure(generation, owner);
      if (!error.canUseOfflineData) rethrow;
      final cached = await super.load(owner);
      _ensure(generation, owner);
      _readOnly.add(owner);
      return cached;
    }
  }

  Future<JourneyMutation> _command(
    String owner,
    String action,
    Map<String, dynamic> body,
  ) async {
    final generation = await _session(owner);
    final response = await _client.post(
      '${ApiConfig.coachJourneyUrl}/$action',
      body: body,
    );
    _ensure(generation, owner);
    final mutation = decodeResponse(response, (json) {
      final changed = json['changed'] as bool;
      return JourneyMutation(
        current: parseJourneyEnrollment(json['current']),
        changed: changed,
      );
    });
    await _cache(owner, mutation.current);
    _ensure(generation, owner);
    _readOnly.remove(owner);
    return mutation;
  }

  @override
  Future<JourneyMutation> choose(
    String owner,
    JourneyPath path, {
    required JourneyEnrollment? expected,
  }) {
    if (owner == 'demo') return super.choose(owner, path, expected: expected);
    return _command(owner, 'choose', {
      'pathId': path.pathId,
      'contentVersion': path.contentVersion,
      'expectedEnrollmentId': expected?.enrollmentId,
    });
  }

  Map<String, dynamic> _expected(JourneyEnrollment current) => {
    'enrollmentId': current.enrollmentId,
    'revision': current.revision,
  };
  @override
  Future<JourneyMutation> pause(String owner, JourneyEnrollment current) =>
      owner == 'demo'
      ? super.pause(owner, current)
      : _command(owner, 'pause', _expected(current));
  @override
  Future<JourneyMutation> resume(String owner, JourneyEnrollment current) =>
      owner == 'demo'
      ? super.resume(owner, current)
      : _command(owner, 'resume', _expected(current));
  @override
  Future<JourneyMutation> completeStep(
    String owner,
    JourneyEnrollment current,
    String stepId,
  ) => owner == 'demo'
      ? super.completeStep(owner, current, stepId)
      : _command(
          owner,
          'steps/${Uri.encodeComponent(stepId)}/complete',
          _expected(current),
        );

  @override
  Future<void> deleteOwner(String owner) {
    _deleted.add(owner);
    _catalogs.remove(owner);
    _readOnly.remove(owner);
    return super.deleteOwner(owner);
  }
}
