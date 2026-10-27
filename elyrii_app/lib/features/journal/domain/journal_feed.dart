import '../../dashboard/domain/civil_day.dart';
import '../../dashboard/presentation/mood_presentation.dart';
import '../data/models/journal_entry_model.dart';

/// Questions of the composer, one per day unless the user changes it.
const journalQuestions = [
  'Comment s’est passée ta journée ?',
  'Qu’est-ce qui t’a marqué aujourd’hui ?',
  'Qu’est-ce qui te préoccupe en ce moment ?',
];

/// Writing prompts of the first day and of the editor's prompt sheet.
const journalPrompts = [
  'Comment s’est passée ta journée ?',
  'Qu’est-ce qui occupe tes pensées ?',
  'Qu’est-ce qui t’a marqué aujourd’hui ?',
  'De quoi as-tu envie pour la suite ?',
];

const journalFreePrompt = 'Écriture libre';

/// Titles saved when the writer leaves the title empty.
const journalFallbackTitle = 'Sans titre';

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
    'très triste' ||
    'tres triste' ||
    'éprouvé' ||
    'eprouve' => MoodType.verySad,
    'triste' || 'vulnérable' || 'vulnerable' => MoodType.sad,
    'neutre' || 'paisible' => MoodType.neutral,
    'joyeux' || 'content' || 'serein' => MoodType.happy,
    'très joyeux' ||
    'tres joyeux' ||
    'radieux' ||
    'rayonnant' => MoodType.veryHappy,
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

/// Entry written closest to one month before [today], within a week of that
/// date. Older or newer entries are not presented as being a month old.
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

/// Plain-text journal export, with unsaved local pages labeled separately from
/// confirmed entries.
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
