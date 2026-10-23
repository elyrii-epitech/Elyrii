import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/journey_repository.dart';
import '../../domain/journey.dart';

final class _JourneySession {
  final String? owner;
  final bool isDemo;
  JourneyEnrollment? current;
  String? error;
  bool isLoading = false;
  bool hasLoadedData = false;
  bool storageFailed = false;
  int pendingWrites = 0;
  int dataVersion = 0;
  Future<void>? load;

  _JourneySession({this.owner, this.isDemo = false});
}

class JourneyProvider extends ChangeNotifier {
  final JourneyRepository _repository;
  final Set<String> _deletedOwners = {};
  _JourneySession _state = _JourneySession();
  Future<void> _writes = Future<void>.value();
  bool _disposed = false;

  JourneyProvider({required this._repository});

  List<JourneyPath> get catalog =>
      _state.hasLoadedData ? _repository.catalog : const [];
  JourneyEnrollment? get current => _state.current;
  bool get isLoading => _state.isLoading;
  bool get isWriting => _state.pendingWrites != 0;
  bool get hasLoadedData => _state.hasLoadedData;
  bool get isDemo => _state.isDemo;
  String? get error => _state.error;
  bool get canWrite =>
      !_disposed &&
      _state.owner != null &&
      !_deletedOwners.contains(_state.owner) &&
      hasLoadedData &&
      !isLoading &&
      !isWriting &&
      !_state.storageFailed;

  Future<void> get flushed => _writes;

  bool _owns(_JourneySession session) =>
      !_disposed && identical(_state, session);

  void _notify(_JourneySession session) {
    if (_owns(session)) notifyListeners();
  }

  void onUserChanged({String? userId, bool isDemo = false}) {
    if (_disposed) return;
    final owner = isDemo ? 'demo' : userId;
    if (_state.owner == owner && _state.isDemo == isDemo) return;
    _state = _JourneySession(owner: owner, isDemo: isDemo);
    if (owner == null) {
      _state.error = 'Connecte-toi à un compte pour conserver un parcours sur cet appareil.';
    } else if (_deletedOwners.contains(owner)) {
      _state.error = 'Les données de ce compte ont été supprimées.';
    }
    notifyListeners();
  }

  void resetSession() {
    if (_disposed) return;
    _state = _JourneySession()..error = 'Connecte-toi à un compte pour conserver un parcours sur cet appareil.';
    notifyListeners();
  }

  Future<void> load({bool force = false}) {
    if (_disposed) return Future<void>.value();
    final session = _state;
    if (session.owner == null || _deletedOwners.contains(session.owner)) {
      session.error = session.owner == null
          ? 'Connecte-toi à un compte pour conserver un parcours sur cet appareil.'
          : 'Les données de ce compte ont été supprimées.';
      _notify(session);
      return Future<void>.value();
    }
    final existing = session.load;
    if (existing != null) return existing;
    if (session.hasLoadedData && !force) return Future<void>.value();
    final completer = Completer<void>();
    session.load = completer.future;
    session.isLoading = true;
    session.error = null;
    unawaited(_performLoad(session, completer));
    _notify(session);
    return completer.future;
  }

  Future<void> _performLoad(
    _JourneySession session,
    Completer<void> completer,
  ) async {
    final version = session.dataVersion;
    try {
      await _writes;
      if (!_owns(session)) return;
      try {
        final current = await _repository.load(session.owner!);
        if (!_owns(session) || version != session.dataVersion) return;
        session.current = current;
        session.hasLoadedData = true;
        session.storageFailed = false;
        session.error = null;
      } catch (_) {
        if (!_owns(session) || version != session.dataVersion) return;
        session.storageFailed = true;
        session.error = 'Ta progression locale n’a pas pu être lue. Réessaie sans effacer tes données.';
      }
    } finally {
      session.load = null;
      session.isLoading = false;
      _notify(session);
      completer.complete();
    }
  }

  Future<JourneyCommandResult> choose(JourneyPath path) => _enqueue(
    (owner, current) => _repository.choose(owner, path, expected: current),
    selectedPath: path,
  );

