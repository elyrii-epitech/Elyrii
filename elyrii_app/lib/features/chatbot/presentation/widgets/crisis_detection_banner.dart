import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/app_dialog.dart';

/// Conservative French cues for offering help, not a clinical assessment.
/// Ordinary verbs such as “sauter” and “avaler” are not distress signals alone.
bool containsCrisisKeyword(String text) {
  final normalized = text
      .toLowerCase()
      .replaceAll(RegExp('[àâä]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[îï]'), 'i')
      .replaceAll(RegExp('[ôö]'), 'o')
      .replaceAll(RegExp('[ùûü]'), 'u')
      .replaceAll('’', "'")
      .replaceAll(RegExp(r"[^a-z0-9']+"), ' ');
  const phrases = [
    'suicide',
    'suicidaire',
    'automutilation',
    'me faire du mal',
    'finir ma vie',
    'mettre fin a ma vie',
    'mettre fin a mes jours',
    'je veux en finir',
    "j'ai envie d'en finir",
    'je ne veux plus vivre',
    'je veux mourir',
    "j'ai envie de mourir",
    'je vais me tuer',
    'je veux me tuer',
    'sauter du pont',
    'sauter par la fenetre',
    'avaler tous mes medicaments',
    'avaler des medicaments pour mourir',
    "je n'en peux plus",
    'je ne peux plus continuer',
  ];
  return phrases.any(
    (phrase) =>
        RegExp(r'(?:^| )' + RegExp.escape(phrase) + r'(?: |$)')
            .hasMatch(normalized),
  );
}

class CrisisDetectionBanner extends StatelessWidget {
  final bool visible;

  final VoidCallback onDismiss;

  const CrisisDetectionBanner({
    super.key,
    required this.visible,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!visible) return const SizedBox.shrink();
    return Semantics(
      liveRegion: true,
      container: true,
      child: AnimatedContainer(
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        height: visible ? null : 0.0,
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: AnimatedOpacity(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 300),
          opacity: visible ? 1.0 : 0.0,
          child: _buildBannerContent(context, isDark),
        ),
      ),
    );
  }

  Widget _buildBannerContent(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing20,
        AppDimensions.spacing16,
        AppDimensions.spacing20,
        AppDimensions.spacing16,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2218) : const Color(0xFFFFF7ED),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppDimensions.radius16),
        ),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 28,
            color: isDark ? AppColors.warningLight : AppColors.warningDark,
          ),
          const SizedBox(height: AppDimensions.spacing8),
          Text(
            'On dirait que tu traverses un moment difficile. Tu n\'es pas seul(e).',
            style: AppTextStyles.bodyLarge(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildPhoneRow(
            context,
            isDark,
            label: 'SOS Amitié',
            number: '09 72 39 40 50',
          ),
          const SizedBox(height: AppDimensions.spacing8),
          _buildPhoneRow(
            context,
            isDark,
            label: 'Prévention suicide',
            number: '3114',
          ),
          const SizedBox(height: AppDimensions.spacing16),

          LiquidGlassButton(
            label: 'J\'ai besoin d\'aide maintenant',
            icon: Icons.phone_in_talk_rounded,
            style: LiquidGlassButtonStyle.filled,
            isExpanded: true,
            onPressed: () => _showHelpDialog(context),
          ),
          const SizedBox(height: AppDimensions.spacing8),
          LiquidGlassButton(
            label: 'Ça va, merci',
            style: LiquidGlassButtonStyle.plain,
            isExpanded: true,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneRow(
    BuildContext context,
    bool isDark, {
    required String label,
    required String number,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing8,
      ),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radius12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.phone_rounded,
            size: 16,
            color: isDark ? AppColors.warningLight : AppColors.warningDark,
          ),
          const SizedBox(width: AppDimensions.spacing8),
          Flexible(
            child: Text(
              '$label : $number',
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showAppDialog(
      context: context,
      title: 'Tu n\'es pas seul(e)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Voici les numéros que tu peux appeler dès maintenant :',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'SOS Amitié\n09 72 39 40 50',
            style: AppTextStyles.titleSmall(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            'Numéro national de prévention du suicide\n3114',
            style: AppTextStyles.titleSmall(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            'Urgence vitale : 15 ou 112',
            style: AppTextStyles.titleSmall(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        AppDialogAction(
          label: 'Fermer',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
