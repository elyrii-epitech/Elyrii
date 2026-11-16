import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_session_page.dart';
import 'package:elyrii_app/features/parcours/data/journey_repository.dart';
import 'package:elyrii_app/features/parcours/domain/journey.dart';
import 'package:elyrii_app/features/parcours/presentation/providers/journey_provider.dart';
import 'package:elyrii_app/features/parcours/presentation/widgets/journey_sheets.dart';
import 'package:elyrii_app/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'returning from meditation never waits for remote registration to validate a local step',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final storage = SecureStorageService();
      final requested = Completer<void>();
      final response = Completer<http.Response>();
      final api = ApiClient(
        storage: storage,
        client: MockClient((request) async {
          if (request.url.path == '/meditation/sessions/start') {
            requested.complete();
            return response.future;
          }
          return http.Response('{"message":"Service indisponible"}', 503);
        }),
      );
      addTearDown(api.dispose);
      late final JourneyProvider journey;
      await tester.runAsync(() async {
        journey = JourneyProvider(
          repository: JourneyRepository(cipher: ContentCipher(storage)),
        );
        await storage.saveAccessToken('local-test-token');
        await storage.saveUserId('alice');
        journey.onUserChanged(userId: 'alice');
        await journey.load();
        await journey.choose(
          journey.catalog.firstWhere((path) => path.topic == JourneyTopic.calm),
        );
      });
      addTearDown(journey.dispose);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => showJourneyStep(context, journey),
                child: const Text('Lire l’étape'),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.meditationSession,
            builder: (_, state) => MeditationSessionPage(
              controller: state.extra! as MeditationController,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ApiClient>.value(value: api),
            ChangeNotifierProvider(create: (_) => MascotProvider()),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lire l’étape'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Ouvrir Souffle conscient')),
      );
      await tester.tap(find.text('Ouvrir Souffle conscient'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer · 3 min'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => requested.future.timeout(const Duration(seconds: 5)),
      );
      await tester.tap(find.byTooltip('Fermer la séance'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Interrompre'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      try {
        expect(journey.current!.completedStepCount, 0);
        final complete = find.widgetWithText(FilledButton, 'Terminer l’étape');
        expect(tester.widget<FilledButton>(complete).onPressed, isNotNull);
        await Scrollable.ensureVisible(tester.element(complete));
        await tester.runAsync(() async {
          await tester.tap(complete);
          await journey.flushed;
        });
        await tester.pumpAndSettle();
        expect(journey.current!.completedStepCount, 1);
        expect(response.isCompleted, isFalse);
      } finally {
        response.complete(
          http.Response('{"message":"Service indisponible"}', 503),
        );
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
