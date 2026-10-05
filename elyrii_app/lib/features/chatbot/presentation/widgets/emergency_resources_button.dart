import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Numéros d'écoute et d'urgence santé mentale (France), tapables.
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
      return IconButton.filledTonal(
        tooltip: 'Aide d’urgence et numéros d’écoute',
        onPressed: () => _showEmergencyResources(context),
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          backgroundColor: isDark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          foregroundColor: foreground,
        ),
        icon: const Icon(Icons.health_and_safety_outlined, size: 23),
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
        foregroundColor: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        textStyle: AppTextStyles.labelLarge(),
      ),
    );
  }

  void _showEmergencyResources(BuildContext context) {
    FocusManager.instance.primaryFocus?.unfocus();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(
        maxWidth: AppDimensions.maxContentWidth,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusXl),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (sheetContext) => Material(
        key: const ValueKey('emergency-sheet-surface'),
        color: Theme.of(sheetContext).brightness == Brightness.dark
            ? AppColors.scaffoldDark
            : AppColors.scaffoldLight,
        child: const _EmergencyResourcesSheet(),
      ),
    );
  }
}

class _EmergencyResourcesSheet extends StatelessWidget {
  const _EmergencyResourcesSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: AppDimensions.spacingSm),
              decoration: BoxDecoration(
                color: divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimensions.spacingLg,
                AppDimensions.spacingSm,
                AppDimensions.spacingMd,
                0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Besoin d’aide ?',
                      style: AppTextStyles.titleLarge(
                        color: ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: secondary,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.spacingLg,
                  AppDimensions.spacingXs,
                  AppDimensions.spacingLg,
                  AppDimensions.spacingLg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu n’es pas seul(e). Ces lignes sont là pour t’écouter et t’orienter.',
                      style: AppTextStyles.bodyMedium(color: ink),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Material(
                      color: surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          for (final (index, resource)
                              in kEmergencyResources.indexed) ...[
                            Semantics(
                              button: true,
                              label:
                                  'Appeler ${resource.title}, ${resource.tel}',
                              child: InkWell(
                                onTap: () => _callNumber(context, resource.tel),
                                child: Padding(
                                  padding: const EdgeInsets.all(
                                    AppDimensions.spacingMd,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        index == 3
                                            ? Icons.health_and_safety_outlined
                                            : Icons.phone_outlined,
                                        size: 22,
                                        color: accent,
                                      ),
                                      const SizedBox(
                                        width: AppDimensions.spacingMd,
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              resource.title,
                                              style: AppTextStyles.titleSmall(
                                                color: ink,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(
                                              height: AppDimensions.spacingXxs,
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
                                      const SizedBox(
                                        width: AppDimensions.spacingXs,
                                      ),
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
                                indent: AppDimensions.spacingMd,
                                endIndent: AppDimensions.spacingMd,
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Text(
                      'Choisis un contact pour ouvrir l’appel.',
                      style: AppTextStyles.bodyMedium(color: ink),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
