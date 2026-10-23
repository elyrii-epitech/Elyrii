import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import '../widgets/journal_sheets.dart';

/// Pushes a Journal page above the shell, without the dock. The board swaps
/// these screens instantly.
Future<void> pushJournalPage(BuildContext context, Widget page) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) => page,
      ),
    );

Future<void> openJournalEntry(BuildContext context, JournalEntry entry) =>
    pushJournalPage(context, JournalEntryPage(entry: entry));

/// Reading one entry: its mood and hour, the full text, and its actions.
class JournalEntryPage extends StatelessWidget {
  final JournalEntry entry;
  const JournalEntryPage({super.key, required this.entry});

  Future<void> _delete(BuildContext context, JournalProvider provider) async {
    if (!await confirmJournalDelete(context) || !context.mounted) return;
    final deleted = await provider.deleteEntry(entry.id);
    if (!context.mounted) return;
    if (!deleted) {
      showJournalToast(context, 'La suppression a échoué. Réessaie.');
      return;
    }
    showJournalToast(context, 'Entrée retirée de ton journal.');
    Navigator.of(context).pop();
    // A leftover draft of a deleted entry is harmless; cleanup is best effort.
    unawaited(provider.deleteDraft(entry.id).catchError((Object _) {}));
  }

  void _more(
    BuildContext context,
    JournalProvider provider,
    JournalEntry shown,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    showJournalSheet<void>(
      context,
      title: 'Cette entrée',
      child: Builder(
        builder: (sheet) => JournalRowGroup(
          children: [
            JournalRow(
              label: 'Modifier',
              leading: JournalSquare(
                Symbols.edit_rounded,
                color: AppColors.journalPaper(dark),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                showJournalEditor(context, provider: provider, entry: shown);
              },
            ),
            JournalRow(
              label: 'Confidentialité',
              leading: JournalSquare(
                Symbols.lock_rounded,
                color: AppColors.journalPaper(dark),
              ),
              onTap: () {
                Navigator.of(sheet).pop();
                showJournalPrivacy(context, provider);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JournalProvider>();
    final shown =
        provider.entries.where((e) => e.id == entry.id).firstOrNull ?? entry;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mood = parseJournalMood(shown.mood);
    final created = shown.createdAt.toLocal();
    final paragraphs = (shown.content ?? '')
        .trim()
        .split(RegExp(r'\n\s*\n'))
        .where((p) => p.trim().isNotEmpty);
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: AppDimensions.journalPill,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.cardDark : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius12,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        spacing: AppDimensions.spacing4,
                        children: [
                          if (mood != null) JournalMoodDot(mood),
                          Text(
                            [
                              ?mood?.label,
                              AppDates.format(created, 'HH:mm'),
                            ].join(' · '),
                            style: AppTextStyles.pillLabel(
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing20),
                  Semantics(
                    header: true,
                    child: Text(
                      shown.title,
                      style: AppTextStyles.titleLarge(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing20),
                  SelectionArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: AppDimensions.spacing16,
                      children: [
                        for (final paragraph in paragraphs)
                          Text(
                            paragraph.trim(),
                            style: AppTextStyles.readingBody(
                              color: context.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing20),
                  JournalRowGroup(
                    children: [
                      JournalRow(
                        label: 'Supprimer',
                        labelColor: AppColors.rose(dark),
                        leading: JournalSquare(
                          Symbols.delete_rounded,
                          color: AppColors.journalPaper(dark),
                        ),
                        onTap: () => _delete(context, provider),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          JournalBar(
            title: AppDates.format(created, 'd MMMM'),
            leading: JournalBarButton(
              icon: Symbols.chevron_left_rounded,
              tooltip: 'Retour au journal',
              onPressed: () => Navigator.of(context).pop(),
            ),
            trailing: JournalBarButton(
              icon: Symbols.more_horiz_rounded,
              tooltip: 'Actions de l’entrée',
              onPressed: () => _more(context, provider, shown),
            ),
          ),
        ],
      ),
    );
  }
}

/// The glass bar of the pushed Journal pages, always visible.
class JournalBar extends StatelessWidget {
  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final Widget? child;
  const JournalBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ColoredBox(
        color: dark
            ? AppColors.glassBackgroundDark
            : AppColors.glassBackgroundLight,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: AppDimensions.accueilBarHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacing12,
              ),
              child:
                  child ??
                  Row(
                    children: [
                      SizedBox(
                        width: AppDimensions.controlSize,
                        child: leading,
                      ),
                      Expanded(
                        child: Text(
                          title ?? '',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.navTitle(
                            color: context.textPrimary,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: AppDimensions.controlSize,
                        child: trailing,
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class JournalBarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  const JournalBarButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: dark
            ? AppColors.glassBackgroundDark
            : AppColors.glassBackgroundLight,
        side: BorderSide(
          color: dark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          width: .5,
        ),
      ),
      icon: Icon(icon, color: context.textPrimary),
    );
  }
}
