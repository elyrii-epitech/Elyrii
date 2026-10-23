import 'package:elyrii_app/core/localization/app_dates.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/network/api_exception.dart';
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
  bool unavailable = false;

  @override
  Future<List<UserChallenge>> getCompletedChallenges() async {
    if (unavailable) {
      throw const ApiException(statusCode: 503, message: 'Jardin indisponible');
    }
    return completed;
  }

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

  Future<void> openDay(WidgetTester tester, CivilDay day) async {
    final date = AppDates.format(
      DateTime(day.year, day.month, day.day),
      'EEEE d MMMM yyyy',
    );
    final cell = find.bySemanticsLabel(RegExp('^${RegExp.escape(date)},'));
    await Scrollable.ensureVisible(tester.element(cell), alignment: .5);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
  }

  Future<void> record(
    WidgetTester tester,
    CivilDay day,
    AccueilRitual ritual,
  ) async {
    final saved = await tester.runAsync(
      () => store.setRitualDone(day: day, ritual: ritual, done: true),
    );
    expect(saved, isTrue);
    await tester.runAsync(store.reload);
  }

  testWidgets('saved local gestures are read-only and do not create flowers', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    await record(tester, today, AccueilRitual.water);
    await open(tester);
    expect(find.text("Boire un verre d'eau"), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text('Ajouter un rituel'), findsNothing);
    expect(find.text('Choisir un défi'), findsNothing);
    expect(find.text('Commencer'), findsNothing);
    expect(garden.completedChallenges, isEmpty);
    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    expect(find.text('Respirer 2 min'), findsNothing);
    expect(store.snapshot.rituals[today]!.isDone(AccueilRitual.water), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a recorded day without a flower opens its saved gestures', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    final day = today.day == 1 ? today : today.addDays(-1);
    await record(tester, day, AccueilRitual.reachOut);
    await open(tester);
    await openDay(tester, day);
    expect(find.text('Tes petits gestes'), findsOneWidget);
    expect(find.text('Écrire à un proche'), findsWidgets);
    expect(find.text('Tes défis terminés'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(garden.completedChallenges, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty today opens an honest read-only day detail', (
    tester,
  ) async {
    await open(tester);
    await openDay(tester, CivilDay.fromLocal(DateTime.now()));
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.text('Tes petits gestes sont enregistrés.'), findsNothing);
    expect(find.text('Tes défis terminés'), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(store.snapshot.rituals, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'completed challenge flowers retain their date and reward count',
    (tester) async {
      final now = DateTime.now();
      repository.completed = [
        UserChallenge(
          id: 'flower',
          userId: 'alice',
          challengeId: 'journal',
          status: 'COMPLETED',
          createdAt: now,
          updatedAt: now,
          completedAt: now,
          template: ChallengeTemplate(
            id: 'journal',
            title: 'Un moment pour écrire',
            source: 'SYSTEM',
            rewardPoints: 0,
            aggregator: 'ALL',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ];
      await open(tester);
      await openDay(tester, CivilDay.fromLocal(now));
      expect(find.text('Tes défis terminés'), findsOneWidget);
      expect(find.text('Un moment pour écrire'), findsOneWidget);
      await tester.tap(find.byTooltip('Fermer'));
      await tester.pumpAndSettle();
      expect(find.text('1 sur 5 défis'), findsOneWidget);
      expect(garden.completedChallenges, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('server errors preserve local consultation and expose retry', (
    tester,
  ) async {
    await record(
      tester,
      CivilDay.fromLocal(DateTime.now()),
      AccueilRitual.music,
    );
    repository.unavailable = true;
    await open(tester);
    expect(find.text('Écouter une chanson calme'), findsOneWidget);
    expect(find.text('Jardin indisponible'), findsWidgets);
    repository.unavailable = false;
    await Scrollable.ensureVisible(
      tester.element(find.text('Réessayer').first),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Réessayer').first);
    await tester.pumpAndSettle();
    expect(find.text('Jardin indisponible'), findsNothing);
    expect(find.text('Écouter une chanson calme'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('recorded dates remain readable when flowers are unavailable', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    final yesterday = today.addDays(-1);
    await record(tester, yesterday, AccueilRitual.music);
    repository.unavailable = true;
    await open(tester);
    if (yesterday.civilMonth != today.civilMonth) {
      final month = AppDates.format(
        DateTime(today.year, today.month),
        'MMMM yyyy',
      );
      await tester.tap(find.widgetWithText(TextButton, month).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mois précédent'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Voir le mois'));
      await tester.pumpAndSettle();
    }
    await openDay(tester, yesterday);
    expect(find.text('Écouter une chanson calme'), findsOneWidget);
    expect(garden.hasLoadedData, isFalse);
    expect(garden.completedChallenges, isEmpty);
    expect(
      store.snapshot.rituals[yesterday]!.isDone(AccueilRitual.music),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('period navigation stays accessible after scrolling', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Semaine'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mois'));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(
      tester.element(find.text('Prochaines récompenses')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Choisir une période'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mois précédent'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voir le mois'));
    await tester.pumpAndSettle();
    final today = CivilDay.fromLocal(DateTime.now());
    final previous = today.civilMonth.shifted(-1);
    final label = AppDates.format(
      DateTime(previous.year, previous.month),
      'MMMM yyyy',
    );
    expect(find.text(label), findsWidgets);
    expect(find.byTooltip('Choisir une période'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
