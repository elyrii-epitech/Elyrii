import 'models/journal_entry_model.dart';

List<JournalEntryModel> getMockJournalEntries() {
  final now = DateTime.now();

  return [
    JournalEntryModel(
      id: '1',
      userId: 'mock-user',
      title: 'Premier jour',
      content:
          'Aujourd\'hui a été une journée incroyable. J\'ai commencé à utiliser cette application et je me sens déjà plus serein.',
      createdAt: now.subtract(const Duration(days: 2)),
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    JournalEntryModel(
      id: '2',
      userId: 'mock-user',
      title: 'Réflexion du soir',
      content:
          'Je me sens un peu anxieux ce soir. Beaucoup de choses dans ma tête.',
      createdAt: now.subtract(const Duration(days: 1)),
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    JournalEntryModel(
      id: '3',
      userId: 'mock-user',
      title: 'Moment zen',
      content:
          'Une journée calme et reposante. J\'ai pris le temps de méditer.',
      createdAt: now,
      updatedAt: now,
    ),
  ];
}
