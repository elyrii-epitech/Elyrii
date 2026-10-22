// Headless Flutter layout evidence. Native WebViews and plugins are mocked;
// screenshots do not measure device performance or native 3D rendering.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/password_reset_page.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';

import '../support/accessibility_fixture.dart';

const auditDir = String.fromEnvironment(
  'AUDIT_OUTPUT',
  defaultValue: 'build/a11y-evidence',
);
final records = <Map<String, Object?>>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Elyrii',
      packageName: 'com.elyrii.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await initializeDateFormatting('fr');
    final loader = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await loader.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    Directory('$auditDir/screenshots').createSync(recursive: true);
  });
  tearDownAll(
    () => File('$auditDir/layout.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records)),
  );
  final pages = <String, Widget>{
    'login': const LoginPage(),
    'register': const RegisterPage(),
    'password-reset': const PasswordResetPage(),
    'dashboard': const DashboardPage(),
    'challenges': const ChallengesPage(),
    'journal': const JournalPage(),
    'chat': const ChatbotPage(),
    'coach': const CoachPage(),
    'meditation': const MeditationPage(),
    'profile-setup': const ProfileSetupPage(),
    'profile-edit': const EditProfilePage(),
    'avatar': const AvatarPickerPage(),
    'settings': const SettingsPage(),
    'reviews': const ReviewsPage(),
  };
  for (final cfg in [
    (name: 'mobile', size: const Size(390, 844), scale: 1.0, dark: false),
    (
      name: 'small-text300',
      size: const Size(320, 568),
      scale: 3.0,
      dark: false,
    ),
    (
      name: 'landscape-text200',
      size: const Size(568, 320),
      scale: 2.0,
      dark: false,
    ),
    (
      name: 'narrow-text200',
      size: const Size(280, 568),
      scale: 2.0,
      dark: false,
    ),
    (
      name: 'small-text200',
      size: const Size(320, 568),
      scale: 2.0,
      dark: false,
    ),
    (name: 'dark-text200', size: const Size(390, 844), scale: 2.0, dark: true),
    (
      name: 'tablet-landscape',
      size: const Size(1024, 768),
      scale: 1.0,
      dark: false,
    ),
  ]) {
    for (final page in pages.entries) {
      testWidgets('${page.key} ${cfg.name}', (tester) async {
        tester.view.physicalSize = cfg.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final app = await tester.runAsync(fixture);
        app!.theme.setThemeMode(
          cfg.dark ? ThemeMode.dark : ThemeMode.light,
          persist: false,
        );
        final errors = <String>[];
        final previous = FlutterError.onError;
        final diagnostics = <String>[];
        FlutterError.onError = (details) {
          errors.add(details.exceptionAsString());
          diagnostics.add(details.toString());
        };
        final key = GlobalKey();
        try {
          await tester.pumpWidget(
            host(app, page.value, key, cfg.dark, cfg.scale),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.runAsync(() async {
            await app.chat.ready;
            await app.mascot.flushed;
          });
          await tester.pump();
          if (page.key == 'dashboard') {
            for (final finder in [
              find.textContaining(RegExp(r'^[A-ZÉÛ]+ \d{1,2} [A-ZÉÛ]+$')),
              find.textContaining(app.dashboard.getGreeting()),
            ]) {
              final paragraph = tester.renderObject<RenderParagraph>(finder);
              final lineHeight = paragraph.textScaler.scale(
                paragraph.text.style!.fontSize!,
              );
              expect(
                paragraph.didExceedMaxLines,
                isFalse,
                reason: '$finder must remain fully readable at ${cfg.scale}',
              );
              expect(
                tester.getRect(finder).height,
                closeTo(paragraph.size.height, 0.5),
                reason: '$finder must not be shrunk to fit at ${cfg.scale}',
              );
              expect(
                paragraph.size.height,
                greaterThanOrEqualTo(lineHeight),
                reason: '$finder must follow the text size ${cfg.scale}',
              );
            }
          }
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final png = await tester.runAsync(() async {
            final picture = await boundary.toImage(pixelRatio: 1);
            final bytes = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            picture.dispose();
            return bytes!.buffer.asUint8List();
          });
          File('$auditDir/screenshots/${page.key}-${cfg.name}.png')
              .writeAsBytesSync(png!);
          records.add({
            'page': page.key,
            'configuration': cfg.name,
            'width': cfg.size.width,
            'height': cfg.size.height,
            'textScale': cfg.scale,
            'errors': errors.toList(),
            'diagnostics': diagnostics,
          });
          expect(
            errors,
            isEmpty,
            reason: '${page.key} ${cfg.name}: ${diagnostics.join('\n')}',
          );
        } finally {
          await tester.pumpWidget(const SizedBox.shrink());
          FlutterError.onError = previous;
          visualJournals.remove(app)!.dispose();
          await tester.runAsync(() async {
            app.dispose();
            await app.chat.flushed;
            await app.history.close();
            await app.journalStore.close();
          });
        }
      });
    }
  }
}
