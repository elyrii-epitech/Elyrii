import '../../../core/widgets/accessible_action.dart';
import '../../../app/app_dependencies.dart';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoSwitch,
        CupertinoTextField,
        showCupertinoDialog;
import 'package:flutter/material.dart';

import '../../../core/widgets/elyrii_page_header.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../core/services/theme_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../routes/app_routes.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../providers/settings_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notifications = true;
  bool _haptics = true;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userProvider = context.watch<UserProvider>();
    final appSettings = userProvider.settings;
    final isDark = themeProvider.isDarkMode;
    final notificationsEnabled =
        appSettings?.notificationsEnabled ?? _notifications;
    final hapticsEnabled = appSettings?.hapticsEnabled ?? _haptics;
    final strictPrivacy = appSettings?.privacyMode == 'STRICT';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ElyriiPageFrame(
        header: const ElyriiPageHeader(
          title: 'Paramètres',
          subtitle: 'Ajuste Elyrii à ton rythme.',
          leading: ElyriiBackButton(),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            if (userProvider.error != null)
              SliverToBoxAdapter(
                child: Semantics(
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          userProvider.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        TextButton(
                          onPressed: userProvider.isLoading
                              ? null
                              : userProvider.loadSettings,
                          child: const Text('Recharger les paramètres'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Titre et sous-titre : dans le scroll, la flèche reste épinglée.

            // Section Apparence
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: 'Apparence',
                isDark: isDark,
                children: [
                  _SettingsCell(
                    title: 'Mode sombre',
                    subtitle: 'Activer le thème sombre',
                    icon: Icons.dark_mode_rounded,
                    iconColor: AppColors.primary,
                    onTap: null,
                    trailing: CupertinoSwitch(
                      value: isDark,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) {
                        final mode = value ? ThemeMode.dark : ThemeMode.light;
                        context.read<UserProvider>().updateSettings(
                          themeMode: _themeModeToServerValue(mode),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Section Notifications
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: 'Notifications',
                isDark: isDark,
                children: [
                  _SettingsCell(
                    title: 'Notifications push',
                    subtitle: 'Rappels et mises à jour',
                    icon: Icons.notifications_rounded,
                    iconColor: AppColors.primary,
                    onTap: null,
                    trailing: CupertinoSwitch(
                      value: notificationsEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _notifications = value);
                        context.read<UserProvider>().updateSettings(
                          notificationsEnabled: value,
                        );
                      },
                    ),
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Retour haptique',
                    subtitle: 'Vibrations lors des interactions',
                    icon: Icons.vibration_rounded,
                    iconColor: AppColors.primary,
                    onTap: null,
                    trailing: CupertinoSwitch(
                      value: hapticsEnabled,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) {
                        setState(() => _haptics = value);
                        ElyriiHaptics.setEnabled(value);
                        context.read<UserProvider>().updateSettings(
                          hapticsEnabled: value,
                        );
                        if (value) {
                          ElyriiHaptics.medium();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Section Compte
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: 'Compte',
                isDark: isDark,
                children: [
                  _SettingsCell(
                    title: 'Profil',
                    subtitle: 'Gère tes informations',
                    icon: Icons.person_rounded,
                    iconColor: AppColors.primary,
                    onTap: () {
                      context.push(AppRoutes.editProfile);
                    },
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Confidentialité stricte',
                    subtitle: strictPrivacy
                        ? 'Mode strict activé'
                        : 'Limite les usages de tes données',
                    icon: Icons.lock_rounded,
                    iconColor: AppColors.primary,
                    onTap: () {
                      context.read<UserProvider>().updateSettings(
                        privacyMode: strictPrivacy ? 'STANDARD' : 'STRICT',
                      );
                    },
                    trailing: CupertinoSwitch(
                      value: strictPrivacy,
                      activeTrackColor: AppColors.primary,
                      onChanged: (value) {
                        context.read<UserProvider>().updateSettings(
                          privacyMode: value ? 'STRICT' : 'STANDARD',
                        );
                      },
                    ),
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Données et stockage',
                    subtitle: 'Exporte ou supprime tes contenus',
                    icon: Icons.storage_rounded,
                    iconColor: AppColors.primary,
                    onTap: () {
                      _showInfoDialog(
                        title: 'Données et stockage',
                        message: 'Tes notes et tes humeurs sont synchronisées quand le réseau est disponible. Les brouillons et l’historique des conversations sont conservés sur cet appareil. Supprimer ton compte efface aussi ses données locales. Une déconnexion conserve les contenus locaux protégés pour ta prochaine connexion.',
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Supprimer mon compte',
                    subtitle: 'Suppression définitive du compte',
                    icon: Icons.delete_forever_rounded,
                    iconColor: AppColors.error,
                    isDestructive: true,
                    onTap: _isDeletingAccount
                        ? null
                        : () => _showDeleteAccountDialog(),
                    trailing: _isDeletingAccount
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CupertinoActivityIndicator(radius: 10),
                          )
                        : Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: AppColors.error.withValues(alpha: 0.75),
                          ),
                  ),
                ],
              ),
            ),
            // Section À propos
            SliverToBoxAdapter(
              child: _buildSection(
                context,
                title: 'À propos',
                isDark: isDark,
                children: [
                  const _SettingsCell(
                    title: 'Version',
                    subtitle: '1.0.0 (Build 1)',
                    icon: Icons.info_rounded,
                    iconColor: AppColors.primary,
                    onTap: null,
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Conditions d\'utilisation',
                    icon: Icons.description_rounded,
                    iconColor: AppColors.primary,
                    onTap: () {
                      _showInfoDialog(
                        title: 'Conditions d\'utilisation',
                        message: 'Elyrii n’est pas un service d’urgence ni un remplacement d’un professionnel de santé. Les conditions doivent préciser les limites de l’accompagnement, les règles de sécurité et les responsabilités.',
                      );
                    },
                  ),
                  _buildDivider(isDark),
                  _SettingsCell(
                    title: 'Politique de confidentialité',
                    icon: Icons.privacy_tip_rounded,
                    iconColor: AppColors.primary,
                    onTap: () {
                      _showInfoDialog(
                        title: 'Politique de confidentialité',
                        message: 'La politique doit être accessible avant connexion et détailler le traitement des données de santé mentale, la durée de conservation, les droits utilisateur et les contacts de suppression.',
                      );
                    },
                  ),
                ],
              ),
            ),
            // Section Déconnexion
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: LiquidGlassButton(
                  label: 'Se déconnecter',
                  icon: Icons.logout_rounded,
                  style: LiquidGlassButtonStyle.gray,
                  isExpanded: true,
                  onPressed: () {
                    showLiquidGlassDialog(
                      context: context,
                      title: 'Se déconnecter',
                      child: const Text(
                        'Es-tu sûr de vouloir te déconnecter ?',
                      ),
                      actions: [
                        LiquidGlassDialogAction(
                          label: 'Annuler',
                          onPressed: () => Navigator.pop(context),
                        ),
                        LiquidGlassDialogAction(
                          label: 'Déconnecter',
                          isDestructive: true,
                          onPressed: () async {
                            Navigator.pop(context);
                            await context.read<AuthProvider>().logout();
                            if (context.mounted) {
                              context.go(AppRoutes.login);
                            }
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            // Espace en bas
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          LiquidGlassCard(
            padding: EdgeInsets.zero,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  String _themeModeToServerValue(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'LIGHT';
      case ThemeMode.dark:
        return 'DARK';
      case ThemeMode.system:
        return 'SYSTEM';
    }
  }

  /// Séparateur inseté à la façon des listes groupées iOS (aligné sur le texte).
  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: 58,
      color: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.black.withValues(alpha: 0.08),
    );
  }

  void _showInfoDialog({required String title, required String message}) {
    showLiquidGlassDialog(
      context: context,
      title: title,
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(height: 1.45),
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Compris',
          isDefault: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final errorNotifier = ValueNotifier<String?>(null);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Validation inline : bannière d'erreur dans le dialogue plutôt que SnackBar.
    void submit() {
      final password = passwordController.text.trim();
      if (password.isEmpty) {
        ElyriiHaptics.warning();
        errorNotifier.value = 'Entre ton mot de passe pour confirmer.';
        return;
      }
      Navigator.pop(context);
      _deleteAccount(password);
    }

    await showLiquidGlassDialog(
      context: context,
      barrierDismissible: false,
      title: 'Supprimer le compte',
      child: ValueListenableBuilder<String?>(
        valueListenable: errorNotifier,
        builder: (context, errorText, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cette action supprimera définitivement ton compte et tes données associées. Entre ton mot de passe pour confirmer.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              CupertinoTextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                placeholder: 'Mot de passe',
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: errorText == null
                        ? Colors.transparent
                        : AppColors.error,
                  ),
                ),
                onChanged: (_) {
                  // L'erreur disparaît dès que l'utilisateur retape.
                  if (errorNotifier.value != null) errorNotifier.value = null;
                },
                onSubmitted: (_) => submit(),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ],
            ],
          );
        },
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.pop(context),
        ),
        LiquidGlassDialogAction(
          label: 'Supprimer',
          isDestructive: true,
          onPressed: submit,
        ),
      ],
    );

    passwordController.dispose();
    errorNotifier.dispose();
  }

  Future<void> _deleteAccount(String password) async {
    setState(() => _isDeletingAccount = true);

    final userProvider = context.read<UserProvider>();
    bool success = false;
    String? localError;
    try {
      success = await context.read<AppDependencies>().deleteAccount(password);
    } catch (_) {
      localError = 'Le compte a été supprimé, mais le nettoyage local a échoué. Redémarre Elyrii pour réessayer le nettoyage.';
    }

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      if (!mounted) return;
      context.go(AppRoutes.login);
      return;
    }

    // Erreur bloquante : alerte Cupertino plutôt que SnackBar Material.
    ElyriiHaptics.warning();
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Suppression impossible'),
        content: Text(
          localError ?? userProvider.error ?? 'Impossible de supprimer le compte. Vérifie ton mot de passe et réessaie.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Cellule de liste groupée façon Réglages iOS : icône colorée dans un
/// squircle arrondi, séparateurs insetés gérés par le parent, trailing libre
/// (switch natif, chevron ou indicateur d'activité).
class _SettingsCell extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _SettingsCell({
    required this.title,
    required this.icon,
    required this.iconColor,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDestructive
        ? Theme.of(context).colorScheme.error
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    final content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Pastille douce monotone : une seule teinte d'accent, ton apaisé.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.25),
            ),
        ],
      ),
    );
    if (onTap == null) return MergeSemantics(child: content);
    return AccessibleAction(
      label: '$title${subtitle == null ? '' : '. $subtitle'}',
      onPressed: onTap,
      child: content,
    );
  }
}
