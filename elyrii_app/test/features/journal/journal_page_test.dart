import 'dart:async';

import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/core/storage/content_cipher.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/features/dashboard/data/accueil_activities.dart';
import 'package:elyrii_app/features/dashboard/domain/civil_day.dart';
import 'package:elyrii_app/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/domain/journal_feed.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/journal_editor_sheet.dart';
import 'package:elyrii_app/features/mascot/presentation/providers/mascot_provider.dart';
import 'package:elyrii_app/core/widgets/mascot_with_accessories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

JournalEntryModel _entry(
  String id,
  String title,
  String content,
  DateTime at, {
  String? mood,
}) => JournalEntryModel(
  id: id,
  userId: 'alice',
  title: title,
  content: content,
  mood: mood,
  createdAt: at,
  updatedAt: at,
);

class _Repository extends JournalRepository {
  final List<JournalEntryModel> items;
  bool failCreation = false;
  Completer<void>? creationGate;
  final createdContents = <String?>[];
  _Repository(this.items)
    : super(client: ApiClient(storage: SecureStorageService()));

  @override
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async => List.unmodifiable(items);
  @override
  Future<List<JournalEntryModel>> getCachedEntries({String? owner}) async =>
      const [];
  @override
  Future<JournalEntryModel> createEntry({
    required String title,
    String? content,
    String? mood,
    List<String>? tags,
    String? clientRequestId,
  }) async {
    createdContents.add(content);
    await creationGate?.future;
    if (failCreation) throw StateError('Offline');
    final entry = _entry(
      'created',
      title,
      content ?? '',
      DateTime.now(),
      mood: mood,
    );
    items.add(entry);
    return entry;
  }

  @override
  Future<void> deleteEntry(String id) async =>
      items.removeWhere((entry) => entry.id == id);
}

class _Routes extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

