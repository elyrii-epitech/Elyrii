import '../../dashboard/domain/civil_day.dart';
import '../../dashboard/presentation/mood_presentation.dart';
import '../data/models/journal_entry_model.dart';

/// Questions of the composer, one per day unless the user changes it.
const journalQuestions = [
  'Qu’est-ce qui t’a fait sourire aujourd’hui ?',
  'Quel petit moment aimerais-tu garder ?',
  'Qu’est-ce qui t’a fait du bien aujourd’hui ?',
];

/// Writing prompts of the first day and of the editor's prompt sheet.
const journalPrompts = [
  'Comment s’est passée ta journée ?',
  'Qu’est-ce qui occupe tes pensées ?',
  'De quoi es-tu reconnaissant(e) ?',
  'Qu’est-ce que tu aimerais améliorer ?',
];

const journalFreePrompt = 'Une page à toi, sans question.';

/// Titles saved when the writer leaves the title empty.
const journalFallbackTitle = 'Quelques mots pour moi';

/// Entries store the mood as free text: recent ones carry the [MoodType]
/// name, older ones a French label. Unknown values have no mood.
MoodType? parseJournalMood(String? raw) {
  final value = raw?.trim().toLowerCase();
  if (value == null || value.isEmpty) return null;
  for (final mood in MoodType.values) {
    if (mood.name.toLowerCase() == value || mood.label.toLowerCase() == value) {
      return mood;
    }
  }
  return switch (value) {
    'très triste' || 'tres triste' => MoodType.verySad,
    'triste' => MoodType.sad,
    'neutre' => MoodType.neutral,
    'joyeux' || 'content' => MoodType.happy,
    'très joyeux' || 'tres joyeux' || 'radieux' => MoodType.veryHappy,
    _ => null,
  };
}

int journalWordCount(String text) {
  final trimmed = text.trim();
  return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
}

/// One month of the feed, newest entry first.
class JournalMonth {
  final CivilMonth month;
  final List<JournalEntryModel> entries;
  const JournalMonth(this.month, this.entries);
}

/// Groups newest-first entries by local calendar month.
List<JournalMonth> groupJournalMonths(List<JournalEntryModel> entries) {
  final months = <JournalMonth>[];
  for (final entry in entries) {
    final month = CivilDay.fromLocal(entry.createdAt).civilMonth;
    if (months.isEmpty || months.last.month != month) {
      months.add(JournalMonth(month, []));
    }
    months.last.entries.add(entry);
  }
  return months;
}

/// The entry written closest to one month before [today], within a week of
/// that date. Nothing older or newer is presented as « il y a un mois ».
JournalEntryModel? journalMemory(
  List<JournalEntryModel> entries,
  CivilDay today,
) {
  final target = today.civilMonth.shifted(-1);
  final anchor = CivilDay(
    target.year,
    target.month,
    today.day.clamp(1, target.lastDay.day),
  );
  JournalEntryModel? best;
  var bestDistance = 8;
  for (final entry in entries) {
    final distance = anchor
        .daysUntil(CivilDay.fromLocal(entry.createdAt))
        .abs();
    if (distance < bestDistance) {
      best = entry;
      bestDistance = distance;
    }
  }
  return best;
}

/// Local search over the loaded entries: words in the title or the text,
/// and optional mood and month filters.
List<JournalEntryModel> searchJournal(
  List<JournalEntryModel> entries, {
  String query = '',
  MoodType? mood,
  CivilMonth? month,
}) {
  final needle = query.trim().toLowerCase();
  return [
    for (final entry in entries)
      if ((mood == null || parseJournalMood(entry.mood) == mood) &&
          (month == null ||
              CivilDay.fromLocal(entry.createdAt).civilMonth == month) &&
          '${entry.title} ${entry.content ?? ''}'.toLowerCase().contains(
            needle,
          ))
        entry,
  ];
}

/// The plain-text file of « Exporter mes écrits », with unsaved local pages
/// labelled separately from confirmed entries.
String journalExportText(
  List<JournalEntryModel> entries,
  String Function(DateTime) date, {
  List<Map<String, dynamic>> drafts = const [],
}) {
  final pages = [
    for (final entry in entries)
      '${date(entry.createdAt.toLocal())}\n${entry.title}\n\n${entry.content ?? ''}',
  ];
  for (final draft in drafts) {
    final data = draft['data'] as Map<String, dynamic>;
    final content = (data['content'] as String? ?? '').trim();
    if (content.isEmpty) continue;
    final title = (data['title'] as String? ?? '').trim();
    pages.add(
      'Brouillon\n${title.isEmpty ? journalFallbackTitle : title}\n\n$content',
    );
  }
  return pages.join('\n\n···\n\n');
}
