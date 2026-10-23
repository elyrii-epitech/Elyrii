import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/gamification/data/models/gamification_models.dart';
import 'package:elyrii_app/features/gamification/data/repositories/gamification_repository.dart';
import 'package:elyrii_app/features/gamification/presentation/pages/challenges_page.dart';
import 'package:elyrii_app/features/gamification/presentation/providers/gamification_provider.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GardenRepository extends GamificationRepository {
  _GardenRepository(ApiClient client) : super(client: client);
  List<UserChallenge> completed = [];
  @override
  Future<List<UserChallenge>> getCompletedChallenges() async => completed;
  @override
  Future<List<UserChallenge>> getActiveChallenges() async => [];
  @override
  Future<List<UserChallenge>> getProposals() async => [];
  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async => [];
}

void main() {
  late AccueilActivities store;
  late GamificationProvider garden;
  late MascotProvider mascot;
  late _GardenRepository repository;

  setUp(() async {
    await initializeDateFormatting('fr_FR');
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final storage = SecureStorageService();
    final client = ApiClient(storage: storage);
    store = AccueilActivities(cipher: ContentCipher(storage));
    store.onUserChanged(userId: 'alice');
    await store.reload();
    repository = _GardenRepository(client);
    garden = GamificationProvider(repository: repository)
      ..onUserChanged(userId: 'alice');
    mascot = MascotProvider();
  });

  tearDown(() {
    store.dispose();
    garden.dispose();
    mascot.dispose();
  });

  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccueilActivities>.value(value: store),
          ChangeNotifierProvider<GamificationProvider>.value(value: garden),
          ChangeNotifierProvider<MascotProvider>.value(value: mascot),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChallengesPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'a completed ritual persists and celebrates the first flower only',
    (tester) async {
      await open(tester);
      final now = DateTime.now();
      repository.completed = [
        UserChallenge(
          id: 'new-flower',
          userId: 'alice',
          challengeId: 'template',
          status: 'COMPLETED',
          createdAt: now,
          updatedAt: now,
          completedAt: now,
        ),
      ];
      await Scrollable.ensureVisible(
        tester.element(find.byType(Checkbox).first),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.byType(Checkbox).first));
      await tester.runAsync(() => store.flushed);
      await tester.pumpAndSettle();
      final today = CivilDay.fromLocal(DateTime.now());
      expect(
        store.snapshot.rituals[today]!.isDone(AccueilRitual.breathe),
        isTrue,
      );
      expect(find.text('Une nouvelle fleur !'), findsOneWidget);
      await tester.tap(find.text('Voir mon jardin'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.byType(Checkbox).first));
      await tester.runAsync(() => store.flushed);
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.byType(Checkbox).first));
      await tester.runAsync(() => store.flushed);
      await tester.pumpAndSettle();
      expect(find.text('Une nouvelle fleur !'), findsNothing);
      await tester.runAsync(store.reload);
      expect(
        store.snapshot.rituals[today]!.isDone(AccueilRitual.breathe),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets('a local ritual never invents a completed challenge', (
    tester,
  ) async {
    await open(tester);
    await Scrollable.ensureVisible(
      tester.element(find.byType(Checkbox).first),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.byType(Checkbox).first));
    await tester.runAsync(() => store.flushed);
    await tester.pumpAndSettle();
    expect(
      store.snapshot.rituals[CivilDay.fromLocal(DateTime.now())]!.isDone(
        AccueilRitual.breathe,
      ),
      isTrue,
    );
    expect(garden.completedChallenges, isEmpty);
    expect(find.text('Une nouvelle fleur !'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('adding a filtered idea preserves selection across reloads', (
    tester,
  ) async {
    await open(tester);
    await Scrollable.ensureVisible(
      tester.element(find.text('Ajouter un rituel')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajouter un rituel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Lien'));
    await tester.pumpAndSettle();
    expect(find.text("Boire un verre d'eau"), findsNothing);
    await tester.runAsync(
      () => tester.tap(find.byTooltip('Ajouter Écrire à un proche')),
    );
    await tester.runAsync(() => store.flushed);
    await tester.pumpAndSettle();
    expect(store.snapshot.addedRituals, contains(AccueilRitual.reachOut));
    await tester.runAsync(store.reload);
    await tester.pumpAndSettle();
    expect(store.snapshot.addedRituals, contains(AccueilRitual.reachOut));
    expect(find.text('Écrire à un proche'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('week breathing alternates its guide and cancels on close', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Respirer 2 min')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Respirer 2 min'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commencer'));
    await tester.pump();
    expect(find.text('Inspire doucement · 4 secondes'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Expire doucement · 4 secondes'), findsOneWidget);
    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Expire doucement · 4 secondes'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  }, timeout: const Timeout(Duration(seconds: 30)));
}
