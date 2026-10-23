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
import 'package:elyrii_app/features/gamification/presentation/widgets/challenge_collection.dart';
import 'package:elyrii_app/features/gamification/presentation/widgets/monthly_garden.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:material_symbols_icons/symbols.dart';
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
  });

  tearDown(() {
    store.dispose();
    garden.dispose();
  });

  Future<void> open(WidgetTester tester, {double height = 844}) async {
    await tester.binding.setSurfaceSize(Size(390, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AccueilActivities>.value(value: store),
          ChangeNotifierProvider<GamificationProvider>.value(value: garden),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ChallengesPage(),
        ),
      ),
    );
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

  UserChallenge challenge(
    String id, {
    DateTime? completedAt,
    DateTime? createdAt,
    String? title,
  }) {
    final created = createdAt ?? DateTime(2020);
    return UserChallenge(
      id: id,
      userId: 'alice',
      challengeId: 'template-$id',
      status: 'COMPLETED',
      createdAt: created,
      updatedAt: DateTime(2020),
      completedAt: completedAt,
      template: ChallengeTemplate(
        id: 'template-$id',
        title: title ?? 'Défi $id',
        source: 'SYSTEM',
        rewardPoints: 0,
        aggregator: 'ALL',
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  DateTime at(CivilDay day, [int hour = 12]) =>
      DateTime(day.year, day.month, day.day, hour);

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
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
    expect(store.snapshot.rituals[today]!.isDone(AccueilRitual.water), isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('today follows the challenges and precedes the monthly garden', (
    tester,
  ) async {
    await open(tester);
    final challenges = tester.getRect(find.byType(ChallengeCollection));
    final today = tester.getRect(find.text("Aujourd'hui"));
    final monthly = tester.getRect(find.byType(MonthlyGarden));
    expect(challenges.bottom, lessThanOrEqualTo(today.top));
    expect(today.bottom, lessThanOrEqualTo(monthly.top));
    expect(find.text('Prochaines récompenses'), findsNothing);
    expect(find.text('Complétion quotidienne'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'each month lists its own completed challenges by completion date',
    (tester) async {
      final today = CivilDay.fromLocal(DateTime.now());
      final previous = today.civilMonth.shifted(-1);
      repository.completed = [
        challenge(
          'now',
          completedAt: at(today),
          createdAt: at(previous.firstDay),
        ),
        challenge('now', completedAt: at(today)),
        challenge(
          'edge',
          completedAt: at(previous.lastDay, 23),
          createdAt: at(today),
        ),
        challenge('mid', completedAt: at(previous.firstDay.addDays(14))),
        challenge('future', completedAt: at(today.addDays(1))),
        challenge('undated'),
      ];
      await open(tester);

      expect(
        find.bySemanticsLabel(RegExp('^Fleur : Défi now')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          RegExp('^Fleur : Défi (edge|mid|future|undated)'),
        ),
        findsNothing,
      );
      expect(find.widgetWithText(ListTile, 'Défi now'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Défi edge'), findsNothing);
      expect(find.textContaining("n'a pas de date"), findsOneWidget);

      await tapVisible(tester, find.byTooltip('Mois précédent'));
      expect(
        find.bySemanticsLabel(RegExp('^Fleur : Défi mid')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(RegExp('^Fleur : Défi edge')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp('^Fleur : Défi now')), findsNothing);
      expect(find.widgetWithText(ListTile, 'Défi edge'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Défi now'), findsNothing);

      await tapVisible(tester, find.byTooltip('Mois suivant'));
      expect(
        find.bySemanticsLabel(RegExp('^Fleur : Défi now')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a challenge completed after a refresh becomes a new flower', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    repository.completed = [challenge('old', completedAt: at(today, 8))];
    await open(tester);
    final oldFlower = find.bySemanticsLabel(RegExp('^Fleur : Défi old'));
    expect(oldFlower, findsOneWidget);
    final oldPosition = tester.getCenter(oldFlower);

    repository.completed = [
      challenge('old', completedAt: at(today, 8)),
      challenge('new', completedAt: at(today, 9)),
    ];
    await tester.runAsync(() => garden.loadAll(force: true));
    await tester.pump();
    expect(find.bySemanticsLabel(RegExp('^Fleur : Défi new')), findsOneWidget);
    expect(oldFlower, findsOneWidget);
    expect(tester.getCenter(oldFlower), oldPosition);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pulling down refreshes the garden from the server', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    await open(tester);
    expect(find.bySemanticsLabel(RegExp('^Fleur : ')), findsNothing);
    repository.completed = [challenge('late', completedAt: at(today))];
    await tester.drag(find.text('Défis à réaliser'), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('^Fleur : Défi late')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failed refresh keeps the monthly garden on screen', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    repository.completed = [challenge('kept', completedAt: at(today))];
    await open(tester);
    repository.unavailable = true;
    await tester.runAsync(() => garden.loadAll(force: true));
    await tester.pump();
    expect(find.text('Jardin indisponible'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('^Fleur : Défi kept')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('every flower of a crowded month stays reachable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final today = CivilDay.fromLocal(DateTime.now());
    repository.completed = [
      for (var i = 0; i < 35; i++) challenge('c$i', completedAt: at(today, 10)),
    ];
    await open(tester, height: 3000);
    expect(find.bySemanticsLabel(RegExp('^Fleur : ')), findsNWidgets(35));

    expect(find.byType(ListTile), findsNWidgets(3));
    await tapVisible(tester, find.text('Voir tout (35)'));
    expect(find.byType(ListTile), findsNWidgets(35));
    await tapVisible(tester, find.text('Réduire'));
    expect(find.byType(ListTile), findsNWidgets(3));
    handle.dispose();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a flower opens its actual challenge and completion date', (
    tester,
  ) async {
    final today = CivilDay.fromLocal(DateTime.now());
    repository.completed = [
      challenge('one', completedAt: at(today), title: 'Un moment pour écrire'),
    ];
    await open(tester, height: 3000);
    final flower = find.bySemanticsLabel(
      RegExp('^Fleur : Un moment pour écrire'),
    );
    await tester.tap(flower);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Fermer'), findsOneWidget);
    expect(find.textContaining('Terminé le'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

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
    expect(find.byType(MonthlyGarden), findsNothing);
    expect(find.text('Aucun défi terminé pendant ce mois.'), findsNothing);
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
    expect(find.byType(MonthlyGarden), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('monthly navigation blocks future months', (tester) async {
    await open(tester);
    final today = CivilDay.fromLocal(DateTime.now());
    final previous = today.civilMonth.shifted(-1);
    await tapVisible(tester, find.byTooltip('Mois précédent'));
    expect(
      find.text(
        AppDates.format(DateTime(previous.year, previous.month), 'MMMM yyyy'),
      ),
      findsWidgets,
    );
    await tapVisible(tester, find.byTooltip('Mois suivant'));
    expect(
      find.text(
        AppDates.format(DateTime(today.year, today.month), 'MMMM yyyy'),
      ),
      findsWidgets,
    );
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Symbols.chevron_right_rounded),
          )
          .onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox());
  });
}
