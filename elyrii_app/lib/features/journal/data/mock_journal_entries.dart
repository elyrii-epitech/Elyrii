import '../presentation/providers/journal_provider.dart';

List<JournalEntry> getMockJournalEntries() {
  final now = DateTime.now();

  return [
    JournalEntry(
      id: '1',
      title: 'Premier jour',
      content:
          'Aujourd\'hui a été une journée incroyable. J\'ai commencé à utiliser cette application et je me sens déjà plus serein.',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    JournalEntry(
      id: '2',
      title: 'Réflexion du soir',
      content:
          'Je me sens un peu anxieux ce soir. Beaucoup de choses dans ma tête.',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    JournalEntry(
      id: '3',
      content:
          'Une journée calme et reposante. J\'ai pris le temps de méditer.',
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
