import '../../../../core/accessibility/motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../data/models/coach_model.dart';
import '../providers/coach_provider.dart';

/// Feuille de guidance : Elyrii prépare une séance pour l'activité choisie.
/// Aucune bannière volante — l'attente et la réponse vivent dans la même
/// surface, façon feuille iOS.
class GuidanceSheet extends StatelessWidget {
  final CoachActivity activity;

  const GuidanceSheet({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = activity.category.color;

    return Consumer<CoachProvider>(
      builder: (context, provider, _) {
        final session = provider.latestSession;
        final isPlaceholder = session?.context['placeholder'] == true;
        final body = provider.isCreatingSession
            ? const _PreparingBody()
            : _ResponseBody(
                response: session?.response ?? '',
                isPlaceholder: isPlaceholder,
              );

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppDimensions.spacing8),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radius12,
                      ),
                    ),
                    child: Center(
                      child: Icon(activity.icon, size: 22, color: color),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Séance guidée',
                          style: AppTextStyles.labelMedium(color: color),
                        ),
                        const SizedBox(height: AppDimensions.spacing2),
                        Text(
                          activity.title,
                          style: AppTextStyles.titleMedium(
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing16),
              body,
            ],
          ),
        );
      },
    );
  }
}

/// Attente : squelette shimmer doux de la couleur de surface, aucune barre
/// de progression brute.
class _PreparingBody extends StatelessWidget {
  const _PreparingBody();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);

    Widget block(double height, {double? width}) => Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppDimensions.radius12),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elyrii prépare ta séance…',
          style: AppTextStyles.bodySmall(color: context.textSecondary),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        ...List.generate(3, (i) {
          final widths = [null, 320.0, 220.0];
          final isLast = i == 2;
          return Padding(
            padding: EdgeInsets.only(
              bottom: isLast ? 0 : AppDimensions.spacing8,
            ),
            child: block(14, width: widths[i])
                .animateRespectingMotion(
                  context,
                  onPlay: (controller) => controller.repeat(),
                )
                .shimmer(
                  duration: 1400.ms,
                  delay: (i * 160).ms,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.5),
                ),
          );
        }),
      ],
    );
  }
}

/// Réponse : le texte de la séance, relu à hauteur d'homme. Quand il s'agit
/// d'un placeholder local, une légende honnête l'annonce.
class _ResponseBody extends StatelessWidget {
  final String response;
  final bool isPlaceholder;

  const _ResponseBody({required this.response, required this.isPlaceholder});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          response.isEmpty
              ? 'Ta séance est prête. À toi de jouer, je reste là.'
              : response,
          style: AppTextStyles.bodyMedium(color: context.textPrimary),
        ),
        if (isPlaceholder) ...[
          const SizedBox(height: AppDimensions.spacing12),
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 13,
                color: context.textTertiary,
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Expanded(
                child: Text(
                  'Aperçu du coach — le contenu personnalisé arrive bientôt.',
                  style: AppTextStyles.labelSmall(color: context.textTertiary),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppDimensions.spacing16),
        LiquidGlassButton(
          label: 'Merci, c\'est noté',
          icon: Icons.check_rounded,
          style: LiquidGlassButtonStyle.tinted,
          isExpanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
