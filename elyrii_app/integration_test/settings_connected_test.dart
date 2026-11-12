import 'dart:convert';
import 'dart:io';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/design_system/haptics/elyrii_haptics.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/settings/pages/settings_page.dart';
import 'package:elyrii_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'support/native_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native Settings save, export, restore, logout and delete a fixture account',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'SettingsNative123';
      final email = 'ios-settings-${const Uuid().v4()}@example.test';
      final client = http.Client(), storage = SecureStorageService();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstName': 'Settings',
          'lastName': 'Fixture',
        }),
      );
      expect(registered.statusCode, 201, reason: registered.body);
      final session = jsonDecode(registered.body) as Map;
      final token = session['token'] as String;
      final owner =
          (jsonDecode(
                utf8.decode(
                  base64Url.decode(base64Url.normalize(token.split('.')[1])),
                ),
              ) as Map)['userId']
              as String;
      await storage.saveAccessToken(token);
      await storage.saveRefreshToken(session['refreshToken'] as String);
      await storage.saveUserId(owner);
      await storage.setProfileSetupCompleted();
      var deleted = false;
      Map? exported;
      const share = MethodChannel('dev.fluttercommunity.plus/share');
      // Exercise consent, remote aggregation and the actual native file. Stop at
      // the OS handoff so this fixture is never delivered to another application.
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(share, (
        call,
      ) async {
        expect(call.method, 'share');
        final paths = (call.arguments as Map)['paths'] as List;
        exported = jsonDecode(
          await File(paths.single as String).readAsString(),
        ) as Map;
        return '';
      });
      addTearDown(() async {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          share,
          null,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        if (!deleted) {
          final login = await client.post(
            Uri.parse('$base/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          );
          if (login.statusCode == 200) {
            final response = await client.delete(
              Uri.parse('$base/user/account'),
              headers: {
                'Authorization':
                    'Bearer ${(jsonDecode(login.body) as Map)['token']}',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({'password': password}),
            );
            expect(response.statusCode, 200, reason: response.body);
          }
        }
        await storage.clearAuthData();
        await storage.clearProfileSetup(owner);
        client.close();
      });
      Future<void> tap(Finder target) async {
        await tester.pump(const Duration(milliseconds: 500));
        if (target.evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            target,
            250,
            scrollable: find
                .descendant(
                  of: find.byType(SettingsPage),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
        }
        await waitFor(
          tester,
          () => target.evaluate().isNotEmpty,
          description: 'settings control to appear',
        );
        // PushedPage has a fixed header: aligning controls at scroll offset
        // zero hides them behind it. Center the target before hit testing.
        await Scrollable.ensureVisible(
          tester.element(target.first),
          alignment: .5,
        );
        await tester.pump(const Duration(milliseconds: 300));
        await waitFor(
          tester,
          () => target.hitTestable().evaluate().isNotEmpty,
          description: 'settings control to accept taps',
        );
        await tester.tap(target.hitTestable().first);
        await tester.pump(const Duration(milliseconds: 500));
      }

      Future<Map> serverSettings() async {
        final response = await client.get(
          Uri.parse('$base/user/settings'),
          headers: {'Authorization': 'Bearer $token'},
        );
        expect(response.statusCode, 200, reason: response.body);
        return jsonDecode(response.body) as Map;
      }

      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'authenticated settings fixture',
      );
      var services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      tester.element(find.byType(DashboardPage)).go('/settings');
      await waitFor(
        tester,
        () => services.user.settings != null && !services.user.isLoading,
        description: 'loaded server preferences',
      );
      await tap(find.text('Sombre'));
      await waitFor(
        tester,
        () => !services.user.isSyncingSettings,
        description: 'saved dark appearance',
      );
      expect(services.theme.themeMode, ThemeMode.dark);
      await tap(find.bySemanticsLabel('Vibrations'));
      await waitFor(
        tester,
        () => !services.user.isSyncingSettings,
        description: 'saved haptics',
      );
      expect(ElyriiHaptics.isEnabled, isFalse);
      expect(
        await tester.runAsync(serverSettings),
        containsPair('themeMode', 'DARK'),
      );
      expect(
        await tester.runAsync(serverSettings),
        containsPair('hapticsEnabled', false),
      );
      await tap(find.text('Clair'));
      await waitFor(
        tester,
        () => !services.user.isSyncingSettings,
        description: 'saved light appearance',
      );
      expect(services.theme.themeMode, ThemeMode.light);
      await tap(find.text('Sombre'));
      await waitFor(
        tester,
        () => !services.user.isSyncingSettings,
        description: 'saved appearance for restore',
      );
      await tester.runAsync(
        () => services.journalStore.saveDraft(owner, 'settings-fixture', {
          'title': 'Local fixture draft',
          'content': 'LOCAL_ONLY_DRAFT',
        }),
      );
      await tap(find.text('Exporter mes données'));
      expect(exported, isNull);
      await tap(find.text('Exporter les données'));
      await waitFor(
        tester,
        () => exported != null,
        description: 'generated export file at OS handoff',
      );
      expect(exported!['server']['profile']['id'], owner);
      expect(exported!['server']['settings']['themeMode'], 'DARK');
      expect(exported!['server']['settings']['hapticsEnabled'], isFalse);
      expect(
        jsonEncode(exported!['server']),
        isNot(contains('LOCAL_ONLY_DRAFT')),
      );
      expect(
        jsonEncode(exported!['localDrafts']),
        contains('LOCAL_ONLY_DRAFT'),
      );
      expect(exported!['server']['profile'].containsKey('password'), isFalse);
      debugPrint('SETTINGS_NATIVE_EXPORT_VERIFIED');
      await tester.runAsync(() async {
        await Future.wait([
          services.user.flushed,
          services.chat.flushed,
          services.mascot.flushed,
        ]);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await (await SharedPreferences.getInstance()).remove(
        'account_settings_$owner',
      );
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored native session',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      tester.element(find.byType(DashboardPage)).go('/settings');
      await waitFor(
        tester,
        () =>
            find.byType(SettingsPage).evaluate().isNotEmpty &&
            services.user.settings != null &&
            !services.user.isLoading,
        description: 'remote settings without local preference cache',
      );
      expect(services.user.settings!.themeMode, 'DARK');
      expect(services.user.settings!.hapticsEnabled, isFalse);
      expect(services.theme.themeMode, ThemeMode.dark);
      expect(ElyriiHaptics.isEnabled, isFalse);
      await Scrollable.ensureVisible(
        tester.element(find.text('Sombre')),
        alignment: .5,
      );
      await tester.pump(const Duration(milliseconds: 500));
      debugPrint('SETTINGS_QA_FRAME_READY');
      if (const bool.fromEnvironment('HOLD_SETTINGS_QA_FRAME')) {
        await Future<void>.delayed(const Duration(seconds: 35));
      }
      await tap(find.text('Se déconnecter'));
      await tap(find.widgetWithText(TextButton, 'Se déconnecter').last);
      await waitFor(
        tester,
        () =>
            find.byType(LoginPage).evaluate().isNotEmpty &&
            !services.auth.isAuthenticated,
        description: 'settings logout',
      );
      expect(services.theme.themeMode, ThemeMode.system);
      expect(ElyriiHaptics.isEnabled, isTrue);
      expect(
        await tester.runAsync(
          () => services.auth.login(email: email, password: password),
        ),
        isTrue,
      );
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'fixture sign-in after logout',
      );
      tester.element(find.byType(DashboardPage)).go('/settings');
      await waitFor(
        tester,
        () => find.byType(SettingsPage).evaluate().isNotEmpty,
        description: 'settings deletion entry',
      );
      await tap(find.text('Supprimer mon compte'));
      await tester.enterText(find.byType(TextField), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tap(find.text('Supprimer'));
      await waitFor(
        tester,
        () =>
            find.byType(LoginPage).evaluate().isNotEmpty &&
            !services.auth.isAuthenticated,
        description: 'deleted fixture account',
      );
      deleted = true;
      expect(
        (await client.get(
          Uri.parse('$base/user/export'),
          headers: {'Authorization': 'Bearer $token'},
        )).statusCode,
        401,
      );
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'account_settings_$owner',
        ),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
