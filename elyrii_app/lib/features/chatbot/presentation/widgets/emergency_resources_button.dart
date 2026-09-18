import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';

/// Numéros d'écoute et d'urgence santé mentale (France), tapables.
const List<({String title, String subtitle, String tel, Color color})>
kEmergencyResources = [
  (
    title: '311 — Prévention suicide',
    subtitle: 'Écoute et accompagnement, 24h/24, gratuit',
    tel: '311',
    color: Color(0xFFE5484D),
  ),
  (
    title: 'Fil Santé Jeunes',
    subtitle: '0 800 235 236 · gratuit, anonyme',
    tel: '0800235236',
    color: Color(0xFF4CAF50),
  ),
  (
    title: 'SOS Amitié',
    subtitle: '09 72 39 40 50 · écoute de jour comme de nuit',
    tel: '0972394050',
    color: Color(0xFF2196F3),
  ),
  (
    title: 'Urgence vitale',
    subtitle: 'Appelle le 15 (SAMU) ou le 112',
    tel: '15',
    color: Color(0xFFB3261E),
  ),
];

class EmergencyResourcesButton extends StatelessWidget {
  const EmergencyResourcesButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label: "Aide d'urgence et numéros d'écoute gratuits",
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showEmergencyResources(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              // Glassmorphic red tint
              color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withValues(alpha: 0.05),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.emergency_outlined,
                  size: 16,
                  color: isDark ? Colors.red.shade200 : Colors.red.shade400,
                ),
                const SizedBox(width: 6),
                Text(
                  'Urgence',
                  style: TextStyle(
                    color: isDark ? Colors.red.shade200 : Colors.red.shade400,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEmergencyResources(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ElyriiGlassSurface(
        role: GlassRole.modalSheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardDark.withValues(alpha: 0.8)
                : AppColors.cardLight.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.favorite_rounded,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Tu n\'es pas seul(e)',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Des professionnels sont disponibles 24h/24',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              for (final (index, resource) in kEmergencyResources.indexed) ...[
                _buildResourceTile(
                  context,
                  icon: Icons.phone_rounded,
                  title: resource.title,
                  subtitle: resource.subtitle,
                  color: resource.color,
                  tel: resource.tel,
                ),
                if (index < kEmergencyResources.length - 1)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Text(
                'Appuyer sur un numéro lance l\'appel.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Fermer',
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResourceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String tel,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: 'Appeler $title',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _callNumber(tel),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.1 : 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: isDark ? 0.2 : 0.1),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.call_rounded,
                  size: 18,
                  color: color,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _callNumber(String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
