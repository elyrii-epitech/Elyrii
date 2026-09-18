import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_editor_sheet.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/coach/data/models/coach_model.dart';
import 'package:elyrii_app/features/coach/data/repositories/coach_repository.dart';
import 'package:elyrii_app/features/settings/providers/settings_provider.dart';
import 'package:elyrii_app/features/coach/presentation/pages/coach_page.dart';
import 'package:elyrii_app/features/coach/presentation/providers/coach_provider.dart';
import 'package:elyrii_app/features/coach/presentation/widgets/coach_activity_cell.dart';
import 'package:elyrii_app/features/coach/presentation/widgets/need_selector.dart';
import 'package:elyrii_app/features/meditation/domain/models/breath_phase.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Routage du coach par besoin', () {
    late CoachRepository repository;
    late CoachProvider provider;

    setUp(() {
      final storage = SecureStorageService();
      final client = ApiClient(storage: storage);
      repository = CoachRepository(client: client);
      provider = CoachProvider(client: client);
    });

    tearDown(() {
      provider.dispose();
    });

    test('chaque besoin renvoie au moins deux activités réelles', () {
      for (final need in CoachNeed.values) {
        final activities = repository.getActivitiesForNeed(need);
        expect(
          activities.length,
          greaterThanOrEqualTo(2),
          reason: '${need.label} devrait proposer au moins deux activités',
        );
        expect(activities.every((a) => a.needs.contains(need)), isTrue);
      }
    });

    test('les techniques respiratoires référencées existent nativement', () {
      final breathingActivities = repository
          .getAllActivities()
          .where((a) => a.kind == CoachActivityKind.breathing);

      for (final activity in breathingActivities) {
        final technique = activity.breathingTechnique;
        expect(technique, isNotNull, reason: '${activity.id} sans technique');
        expect(
          BreathingType.values.any((t) => t.name == technique),
          isTrue,
          reason:
              'Technique "$technique" (${activity.id}) inconnue de la méditation',
        );
      }
    });

    test('les activités journal ont toutes un prompt guidé', () {
      final journalActivities = repository
          .getAllActivities()
          .where((a) => a.kind == CoachActivityKind.journal);

      expect(journalActivities, isNotEmpty);
      for (final activity in journalActivities) {
        expect(
          activity.journalPrompt,
          isNotNull,
          reason: '${activity.id} devrait préremplir le journal',
        );
      }
    });

    test('sélection de besoin pilote les recommandations et la bulle', () {
      // Par défaut : la sélection curatée du coach.
      expect(provider.selectedNeed, isNull);
      expect(
        provider.highlightedActivities.map((a) => a.id),
        equals(['body-scan-5', 'gratitude-soir', 'respiration-coherence']),
      );

      provider.selectNeed(CoachNeed.sleep);
      expect(provider.selectedNeed, equals(CoachNeed.sleep));
      expect(
        provider.highlightedActivities.map((a) => a.id),
        equals(['gratitude-soir', 'muscle-relaxation', 'respiration-478']),
      );
      expect(provider.mascotMessage, equals(CoachNeed.sleep.bubbleMessage));

      // Désélection explicite (le chip actif envoie null au provider).
      provider.selectNeed(null);
      expect(provider.selectedNeed, isNull);
      expect(
        provider.highlightedActivities.map((a) => a.id),
        equals(['body-scan-5', 'gratitude-soir', 'respiration-coherence']),
      );
    });

    test('la bulle de Velours tourne et accepte un message contextuel', () {
      final first = provider.mascotMessage;
      provider.nextMascotMessage();
      expect(provider.mascotMessage, isNot(equals(first)));

      provider.setMascotMessage('Voilà. À toi de jouer, je reste là.');
      expect(provider.mascotMessage, contains('je reste là'));
    });

    test('sans backend, la guidance retombe sur un placeholder honnête', (
      ) async {
      final bodyScan = repository.getAllActivities().firstWhere(
        (a) => a.id == 'body-scan-5',
      );

      final success = await provider.requestGuidanceForActivity(bodyScan);
      expect(success, isTrue);
      expect(provider.isCreatingSession, isFalse);

      final session = provider.latestSession;
      expect(session, isNotNull);
      expect(session!.response, isNotEmpty);
      expect(session.context['placeholder'], isTrue);
      expect(session.context['activityId'], equals('body-scan-5'));
    });
  });

  group('CoachPage — parcours utile et immersif', () {
    Widget createApp() {
      final storage = SecureStorageService();
      final client = ApiClient(storage: storage);
      return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => AuthProvider(client: client, storage: storage),
          ),
          ChangeNotifierProvider(
            create: (_) => DashboardProvider(apiClient: client),
          ),
          ChangeNotifierProvider(
            create: (_) => JournalProvider(client: client),
          ),
          ChangeNotifierProvider(
            create: (_) => GamificationProvider(client: client),
          ),
          ChangeNotifierProvider(create: (_) => CoachProvider(client: client)),
          ChangeNotifierProvider(create: (_) => UserProvider(client: client)),
          ChangeNotifierProvider(create: (_) => MascotProvider(client: client)),
        ],
        child: const MaterialApp(home: CoachPage()),
      );
    }

    testWidgets('accueil : Velours, besoin et recommandations groupées', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Velours t'accompagne"), findsOneWidget);
      expect(find.text('De quoi as-tu besoin ?'), findsOneWidget);
      expect(find.byType(NeedSelector), findsOneWidget);
      // Sélection par défaut : trois cellules groupées.
      expect(find.byType(CoachActivityCell), findsNWidgets(3));
      expect(find.text('Recommandé pour toi'), findsOneWidget);
    });

    testWidgets('filtrer par besoin réorganise les recommandations', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      await tester.tap(find.text('Mieux dormir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text("Pour t'endormir"), findsOneWidget);
      expect(find.byType(CoachActivityCell), findsNWidgets(3));
      // « Respiration 4-7-8 » apparaît dans le groupe filtré (et la grille).
      expect(
        find.descendant(
          of: find.byType(CoachActivityCell),
          matching: find.text('Respiration apaisante 4-7-8'),
        ),
        findsOneWidget,
      );

      // Re-taper le filtre revient à la sélection par défaut.
      await tester.tap(find.text('Mieux dormir'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Recommandé pour toi'), findsOneWidget);
    });

    testWidgets('une activité d\'écriture ouvre le journal prérempli', (
      tester,
    ) async {
      await tester.pumpWidget(createApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // La zone héroïque pousse le groupe sous le pli : le rendre visible.
      final gratitudeCell = find
          .descendant(
            of: find.byType(CoachActivityCell),
            matching: find.text('3 gratitudes du soir'),
          )
          .first;
      await tester.ensureVisible(gratitudeCell);
      await tester.pump(const Duration(milliseconds: 400));

      // La cellule recommandée du groupe (la grille montre aussi ce titre).
      await tester.tap(
        find.descendant(
          of: find.byType(CoachActivityCell),
          matching: find.text('3 gratitudes du soir'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));

      expect(find.byType(JournalEditorSheet), findsOneWidget);
      expect(find.text('Trois gratitudes du soir'), findsWidgets);
    });
  });
}