Future<AccueilActivities> _mount(
  WidgetTester tester,
  List<JournalEntryModel> entries, {
  _Repository? repository,
  NavigatorObserver? observer,
  double scale = 1,
  bool reduced = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final client = ApiClient(storage: SecureStorageService());
  final journal = JournalProvider(
    repository: repository ?? _Repository(entries),
  );
  final activities = AccueilActivities(
    cipher: ContentCipher(SecureStorageService()),
  )..onUserChanged(userId: 'alice');
  addTearDown(journal.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: journal),
        ChangeNotifierProvider.value(value: activities),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider(apiClient: client),
        ),
        ChangeNotifierProvider(create: (_) => MascotProvider(client: client)),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        navigatorObservers: [?observer],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: const JournalPage(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  return activities;
}

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final now = DateTime.now();
  final today = CivilDay.fromLocal(now);
  final lastMonth = today.civilMonth.shifted(-1);
  final monthAgo = DateTime(
    lastMonth.year,
    lastMonth.month,
    today.day.clamp(1, lastMonth.lastDay.day),
    19,
    5,
  );

  testWidgets('a past entry comes back as a memory and opens for reading', (
    tester,
  ) async {
    await _mount(tester, [
      _entry('table', 'Une place à table', 'Lina m’a gardé une place.', now),
      _entry(
        'courage',
        'Oser dire bonjour',
        'Ça paraît petit, mais pour moi ça compte.',
        monthAgo,
        mood: 'sad',
      ),
    ]);

    expect(find.text('Il y a un mois'), findsOneWidget);
    await tester.ensureVisible(find.text('Relire cette note'));
    await tester.pump();
    await tester.tap(find.text('Relire cette note'));
    await tester.pump();

    expect(find.text('Supprimer'), findsOneWidget);
    expect(find.textContaining('Mal ·'), findsOneWidget);
    expect(
      find.text('Ça paraît petit, mais pour moi ça compte.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting from the reading page removes the entry', (
    tester,
  ) async {
    await _mount(tester, [
      _entry('table', 'Une place à table', 'Lina m’a gardé une place.', now),
    ]);

    await tester.tap(find.text('Une place à table'));
    await tester.pump();
    await tester.tap(find.text('Supprimer'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Supprimer la note'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Une place à table'), findsNothing);
    expect(find.text('Note supprimée de ton journal.'), findsOneWidget);
    expect(find.text('Comment s’est passée ta journée ?'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Note supprimée de ton journal.'), findsNothing);
  });

  testWidgets('search narrows the loaded entries by word and mood', (
    tester,
  ) async {
    await _mount(tester, [
      _entry(
        'oral',
        'Avant l’oral',
        'Je répète mon oral.',
        now,
        mood: 'neutral',
      ),
      _entry('walk', 'Un banc', 'Dix minutes au soleil.', now, mood: 'happy'),
      _entry('bus', 'Le bus', 'Rien à voir avec un ORAL.', now, mood: 'sad'),
    ]);

    await tester.tap(find.byTooltip('Rechercher dans le journal'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'oral');
    await tester.pump();
    expect(find.text('2 notes pour « oral »'), findsOneWidget);

    await tester.tap(
      find.bySemanticsLabel(
        'Filtrer les notes ${MoodType.neutral.label.toLowerCase()}',
      ),
    );
    await tester.pump();
    expect(find.text('1 note pour « oral »'), findsOneWidget);
    expect(find.text('Le bus'), findsNothing);

    await tester.enterText(find.byType(TextField), 'introuvable');
    await tester.pump();
    expect(find.textContaining('Aucune note avec ces mots.'), findsOneWidget);
  });

  testWidgets('the question of the day changes and stays for that day', (
    tester,
  ) async {
    final activities = await _mount(tester, [
      _entry('table', 'Une place à table', 'Lina m’a gardé une place.', now),
    ]);
    final shown = activities.snapshot.journalQuestionIndex(
      today,
      journalQuestions.length,
    );
    expect(find.text(journalQuestions[shown]), findsOneWidget);

    await tester.tap(find.byTooltip('Changer la question'));
    await tester.pumpAndSettle();
    final next = (shown + 1) % journalQuestions.length;
    expect(find.text(journalQuestions[next]), findsOneWidget);
    expect(activities.snapshot.journalQuestion?.day, today);
  });

  testWidgets('the same purple card expands in place for the first note', (
    tester,
  ) async {
    final observer = _Routes();
    await _mount(tester, [], observer: observer);
    final card = find.byKey(const Key('journal-composer-card'));
    final collapsed = tester.getSize(card).height;
    final originalCard = tester.element(card);
    expect(find.byType(MascotWithAccessories), findsNothing);
    expect(find.text('Pour commencer'), findsOneWidget);
    final routes = observer.pushes;
    await tester.tap(find.text('Écrire'));
    await tester.pumpAndSettle();
    expect(tester.getSize(card).height, greaterThan(collapsed));
    expect(tester.element(card), same(originalCard));
    expect(observer.pushes, routes);
    expect(find.byType(JournalEditorSheet), findsOneWidget);
    expect(find.text('0 mots'), findsOneWidget);
    await tester.tap(find.byTooltip('Réduire la note'));
    await tester.pumpAndSettle();
    expect(find.byType(JournalEditorSheet), findsNothing);
    expect(tester.getSize(card).height, collapsed);
    expect(observer.pushes, routes);
  });

  testWidgets(
    'the first autosave keeps the editor and later words in the same card',
    (tester) async {
      final repository = _Repository([])..creationGate = Completer<void>();
      await _mount(tester, [], repository: repository);
      await tester.tap(find.text('Écrire'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Ma première note');
      await tester.pump(const Duration(seconds: 2));
      final editor = tester.state(find.byType(JournalEditorSheet));
      repository.creationGate!.complete();
      await tester.pump();
      expect(tester.state(find.byType(JournalEditorSheet)), same(editor));
      expect(find.text('Ma première note'), findsWidgets);
      expect(repository.createdContents, ['Ma première note']);
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalEditorSheet), findsNothing);
      expect(find.text('Ma première note'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'a failed first save keeps the expanded note available for retry',
    (tester) async {
      final repository = _Repository([])..failCreation = true;
      await _mount(tester, [], repository: repository);
      await tester.tap(find.text('Écrire'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'À conserver');
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(find.byType(JournalEditorSheet), findsOneWidget);
      expect(find.text('À conserver'), findsOneWidget);
      expect(find.text('Enregistrement impossible. Réessaie.'), findsOneWidget);
      repository.failCreation = false;
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalEditorSheet), findsNothing);
      expect(find.text('À conserver'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'inline writing remains scrollable with large text and the keyboard',
    (tester) async {
      await _mount(tester, [], scale: 3);
      tester.view.physicalSize = const Size(320, 568);
      await tester.pumpAndSettle();
      await Scrollable.ensureVisible(
        tester.element(find.text('Écrire')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Écrire'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Texte agrandi');
      await tester.ensureVisible(find.text('Enregistrer'));
      await tester.pumpAndSettle();
      expect(find.text('Texte agrandi'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'reduced motion expands directly without a route or layout mutation',
    (tester) async {
      final observer = _Routes();
      await _mount(tester, [], observer: observer, reduced: true);
      final routes = observer.pushes;
      await tester.tap(find.byKey(const Key('journal-composer-card')));
      await tester.pumpAndSettle();
      expect(find.byType(JournalEditorSheet), findsOneWidget);
      expect(observer.pushes, routes);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Réduire la note'));
      await tester.pumpAndSettle();
      expect(find.byType(JournalEditorSheet), findsNothing);
    },
  );

  test('historical and current mood labels preserve their stored meaning', () {
    final aliases = <MoodType, List<String>>{
      MoodType.verySad: [
        'verySad',
        'Très triste',
        'Éprouvé',
        'eprouve',
        'Très mal',
      ],
      MoodType.sad: ['sad', 'Triste', 'Vulnérable', 'vulnerable', 'Mal'],
      MoodType.neutral: ['neutral', 'Neutre', 'Paisible', 'Bof'],
      MoodType.happy: ['happy', 'Joyeux', 'Serein', 'Bien'],
      MoodType.veryHappy: [
        'veryHappy',
        'Très joyeux',
        'Rayonnant',
        'Très bien',
      ],
    };
    for (final entry in aliases.entries) {
      for (final label in entry.value) {
        expect(parseJournalMood(label), entry.key, reason: label);
        expect(
          parseJournalMood('  ${label.toUpperCase()}  '),
          entry.key,
          reason: label,
        );
      }
    }
    expect(parseJournalMood('inconnue'), isNull);
  });

  test('a memory is only an entry about one month old', () {
    final day = CivilDay(2026, 10, 22);
    final near = _entry('a', 'A', 'a', DateTime(2026, 9, 25, 12));
    final far = _entry('b', 'B', 'b', DateTime(2026, 9, 2, 12));
    expect(journalMemory([near, far], day)?.id, 'a');
    expect(journalMemory([far], day), isNull);
  });

  test(
    'text export includes local drafts without presenting them as saved',
    () {
      final text = journalExportText(
        [
          _entry(
            'saved',
            'Mon titre',
            'Texte enregistré',
            DateTime(2026, 10, 22),
          ),
        ],
        (_) => '22 octobre 2026',
        drafts: [
          {
            'id': 'new',
            'data': {'title': '', 'content': 'Encore en brouillon'},
          },
        ],
      );
      expect(text, contains('22 octobre 2026\nMon titre\n\nTexte enregistré'));
      expect(
        text,
        contains('Brouillon\n$journalFallbackTitle\n\nEncore en brouillon'),
      );
    },
  );
}
