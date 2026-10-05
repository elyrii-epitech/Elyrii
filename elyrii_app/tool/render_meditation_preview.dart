// flutter test tool/render_meditation_preview.dart --no-pub
// Uses production Flutter widgets, the real dock, native wheels and Poppins.
// Mascot3DViewer uses its existing assets/mascotte.png fallback in widget tests;
// these previews verify layout and glass surfaces, not the native 3D renderer.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:elyrii_app/app/router/app_shell.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/controllers/meditation_controller.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_catalog_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _boundaryKey = ValueKey('meditation-preview');

Future<void> _capture(WidgetTester tester, String name) async {
  expect(tester.takeException(), isNull);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundaryKey),
  );
  await tester.runAsync(() async {
    final screenshot = await boundary.toImage(pixelRatio: 2);
    final data = await screenshot.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('../art/meditation');
    await directory.create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(data!.buffer.asUint8List());
    screenshot.dispose();
  });
  expect(tester.takeException(), isNull);
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final nativeFontFile = File('/System/Library/Fonts/SFNS.ttf');
    if (!nativeFontFile.existsSync()) {
      throw StateError(
        'This renderer needs the macOS SF system font for the native picker.',
      );
    }
    final nativeFont = FontLoader('CupertinoSystemText')
      ..addFont(
        Future.value(ByteData.sublistView(nativeFontFile.readAsBytesSync())),
      );
    await nativeFont.load();
  });

  for (final variant in [
    (
      name: 'meditation-light',
      size: const Size(390, 844),
      scale: 1.0,
      dark: false,
    ),
    (
      name: 'meditation-dark',
      size: const Size(390, 844),
      scale: 1.0,
      dark: true,
    ),
    (
      name: 'meditation-compact-text150',
      size: const Size(320, 568),
      scale: 1.5,
      dark: false,
    ),
  ]) {
    testWidgets('export ${variant.name}', (tester) async {
      tester.view.physicalSize = variant.size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // This executable is a Flutter widget-test renderer and uses isolated storage.
      // ignore: invalid_use_of_visible_for_testing_member
      SharedPreferences.setMockInitialValues({});
      // ignore: invalid_use_of_visible_for_testing_member
      FlutterSecureStorage.setMockInitialValues({});
      final controller = MeditationController();
      addTearDown(controller.dispose);
      final router = GoRouter(
        initialLocation: '/branch3',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppShell(navigationShell: shell),
            branches: [
              for (var i = 0; i < 6; i++)
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/branch$i',
                      builder: (_, _) => i == 3
                          ? Scaffold(
                              body: MeditationCatalogView(
                                controller: controller,
                              ),
                            )
                          : const Scaffold(body: SizedBox.expand()),
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => MascotProvider(),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            routerConfig: router,
            theme: variant.dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(variant.scale),
                padding: const EdgeInsets.only(top: 24, bottom: 20),
              ),
              child: RepaintBoundary(key: _boundaryKey, child: child!),
            ),
          ),
        ),
      );
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MeditationCatalogView));
        await precacheImage(const AssetImage('assets/mascotte.png'), context);
        await precacheImage(
          const AssetImage('assets/brand/logo_monochrome.png'),
          context,
        );
      });
      await tester.pumpAndSettle();
      await _capture(tester, variant.name);

      if (variant.scale != 1) {
        await tester.drag(
          find.byKey(const Key('meditation-catalog-scroll')),
          const Offset(0, -320),
        );
        await tester.pumpAndSettle();
        await _capture(tester, '${variant.name}-scrolled');
      }

      if (variant.scale == 1) {
        // A second view shows the production selection and active start button.
        controller.setExercise(
          MeditationExercises.all.firstWhere(
            (exercise) => exercise.id == 'carree',
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, '${variant.name}-selected');
      }
      // Open the catalog's actual root-navigator modal with a free hour value.
      controller.setSessionDuration(const Duration(hours: 1, minutes: 13));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('meditation-custom-duration')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('meditation-custom-duration')));
      await tester.pumpAndSettle();
      final minutes = tester.getRect(find.text('13'));
      final minuteUnit = tester.getRect(find.text('minutes'));
      expect(minutes.right + 4, lessThanOrEqualTo(minuteUnit.left));
      final hours = tester.getRect(find.text('01'));
      final hourUnit = tester.getRect(find.text('heure'));
      expect(hours.right + 4, lessThanOrEqualTo(hourUnit.left));
      await _capture(tester, '${variant.name}-duration');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
