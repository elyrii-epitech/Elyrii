import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/pages/login_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/password_reset_page.dart';
import 'package:elyrii_app/features/auth/presentation/pages/register_page.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

void main() {
  late ApiClient api;
  late AuthProvider auth;
  late List<http.Request> requests;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    requests = [];
    final storage = SecureStorageService();
    api = ApiClient(
      storage: storage,
      client: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    auth = AuthProvider(client: api, storage: storage);
  });
  tearDown(() {
    auth.dispose();
  });
  Widget host(Widget child) => MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider(create: (_) => MascotProvider()),
    ],
    child: MaterialApp(home: child),
  );

  Future<void> tap(WidgetTester tester, String label) async {
    final target = find.text(label).last;
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
  }

  testWidgets('welcome enters login and empty login never sends credentials', (
    tester,
  ) async {
    await tester.pumpWidget(host(const LoginPage()));
    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.bySemanticsLabel('Entrer dans Elyrii'));
    await tester.pump();
    await tap(tester, 'Se connecter');
    expect(find.text('Entre une adresse email valide.'), findsOneWidget);
    expect(find.text('Entre ton mot de passe.'), findsOneWidget);
    expect(requests, isEmpty);
  });

  testWidgets(
    'registration validates password and mandatory consent before sending',
    (tester) async {
      await tester.pumpWidget(host(const RegisterPage()));
      await tester.enterText(find.byType(TextFormField).at(0), 'Camille');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'camille@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'court');
      await tap(tester, 'Créer mon compte');
      expect(find.text('Utilise au moins 8 caractères.'), findsOneWidget);
      expect(
        find.text('Accepte les conditions pour créer ton espace.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).at(2), 'UnSecret123');
      await tap(tester, 'Créer mon compte');
      expect(requests, isEmpty);
    },
  );

  testWidgets(
    'reset keeps the token confirmation path and refuses incomplete tokens',
    (tester) async {
      await tester.pumpWidget(host(const PasswordResetPage()));
      await tap(tester, 'J’ai déjà un code');
      await tester.enterText(find.byType(TextFormField).at(0), 'incomplet');
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'une phrase très longue',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        'une phrase très longue',
      );
      await tap(tester, 'Modifier mon mot de passe');
      expect(
        find.text('Colle le code complet reçu par email.'),
        findsOneWidget,
      );
      expect(requests, isEmpty);
    },
  );
}
