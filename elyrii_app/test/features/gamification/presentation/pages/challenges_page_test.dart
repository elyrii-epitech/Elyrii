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
  List<ChallengeTemplate> available = [];
  List<UserChallenge> active = [];
  List<UserChallenge> proposals = [];
  @override
  Future<List<UserChallenge>> getCompletedChallenges() async => completed;
  @override
  Future<List<UserChallenge>> getActiveChallenges() async => active;
  @override
  Future<List<UserChallenge>> getProposals() async => proposals;
  @override
  Future<List<ChallengeTemplate>> getAvailableChallenges() async => available;

  @override
  Future<UserChallenge> startChallenge(String challengeId) async {
    final template = available.firstWhere(
      (challenge) => challenge.id == challengeId,
    );
    available = available
        .where((challenge) => challenge.id != challengeId)
        .toList();
    final started = assignment('active-$challengeId', template, 'ACTIVE');
    active = [...active, started];
    return started;
  }

  @override
  Future<UserChallenge> acceptChallenge(String challengeId) async {
    final proposal = proposals.firstWhere(
      (challenge) => challenge.id == challengeId,
    );
    proposals = proposals
        .where((challenge) => challenge.id != challengeId)
        .toList();
    final accepted = assignment(proposal.id, proposal.template!, 'ACTIVE');
    active = [...active, accepted];
    return accepted;
  }

  @override
  Future<UserChallenge> rejectChallenge(String challengeId) async {
    final proposal = proposals.firstWhere(
      (challenge) => challenge.id == challengeId,
    );
    proposals = proposals
        .where((challenge) => challenge.id != challengeId)
        .toList();
    return assignment(proposal.id, proposal.template!, 'REJECTED');
  }

  UserChallenge assignment(
    String id,
    ChallengeTemplate template,
    String status,
  ) => UserChallenge(
    id: id,
    userId: 'alice',
    challengeId: template.id,
    status: status,
    createdAt: DateTime(2026, 10, 23),
    updatedAt: DateTime(2026, 10, 23),
    template: template,
  );
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

  testWidgets(
    'garden starts a challenge and accepts or declines Elyrii proposals',
    (tester) async {
      ChallengeTemplate idea(String id, String title, String source) =>
          ChallengeTemplate(
            id: id,
            title: title,
            description: 'Un petit geste pour toi.',
            source: source,
            rewardPoints: 0,
            aggregator: 'ALL',
            createdAt: DateTime(2026, 10, 23),
            updatedAt: DateTime(2026, 10, 23),
          );
      repository.available = [
        idea('journal', 'Un moment pour écrire', 'SYSTEM'),
      ];
      repository.proposals = [
        repository.assignment(
          'proposal-walk',
          idea('walk', 'Une promenade douce', 'AI'),
          'PENDING',
        ),
        repository.assignment(
          'proposal-music',
          idea('music', 'Une chanson pour moi', 'AI'),
          'PENDING',
        ),
      ];
      await open(tester);
      await Scrollable.ensureVisible(
        tester.element(find.text('Choisir un défi')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choisir un défi'));
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Commencer')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Commencer'));
      await tester.pumpAndSettle();
      expect(garden.availableChallenges, isEmpty);
      expect(
        garden.activeChallenges.map((challenge) => challenge.challengeId),
        contains('journal'),
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Accepter').first),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accepter').first);
      await tester.pumpAndSettle();
      expect(
        garden.activeChallenges.map((challenge) => challenge.challengeId),
        contains('walk'),
      );
      expect(garden.proposals.map((challenge) => challenge.id), [
        'proposal-music',
      ]);
      await Scrollable.ensureVisible(
        tester.element(find.text('Refuser')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refuser'));
      await tester.pumpAndSettle();
      expect(garden.proposals, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
