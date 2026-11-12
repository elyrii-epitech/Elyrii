import 'dart:convert';

import 'package:elyrii_app/app/app_dependencies.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/profile_setup_page.dart';
import 'package:elyrii_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'support/native_app.dart';

/// Real new-frontend screens, native Keychain/SQLite, HTTP and PostgreSQL.
/// Run only with the disposable local auth integration API.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'native login, onboarding profile and mood survive restarting the app',
    (tester) async {
      const base = String.fromEnvironment('ELYRII_API_URL');
      expect(Uri.parse(base).host, '127.0.0.1');
      const password = 'NativeSecret123';
      final email = 'ios-${const Uuid().v4()}@example.test';
      final client = http.Client();
      final registered = await client.post(
        Uri.parse('$base/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'firstName': 'Native',
          'lastName': 'Fixture',
        }),
      );
      expect(registered.statusCode, 201, reason: registered.body);
      final fixtureToken =
          (jsonDecode(registered.body) as Map)['token'] as String;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await client.delete(
          Uri.parse('$base/user/account'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $fixtureToken',
          },
          body: jsonEncode({'password': password}),
        );
        await SecureStorageService().clearAuthData();
        client.close();
      });

      app.main();
      await waitFor(
        tester,
        () => find.byType(LoginPage).evaluate().isNotEmpty,
        description: 'login',
      );
      await tapVisible(tester, find.bySemanticsLabel('Commencer'));
      await tester.enterText(find.byType(TextFormField).at(0), email);
      await tester.enterText(find.byType(TextFormField).at(1), password);
      FocusManager.instance.primaryFocus?.unfocus();
      await tapVisible(tester, find.text('Se connecter').last);
      await waitFor(
        tester,
        () => find.byType(ProfileSetupPage).evaluate().isNotEmpty,
        description: 'real-account onboarding',
      );

      await tester.enterText(find.byType(TextFormField), 'Camille iOS');
      FocusManager.instance.primaryFocus?.unfocus();
      await tapVisible(tester, find.text('Continuer'));
      await waitFor(
        tester,
        () => find.text('Ton objectif').evaluate().isNotEmpty,
        description: 'goal step',
      );
      await tapVisible(tester, find.text('Gérer mon stress'));
      await tapVisible(tester, find.text('Continuer'));
      await waitFor(
        tester,
        () => find.text('Ton humeur du moment').evaluate().isNotEmpty,
        description: 'mood step',
      );
      await tapVisible(tester, find.text('Bien'));
      await tapVisible(tester, find.text('Continuer'));
      await waitFor(
        tester,
        () => find.text('L’apparence d’Elyrii').evaluate().isNotEmpty,
        description: 'appearance step',
      );
      await tapVisible(tester, find.text('Commencer'));
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'connected dashboard',
      );
      var services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      expect(services.user.profile?.firstName, 'Camille iOS');
      expect(services.dashboard.selectedMood, MoodType.happy);
      await tester.runAsync(() async {
        final response = await client.get(
          Uri.parse('$base/user/me'),
          headers: {'Authorization': 'Bearer $fixtureToken'},
        );
        expect((jsonDecode(response.body) as Map)['firstName'], 'Camille iOS');
        final mood = await client.get(
          Uri.parse('$base/user/mood/latest'),
          headers: {'Authorization': 'Bearer $fixtureToken'},
        );
        expect((jsonDecode(mood.body) as Map)['moodType'], 'happy');
        await Future.wait([
          services.chat.flushed,
          services.user.flushed,
          services.mascot.flushed,
        ]);
      });

      // Dispose and bootstrap again: native credentials remain, providers do not.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      app.main();
      await waitFor(
        tester,
        () => find.byType(DashboardPage).evaluate().isNotEmpty,
        description: 'restored native dashboard',
      );
      services = tester
          .element(find.byType(DashboardPage))
          .read<AppDependencies>();
      await waitFor(
        tester,
        () =>
            services.user.profile?.firstName == 'Camille iOS' &&
            services.dashboard.selectedMood == MoodType.happy,
        description: 'server profile and mood after restart',
      );
      expect(services.auth.isDemoSession, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
