import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart' show ShareResultStatus;

import '../../../../core/export/private_export.dart';
import '../../../../core/localization/app_dates.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../dashboard/presentation/mood_presentation.dart';
import '../../domain/journal_feed.dart';
import '../providers/journal_provider.dart';
import 'journal_editor_sheet.dart';

Future<void> showJournalEditor(
  BuildContext context, {
  required JournalProvider provider,
  JournalEntry? entry,
  String? initialPrompt,
  MoodType? initialMood,
}) => Navigator.of(context, rootNavigator: true).push<void>(
  AppSheetRoute(
    reduced: MediaQuery.disableAnimationsOf(context),
    builder: (_) => JournalEditorSheet(
      provider: provider,
      entry: entry,
      initialPrompt: initialPrompt,
      initialMood: initialMood,
    ),
  ),
);

Future<T?> showJournalSheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  AppSheetRoute(
    reduced: MediaQuery.disableAnimationsOf(context),
    builder: (_) => AppSheetPanel(title: title, child: child),
  ),
);

Future<MoodType?> showJournalMoodPicker(BuildContext context) =>
    showJournalSheet<MoodType>(
      context,
      title: 'Comment te sens-tu ?',
      child: const _MoodPicker(),
    );

Future<String?> showJournalPromptPicker(BuildContext context) =>
    showJournalSheet<String>(
      context,
      title: 'Une piste pour écrire',
      child: JournalRowGroup(
        children: [
          for (final prompt in journalPrompts)
            JournalRow(
              label: prompt,
              onTap: () =>
                  Navigator.of(context, rootNavigator: true).pop(prompt),
            ),
        ],
      ),
    );

Future<bool> confirmJournalDelete(BuildContext context) async {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final confirmed = await showJournalSheet<bool>(
    context,
    title: 'Supprimer cette entrée ?',
    child: Builder(
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing12,
        children: [
          Text(
            'Cette page sera retirée de ton journal. Tu peux encore la garder.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          JournalButton(
            label: 'Supprimer l’entrée',
            background: dark ? AppColors.cardDark : AppColors.cardLight,
            foreground: AppColors.rose(dark),
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
          JournalButton(
            label: 'La garder',
            background: AppColors.tintSoft(dark),
            foreground: AppColors.primaryText(dark),
            onPressed: () => Navigator.of(sheet).pop(false),
          ),
        ],
      ),
    ),
  );
  return confirmed ?? false;
}

Future<void> showJournalPrivacy(
  BuildContext context,
  JournalProvider provider,
) => showJournalSheet<void>(
  context,
  title: 'Un espace à toi',
  child: _PrivacySheet(provider: provider),
);

OverlayEntry? _toast;
Timer? _toastTimer;

void showJournalToast(BuildContext context, String text) {
  final overlay = Overlay.of(context, rootOverlay: true);
  final dark = Theme.of(context).brightness == Brightness.dark;
  final ink = context.textPrimary;
  _toastTimer?.cancel();
  _toast?.remove();
  final entry = OverlayEntry(
    builder: (context) => Positioned(
      top: AppDimensions.journalToastTop,
      left: AppDimensions.spacing20,
      right: AppDimensions.spacing20,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Semantics(
            liveRegion: true,
            child: Material(
              color: AppColors.journalToast(dark),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radius18),
                side: BorderSide(
                  color: dark
                      ? AppColors.glassBorderDark
                      : AppColors.borderLight,
                  width: .5,
                ),
              ),
              elevation: dark ? 0 : AppDimensions.elevationSm,
              shadowColor: AppColors.shadowLight,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                  vertical: AppDimensions.spacing12,
                ),
                child: Text(text, style: AppTextStyles.journalLine(color: ink)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  _toast = entry;
  _toastTimer = Timer(AppMotion.journalToast, () {
    if (identical(_toast, entry)) {
      entry.remove();
      _toast = null;
    }
  });
}

class JournalGrabber extends StatelessWidget {
  const JournalGrabber({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: AppDimensions.grabberWidth,
      height: AppDimensions.grabberHeight,
      decoration: BoxDecoration(
        color: context.textTertiary.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(AppDimensions.radius4),
      ),
    ),
  );
}

class JournalMoodDot extends StatelessWidget {
  final MoodType mood;
  final double size;
  const JournalMoodDot(
    this.mood, {
    super.key,
    this.size = AppDimensions.journalMoodDot,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: mood.colorFor(Theme.of(context).brightness),
      shape: BoxShape.circle,
    ),
  );
}

/// The filled square of a row, with a dark glyph.
class JournalSquare extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const JournalSquare(
    this.icon, {
    super.key,
    required this.color,
    this.size = AppDimensions.journalSquare,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(
        size > AppDimensions.journalSquare
            ? AppDimensions.radius12
            : AppDimensions.journalSquareRadius,
      ),
    ),
    child: Icon(
      icon,
      size: size > AppDimensions.journalSquare
          ? AppDimensions.iconMd
          : AppDimensions.iconSm,
      color: AppColors.journalToolInk(
        Theme.of(context).brightness == Brightness.dark,
      ),
      fill: 1,
    ),
  );
}

/// An inset group of rows on the sheet surface.
class JournalRowGroup extends StatelessWidget {
  final List<Widget> children;
  const JournalRowGroup({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? AppColors.cardDark : AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(AppDimensions.radius20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (index, child) in children.indexed) ...[
            if (index > 0)
              Divider(
                height: AppDimensions.dividerThickness,
                indent: AppDimensions.spacing12,
                color: dark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            child,
          ],
        ],
      ),
    );
  }
}

