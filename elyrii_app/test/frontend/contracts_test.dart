import 'package:elyrii_app/core/config/app_config.dart';
import 'package:elyrii_app/core/data/json_contract.dart';
import 'package:elyrii_app/features/auth/data/models/user_model.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_appearance.dart';
import 'package:elyrii_app/features/mascot/data/models/mascot_model.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('release environments require a real HTTPS endpoint', () {
    for (final env in [AppEnvironment.staging, AppEnvironment.production]) {
      for (final url in [
        null,
        'http://api.example.test',
        'https://localhost:3001',
        'https://user:password@api.example.test',
      ]) {
        expect(
          () => AppConfig.resolveGateway(environment: env, gatewayUrl: url),
          throwsFormatException,
        );
      }
      expect(
        AppConfig.resolveGateway(
          environment: env,
          gatewayUrl: 'https://api.example.test/',
        ),
        'https://api.example.test',
      );
    }
  });
  test(
    'required IDs and dates fail parsing instead of creating empty resources',
    () {
      expect(
        () => UserModel.fromJson({'email': 'alice@example.test'}),
        throwsFormatException,
      );
      expect(
        () => JournalEntryModel.fromJson({
          'id': 'entry',
          'userId': 'alice',
          'createdAt': 'broken',
        }),
        throwsFormatException,
      );
      expect(() => requiredJsonDate(null, 'createdAt'), throwsFormatException);
    },
  );
  test(
    'mascot snapshots detach collections and preserve equality/hash stability',
    () {
      final colors = {'body': '#12AB9F'};
      final accessories = ['hat'];
      final value = MascotModel(
        baseModelPath: 'model.glb',
        equippedCosmetics: accessories,
        appearance: MascotAppearance(colors: colors),
      );
      final originalHash = value.hashCode;
      colors['body'] = '#FFFFFF';
      accessories.add('scarf');
      expect(value.equippedCosmetics, ['hat']);
      expect(value.appearance.colors['body'], '#12AB9F');
      expect(value.hashCode, originalHash);
      expect(
        () => value.equippedCosmetics.add('other'),
        throwsUnsupportedError,
      );
      expect(
        () => value.appearance.colors['body'] = '#000000',
        throwsUnsupportedError,
      );
    },
  );
  test(
    'delayed timer callbacks advance real elapsed seconds and breath phases',
    () async {
      var elapsed = Duration.zero;
      final controller = MeditationController(elapsed: () => elapsed)
        ..setDuration(1)
        ..setBreathingType(BreathingType.carree);
      addTearDown(controller.dispose);
      await controller.startSession();
      elapsed = const Duration(seconds: 9);
      controller.synchronizeClock();
      expect(controller.remainingSeconds, 51);
      expect(controller.currentPhaseIndex, 2);
      controller.pauseSession();
      elapsed = const Duration(seconds: 109);
      controller.synchronizeClock();
      expect(controller.remainingSeconds, 51);
      controller.resumeSession();
      elapsed = const Duration(seconds: 160);
      controller.synchronizeClock();
      expect(controller.isFinished, isTrue);
      expect(controller.remainingSeconds, 0);
    },
  );
}
