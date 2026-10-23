import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'dart:ui' show FlutterView;
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/password_reset_page.dart';
import 'package:elyrii_app/features/chatbot/presentation/pages/chatbot_page.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/meditation/presentation/pages/meditation_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/avatar_picker_page.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_page.dart';
import 'package:elyrii_app/features/reviews/presentation/pages/reviews_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';

import 'package:elyrii_app/core/widgets/elyrii_page_header.dart';

import '../support/accessibility_fixture.dart';

final results = <Map<String, Object?>>[];

/// Flutter 3.47's guideline compares the already transformed child bounds with
/// the scroll parent's local rect. With SafeArea translations it can report a
/// partially clipped control as undersized. Apply the same boundary exception
/// in the parent's coordinate space; fully visible controls still use the
/// unmodified SDK size evaluation.
class _ScrolledTapTargetGuideline extends MinimumTapTargetGuideline {
  const _ScrolledTapTargetGuideline({required super.size, required super.link});
  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) return true;
    var bounds = node.rect;
    SemanticsNode? current = node;
    while (current != null) {
      if (current.flagsCollection.hasImplicitScrolling) {
        final viewport = current.rect;
        if (bounds.top <= viewport.top + .001 ||
            bounds.bottom >= viewport.bottom - .001 ||
            bounds.left <= viewport.left + .001 ||
            bounds.right >= viewport.right - .001) {
          return true;
        }
      }
      if (current.transform case final transform?) {
        bounds = MatrixUtils.transformRect(transform, bounds);
      }
      current = current.parent;
    }
    return false;
  }
}

/// Content scrolled under the glass header bar is blurred on purpose.
class _UnoccludedTextContrastGuideline extends MinimumTextContrastGuideline {
  const _UnoccludedTextContrastGuideline();
  @override
  bool isNodeOffScreen(Rect paintBounds, FlutterView window) =>
      super.isNodeOffScreen(paintBounds, window) ||
      paintBounds.top <
          window.padding.top / window.devicePixelRatio +
              ElyriiHeaderBar.rowExtent;
}

void main() {
  testWidgets(
    'scrolled guideline still rejects a fully visible 44 px Android control inside a translated scroll viewport',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                minimum: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 100),
                      Center(
                        child: Semantics(
                          container: true,
                          label: 'Small fixture target',
                          button: true,
                          onTap: () {},
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.add),
                          ),
                        ),
                      ),
                      const SizedBox(height: 1200),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        const guideline = _ScrolledTapTargetGuideline(
          size: Size(48, 48),
          link: 'https://developer.android.com/guide/topics/ui/accessibility/apps',
        );
        expect((await guideline.evaluate(tester)).passed, isFalse);
      } finally {
        semantics.dispose();
      }
    },
  );
  tearDownAll(() {
    final file = File(
      '${const String.fromEnvironment('AUDIT_OUTPUT', defaultValue: 'build/a11y-evidence')}/semantics.json',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(results));
  });
  setUpAll(() async {
    PackageInfo.setMockInitialValues(
      appName: 'Elyrii',
      packageName: 'com.elyrii.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await initializeDateFormatting('fr');
    final fonts = FontLoader('Poppins')
      ..addFont(rootBundle.load('assets/fonts/Poppins-Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Poppins-Bold.ttf'));
    await fonts.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load();
  });
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
    'profile': const ProfilePage(),
    'profile-edit': const EditProfilePage(),
    'avatar': const AvatarPickerPage(),
    'settings': const SettingsPage(),
    'reviews': const ReviewsPage(),
  };
  for (final dark in [false, true]) {
    for (final page in pages.entries) {
      testWidgets('${page.key} names, targets and contrast, dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final semantics = tester.ensureSemantics();
        final app = (await tester.runAsync(fixture))!;
        app.theme.setThemeMode(
          dark ? ThemeMode.dark : ThemeMode.light,
          persist: false,
        );
        try {
          await tester.pumpWidget(host(app, page.value, GlobalKey(), dark, 1));
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          await tester.runAsync(() async {
            await app.chat.ready;
            await app.mascot.flushed;
          });
          await tester.pump();
          expect(tester.takeException(), isNull);
          for (final viewport in ['top', 'bottom']) {
            if (viewport == 'bottom') {
              for (final scroll in tester.stateList<ScrollableState>(
                find.byType(Scrollable),
              )) {
                if (scroll.position.hasContentDimensions &&
                    scroll.position.maxScrollExtent.isFinite) {
                  scroll.position.jumpTo(scroll.position.maxScrollExtent);
                }
              }
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 400));
            }
            final checks = <Map<String, Object?>>[];
            for (final guideline in [
              labeledTapTargetGuideline,
              if (viewport == 'top')
                androidTapTargetGuideline
              else
                _ScrolledTapTargetGuideline(
                  size: (androidTapTargetGuideline as MinimumTapTargetGuideline)
                      .size,
                  link: (androidTapTargetGuideline as MinimumTapTargetGuideline)
                      .link,
                ),
              if (viewport == 'top')
                iOSTapTargetGuideline
              else
                _ScrolledTapTargetGuideline(
                  size:
                      (iOSTapTargetGuideline as MinimumTapTargetGuideline).size,
                  link:
                      (iOSTapTargetGuideline as MinimumTapTargetGuideline).link,
                ),
              if (viewport == 'top')
                textContrastGuideline
              else
                const _UnoccludedTextContrastGuideline(),
            ]) {
              final check = await guideline.evaluate(tester);
              checks.add({
                'guideline': guideline.runtimeType.toString(),
                'passed': check.passed,
                'reason': check.reason,
              });
            }
            results.add({
              'page': page.key,
              'dark': dark,
              'viewport': viewport,
              'checks': checks,
            });
            expect(
              checks.every((check) => check['passed'] == true),
              isTrue,
              reason: checks
                  .where((c) => c['passed'] != true)
                  .map((c) => '${c['guideline']}: ${c['reason']}')
                  .join('\n'),
            );
          }
        } finally {
          semantics.dispose();
          await tester.pumpWidget(const SizedBox.shrink());
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
