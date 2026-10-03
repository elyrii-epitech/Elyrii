import 'package:flutter_test/flutter_test.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeditationController', () {
    late MeditationController controller;

    setUp(() {
      controller = MeditationController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('état initial conforme par défaut', () {
      expect(controller.isSetup, isTrue);
      expect(controller.selectedDurationMinutes, equals(5));
      expect(controller.remainingSeconds, equals(300));
      expect(controller.selectedBreathingType, isNull);
      expect(controller.completedCycles, equals(0));
    });

    test('démarrage sans intention choisie est un no-op', () async {
      await controller.startSession();

      expect(controller.isSetup, isTrue);
      expect(controller.isRunning, isFalse);
    });

    test('changement de durée et de type en mode setup', () {
      controller.setDuration(10);
      expect(controller.selectedDurationMinutes, equals(10));
      expect(controller.remainingSeconds, equals(600));

      controller.setBreathingType(BreathingType.carree);
      expect(controller.selectedBreathingType, equals(BreathingType.carree));
    });

    test('durées libres valides et refus des valeurs hors limites', () {
      for (final minutes in [1, 7, 45, 180]) {
        controller.setDuration(minutes);
        expect(controller.remainingSeconds, minutes * 60);
      }
      for (final invalid in [0, -1, 181]) {
        expect(() => controller.setDuration(invalid), throwsRangeError);
      }
      expect(controller.selectedDurationMinutes, 180);
    });

    test('chaque exercice termine exactement à la durée choisie', () async {
      for (final exercise in MeditationExercises.all) {
        for (final minutes in [1, 7]) {
          controller.resetToSetup();
          controller.setExercise(exercise);
          controller.setDuration(minutes);
          await controller.startSession();
          for (var second = 0; second < minutes * 60 - 1; second++) {
            controller.tick();
          }
          expect(controller.isRunning, isTrue, reason: exercise.id);
          expect(controller.remainingSeconds, 1);
          controller.tick();
          expect(controller.isFinished, isTrue, reason: exercise.id);
          expect(controller.remainingSeconds, 0);
          if (!exercise.isBreathing) {
            expect(
              controller.currentGuidanceStepIndex,
              exercise.steps.length - 1,
            );
          }
        }
      }
    });

    test(
      'les étapes guidées évoluent et restent figées pendant une pause',
      () async {
        final exercise = MeditationExercises.all.firstWhere(
          (e) => e.id == 'body-scan',
        );
        controller.setExercise(exercise);
        controller.setDuration(7);
        await controller.startSession();
        expect(controller.currentGuidanceStep.title, 'S’installer');
        for (var i = 0; i < 100; i++) {
          controller.tick();
        }
        expect(controller.currentGuidanceStepIndex, greaterThan(0));
        controller.pauseSession();
        final step = controller.currentGuidanceStepIndex;
        final remaining = controller.remainingSeconds;
        for (var i = 0; i < 100; i++) {
          controller.tick();
        }
        expect(controller.remainingSeconds, remaining);
        expect(controller.currentGuidanceStepIndex, step);
        controller.resumeSession();
        controller.tick();
        expect(controller.remainingSeconds, remaining - 1);
      },
    );

    test('le 4–7–8 rejoint le souffle libre après quatre cycles', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      controller.setDuration(7);
      await controller.startSession();
      for (var i = 0; i < 76; i++) {
        controller.tick();
      }
      expect(controller.completedCycles, 4);
      expect(controller.isBreathingRecovery, isTrue);
      expect(controller.currentPhase.label, 'Souffle libre');
      for (var i = 0; i < 20; i++) {
        controller.tick();
      }
      expect(controller.completedCycles, 4);
      expect(controller.remainingSeconds, 324);
    });

    test('démarrage de session initialise la première phase', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      await controller.startSession();

      expect(controller.isRunning, isTrue);
      expect(controller.currentPhaseIndex, equals(0));
      expect(controller.currentPhase.label, equals('Inspire'));
      expect(controller.phaseSecondsRemaining, equals(4));
    });

    test(
      'transition exacte des phases (4-7-8 : inspire -> retiens -> expire)',
      () async {
        controller.setBreathingType(BreathingType.relaxation478);
        await controller.startSession();

        // Phase 0 : Inspire (4 secondes)
        controller.tick(); // 3s
        expect(controller.currentPhaseIndex, equals(0));
        expect(controller.phaseSecondsRemaining, equals(3));

        controller.tick(); // 2s
        controller.tick(); // 1s
        expect(controller.currentPhaseIndex, equals(0));

        // 4e tick : bascule vers Phase 1 (Retiens, 7s)
        controller.tick();
        expect(controller.currentPhaseIndex, equals(1));
        expect(controller.currentPhase.label, equals('Retiens'));
        expect(controller.phaseSecondsRemaining, equals(7));

        // 7 ticks dans Retiens
        for (int i = 0; i < 6; i++) {
          controller.tick();
        }
        expect(controller.currentPhaseIndex, equals(1));

        // Dernier tick de Retiens : bascule vers Phase 2 (Expire, 8s)
        controller.tick();
        expect(controller.currentPhaseIndex, equals(2));
        expect(controller.currentPhase.label, equals('Expire'));
        expect(controller.phaseSecondsRemaining, equals(8));
      },
    );

    test('complétion d\'un cycle incrémente completedCycles', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      await controller.startSession();

      // Cycle complet 4-7-8 = 4 + 7 + 8 = 19 secondes (ticks)
      for (int i = 0; i < 19; i++) {
        controller.tick();
      }

      expect(controller.completedCycles, equals(1));
      expect(controller.currentPhaseIndex, equals(0)); // Retour à Inspire
    });

    test('mise en pause et reprise de la session', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      await controller.startSession();
      expect(controller.isRunning, isTrue);

      controller.pauseSession();
      expect(controller.isPaused, isTrue);

      controller.resumeSession();
      expect(controller.isRunning, isTrue);
    });

    test('arrêt anticipé réinitialise vers setup', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      await controller.startSession();
      await controller.stopSession(finished: false);

      expect(controller.isSetup, isTrue);
      expect(controller.remainingSeconds, equals(300));
    });

    test('fin de séance normale passe en finished', () async {
      controller.setBreathingType(BreathingType.relaxation478);
      await controller.startSession();
      await controller.stopSession(finished: true);

      expect(controller.isFinished, isTrue);
    });
  });
}
