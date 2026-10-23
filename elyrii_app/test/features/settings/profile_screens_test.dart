import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/profile_setup/presentation/pages/edit_profile_page.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:elyrii_app/features/settings/pages/account_sheets.dart';

void main() {
  testWidgets(
    'required name and age bounds protect save, valid identity returns to profile',
    (tester) async {
      final writes = <Map<String, dynamic>>[];
      final client = ApiClient(
        storage: SecureStorageService(),
        client: MockClient((request) async {
          if (request.method == 'PUT') {
            writes.add(jsonDecode(request.body) as Map<String, dynamic>);
          }
          return http.Response(
            jsonEncode({
              'id': 'user',
              'email': 'test@example.com',
              'firstName': writes.isEmpty ? 'Anaïs' : writes.last['firstName'],
            }),
            200,
          );
        }),
      );
      final user = UserProvider(client: client);
      await user.loadProfile();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/edit'),
                child: const Text('Modifier le profil'),
              ),
            ),
          ),
          GoRoute(path: '/edit', builder: (_, _) => const EditProfilePage()),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: user,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Modifier le profil'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '');
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(writes, isEmpty);
      await tester.enterText(fields.at(0), 'Camille');
      await tester.enterText(fields.at(2), '121');
      await tester.tap(find.text('Enregistrer'));
      await tester.pump();
      expect(writes, isEmpty);
      await tester.enterText(fields.at(2), '31');
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(writes.single['firstName'], 'Camille');
      expect(writes.single['age'], 31);
      expect(user.profile?.firstName, 'Camille');
      expect(find.text('Modifier le profil'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3300));
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      user.dispose();
    },
  );
  testWidgets(
    'deletion cannot dismiss at the veil and export first opens consent without deletion',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => confirmAccountDeletion(context),
                child: const Text('Compte'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Compte'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text('Supprimer'));
      await tester.pump();
      expect(
        find.text('Entre ton mot de passe pour confirmer.'),
        findsOneWidget,
      );
      await tester.tap(find.text("Exporter d'abord"));
      await tester.pumpAndSettle();
      expect(find.text('Préparer le fichier'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
    },
  );
}
