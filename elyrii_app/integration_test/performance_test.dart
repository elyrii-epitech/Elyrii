import 'dart:io';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/app/router/app_routes.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_message.dart';
import 'package:elyrii_app/features/chatbot/data/entities/chat_session.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/mascot/presentation/pages/mascot_customization_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'support/native_app.dart';

/// Use --profile on physical Android/iOS hardware; raster metrics in headless
/// browsers or widget tests do not substitute for native GPU measurements.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'demo session initialization and Flutter dashboard frame timings',
    (tester) async {
      expect(
        kProfileMode,
        isTrue,
        reason: 'Use --profile on physical hardware.',
      );
      final startup = Stopwatch()..start();
      await startDemoApp(tester);
      startup.stop();
      final timings = <FrameTiming>[];
      SchedulerBinding.instance.addTimingsCallback(timings.addAll);
      try {
        await binding.traceAction(() async {
          for (var i = 0; i < 60; i++) {
            await tester.pump(const Duration(milliseconds: 250));
          }
        }, reportKey: 'dashboard_3d');
      } finally {
        SchedulerBinding.instance.removeTimingsCallback(timings.addAll);
      }
      double percentile(List<int> samples) {
        if (samples.isEmpty) return 0;
        samples.sort();
        return samples[((samples.length - 1) * .95).round()] / 1000;
      }

      expect(
        timings,
        isNotEmpty,
        reason: 'Run this profile on a physical device.',
      );
      binding.reportData ??= {};
      binding.reportData!['measurement_scope'] = 'Demo session initialization after test process startup; Flutter frames only. Excludes OS cold launch, WebGL GPU and native WebView memory.';
      binding.reportData!['dashboard_ready_ms'] = startup.elapsedMilliseconds;
      final budget = double.parse(
        const String.fromEnvironment(
          'ELYRII_FRAME_BUDGET_MS',
          defaultValue: '16.7',
        ),
      );
      final buildP95 = percentile(
        timings.map((f) => f.buildDuration.inMicroseconds).toList(),
      );
      final rasterP95 = percentile(
        timings.map((f) => f.rasterDuration.inMicroseconds).toList(),
      );
      expect(
        buildP95,
        lessThanOrEqualTo(budget),
        reason: 'Flutter build p95 exceeds the declared device budget',
      );
      expect(
        rasterP95,
        lessThanOrEqualTo(budget),
        reason: 'Flutter raster p95 exceeds the declared device budget',
      );
      binding.reportData!['frame_budget_ms'] = budget;
      binding.reportData!['frames'] = {
        'count': timings.length,
        'build_p95_ms': percentile(
          timings.map((f) => f.buildDuration.inMicroseconds).toList(),
        ),
        'raster_p95_ms': percentile(
          timings.map((f) => f.rasterDuration.inMicroseconds).toList(),
        ),
      };
    },
  );

  testWidgets('native screen navigation, long chat and backward scrolling', (
    tester,
  ) async {
    expect(
      kProfileMode,
      isTrue,
      reason: 'Run this on a physical device with --profile.',
    );
    expect(Platform.isAndroid || Platform.isIOS, isTrue);
    await startDemoApp(tester);
    final context = tester.element(find.byType(DashboardPage));
    final services = context.read<AppDependencies>();
    expect(
      services.auth.isDemoSession,
      isTrue,
      reason: 'Use a demo session for synthetic native performance fixtures.',
    );
    final router = GoRouter.of(context);
    final owner = services.auth.accountId!;
    const sessionId = 'elyrii-performance-fixture';
    final now = DateTime.now();
    final session = ChatSession(
      id: sessionId,
      title: 'Synthetic performance fixture',
      createdAt: now,
      updatedAt: now,
      messages: const [],
    );
    // Fixture writes and twenty history reads are outside the measured UI
    // interval. Delete only this synthetic conversation after the test.
    try {
      await services.history.delete(owner, sessionId);
      for (var i = 0; i < 1100; i++) {
        await services.history.append(
          owner,
          session,
          ChatMessage(
            id: '$sessionId-$i',
            content:
                'Synthetic message $i. ${'A calm conversation. ' * (1 + i % 7)}',
            isUser: i.isEven,
            timestamp: now.add(Duration(seconds: i)),
          ),
        );
      }
      await services.chat.onUserChanged(null);
      await services.chat.onUserChanged(owner);
      expect(services.chat.activeSessionId, sessionId);
      for (var page = 1; page < 20; page++) {
        await services.chat.loadOlderMessages();
      }
      expect(services.chat.messages.length, 1000);
      final routes = <String, ({String path, Type page})>{
        'dashboard': (path: AppRoutes.dashboard, page: DashboardPage),
        'garden': (path: AppRoutes.challenges, page: ChallengesPage),
        'journal': (path: AppRoutes.journal, page: JournalPage),
        'meditation': (path: AppRoutes.meditation, page: MeditationPage),
        'coach': (path: AppRoutes.coach, page: CoachPage),
        'chat': (path: AppRoutes.chatbot, page: ChatbotPage),
        'settings': (path: AppRoutes.settings, page: SettingsPage),
        'reviews': (path: AppRoutes.reviews, page: ReviewsPage),
        'mascot': (
          path: AppRoutes.mascotCustomization,
          page: MascotCustomizationPage,
        ),
      };
      final screens = <String, Object>{};
      for (final entry in routes.entries) {
        final frames = <FrameTiming>[];
        SchedulerBinding.instance.addTimingsCallback(frames.addAll);
        final watch = Stopwatch()..start();
        double? openedMs;
        try {
          await binding.traceAction(() async {
            router.go(entry.value.path);
            await waitFor(
              tester,
              () => find.byType(entry.value.page).evaluate().isNotEmpty,
              description: '${entry.key} to mount',
            );
            await tester.pump();
            openedMs = watch.elapsedMicroseconds / 1000;
            final scrollables = find.descendant(
              of: find.byType(entry.value.page),
              matching: find.byType(Scrollable),
            );
            if (scrollables.evaluate().isNotEmpty) {
              for (var drag = 0; drag < 20; drag++) {
                await tester.drag(
                  scrollables.first,
                  Offset(0, entry.key == 'chat' ? 250 : -250),
                );
                await tester.pump(const Duration(milliseconds: 16));
              }
            }
            await tester.pump(const Duration(seconds: 1));
          }, reportKey: 'screen_${entry.key}');
        } finally {
          SchedulerBinding.instance.removeTimingsCallback(frames.addAll);
        }
        double p95(Iterable<Duration> samples) {
          final values = samples.map((d) => d.inMicroseconds).toList()..sort();
          return values.isEmpty
              ? 0
              : values[((values.length - 1) * .95).round()] / 1000;
        }

        expect(
          frames,
          isNotEmpty,
          reason:
              'The device must report actual Flutter frames for ${entry.key}.',
        );

        screens[entry.key] = {
          'route_mount_ms': openedMs,
          'frames': frames.length,
          'build_p95_ms': p95(frames.map((f) => f.buildDuration)),
          'raster_p95_ms': p95(frames.map((f) => f.rasterDuration)),
        };
      }
      router.go(AppRoutes.chatbot);
      await tester.pump();
      final before = services.chat.messages.length;
      final pageWatch = Stopwatch()..start();
      await services.chat.loadOlderMessages();
      await tester.pump();
      binding.reportData ??= {};
      binding.reportData!['native_screens'] = screens;
      binding.reportData!['older_chat_page'] = {
        'elapsed_ms': pageWatch.elapsedMicroseconds / 1000,
        'messages_loaded': services.chat.messages.length - before,
      };
      binding.reportData!['native_screen_scope'] =
          'In-process route mount and Flutter build/raster frames in a demo session. '
          'Synthetic 1,100-message history, 1,000 loaded before timing. Excludes fixture preparation, '
          'OS cold launch, production network, native WebView/WebGL GPU, memory and energy.';
    } finally {
      await services.chat.onUserChanged(null);
      await services.history.delete(owner, sessionId);
    }
  });
}
