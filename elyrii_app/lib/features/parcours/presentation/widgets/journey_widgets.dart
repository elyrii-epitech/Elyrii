import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/journey.dart';

String journeyTopicLabel(JourneyTopic topic) => switch (topic) {
  JourneyTopic.connection => 'Créer du lien',
  JourneyTopic.calm => 'Retrouver du calme',
  JourneyTopic.sleep => 'Préparer le sommeil',
};

IconData journeyTopicIcon(JourneyTopic topic) => switch (topic) {
  JourneyTopic.connection => Symbols.favorite_rounded,
  JourneyTopic.calm => Symbols.spa_rounded,
  JourneyTopic.sleep => Symbols.bedtime_rounded,
};

class JourneyButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  const JourneyButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.primary = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final style = TextButton.styleFrom(
      minimumSize: const Size.fromHeight(AppDimensions.controlSize),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      textStyle: AppTextStyles.labelLarge(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
    );
    if (!primary) {
      return TextButton(
        onPressed: onPressed,
        style: style.copyWith(
          foregroundColor: WidgetStatePropertyAll(AppColors.primaryText(dark)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      );
    }
    return FilledButton(
      onPressed: onPressed,
      style: style.copyWith(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.track(dark)
              : AppColors.helpInk(dark),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? context.textSecondary
              : dark
              ? AppColors.backgroundDark
              : Colors.white,
        ),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }
}

class JourneyCard extends StatelessWidget {
  final Widget child;
  final bool accented;
  const JourneyCard({super.key, required this.child, this.accented = false});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: accented
            ? AppColors.pink(dark).withValues(alpha: .08)
            : dark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
        border: Border.all(
          color: accented
              ? AppColors.pink(dark).withValues(alpha: .35)
              : dark
              ? AppColors.borderDark
              : AppColors.borderLight,
          width: AppDimensions.borderWidthThin,
        ),
      ),
      child: child,
    );
  }
}

class JourneyNote extends StatelessWidget {
  final String text;
  final bool live;
  const JourneyNote(this.text, {super.key, this.live = false});

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: live,
    child: Text(
      text,
      style: AppTextStyles.bodyMedium(color: context.textSecondary),
    ),
  );
}

class JourneyFeedback extends StatelessWidget {
  final String? error;
  final bool loading;
  final bool writing;
  final VoidCallback onRetry;
  const JourneyFeedback({
    super.key,
    required this.error,
    required this.loading,
    required this.writing,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.spacing8,
    children: [
      if (loading || writing)
        JourneyNote(
          writing ? 'Enregistrement en cours…' : 'Actualisation en cours…',
          live: true,
        ),
      if (error != null)
        JourneyCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppDimensions.spacing8,
            children: [
              JourneyNote(error!, live: true),
              const JourneyNote(
                'Aucune nouvelle action n’est confirmée. Actualise avant de réessayer.',
              ),
              JourneyButton(
                label: 'Réessayer',
                primary: false,
                onPressed: loading || writing ? null : onRetry,
              ),
            ],
          ),
        ),
    ],
  );
}

class JourneyPathTile extends StatelessWidget {
  final JourneyPath path;
  final VoidCallback? onTap;
  const JourneyPathTile({super.key, required this.path, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
        side: BorderSide(
          color: dark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacing16),
          child: Row(
            children: [
              JourneyTopicMark(topic: path.topic),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppDimensions.spacing4,
                  children: [
                    Text(
                      path.title,
                      style: AppTextStyles.titleSmall(
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      path.description,
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                    Text(
                      '${path.steps.length} étapes',
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Icon(Symbols.chevron_right_rounded, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

class JourneyTopicMark extends StatelessWidget {
  final JourneyTopic topic;
  const JourneyTopicMark({super.key, required this.topic});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacing8),
      decoration: BoxDecoration(
        color: AppColors.pink(dark).withValues(alpha: .12),
        borderRadius: BorderRadius.circular(AppDimensions.radius12),
      ),
      child: Icon(
        journeyTopicIcon(topic),
        color: AppColors.pink(dark),
        size: AppDimensions.iconMd,
      ),
    );
  }
}

class JourneyStepList extends StatelessWidget {
  final JourneyPath path;
  final int? completedCount;
  final bool paused;
  final VoidCallback? onCurrent;
  const JourneyStepList({
    super.key,
    required this.path,
    this.completedCount,
    this.paused = false,
    this.onCurrent,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.spacing8,
    children: [
      for (var index = 0; index < path.steps.length; index++)
        _row(context, index),
    ],
  );

  Widget _row(BuildContext context, int index) {
    final step = path.steps[index];
    final done = completedCount != null && index < completedCount!;
    final current = completedCount == index;
    final status = completedCount == null
        ? '${step.durationMinutes} min environ'
        : done
        ? 'Terminée'
        : current
        ? (paused ? 'En pause' : 'Étape courante')
        : 'À venir';
    return JourneyCard(
      accented: current,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                done
                    ? Symbols.check_circle_rounded
                    : current
                    ? Symbols.radio_button_checked_rounded
                    : Symbols.circle_rounded,
                size: AppDimensions.iconSm,
                color: done || current
                    ? AppColors.pink(
                        Theme.of(context).brightness == Brightness.dark,
                      )
                    : context.textTertiary,
              ),
              const SizedBox(width: AppDimensions.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: AppDimensions.spacing4,
                  children: [
                    Text(
                      '${index + 1}. ${step.title}',
                      style: AppTextStyles.titleSmall(
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      status,
                      style: AppTextStyles.bodySmall(
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (completedCount == null) JourneyNote(step.instructions),
          if (current && !paused && onCurrent != null)
            JourneyButton(
              label: 'Ouvrir cette étape',
              primary: false,
              onPressed: onCurrent,
            ),
        ],
      ),
    );
  }
}
