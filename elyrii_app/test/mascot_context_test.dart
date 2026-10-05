import 'package:elyrii_app/core/config/mascot_animations.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/widgets/mascot_with_accessories.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/presentation/providers/chatbot_provider.dart';
import 'package:elyrii_app/features/chatbot/presentation/widgets/mascot_widget.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/widgets/mascot_peek.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/active_breathing_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/empty_chat_history.dart';

class _Chat extends ChatbotProvider {
  _Chat() : super(storage: SecureStorageService(), history: EmptyChatHistory());
  bool thinking = false;
  bool connected = true;
  final replies = <ChatMessage>[];
  @override
  bool get isTyping => thinking;
  @override
  bool get isConnected => connected;
  @override
  List<ChatMessage> get messages => replies;
  void update() => notifyListeners();
  @override
  Future<void> disconnect() async {}
}

Widget wrap(
  Widget child,
  MascotProvider mascot, {
  ChatbotProvider? chat,
  bool reduced = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: mascot),
      if (chat != null)
        ChangeNotifierProvider<ChatbotProvider>.value(value: chat),
    ],
    child: MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(body: child),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'toucher, maintien et humeur difficile ont leurs gestes propres',
    (tester) async {
      final mascot = MascotProvider();
      await tester.pumpWidget(wrap(const MascotPeek(), mascot));
      MascotWithAccessories body() =>
          tester.widget(find.byType(MascotWithAccessories));
      expect(body().animation, MascotAnimations.greet);
      await tester.longPress(find.byType(MascotPeek));
      await tester.pump();
      expect(body().animation, MascotAnimations.nuzzle);
      await tester.pumpWidget(
        wrap(const MascotPeek(selectedMood: MoodType.sad), mascot),
      );
      expect(body().animation, MascotAnimations.reassure);
      final trigger = body().animationTrigger;
      await tester.pumpWidget(
        wrap(const MascotPeek(selectedMood: MoodType.verySad), mascot),
      );
      expect(body().animation, MascotAnimations.reassure);
      expect(body().animationTrigger, greaterThan(trigger));
      await tester.pumpWidget(wrap(const SizedBox(), mascot));
      await tester.pumpWidget(wrap(const MascotPeek(), mascot));
      expect(body().animation, MascotAnimations.idle); // No repeated arrival.
      await tester.pumpWidget(const SizedBox());
      mascot.dispose();
    },
  );

  testWidgets('une réussite reçue depuis un autre onglet arrive au dashboard', (
    tester,
  ) async {
    final mascot = MascotProvider();
    await tester.pumpWidget(wrap(const MascotPeek(), mascot));
    mascot.react(MascotAnimations.celebrate);
    await tester.pump();

    final body = tester.widget<MascotWithAccessories>(
      find.byType(MascotWithAccessories),
    );
    expect(body.animation, MascotAnimations.celebrate);
    expect(body.animationTrigger, 1);

    mascot.dispose();
  });

  testWidgets(
    'le chat suit saisie, attente, réponse et déconnexion sans rejouer les notifications',
    (tester) async {
      final mascot = MascotProvider();
      final chat = _Chat();
      await tester.pumpWidget(
        wrap(
          const MascotWidget(isMinimized: true, isUserTyping: true),
          mascot,
          chat: chat,
        ),
      );
      MascotWithAccessories body() =>
          tester.widget(find.byType(MascotWithAccessories));
      expect(body().animation, MascotAnimations.attentive);
      chat.thinking = true;
      chat.update();
      await tester.pump();
      expect(body().animation, MascotAnimations.thinking);
      await tester.pumpWidget(
        wrap(const MascotWidget(isMinimized: true), mascot, chat: chat),
      );
      chat.thinking = false;
      chat.replies.add(ChatMessage.ai('Je suis là.'));
      chat.update();
      await tester.pump();
      expect(body().animation, MascotAnimations.acknowledge);
      final trigger = body().animationTrigger;
      chat.update();
      await tester.pump();
      expect(body().animationTrigger, trigger);
      chat.connected = false;
      chat.update();
      await tester.pump();
      expect(body().animation, MascotAnimations.reassure);
      await tester.pumpWidget(const SizedBox());
      mascot.dispose();
      chat.dispose();
    },
  );

  testWidgets(
    'la détection de crise dans le chat bascule la mascotte en posture rassurante',
    (tester) async {
      final mascot = MascotProvider();
      final chat = _Chat();
      await tester.pumpWidget(
        wrap(
          const MascotWidget(isMinimized: true, isCrisis: false),
          mascot,
          chat: chat,
        ),
      );
      MascotWithAccessories body() =>
          tester.widget(find.byType(MascotWithAccessories));
      expect(body().animation, MascotAnimations.idle);
      await tester.pumpWidget(
        wrap(
          const MascotWidget(isMinimized: true, isCrisis: true),
          mascot,
          chat: chat,
        ),
      );
      expect(body().animation, MascotAnimations.reassure);
      await tester.pumpWidget(
        wrap(
          const MascotWidget(isMinimized: true, isCrisis: false),
          mascot,
          chat: chat,
        ),
      );
      expect(body().animation, MascotAnimations.idle);
      await tester.pumpWidget(const SizedBox());
      mascot.dispose();
      chat.dispose();
    },
  );

  testWidgets(
    'une fin de méditation prépare le geste settle pour le dashboard',
    (tester) async {
      final mascot = MascotProvider();
      await tester.pumpWidget(wrap(const MascotPeek(), mascot));
      mascot.react(MascotAnimations.settle);
      await tester.pump();
      final body = tester.widget<MascotWithAccessories>(
        find.byType(MascotWithAccessories),
      );
      expect(body.animation, MascotAnimations.settle);
      expect(body.animationTrigger, 1);
      mascot.dispose();
    },
  );

  for (final type in BreathingType.values) {
    testWidgets(
      '${type.name}: souffle synchronisé, pause exacte et rétention',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1000);
        tester.view.devicePixelRatio = 1;
        final mascot = MascotProvider();
        final controller = MeditationController()..setBreathingType(type);
        await controller.startSession();
        await tester.pumpWidget(
          wrap(
            ActiveBreathingView(controller: controller, onRequestExit: () {}),
            mascot,
          ),
        );
        final breath = tester
            .widget<MascotWithAccessories>(find.byType(MascotWithAccessories))
            .breathProgress!;
        await tester.pump(const Duration(milliseconds: 1500));
        expect(breath.value, greaterThan(0));
        expect(breath.value, lessThan(1));
        controller.pauseSession();
        final held = breath.value;
        await tester.pump(const Duration(seconds: 2));
        expect(breath.value, held);
        controller.resumeSession();
        await tester.pump(Duration(seconds: controller.phaseSecondsRemaining));
        await tester.pump();
        expect(controller.currentPhaseIndex, 1);
        expect(breath.value, 1);
        if (controller.currentPhase.action == BreathAction.hold) {
          await tester.pump(const Duration(seconds: 1));
          expect(breath.value, 1);
        }
        await tester.pumpWidget(
          wrap(
            ActiveBreathingView(controller: controller, onRequestExit: () {}),
            mascot,
            reduced: true,
          ),
        );
        expect(breath.value, .5);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        mascot.dispose();
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      },
    );
  }
}
