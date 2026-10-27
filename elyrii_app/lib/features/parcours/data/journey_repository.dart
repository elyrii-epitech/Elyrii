import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/content_cipher.dart';
import '../domain/journey.dart';
import 'journey_catalog.dart';
import 'journey_parser.dart';

final class JourneyMutation {
  final JourneyEnrollment current;
  final bool changed;

  const JourneyMutation({required this.current, required this.changed});
}

final class JourneyCommandException implements Exception {
  final String message;

  const JourneyCommandException(this.message);
}

class JourneyRepository {
  final ContentCipher _cipher;
  final SharedPreferences? _preferences;
  final DateTime Function() _now;
  final Set<String> _deletedOwners = {};
  Future<void> _writes = Future<void>.value();

  JourneyRepository({
    required this._cipher,
    this._preferences,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  List<JourneyPath> get catalog => journeyCatalog;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? await SharedPreferences.getInstance();

  String _key(String owner) => 'journey_progress_${Uri.encodeComponent(owner)}';

  Future<JourneyEnrollment?> load(String owner) async {
    await _writes;
    if (_deletedOwners.contains(owner)) {
      throw const JourneyCommandException(
        'Les données de ce compte ont été supprimées.',
      );
    }
    final prefs = await _prefs;
    await prefs.reload();
    final encrypted = prefs.getString(_key(owner));
    if (encrypted == null) return null;
    final clear = await _cipher.open(owner, encrypted, purpose: 'journey:v1');
    final current = JourneyDocument.fromJson(
      jsonDecode(clear),
      owner: owner,
    ).current;
    if (current == null) return null;
    final path = refreshedJourneyCopy(current.path);
    if (identical(path, current.path)) return current;
    return JourneyEnrollment(
      enrollmentId: current.enrollmentId,
      path: path,
      status: current.status,
      completedStepCount: current.completedStepCount,
      revision: current.revision,
      startedAt: current.startedAt,
      updatedAt: current.updatedAt,
      completedAt: current.completedAt,
    );
  }

  Future<Map<String, Object?>?> exportOwner(String owner) async {
    final current = await load(owner);
    return current == null
        ? null
        : JourneyDocument(owner: owner, current: current).toJson();
  }

  Future<JourneyMutation> choose(
    String owner,
    JourneyPath path, {
    required JourneyEnrollment? expected,
  }) async {
    if (expected != null &&
        expected.path.pathId == path.pathId &&
        expected.path.contentVersion == path.contentVersion) {
      return JourneyMutation(current: expected, changed: false);
    }
    final chosen = catalog
        .where(
          (candidate) =>
              candidate.pathId == path.pathId &&
              candidate.contentVersion == path.contentVersion,
        )
        .firstOrNull;
    if (chosen == null) {
      throw const JourneyCommandException(
        'Ce programme n’est plus disponible. Actualise la liste.',
      );
    }
    final now = _now().toUtc();
    final enrollment = JourneyEnrollment(
      enrollmentId: const Uuid().v4(),
      path: chosen,
      status: JourneyStatus.active,
      completedStepCount: 0,
      revision: 1,
      startedAt: now,
      updatedAt: now,
      completedAt: null,
    );
    await _persist(owner, enrollment);
    return JourneyMutation(current: enrollment, changed: true);
  }

  Future<JourneyMutation> pause(String owner, JourneyEnrollment current) async {
    if (current.status == JourneyStatus.paused) {
      return JourneyMutation(current: current, changed: false);
    }
    if (current.status == JourneyStatus.completed) {
      throw const JourneyCommandException(
        'Ce programme est terminé. Tu peux en choisir un autre.',
      );
    }
    return _change(owner, current, status: JourneyStatus.paused);
  }

  Future<JourneyMutation> resume(
    String owner,
    JourneyEnrollment current,
  ) async {
    if (current.status == JourneyStatus.active) {
      return JourneyMutation(current: current, changed: false);
    }
    if (current.status == JourneyStatus.completed) {
      throw const JourneyCommandException(
        'Ce programme est terminé. Tu peux en choisir un autre.',
      );
    }
    return _change(owner, current, status: JourneyStatus.active);
  }

  Future<JourneyMutation> completeStep(
    String owner,
    JourneyEnrollment current,
    String stepId,
  ) async {
    final index = current.path.steps.indexWhere(
      (step) => step.stepId == stepId,
    );
    if (index >= 0 && index < current.completedStepCount) {
      return JourneyMutation(current: current, changed: false);
    }
    if (current.status == JourneyStatus.paused) {
      throw const JourneyCommandException(
        'Reprends ce programme avant de valider une étape.',
      );
    }
    if (current.status == JourneyStatus.completed) {
      throw const JourneyCommandException('Ce programme est déjà terminé.');
    }
    if (index != current.completedStepCount) {
      throw const JourneyCommandException(
        'Seule l’étape en cours peut être validée.',
      );
    }
    final count = current.completedStepCount + 1;
    return _change(
      owner,
      current,
      status: count == current.path.steps.length
          ? JourneyStatus.completed
          : JourneyStatus.active,
      count: count,
    );
  }

  Future<JourneyMutation> _change(
    String owner,
    JourneyEnrollment current, {
    required JourneyStatus status,
    int? count,
  }) async {
    final clock = _now().toUtc();
    final updatedAt = clock.isBefore(current.updatedAt)
        ? current.updatedAt
        : clock;
    final next = JourneyEnrollment(
      enrollmentId: current.enrollmentId,
      path: current.path,
      status: status,
      completedStepCount: count ?? current.completedStepCount,
      revision: current.revision + 1,
      startedAt: current.startedAt,
      updatedAt: updatedAt,
      completedAt: status == JourneyStatus.completed
          ? current.completedAt ?? updatedAt
          : null,
    );
    await _persist(owner, next);
    return JourneyMutation(current: next, changed: true);
  }

  Future<void> _persist(String owner, JourneyEnrollment enrollment) {
    if (_deletedOwners.contains(owner)) {
      return Future.error(
        const JourneyCommandException(
          'Les données de ce compte ont été supprimées.',
        ),
      );
    }
    final write = _writes.then((_) async {
      final clear = jsonEncode(
        JourneyDocument(owner: owner, current: enrollment).toJson(),
      );
      final encrypted = await _cipher.seal(owner, clear, purpose: 'journey:v1');
      final prefs = await _prefs;
      if (!await prefs.setString(_key(owner), encrypted)) {
        throw StateError('Journey local storage refused the write.');
      }
    });
    _writes = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return write;
  }

  Future<void> deleteOwner(String owner) {
    _deletedOwners.add(owner);
    final deletion = _writes.then((_) async {
      final prefs = await _prefs;
      if (!await prefs.remove(_key(owner))) {
        throw StateError('Journey local storage refused deletion.');
      }
    });
    _writes = deletion.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return deletion;
  }
}
