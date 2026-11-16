import 'dart:math';

import 'package:elyrii_app/core/config/mascot_animations.dart';
import 'package:elyrii_app/core/services/mascot_motion_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MascotMotionController motion;
  setUp(() => motion = MascotMotionController(random: Random(12)));
  tearDown(() => motion.dispose());

  testWidgets('un geste se termine et le même événement ne le redémarre pas', (
    tester,
  ) async {
    motion.setAnimation(MascotAnimations.greet, trigger: 1);
    motion.setPlaybackEnabled(true);
    expect(motion.current, MascotAnimations.greet);
    await tester.pump(MascotAnimations.greet.duration);
    expect(motion.current, MascotAnimations.idle);
    final revision = motion.revision;
    motion.setAnimation(MascotAnimations.greet, trigger: 1);
    expect(motion.revision, revision);
    motion.setAnimation(MascotAnimations.greet, trigger: 2);
    expect(motion.current, MascotAnimations.greet);
    motion.setPlaybackEnabled(false);
  });

  testWidgets('une réponse rapide annule la réflexion différée', (
    tester,
  ) async {
    motion.setPlaybackEnabled(true);
    motion.setAnimation(MascotAnimations.thinking);
    await tester.pump(const Duration(milliseconds: 250));
    motion.setAnimation(MascotAnimations.acknowledge);
    await tester.pump(const Duration(milliseconds: 200));
    expect(motion.current, MascotAnimations.acknowledge);
    motion.setPlaybackEnabled(false);
  });

  testWidgets(
    'la réflexion interrompt le salut et se calme après deux boucles',
    (tester) async {
      motion.setAnimation(MascotAnimations.greet);
      motion.setPlaybackEnabled(true);
      await tester.pump(const Duration(seconds: 1));
      motion.setAnimation(MascotAnimations.thinking);
      await tester.pump(const Duration(milliseconds: 400));
      expect(motion.current, MascotAnimations.thinking);
      await tester.pump(const Duration(seconds: 3));
      expect(motion.current, MascotAnimations.thinking);
      await tester.pump(const Duration(milliseconds: 5800));
      expect(motion.current, MascotAnimations.idle);
      await tester.pump(const Duration(seconds: 35));
      expect(motion.current, MascotAnimations.idle);
      motion.setPlaybackEnabled(false);
    },
  );

  testWidgets(
    'une interruption suspend les timers et consomme les gestes périmés',
    (tester) async {
      motion.setAnimation(MascotAnimations.celebrate);
      motion.setPlaybackEnabled(true);
      await tester.pump(const Duration(seconds: 1));
      motion.setPlaybackEnabled(false);
      motion.setAnimation(MascotAnimations.nuzzle, trigger: 2);
      final revision = motion.revision;
      await tester.pump(const Duration(minutes: 2));
      expect(motion.current, MascotAnimations.holdPose);
      expect(motion.revision, revision);
      motion.setPlaybackEnabled(true);
      expect(motion.current, MascotAnimations.idle);
      motion.setPlaybackEnabled(false);
    },
  );

  testWidgets(
    'le repos varie entre dix et quinze secondes sans répéter le même geste',
    (tester) async {
      const calmGestures = [
        MascotAnimations.curious,
        MascotAnimations.cozy,
        MascotAnimations.stretch,
        MascotAnimations.acknowledge,
        MascotAnimations.nuzzle,
        MascotAnimations.delight,
      ];
      MascotAnimation? previous;
      motion.setPlaybackEnabled(true);
      for (var cycle = 0; cycle < 18; cycle++) {
        expect(motion.current, MascotAnimations.idle);
        await tester.pump(const Duration(seconds: 9));
        expect(motion.current, MascotAnimations.idle);
        for (var second = 10; second <= 15; second++) {
          await tester.pump(const Duration(seconds: 1));
          if (motion.current != MascotAnimations.idle) break;
        }
        final gesture = motion.current;
        expect(calmGestures, contains(gesture));
        expect(gesture, isNot(previous));
        previous = gesture;
        await tester.pump(gesture.duration);
      }
      expect(motion.current, MascotAnimations.idle);
      motion.setPlaybackEnabled(false);
    },
  );

  testWidgets('une écoute interrompt immédiatement une variation du repos', (
    tester,
  ) async {
    motion.setPlaybackEnabled(true);
    for (var second = 1; second <= 15; second++) {
      await tester.pump(const Duration(seconds: 1));
      if (motion.current != MascotAnimations.idle) break;
    }
    expect(motion.current, isNot(MascotAnimations.idle));
    motion.setAnimation(MascotAnimations.attentive);
    expect(motion.current, MascotAnimations.attentive);
    await tester.pump(const Duration(minutes: 2));
    expect(motion.current, MascotAnimations.attentive);
    motion.setPlaybackEnabled(false);
  });
}