class JournalRow extends StatelessWidget {
  final String label;
  final String? detail;
  final Widget? leading;
  final Color? labelColor;
  final double minHeight;
  final VoidCallback onTap;
  const JournalRow({
    super.key,
    required this.label,
    required this.onTap,
    this.detail,
    this.leading,
    this.labelColor,
    this.minHeight = AppDimensions.journalRowHeight,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        child: Row(
          spacing: AppDimensions.spacing12,
          children: [
            ?leading,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: AppTextStyles.bodyMedium(
                      color: labelColor ?? context.textPrimary,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              Symbols.chevron_right_rounded,
              size: AppDimensions.iconSm,
              color: labelColor ?? context.textTertiary,
            ),
          ],
        ),
      ),
    ),
  );
}

class JournalButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;
  final IconData? icon;
  const JournalButton({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: onPressed,
    icon: icon == null ? null : Icon(icon, size: AppDimensions.iconSm),
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(AppDimensions.journalBigButton),
      backgroundColor: background,
      foregroundColor: foreground,
      textStyle: AppTextStyles.labelLarge(),
      shape: const StadiumBorder(),
    ),
    label: Text(label),
  );
}

class _MoodPicker extends StatelessWidget {
  const _MoodPicker();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final mood in MoodType.values)
          Semantics(
            button: true,
            label: mood.label,
            excludeSemantics: true,
            child: InkWell(
              onTap: () => Navigator.of(context).pop(mood),
              borderRadius: BorderRadius.circular(AppDimensions.radius12),
              child: SizedBox(
                width: AppDimensions.journalMoodColumn,
                child: Column(
                  spacing: AppDimensions.spacing8,
                  children: [
                    Container(
                      width: AppDimensions.accueilMoodFace,
                      height: AppDimensions.accueilMoodFace,
                      decoration: BoxDecoration(
                        color: mood.colorFor(brightness),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        mood.icon,
                        color: AppColors.journalSquareInk,
                        size: AppDimensions.iconMd,
                        fill: 1,
                      ),
                    ),
                    Text(
                      mood.label,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      softWrap: false,
                      style: AppTextStyles.moodLabel(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PrivacySheet extends StatefulWidget {
  final JournalProvider provider;
  const _PrivacySheet({required this.provider});

  @override
  State<_PrivacySheet> createState() => _PrivacySheetState();
}

class _PrivacySheetState extends State<_PrivacySheet> {
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    final provider = widget.provider;
    final owner = provider.owner;
    bool currentOwner() => provider.owner == owner;
    setState(() => _exporting = true);
    try {
      while (provider.hasMore && currentOwner()) {
        final before = provider.entries.length;
        await provider.loadMore();
        if (provider.error != null || provider.entries.length <= before) {
          throw StateError('Journal export history is incomplete');
        }
      }
      final drafts = await provider.exportDrafts();
      if (!mounted || !currentOwner()) return;
      final text = journalExportText(
        provider.entries,
        (date) => AppDates.format(date, 'd MMMM yyyy · HH:mm'),
        drafts: drafts,
      );
      if (text.isEmpty) {
        showJournalToast(context, 'Ton journal est encore vide.');
        return;
      }
      final result = await PrivateExport.shareText(
        context,
        text,
        title: 'Mon journal Elyrii',
        isCurrentOwner: currentOwner,
      );
      if (mounted && result.status != ShareResultStatus.dismissed) {
        showJournalToast(context, 'Ton fichier texte est prêt.');
      }
    } catch (_) {
      if (mounted) {
        showJournalToast(context, 'L’export n’a pas pu être préparé.');
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: AppDimensions.spacing12,
          children: [
            JournalSquare(
              Symbols.lock_rounded,
              color: AppColors.journalPaper(dark),
              size: AppDimensions.journalShield,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: AppDimensions.spacing4,
                children: [
                  Text(
                    'Ton journal est privé',
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                  Text(
                    'Ni ton coach ni Elyrii ne lisent tes entrées sans ton accord. Tu choisis l’extrait à partager.',
                    style: AppTextStyles.bodyMedium(
                      color: context.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        JournalRowGroup(
          children: [
            JournalRow(
              label: 'Exporter mes écrits',
              detail: _exporting
                  ? 'Préparation de ton fichier…'
                  : 'Un fichier texte à garder pour toi',
              leading: JournalSquare(
                Symbols.download_rounded,
                color: AppColors.journalPaper(dark),
              ),
              onTap: _export,
            ),
          ],
        ),
        Text(
          'Tes mots t’appartiennent.',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall(color: context.textTertiary),
        ),
        JournalButton(
          label: 'Compris',
          background: AppColors.primaryText(dark),
          foreground: AppColors.onTint(dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
