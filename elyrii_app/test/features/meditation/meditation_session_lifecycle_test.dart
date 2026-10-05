import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/meditation/data/models/meditation_session_model.dart';
import 'package:elyrii_app/features/meditation/data/repositories/meditation_repository.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';

class SessionRepository extends MeditationRepository {
  SessionRepository()
    : super(client: ApiClient(storage: SecureStorageService()));
  final pending = Completer<MeditationSessionModel>();
  String? requestedType;
  int? requestedMinutes;
  final completedMoods = <String?>[];
  final canceled = <String>[];
  final session = MeditationSessionModel(
    id: 'session-7',
    type: 'body-scan',
    durationMinutes: 7,
    status: 'STARTED',
    createdAt: DateTime(2026),
  );

  @override
  Future<MeditationSessionModel> startSession({
    required String type,
    required int durationMinutes,
    String? moodBefore,
  }) {
    requestedType = type;
    requestedMinutes = durationMinutes;
    return pending.future;
  }

  @override
  Future<MeditationSessionModel> completeSession({
    required String sessionId,
    String? moodBefore,
    String? moodAfter,
    String? notes,
  }) async {
    completedMoods.add(moodAfter);
    return session;
  }

  @override
  Future<MeditationSessionModel> cancelSession(String sessionId) async {
    canceled.add(sessionId);
    return session;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SessionRepository repository;
  late MeditationController controller;
  setUp(() {
    repository = SessionRepository();
    controller = MeditationController(repository: repository)
      ..setExercise(
        MeditationExercises.all.firstWhere((e) => e.id == 'body-scan'),
      )
      ..setDuration(7);
  });
  tearDown(() => controller.dispose());

  test(
    'identifiant et durée libres envoyés, fin enregistrée avant le ressenti',
    () async {
      final starting = controller.startSession();
      expect(repository.requestedType, 'body-scan');
      expect(repository.requestedMinutes, 7);
      repository.pending.complete(repository.session);
      await starting;
      await controller.stopSession(finished: true);
      expect(repository.completedMoods, [null]);
      await controller.selectMood(2, 'happy');
      expect(repository.completedMoods, [null, 'happy']);
    },
  );

  test('une réponse tardive après interruption est annulée', () async {
    final starting = controller.startSession();
    await controller.stopSession();
    repository.pending.complete(repository.session);
    await starting;
    expect(controller.isSetup, isTrue);
    expect(controller.backendSessionId, isNull);
    expect(repository.canceled, ['session-7']);
    expect(repository.completedMoods, isEmpty);
  });

  test(
    'une courte séance terminée avant la réponse est comptabilisée',
    () async {
      final starting = controller.startSession();
      await controller.stopSession(finished: true);
      repository.pending.complete(repository.session);
      await starting;
      await Future<void>.delayed(Duration.zero);
      expect(controller.isFinished, isTrue);
      expect(repository.completedMoods, [null]);
    },
  );
  test(
    'une séance finie reste comptabilisée après retour au catalogue',
    () async {
      final starting = controller.startSession();
      await controller.stopSession(finished: true);
      await controller.selectMood(2, 'happy');
      controller.resetToSetup();
      repository.pending.complete(repository.session);
      await starting;
      expect(controller.isSetup, isTrue);
      expect(controller.backendSessionId, isNull);
      expect(repository.completedMoods, ['happy']);
      expect(repository.canceled, isEmpty);
    },
  );
}
