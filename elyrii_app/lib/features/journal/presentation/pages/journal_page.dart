import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass_bar_button.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/domain/civil_day.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import '../widgets/journal_entry_card.dart';
import '../widgets/journal_editor_sheet.dart';
import '../widgets/journal_sheets.dart';
import 'journal_entry_page.dart';
import 'journal_search_page.dart';

/// The Journal tab: a page to write on, then the thread of the days with entries.
class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final _scroll = ScrollController();
  final _composer = GlobalKey();
  final _editor = GlobalKey();
  bool _writing = false;
  bool _revealPending = false;
  String? _writingOwner;
  String? _prompt;
  MoodType? _mood;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_loadMoreNearEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<JournalProvider>().loadEntries());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    final provider = context.read<JournalProvider>();
    if (_scroll.position.extentAfter < AppDimensions.sectionSkyHeight &&
        provider.hasMore &&
        !provider.loadingMore) {
      unawaited(provider.loadMore());
    }
  }

  JournalProvider get _provider => context.read<JournalProvider>();
  bool get _isWriting => _writing && _writingOwner == _provider.owner;

  void _write({String? prompt, MoodType? mood}) {
    if (_writing && _writingOwner == _provider.owner) return;
    setState(() {
      _writing = true;
      _revealPending = true;
      _writingOwner = _provider.owner;
      _prompt = prompt;
      _mood = mood;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealComposer());
  }

  void _revealComposer({bool animationFinished = false}) {
    if (!mounted || !_isWriting || !_revealPending || !_scroll.hasClients) {
      return;
    }
    final box = _composer.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced || animationFinished) _revealPending = false;
    final top =
        MediaQuery.paddingOf(context).top +
        AppDimensions.accueilBarHeight +
        AppDimensions.spacing12;
    final target = (_scroll.offset + box.localToGlobal(Offset.zero).dy - top)
        .clamp(0.0, _scroll.position.maxScrollExtent);
    if (reduced) {
      _scroll.jumpTo(target);
    } else {
      unawaited(
        _scroll.animateTo(
          target,
          duration: AppMotion.sheetEnter,
          curve: AppMotion.accueilEase,
        ),
      );
    }
  }

  void _collapse() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _writing = false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final activities = context.watch<AccueilActivities?>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final today = CivilDay.fromLocal(DateTime.now());
    final entries = provider.entries;
    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Stack(
                      children: [
                        const SectionSkyHeader(
                          title: 'Journal',
                          scene: SectionSkyScene.window,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            top:
                                AppDimensions.sectionSkyHeight -
                                AppDimensions.sectionBodyOverlap,
                          ),
                          child: SectionSkyBody(
                            bottomPadding:
                                AppShell.bottomClearanceOf(context) +
                                AppDimensions.spacing24,
                            child:
                                entries.isEmpty &&
                                    !_isWriting &&
                                    (provider.isLoading ||
                                        provider.error != null)
                                ? _withoutEntries(provider)
                                : _feed(provider, activities, today, dark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _TopBar(
                scroll: _scroll,
                onSearch: () =>
                    pushJournalPage(context, const JournalSearchPage()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withoutEntries(JournalProvider provider) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AppDimensions.spacing48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (provider.error case final error?) {
      return Column(
        spacing: AppDimensions.spacing12,
        children: [
          Text(
            error,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          TextButton(
            onPressed: provider.loadEntries,
            child: const Text('Réessayer'),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _feed(
    JournalProvider provider,
    AccueilActivities? activities,
    CivilDay today,
    bool dark,
  ) {
    final question =
        journalQuestions[activities?.snapshot.journalQuestionIndex(
              today,
              journalQuestions.length,
            ) ??
            CivilDay(1970, 1, 1).daysUntil(today) % journalQuestions.length];
    final memory = journalMemory(provider.entries, today);
    final months = groupJournalMonths(provider.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.accueilSectionGap,
      children: [
        _Composer(
          key: _composer,
          onExpanded: () => WidgetsBinding.instance.addPostFrameCallback(
            (_) => _revealComposer(animationFinished: true),
          ),
          editor: _isWriting
              ? JournalEditorSheet(
                  key: _editor,
                  provider: provider,
                  initialPrompt: _prompt,
                  initialMood: _mood,
                  onClose: _collapse,
                )
              : null,
          question: question,
          onWrite: () => _write(prompt: question),
          onNextQuestion: activities == null
              ? null
              : () => activities.nextJournalQuestion(
                  day: today,
                  count: journalQuestions.length,
                ),
          onMood: () async {
            final mood = await showJournalMoodPicker(context);
            if (mood != null && mounted) _write(prompt: question, mood: mood);
          },
        ),
        if (provider.entries.isEmpty && !_isWriting)
          _WritingIdeas(onWrite: (prompt) => _write(prompt: prompt)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.journalMonthGap,
          children: [
            for (final month in months)
              _MonthSection(
                month: month,
                memory:
                    memory != null &&
                        CivilDay.fromLocal(memory.createdAt).civilMonth ==
                            month.month
                    ? memory
                    : null,
                onOpen: (entry) => openJournalEntry(context, entry),
              ),
          ],
        ),
        if (provider.loadingMore)
          const Center(child: CircularProgressIndicator())
        else if (provider.error case final error?)
          Column(
            children: [
              Text(
                error,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
              TextButton(
                onPressed: provider.hasMore
                    ? provider.loadMore
                    : provider.loadEntries,
                child: const Text('Réessayer'),
              ),
            ],
          ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final ScrollController scroll;
  final VoidCallback onSearch;
  const _TopBar({required this.scroll, required this.onSearch});

  @override
  Widget build(BuildContext context) => SectionSkyBar(
    scroll: scroll,
    title: 'Journal',
    trailing: GlassBarButton(
      icon: Symbols.search_rounded,
      tooltip: 'Rechercher dans le journal',
      onPressed: onSearch,
    ),
  );
}

class _Composer extends StatelessWidget {
  final Widget? editor;
  final VoidCallback onExpanded;
  final String question;
  final VoidCallback onWrite;
  final VoidCallback? onNextQuestion;
  final VoidCallback onMood;
  const _Composer({
    super.key,
    this.editor,
    required this.onExpanded,
    required this.question,
    required this.onWrite,
    required this.onNextQuestion,
    required this.onMood,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final content =
        editor ??
        InkWell(
          onTap: onWrite,
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacing16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppDimensions.spacing12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppDimensions.spacing8,
                  children: [
                    Expanded(
                      child: Text(
                        question,
                        style: AppTextStyles.journalLine(
                          color: AppColors.journalQuestionInk(dark),
                        ),
                      ),
                    ),
                    if (onNextQuestion != null)
                      IconButton(
                        tooltip: 'Changer la question',
                        onPressed: onNextQuestion,
                        constraints: const BoxConstraints.tightFor(
                          width: AppDimensions.controlSize,
                          height: AppDimensions.controlSize,
                        ),
                        icon: Icon(
                          Symbols.refresh_rounded,
                          size: AppDimensions.iconSm,
                          color: AppColors.journalQuestionInk(dark),
                        ),
                      ),
                  ],
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: AppDimensions.controlSize,
                  ),
                  child: Text(
                    'Écris ici…',
                    style: AppTextStyles.bodyLarge(
                      color: AppColors.journalPlaceholder(dark),
                    ),
                  ),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppDimensions.spacing12,
                  runSpacing: AppDimensions.spacing8,
                  children: [
                    IconButton(
                      tooltip: 'Ajouter une humeur',
                      onPressed: onMood,
                      constraints: const BoxConstraints.tightFor(
                        width: AppDimensions.controlSize,
                        height: AppDimensions.controlSize,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.journalTool(dark),
                      ),
                      icon: Icon(
                        Symbols.sentiment_calm_rounded,
                        size: AppDimensions.iconSm,
                        color: AppColors.journalToolInk(dark),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onWrite,
                      icon: const Icon(
                        Symbols.edit_rounded,
                        size: AppDimensions.iconSm,
                      ),
                      label: const Text('Écrire'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, AppDimensions.controlSize),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing16,
                        ),
                        backgroundColor: AppColors.primaryText(dark),
                        foregroundColor: AppColors.onTint(dark),
                        textStyle: AppTextStyles.buttonSmall(),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
    return Material(
      key: const Key('journal-composer-card'),
      color: AppColors.journalPaper(dark),
      borderRadius: BorderRadius.circular(AppDimensions.radius20),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery.disableAnimationsOf(context)
          ? content
          : AnimatedSize(
              onEnd: onExpanded,
              duration: AppMotion.sheetEnter,
              curve: AppMotion.accueilEase,
              alignment: Alignment.topCenter,
              child: content,
            ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final JournalMonth month;
  final JournalEntry? memory;
  final ValueChanged<JournalEntry> onOpen;
  const _MonthSection({
    required this.month,
    required this.memory,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = AppDates.format(
      DateTime(month.month.year, month.month.month),
      'MMMM',
    );
    final days = [
      for (final entry in month.entries) CivilDay.fromLocal(entry.createdAt),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacing16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '${name[0].toUpperCase()}${name.substring(1)}',
                  style: AppTextStyles.titleMedium(color: context.textPrimary),
                ),
              ),
              Text(
                '${month.month.year}',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            ],
          ),
        ),
        if (memory case final memory?) ...[
          _Memory(entry: memory, onOpen: () => onOpen(memory)),
          const SizedBox(height: AppDimensions.spacing20),
        ],
        Stack(
          children: [
            Positioned(
              left: AppDimensions.journalThreadInset,
              top: AppDimensions.journalThreadTop,
              bottom: AppDimensions.journalThreadBottom,
              child: SizedBox(
                width: AppDimensions.dividerThickness,
                child: ColoredBox(color: AppColors.journalThread(dark)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppDimensions.spacing20,
              children: [
                for (final (index, entry) in month.entries.indexed)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: AppDimensions.spacing12,
                    children: [
                      SizedBox(
                        width: AppDimensions.journalDayColumn,
                        child: index == 0 || days[index] != days[index - 1]
                            ? _DayStamp(entry.createdAt.toLocal())
                            : null,
                      ),
                      Expanded(
                        child: JournalEntryCard(
                          entry: entry,
                          onTap: () => onOpen(entry),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _DayStamp extends StatelessWidget {
  final DateTime date;
  const _DayStamp(this.date);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: AppColors.sectionBody(dark),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing4),
        child: Column(
          spacing: AppDimensions.spacing2,
          children: [
            Text(
              '${date.day}',
              style: AppTextStyles.headlineSmall(
                color: AppColors.journalAccent(dark),
              ),
            ),
            Text(
              AppDates.format(date, 'E'),
              style: AppTextStyles.moodLabel(color: context.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Memory extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onOpen;
  const _Memory({required this.entry, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final quote = (entry.content ?? '').trim();
    return Padding(
      padding: const EdgeInsets.only(
        left: AppDimensions.journalDayColumn + AppDimensions.spacing12,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDimensions.spacing16),
        decoration: BoxDecoration(
          color: AppColors.journalEntry(dark),
          borderRadius: BorderRadius.circular(AppDimensions.radius20),
          border: Border.all(
            color: AppColors.journalEntryBorder(dark),
            width: .5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppDimensions.spacing8,
          children: [
            Text(
              'Il y a un mois',
              style: AppTextStyles.bodySmall(
                color: AppColors.journalAccent(dark),
              ),
            ),
            if (quote.isNotEmpty)
              Container(
                padding: const EdgeInsets.only(left: AppDimensions.spacing8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: AppColors.journalAccent(dark),
                      width: AppDimensions.borderWidthMedium,
                    ),
                  ),
                ),
                child: Text(
                  '« $quote »',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium(color: context.textSecondary),
                ),
              ),
            TextButton.icon(
              onPressed: onOpen,
              iconAlignment: IconAlignment.end,
              icon: const Icon(
                Symbols.arrow_forward_rounded,
                size: AppDimensions.iconSm,
              ),
              label: const Text('Relire cette note'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                foregroundColor: AppColors.primaryText(dark),
                textStyle: AppTextStyles.buttonSmall(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// First use shares the same composer as a populated journal.
class _WritingIdeas extends StatelessWidget {
  final ValueChanged<String?> onWrite;
  const _WritingIdeas({required this.onWrite});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing12,
      children: [
        Text(
          'Pour commencer',
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        Text(
          'Choisis une question ou écris librement.',
          style: AppTextStyles.bodyMedium(color: context.textSecondary),
        ),
        for (final prompt in journalPrompts)
          Material(
            color: AppColors.journalEntry(dark),
            borderRadius: BorderRadius.circular(AppDimensions.radius14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onWrite(prompt),
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.spacing16),
                child: Row(
                  spacing: AppDimensions.spacing12,
                  children: [
                    Icon(
                      Symbols.edit_note_rounded,
                      size: AppDimensions.iconSm,
                      color: AppColors.journalAccent(dark),
                    ),
                    Expanded(
                      child: Text(
                        prompt,
                        style: AppTextStyles.bodyMedium(
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      Symbols.arrow_forward_rounded,
                      size: AppDimensions.iconSm,
                      color: AppColors.journalAccent(dark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        TextButton(
          onPressed: () => onWrite(null),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.journalAccent(dark),
          ),
          child: const Text('Écrire librement'),
        ),
      ],
    );
  }
}
