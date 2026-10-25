import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/app_sheet_route.dart';

/// Tappable French mental-health support and emergency numbers.
const List<({String title, String subtitle, String tel})> kEmergencyResources =
    [
      (
        title: '3114 · Prévention suicide',
        subtitle: 'Écoute et accompagnement, 24h/24, gratuit',
        tel: '3114',
      ),
      (
        title: 'Fil Santé Jeunes',
        subtitle: '0 800 235 236 · gratuit, anonyme',
        tel: '0800235236',
      ),
      (
        title: 'SOS Amitié',
        subtitle: '09 72 39 40 50 · écoute de jour comme de nuit',
        tel: '0972394050',
      ),
      (
        title: 'Urgence vitale',
        subtitle: 'Appelle le 15 (SAMU) ou le 112',
        tel: '15',
      ),
    ];

class EmergencyResourcesButton extends StatelessWidget {
  final bool compact;
  const EmergencyResourcesButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground = isDark ? AppColors.primaryDark : AppColors.primary;
    if (compact) {
      return LiquidGlassIconButton(
        tooltip: 'Aide d’urgence et numéros d’écoute',
        onPressed: () => _showEmergencyResources(context),
        size: 48,
        color: foreground,
        icon: Icons.health_and_safety_outlined,
      );
    }
    return FilledButton.tonalIcon(
      onPressed: () => _showEmergencyResources(context),
      icon: const Icon(Icons.health_and_safety_outlined, size: 20),
      label: const Text('Aide d’urgence'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 44),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.primaryLight,
        foregroundColor: context.textPrimary,
        textStyle: AppTextStyles.labelLarge(),
      ),
    );
  }

  void _showEmergencyResources(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).push<void>(
      AppSheetRoute<void>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (_) => const _EmergencyResourcesSheet(),
      ),
    );
  }
}

class _EmergencyResourcesSheet extends StatelessWidget {
  const _EmergencyResourcesSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = context.textPrimary;
    final secondary = context.textSecondary;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return AppSheetPanel(
      title: 'Besoin d’aide ?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu n’es pas seul(e). Ces lignes sont là pour t’écouter et t’orienter.',
            style: AppTextStyles.bodyMedium(color: ink),
          ),
          const SizedBox(height: AppDimensions.spacing24),
          Material(
            color: surface,
            borderRadius: BorderRadius.circular(AppDimensions.radius16),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (index, resource)
                    in kEmergencyResources.indexed) ...[
                  Semantics(
                    button: true,
                    label: 'Appeler ${resource.title}, ${resource.tel}',
                    child: InkWell(
                      onTap: () => _callNumber(context, resource.tel),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.spacing16),
                        child: Row(
                          children: [
                            Icon(
                              index == 3
                                  ? Icons.health_and_safety_outlined
                                  : Icons.phone_outlined,
                              size: 22,
                              color: accent,
                            ),
                            const SizedBox(width: AppDimensions.spacing16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    resource.title,
                                    style: AppTextStyles.titleSmall(color: ink),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing4,
                                  ),
                                  Text(
                                    resource.subtitle,
                                    style: AppTextStyles.bodyMedium(
                                      color: secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacing8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: secondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (index < kEmergencyResources.length - 1)
                    Divider(
                      height: 1,
                      color: divider,
                      indent: AppDimensions.spacing16,
                      endIndent: AppDimensions.spacing16,
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'Choisis un contact pour ouvrir l’appel.',
            style: AppTextStyles.bodyMedium(color: ink),
          ),
        ],
      ),
    );
  }

  Future<void> _callNumber(BuildContext context, String tel) async {
    final uri = Uri(scheme: 'tel', path: tel);
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // Simulators and devices without a dialer can still show the number.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Appel indisponible sur cet appareil. Compose le $tel.'),
      ),
    );
  }
}
