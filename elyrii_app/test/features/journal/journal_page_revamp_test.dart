import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:elyrii_app/core/theme/app_theme.dart';
import 'package:elyrii_app/core/network/api_client.dart';
import 'package:elyrii_app/core/services/secure_storage_service.dart';
import 'package:elyrii_app/features/journal/data/models/journal_entry_model.dart';
import 'package:elyrii_app/features/journal/data/repositories/journal_repository.dart';
import 'package:elyrii_app/features/journal/presentation/pages/journal_page.dart';
import 'package:elyrii_app/features/journal/presentation/providers/journal_provider.dart';
import 'package:elyrii_app/features/journal/presentation/widgets/glass_journal_card.dart';

class _FakeJournalRepository extends JournalRepository {
  final List<JournalEntryModel> _mockEntries;

  _FakeJournalRepository(this._mockEntries)
    : super(client: ApiClient(storage: SecureStorageService()));

  @override
  Future<List<JournalEntryModel>> getEntries({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _mockEntries;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedDate = DateTime(2026, 9, 15, 14, 30); // 15 sept. 2026 (mardi)

  final testEntry = JournalEntryModel(
    id: 'entry_1',
    userId: 'user_1',
    title: 'Une belle promenade',
    content: 'Le soleil brillait et l\'air frais m\'a fait du bien.',
    mood: 'happy',
    createdAt: fixedDate,
    updatedAt: fixedDate,
  );

  group('GlassJournalCard Apple HIG typography', () {
    testWidgets(
      'affiche la date au format FR, l\'heure, le titre et la pastille d\'humeur',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: GlassJournalCard(
                entry: testEntry,
                isDark: false,
                onTap: () {},
              ),
            ),
          ),
        );

        // Date FR et heure
        expect(find.textContaining('15'), findsOneWidget);
        expect(find.textContaining('14:30'), findsOneWidget);

        // Titre
        expect(find.text('Une belle promenade'), findsOneWidget);

        // Pastille humeur
        expect(find.text('Joyeux'), findsOneWidget);

        // Contenu
        expect(find.textContaining('Le soleil brillait'), findsOneWidget);
      },
    );
  });

  group('JournalPage iOS HIG architecture', () {
    testWidgets('keeps a thousand notes lazy while scrolling', (tester) async {
      final entries = List.generate(
        1000,
        (index) => JournalEntryModel(
          id: 'entry-$index',
          userId: 'user_1',
          title: 'Note $index',
          content: 'Une pensée à conserver.',
          createdAt: fixedDate.subtract(Duration(days: index)),
          updatedAt: fixedDate,
        ),
      );
      final provider = JournalProvider(
        repository: _FakeJournalRepository(entries),
      );
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const JournalPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassJournalCard).evaluate().length, lessThan(15));
      expect(find.text('Note 999'), findsNothing);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -1400));
      await tester.pumpAndSettle();
      expect(find.byType(GlassJournalCard).evaluate().length, lessThan(15));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'utilise CustomScrollView sans bandeau sombre avec boutons en verre liquide et grand titre',
      (tester) async {
        final fakeRepo = _FakeJournalRepository([testEntry]);
        final provider = JournalProvider(repository: fakeRepo);

        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<JournalProvider>.value(value: provider),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const JournalPage(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Structure CustomScrollView fluide
        expect(find.byType(CustomScrollView), findsOneWidget);
        // Aucun bandeau sombre SliverAppBar
        expect(find.byType(SliverAppBar), findsNothing);

        // Boutons d'actions décrochés en verre liquide
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);

        // Grand titre Journal présent
        expect(find.text('Journal'), findsOneWidget);

        // Carte de note affichée
        expect(find.byType(GlassJournalCard), findsOneWidget);
      },
    );
  });
}
