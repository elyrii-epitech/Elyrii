import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoSwitch,
        CupertinoTextField,
        showCupertinoDialog;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/haptics/elyrii_haptics.dart';
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
      context.read<UserProvider>().loadSettings();
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
    ElyriiHaptics.setEnabled(hapticsEnabled);
    final strictPrivacy = appSettings?.privacyMode == 'STRICT';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, isDark),
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
                      themeProvider.setThemeMode(mode);
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
                  iconColor: AppColors.errorDark,
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
                  iconColor: AppColors.warningDark,
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
                  subtitle: 'Gerer vos informations personnelles',
                  icon: Icons.person_rounded,
                  iconColor: AppColors.infoDark,
                  onTap: () {
                    context.push(AppRoutes.editProfile);
                  },
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Confidentialité stricte',
                  subtitle: strictPrivacy
                      ? 'Mode strict activé'
                      : 'Limiter au maximum les usages de données',
                  icon: Icons.lock_rounded,
                  iconColor: AppColors.primaryDark,
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
                  subtitle: 'Exporter ou supprimer tes contenus',
                  icon: Icons.storage_rounded,
                  iconColor: AppColors.successDark,
                  onTap: () {
                    _showInfoDialog(
                      title: 'Données et stockage',
                      message:
                          'Tes entrées de journal, tes humeurs et tes conversations sont synchronisées avec ton compte sur nos serveurs. Tes préférences (thème, effets visuels, vibrations) et ta session restent stockées localement sur ton appareil. Pour effacer définitivement l’ensemble de tes données, utilise « Supprimer mon compte » ci-dessous.',
                    );
                  },
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Supprimer mon compte',
                  subtitle: 'Effacer définitivement ton compte Elyrii',
                  icon: Icons.delete_forever_rounded,
                  iconColor: AppColors.errorDark,
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
                          Icons.chevron_right,
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
                  iconColor: AppColors.infoDark,
                  onTap: null,
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Conditions d\'utilisation',
                  icon: Icons.description_rounded,
                  iconColor: AppColors.infoDark,
                  onTap: () {
                    _showInfoDialog(
                      title: 'Conditions d\'utilisation',
                      message:
                          'Elyrii n’est pas un service d’urgence ni un remplacement d’un professionnel de santé. Les conditions doivent préciser les limites de l’accompagnement, les règles de sécurité et les responsabilités.',
                    );
                  },
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Politique de confidentialité',
                  icon: Icons.privacy_tip_rounded,
                  iconColor: AppColors.infoDark,
                  onTap: () {
                    _showInfoDialog(
                      title: 'Politique de confidentialité',
                      message:
                          'La politique doit être accessible avant connexion et détailler le traitement des données de santé mentale, la durée de conservation, les droits utilisateur et les contacts de suppression.',
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
                      'Êtes-vous sûr de vouloir vous déconnecter ?',
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
    );
  }

  /// Barre d'application iOS : pinned, translucide et floutée,
  /// titre centré, bouton retour chevron standard.
  Widget _buildAppBar(BuildContext context, bool isDark) {
    final background = isDark
        ? AppColors.scaffoldDark
        : AppColors.scaffoldLight;

    return SliverAppBar(
      pinned: true,
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      title: Text(
        'Paramètres',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        splashColor: Colors.transparent,
        onPressed: () {
          ElyriiHaptics.light();
          Navigator.pop(context);
        },
      ),
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: background.withValues(alpha: 0.72),
          ),
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
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
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
    final authProvider = context.read<AuthProvider>();
    final success = await userProvider.deleteAccount(password: password);

    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      await authProvider.clearLocalSession();
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
          userProvider.error ??
              'Impossible de supprimer le compte. Vérifie ton mot de passe et réessaie.',
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
class _SettingsCell extends StatefulWidget {
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
  State<_SettingsCell> createState() => _SettingsCellState();
}

class _SettingsCellState extends State<_SettingsCell> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = widget.isDestructive
        ? AppColors.errorDark
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return GestureDetector(
      onTapDown: widget.onTap != null
          ? (_) => setState(() => _isPressed = true)
          : null,
      onTapUp: widget.onTap != null
          ? (_) => setState(() => _isPressed = false)
          : null,
      onTapCancel: widget.onTap != null
          ? () => setState(() => _isPressed = false)
          : null,
      onTap: widget.onTap != null
          ? () {
              ElyriiHaptics.light();
              widget.onTap?.call();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        color: _isPressed
            ? (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04))
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Squircle coloré façon Réglages iOS
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(widget.icon, size: 17, color: widget.iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w400,
                      color: titleColor,
                    ),
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 12),
              widget.trailing!,
            ] else if (widget.onTap != null)
              Icon(
                Icons.chevron_right,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.25),
              ),
          ],
        ),
      ),
    );
  }
}