  Future<JourneyCommandResult> pause() => _enrollmentCommand(_repository.pause);

  Future<JourneyCommandResult> resume() =>
      _enrollmentCommand(_repository.resume);

  Future<JourneyCommandResult> completeStep(String stepId) {
    final requested = _state.current;
    final index = requested?.path.steps.indexWhere(
      (step) => step.stepId == stepId,
    );
    return _enrollmentCommand((owner, current) {
      if (requested != null && index != null) {
        if (index > requested.completedStepCount) {
          throw const JourneyCommandException(
            'Seule l’étape en cours peut être validée.',
          );
        }
        if (requested.status == JourneyStatus.paused &&
            index >= requested.completedStepCount) {
          throw const JourneyCommandException(
            'Reprends ce parcours avant de valider une étape.',
          );
        }
      }
      return _repository.completeStep(owner, current, stepId);
    });
  }

  Future<JourneyCommandResult> _enrollmentCommand(
    Future<JourneyMutation> Function(String, JourneyEnrollment) command,
  ) => _enqueue((owner, current) {
    if (current == null) {
      throw const JourneyCommandException('Choisis d’abord un parcours.');
    }
    return command(owner, current);
  });

  Future<JourneyCommandResult> _enqueue(
    Future<JourneyMutation> Function(String, JourneyEnrollment?) command, {
    JourneyPath? selectedPath,
  }) {
    final session = _state;
    if (_disposed ||
        session.owner == null ||
        _deletedOwners.contains(session.owner) ||
        !session.hasLoadedData ||
        session.storageFailed) {
      if (!_disposed) {
        session.error ??= 'Relis ta progression locale avant de réessayer.';
        _notify(session);
      }
      return Future.value(JourneyCommandResult.failed);
    }
    final previous = _writes;
    final enrollmentId = session.current?.enrollmentId;
    session.pendingWrites++;
    session.dataVersion++;
    session.error = null;
    final request = _performWrite(
      previous,
      session,
      enrollmentId,
      command,
      selectedPath,
    );
    _writes = request.then<void>((_) {});
    _notify(session);
    return request;
  }

  Future<JourneyCommandResult> _performWrite(
    Future<void> previous,
    _JourneySession session,
    String? enrollmentId,
    Future<JourneyMutation> Function(String, JourneyEnrollment?) command,
    JourneyPath? selectedPath,
  ) async {
    await previous;
    try {
      if (session.storageFailed) return JourneyCommandResult.failed;
      final sameChoice =
          selectedPath != null &&
          session.current?.path.pathId == selectedPath.pathId &&
          session.current?.path.contentVersion == selectedPath.contentVersion;
      if (session.current?.enrollmentId != enrollmentId && !sameChoice) {
        session.error = 'Le parcours a changé. Consulte sa nouvelle position avant de réessayer.';
        return JourneyCommandResult.failed;
      }
      final result = await command(session.owner!, session.current);
      session.current = result.current;
      session.error = null;
      if (!_owns(session)) return JourneyCommandResult.failed;
      return result.changed
          ? JourneyCommandResult.changed
          : JourneyCommandResult.unchanged;
    } on JourneyCommandException catch (error) {
      session.error = error.message;
      return JourneyCommandResult.failed;
    } catch (_) {
      session.storageFailed = true;
      session.error = 'Ta progression n’a pas pu être enregistrée sur cet appareil. Réessaie après l’avoir relue.';
      return JourneyCommandResult.failed;
    } finally {
      session.pendingWrites--;
      session.dataVersion++;
      _notify(session);
    }
  }

  Future<Map<String, Object?>?> exportOwner(String owner) async {
    await flushed;
    return _repository.exportOwner(owner);
  }

  Future<void> deleteOwner(String owner) {
    _deletedOwners.add(owner);
    if (_state.owner == owner) resetSession();
    final deletion = _writes.then((_) => _repository.deleteOwner(owner));
    _writes = deletion.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return deletion;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
