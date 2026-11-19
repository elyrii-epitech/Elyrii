import 'package:flutter/material.dart';

import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import 'journal_sheets.dart';

/// An entry of the feed and of the search results. [highlight] marks the
/// searched words in the title and the excerpt.
class JournalEntryCard extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onTap;
  final String highlight;
  const JournalEntryCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.highlight = '',
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mood = parseJournalMood(entry.mood);
    final radius = BorderRadius.circular(AppDimensions.radius20);
    return Material(
      color: AppColors.journalEntry(dark),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: AppColors.journalEntryBorder(dark), width: .5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppDimensions.spacing8,
            children: [
              Text.rich(
                _marked(
                  entry.title,
                  AppTextStyles.titleSmall(color: context.textPrimary),
                  dark,
                ),
              ),
              if ((entry.content ?? '').trim().isNotEmpty)
                Text.rich(
                  _marked(
                    entry.content!.trim(),
                    AppTextStyles.journalLine(color: context.textSecondary),
                    dark,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              Row(
                spacing: AppDimensions.spacing8,
                children: [
                  if (mood != null) ...[
                    JournalMoodDot(mood),
                    Text(
                      mood.label,
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    AppDates.format(entry.createdAt.toLocal(), 'HH:mm'),
                    style: AppTextStyles.bodySmall(color: context.textTertiary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextSpan _marked(String text, TextStyle style, bool dark) {
    final needle = highlight.trim().toLowerCase();
    if (needle.isEmpty) return TextSpan(text: text, style: style);
    final lower = text.toLowerCase();
    final mark = style.copyWith(
      color: AppColors.journalAccent(dark),
      backgroundColor: AppColors.journalMark(dark),
    );
    final spans = <TextSpan>[];
    var start = 0;
    for (
      var at = lower.indexOf(needle);
      at >= 0;
      at = lower.indexOf(needle, start)
    ) {
      if (at > start) spans.add(TextSpan(text: text.substring(start, at)));
      start = at + needle.length;
      spans.add(TextSpan(text: text.substring(at, start), style: mark));
    }
    if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
    return TextSpan(style: style, children: spans);
  }
}
