import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';

/// Crisis keywords in French that may indicate the user is in distress.
const List<String> _crisisKeywords = [
  'suicide',
  'suicidaire',
  'mourir',
  'finir ma vie',
  'ne plus en pouvoir',
  'automutilation',
  'me faire du mal',
  'mettre fin',
  'sauter',
  'avaler',
];

/// Checks whether [text] contains any crisis keyword.
bool containsCrisisKeyword(String text) {
  final lowered = text.toLowerCase();
  for (final keyword in _crisisKeywords) {
    if (lowered.contains(keyword)) return true;
  }
  return false;
}

/// A non-intrusive but visible banner that slides down smoothly when the
/// chatbot detects concerning language. It shows supportive messaging and
/// emergency contact numbers for France.
class CrisisDetectionBanner extends StatelessWidget {
  /// Whether the banner is currently visible.
  final bool visible;

  /// Called when the user dismisses the banner.
  final VoidCallback onDismiss;

  const CrisisDetectionBanner({
    super.key,
    required this.visible,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      height: visible ? null : 0.0,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: visible ? 1.0 : 0.0,
        child: _buildBannerContent(context, isDark),
      ),
    );
  }

  Widget _buildBannerContent(BuildContext context, bool isDark) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: isDark ? 0.15 : 0.12),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            border: Border.all(
              color: AppColors.warning.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.warning.withValues(alpha: 0.06),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gentle icon + message
              Icon(
                Icons.favorite_rounded,
                size: 28,
                color: isDark ? AppColors.warningLight : AppColors.warningDark,
              ),
              const SizedBox(height: 10),
              Text(
                'On dirait que tu traverses un moment difficile. Tu n\'es pas seul(e).',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Emergency numbers
              _buildPhoneRow(
                context,
                isDark,
                label: 'SOS Amitié',
                number: '09 72 39 40 50',
              ),
              const SizedBox(height: 8),
              _buildPhoneRow(
                context,
                isDark,
                label: 'Prévention suicide',
                number: '3114',
              ),
              const SizedBox(height: 16),

              // Action buttons
              LiquidGlassButton(
                label: 'J\'ai besoin d\'aide maintenant',
                icon: Icons.phone_in_talk_rounded,
                style: LiquidGlassButtonStyle.filled,
                isExpanded: true,
                onPressed: () => _showHelpDialog(context, isDark),
              ),
              const SizedBox(height: 8),
              LiquidGlassButton(
                label: 'Ça va, merci',
                style: LiquidGlassButtonStyle.plain,
                isExpanded: true,
                onPressed: onDismiss,
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '$label : $number',
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context, bool isDark) {
    showLiquidGlassDialog(
      context: context,
      title: 'Tu n\'es pas seul(e)',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Voici les numéros que tu peux appeler dès maintenant :',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'SOS Amitié\n09 72 39 40 50',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Numéro national de prévention du suicide\n3114',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Urgence vitale : 15 ou 112',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Fermer',
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
