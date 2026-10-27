// Reproducible review captures of real Flutter widgets. Native plugins and the
// 3D WebView use the existing test adapters; these are not device screenshots.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/password_reset_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_sheets.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_summary_sheet.dart';
import 'package:elyrii_app/features/meditation/domain/models/meditation_exercises.dart';
import 'package:elyrii_app/features/meditation/presentation/widgets/meditation_session_view.dart';
import 'package:elyrii_app/features/parcours/presentation/pages/parcours_page.dart';
import 'package:elyrii_app/features/parcours/presentation/widgets/journey_sheets.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';
import 'package:elyrii_app/features/settings/pages/account_sheets.dart';

import '../test/support/accessibility_fixture.dart';

const output = String.fromEnvironment(
  'WORDING_OUTPUT',
  defaultValue: 'build/wording-review',
);

Future<void> tapText(WidgetTester tester, List<String> labels) async {
  final targets = [
    for (final label in labels) find.text(label),
    for (final label in labels) find.bySemanticsLabel(label),
  ];
  final target = targets.firstWhere((finder) => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(target.last);
  await tester.pump();
  await tester.tap(target.last);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 450));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // This executable uses flutter_test, outside the automatically discovered test directory.
    // ignore: invalid_use_of_visible_for_testing_member
    PackageInfo.setMockInitialValues(
      appName: 'Elyrii',
      packageName: 'com.elyrii.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await initializeDateFormatting('fr');
    await (FontLoader('Poppins')
          ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf')))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
    await (FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded')
          ..addFont(
            rootBundle.load(
              'packages/material_symbols_icons/lib/fonts/MaterialSymbolsRounded.ttf',
            ),
          ))
        .load();
    Directory(output).createSync(recursive: true);
  });
  final scenes = <(String, Widget, int)>[
    ('01-welcome', const LoginPage(), 0),
    ('02-login', const LoginPage(), 1),
    ('03-register', const RegisterPage(), 0),
    ('04-password', const PasswordResetPage(), 0),
    ('05-onboarding-name', const ProfileSetupPage(), 0),
    ('06-onboarding-goal', const ProfileSetupPage(), 1),
    ('07-onboarding-mood', const ProfileSetupPage(), 2),
    ('08-onboarding-appearance', const ProfileSetupPage(), 3),
    ('09-home', const DashboardPage(), 0),
    ('09-home-activities', const DashboardPage(), 1),
    ('09-home-appearance', const DashboardPage(), 2),
    ('10-challenges', const ChallengesPage(), 0),
    ('11-journal', const JournalPage(), 0),
    ('11-journal-editor', const JournalPage(), 2),
    ('12-journal-data', const JournalPage(), 1),
    ('13-meditation', const MeditationPage(), 0),
    ('14-programs', const ParcoursPage(), 0),
    ('15-program-step', const ParcoursPage(), 1),
    ('16-chat', const ChatbotPage(), 0),
    ('17-profile', const ProfilePage(), 0),
    ('18-edit-profile', const EditProfilePage(), 0),
    ('19-avatar', const AvatarPickerPage(), 0),
    ('20-settings', const SettingsPage(), 0),
    ('21-account-data', const SettingsPage(), 1),
    ('22-statistics', const ReviewsPage(), 0),
    ('23-session', const SizedBox.shrink(), 0),
    ('24-session-summary', const SizedBox.shrink(), 0),
  ];
  for (final (name, page, stage) in scenes) {
    testWidgets(name, (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final semantics = tester.ensureSemantics();
      final app = (await tester.runAsync(() async {
        final app = await fixture();
        if (page is ParcoursPage) {
          await app.parcours.load();
          if (stage == 1) await app.parcours.choose(app.parcours.catalog.first);
        }
        return app;
      }))!;
      final boundaryKey = GlobalKey();
      MeditationController? controller;
      try {
        var content = page;
        if (name.startsWith('23-') || name.startsWith('24-')) {
          controller = MeditationController()
            ..setExercise(
              MeditationExercises.all.firstWhere(
                (exercise) => exercise.id == 'carree',
              ),
            )
            ..setDuration(3);
          await controller.startSession();
          if (name.startsWith('24-')) {
            for (var i = 0; i < 12; i++) {
              // Advance the deterministic test clock without a device timer.
              // ignore: invalid_use_of_visible_for_testing_member
              controller.tick();
            }
            await controller.stopSession(finished: true);
            content = Scaffold(
              body: Center(
                child: MeditationSummarySheet(controller: controller),
              ),
            );
          } else {
            content = Scaffold(
              body: MeditationSessionView(
                controller: controller,
                onExit: () {},
                onFinish: () {},
              ),
            );
          }
        }
        await tester.pumpWidget(host(app, content, boundaryKey, false, 1));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        if (page is LoginPage && stage == 1) {
          await tapText(tester, ['Commencer', 'Entrer dans Elyrii']);
        }
        if (page is ProfileSetupPage) {
          for (var i = 0; i < stage; i++) {
            await tapText(tester, ['Passer']);
          }
        }
        if (page is DashboardPage && stage == 1) {
          await tapText(tester, ['Mal', 'Vulnérable']);
        }
        if (page is DashboardPage && stage == 2) {
          await tapText(tester, ['Apparence', 'Tenue']);
        }
        if (page is JournalPage && stage == 2) {
          await tapText(tester, ['Écrire librement']);
        }
        if (page is JournalPage && stage == 1) {
          final context = tester.element(find.byType(JournalPage));
          showJournalPrivacy(context, visualJournals[app]!);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (page is ParcoursPage && stage == 1) {
          showJourneyStep(
            tester.element(find.byType(ParcoursPage)),
            app.parcours,
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        if (page is SettingsPage && stage == 1) {
          showAccountData(tester.element(find.byType(SettingsPage)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        await tester.runAsync(() async {
          await app.chat.ready;
          await app.mascot.flushed;
        });
        await tester.pump();
        for (var attempt = 0; attempt < 8; attempt++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }
        if (page is ParcoursPage) expect(app.parcours.isLoading, isFalse);
        expect(tester.takeException(), isNull, reason: name);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final rendered = await boundary.toImage(pixelRatio: 2);
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          rendered.dispose();
          File('$output/$name.png')
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      } finally {
        semantics.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
        controller?.dispose();
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
