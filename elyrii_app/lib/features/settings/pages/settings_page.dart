import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../../core/content/account_information.dart';
import '../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/pushed_page.dart';
import '../../../routes/app_routes.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../profile_setup/presentation/widgets/profile_controls.dart';
import '../providers/settings_provider.dart';
import 'account_sheets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = 'Chargement…';
  bool _deleting = false;
  bool _exporting = false;
  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) setState(() => _version = info.version);
        })
        .catchError((Object _) {
          if (mounted) setState(() => _version = 'Indisponible');
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserProvider>().loadSettings();
    });
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    await confirmAccountDeletion(context);
    if (mounted) setState(() => _deleting = false);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    await exportAccount(context);
    if (mounted) setState(() => _exporting = false);
  }

  Future<void> _logout() async {
    final logout = await profileSheet<bool>(
      context,
      'Se déconnecter ?',
      Builder(
        builder: (sheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Tes notes et ton historique sur cet appareil seront conservés pour ta prochaine connexion.',
              style: AppTextStyles.bodyMedium(color: sheet.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            ProfileButton(
              label: 'Annuler',
              filled: false,
              onPressed: () => Navigator.pop(sheet, false),
            ),
            TextButton(
              onPressed: () => Navigator.pop(sheet, true),
              child: const Text('Se déconnecter'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || logout != true) return;
    await context.read<AuthProvider>().logout();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final settings = user.settings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PushedPage(
      title: 'Réglages',
      children: [
        if (user.error != null)
          Semantics(
            liveRegion: true,
            child: Column(
              children: [
                Text(
                  user.error!,
                  style: AppTextStyles.bodyMedium(
                    color: AppColors.errorText(dark),
                  ),
                ),
                TextButton(
                  onPressed: user.isLoading ? null : user.loadSettings,
                  child: const Text('Recharger les paramètres'),
                ),
              ],
            ),
          ),
        ProfileSection(
          title: 'Apparence',
          child: ProfileCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppDimensions.profileSquare,
                  height: AppDimensions.profileSquare,
                  decoration: BoxDecoration(
                    color: AppColors.violet(dark),
                    borderRadius: BorderRadius.circular(
                      AppDimensions.profileSquareRadius,
                    ),
                  ),
                  child: const Icon(
                    Icons.contrast_rounded,
                    color: Colors.white,
                    size: AppDimensions.profileIcon,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Apparence',
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      ProfileSegments<String>(
                        options: const {
                          'DARK': 'Sombre',
                          'LIGHT': 'Clair',
                          'SYSTEM': 'Système',
                        },
                        selected: settings?.themeMode ?? 'SYSTEM',
                        onChanged: (value) =>
                            user.updateSettings(themeMode: value),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ProfileSection(
          title: 'Interactions',
          child: ProfileGroup(
            children: [
              ProfileRow(
                title: 'Vibrations',
                icon: Icons.vibration_rounded,
                color: AppColors.pink(dark),
                trailing: ProfileToggle(
                  label: 'Vibrations',
                  value: settings?.hapticsEnabled ?? true,
                  onChanged: (value) {
                    ElyriiHaptics.setEnabled(value);
                    user.updateSettings(hapticsEnabled: value);
                    if (value) ElyriiHaptics.medium();
                  },
                ),
              ),
            ],
          ),
        ),
        ProfileSection(
          title: 'Confidentialité',
          footer: 'Stockage, export et suppression.',
          child: ProfileGroup(
            children: [
              ProfileRow(
                title: 'Mes données',
                icon: Icons.storage_rounded,
                color: AppColors.teal(dark),
                onTap: () => showAccountData(context),
              ),
            ],
          ),
        ),
        ProfileSection(
          title: 'Compte',
          child: ProfileGroup(
            children: [
              ProfileRow(
                title: 'Exporter mes données',
                icon: Icons.download_rounded,
                color: AppColors.green(dark),
                onTap: _exporting ? null : _export,
                trailing: _exporting
                    ? const CupertinoActivityIndicator()
                    : null,
              ),
              ProfileRow(
                title: 'Supprimer mon compte',
                icon: Icons.delete_rounded,
                color: AppColors.pink(dark),
                destructive: true,
                onTap: _deleting ? null : _delete,
                trailing: _deleting ? const CupertinoActivityIndicator() : null,
              ),
            ],
          ),
        ),
        ProfileSection(
          title: 'À propos',
          child: ProfileGroup(
            children: [
              ProfileRow(
                title: 'Version',
                icon: Icons.info_rounded,
                color: AppColors.violet(dark),
                value: _version,
              ),
              ProfileRow(
                title: AccountInformation.serviceTitle,
                icon: Icons.description_rounded,
                color: AppColors.violet(dark),
                onTap: () => showProfileInfo(
                  context,
                  AccountInformation.serviceTitle,
                  AccountInformation.service,
                ),
              ),
              ProfileRow(
                title: AccountInformation.dataTitle,
                icon: Icons.policy_rounded,
                color: AppColors.violet(dark),
                onTap: () => showProfileInfo(
                  context,
                  AccountInformation.dataTitle,
                  AccountInformation.data,
                ),
              ),
              ProfileRow(
                title: 'Diagnostic technique',
                icon: Icons.monitor_heart_rounded,
                color: AppColors.orange(dark),
                onTap: () async {
                  final export = await profileSheet<bool>(
                    context,
                    'Diagnostic technique',
                    Builder(
                      builder: (sheet) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ProfileGroup(
                            children: [
                              ProfileRow(
                                title: 'Version',
                                icon: Icons.info_rounded,
                                color: AppColors.violet(dark),
                                value: _version,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          Text(
                            'Événements techniques sans tes contenus ni tes identifiants',
                            style: AppTextStyles.bodyMedium(
                              color: sheet.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          ProfileButton(
                            label: 'Exporter un diagnostic technique',
                            onPressed: () => Navigator.pop(sheet, true),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (context.mounted && export == true) {
                    await exportDiagnostics(context);
                  }
                },
              ),
            ],
          ),
        ),
        ProfileCard(
          padding: EdgeInsets.zero,
          child: TextButton(
            onPressed: _logout,
            style: TextButton.styleFrom(
              minimumSize: const Size.fromHeight(
                AppDimensions.profileRowHeight,
              ),
            ),
            child: Text(
              'Se déconnecter',
              style: AppTextStyles.titleSmall(
                color: AppColors.profileDanger(dark),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing32),
        Text(
          'Elyrii · fait avec soin',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodySmall(color: context.textTertiary),
        ),
      ],
    );
  }
}
