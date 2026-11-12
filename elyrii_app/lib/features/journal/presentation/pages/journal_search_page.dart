import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import '../widgets/journal_entry_card.dart';
import '../widgets/journal_sheets.dart';
import 'journal_entry_page.dart';

/// Searches the loaded entries by words, mood and month.
class JournalSearchPage extends StatefulWidget {
  const JournalSearchPage({super.key});

  @override
  State<JournalSearchPage> createState() => _JournalSearchPageState();
}

class _JournalSearchPageState extends State<JournalSearchPage> {
  final _query = TextEditingController();
  MoodType? _mood;
  CivilMonth? _month;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  String _monthName(CivilMonth month) {
    final label = AppDates.format(
      DateTime(month.year, month.month),
      'MMMM yyyy',
    );
    return '${label[0].toUpperCase()}${label.substring(1)}';
  }

  Future<void> _pickMonth(List<JournalEntry> entries) async {
    final months = groupJournalMonths(entries).map((group) => group.month);
    final picked = await showJournalSheet<(CivilMonth?,)>(
      context,
      title: 'Quel mois ?',
      child: Builder(
        builder: (sheet) => JournalRowGroup(
          children: [
            JournalRow(
              label: 'Tous les mois',
              onTap: () => Navigator.of(sheet).pop((null,)),
            ),
            for (final month in months)
              JournalRow(
                label: _monthName(month),
                onTap: () => Navigator.of(sheet).pop((month,)),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _month = picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.text.trim();
    final results = searchJournal(
      provider.entries,
      query: query,
      mood: _mood,
      month: _month,
    );
    final count = results.length;
    final safe = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppDimensions.pageHorizontalPadding,
                  safe.top +
                      AppDimensions.accueilBarHeight +
                      AppDimensions.spacing12,
                  AppDimensions.pageHorizontalPadding,
                  safe.bottom + AppDimensions.spacing48,
                ),
                children: [
                  Row(
                    spacing: AppDimensions.spacing8,
                    children: [
                      for (final mood in MoodType.values)
                        _moodFilter(mood, dark),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Material(
                            color: dark
                                ? AppColors.cardDark
                                : AppColors.surfaceLight,
                            shape: StadiumBorder(
                              side: BorderSide(
                                color: dark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: InkWell(
                              customBorder: const StadiumBorder(),
                              onTap: () => _pickMonth(provider.entries),
                              child: Container(
                                height: AppDimensions.journalTool,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppDimensions.spacing12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        _month == null
                                            ? 'Tous les mois'
                                            : _monthName(_month!),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTextStyles.pillLabel(
                                          color: context.textPrimary,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Symbols.expand_more_rounded,
                                      size: AppDimensions.iconSm,
                                      color: context.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacing20),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacing4,
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        [
                          '$count ${count == 1 ? 'note' : 'notes'}${query.isEmpty ? '' : ' pour « $query »'}',
                          if (provider.hasMore)
                            'Parmi les ${provider.entries.length} notes chargées.',
                        ].join('\n'),
                        style: AppTextStyles.bodySmall(
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing12),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing4,
                        vertical: AppDimensions.spacing20,
                      ),
                      child: Text(
                        'Aucune note avec ces mots.\nEssaie un autre mot ou enlève un filtre.',
                        style: AppTextStyles.journalLine(
                          color: context.textSecondary,
                        ),
                      ),
                    )
                  else
                    for (final entry in results)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.spacing12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: AppDimensions.spacing4,
                                bottom: AppDimensions.spacing8,
                              ),
                              child: Text(
                                AppDates.format(
                                  entry.createdAt.toLocal(),
                                  'd MMMM yyyy',
                                ),
                                style: AppTextStyles.bodySmall(
                                  color: context.textTertiary,
                                ),
                              ),
                            ),
                            JournalEntryCard(
                              entry: entry,
                              highlight: query,
                              onTap: () => openJournalEntry(context, entry),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            ),
          ),
          JournalBar(
            child: Row(
              spacing: AppDimensions.spacing8,
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppDimensions.journalSearchField,
                    child: Semantics(
                      label: 'Rechercher une note',
                      child: TextField(
                        controller: _query,
                        autofocus: true,
                        onChanged: (_) => setState(() {}),
                        textInputAction: TextInputAction.search,
                        style: AppTextStyles.bodyLarge(
                          color: context.textPrimary,
                        ),
                        cursorColor: AppColors.primaryText(dark),
                        decoration: InputDecoration(
                          hintText: 'Rechercher dans le journal',
                          hintStyle: AppTextStyles.bodyLarge(
                            color: context.textTertiary,
                          ),
                          prefixIcon: Icon(
                            Symbols.search_rounded,
                            size: AppDimensions.iconSm,
                            color: context.textTertiary,
                          ),
                          filled: true,
                          fillColor: AppColors.track(dark),
                          contentPadding: EdgeInsets.zero,
                          border: _searchBorder,
                          enabledBorder: _searchBorder,
                          focusedBorder: _searchBorder,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryText(dark),
                    backgroundColor: Colors.transparent,
                    textStyle: AppTextStyles.journalLine(),
                  ),
                  child: const Text('Annuler'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _moodFilter(MoodType mood, bool dark) {
    final on = _mood == mood;
    return Semantics(
      button: true,
      selected: on,
      label: 'Filtrer les notes ${mood.label.toLowerCase()}',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => setState(() => _mood = on ? null : mood),
        customBorder: const CircleBorder(),
        child: Container(
          width: AppDimensions.journalTool,
          height: AppDimensions.journalTool,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: on
                ? AppColors.tintSoft(dark)
                : (dark ? AppColors.surfaceDark : AppColors.surfaceLight),
            border: Border.all(
              color: on
                  ? AppColors.primaryText(dark)
                  : (dark ? AppColors.borderDark : AppColors.borderLight),
            ),
          ),
          child: JournalMoodDot(mood, size: AppDimensions.journalFilterDot),
        ),
      ),
    );
  }
}

final _searchBorder = OutlineInputBorder(
  borderRadius: BorderRadius.circular(AppDimensions.radius12),
  borderSide: BorderSide.none,
);
