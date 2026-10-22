import '../../../core/widgets/accessible_action.dart';
import '../../../app/app_dependencies.dart';
import '../../../core/export/private_export.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/config/api_config.dart';

import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/cupertino.dart'
    show
        CupertinoActivityIndicator,
        CupertinoAlertDialog,
        CupertinoDialogAction,
        CupertinoTextField,
        showCupertinoDialog;
import 'package:flutter/material.dart';

import '../../../core/widgets/elyrii_page_header.dart';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
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
  bool _haptics = true;
  bool _isDeletingAccount = false;
  bool _isExporting = false;
  String _version = 'Chargement…';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform()
        .then((info) {
          if (mounted) {
            setState(
              () => _version = '${info.version} (Build ${info.buildNumber})',
            );
          }
        })
        .catchError((Object _) {
          if (mounted) setState(() => _version = 'Indisponible');
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<UserProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final appSettings = userProvider.settings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hapticsEnabled = appSettings?.hapticsEnabled ?? _haptics;
    final strictPrivacy = appSettings?.privacyMode == 'STRICT';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ElyriiPageFrame.detail(
        title: 'Paramètres',
        leading: const ElyriiBackButton(),
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (userProvider.error != null)
            SliverToBoxAdapter(
              child: Semantics(
                liveRegion: true,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing20),
                  child: Column(
                    children: [
                      Text(
                        userProvider.error!,
                        style: AppTextStyles.bodyMedium(
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
          // Section Apparence
          SliverToBoxAdapter(
            child: _buildSection(
              context,
              title: 'Apparence',
              children: [
                _SettingsCell(
                  title: 'Mode sombre',
                  subtitle: 'Activer le thème sombre',
                  icon: Icons.dark_mode_rounded,
                  iconColor: AppColors.primary,
                  onTap: null,
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeThumbColor: AppColors.primary,
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
              children: [
                const _SettingsCell(
                  title: 'Notifications push',
                  subtitle:
                      'Les rappels ne sont pas disponibles dans cette version.',
                  icon: Icons.notifications_rounded,
                  iconColor: AppColors.primary,
                  onTap: null,
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Retour haptique',
                  subtitle: 'Vibrations lors des interactions',
                  icon: Icons.vibration_rounded,
                  iconColor: AppColors.primary,
                  onTap: null,
                  trailing: Switch.adaptive(
                    value: hapticsEnabled,
                    activeThumbColor: AppColors.primary,
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
                  trailing: Switch.adaptive(
                    value: strictPrivacy,
                    activeThumbColor: AppColors.primary,
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
                  subtitle: 'Comprendre les copies locales',
                  icon: Icons.storage_rounded,
                  iconColor: AppColors.primary,
                  onTap: () {
                    _showInfoDialog(
                      title: 'Données et stockage',
                      message: 'Les notes enregistrées sur le serveur ont une copie locale protégée. Hors connexion, les modifications restent dans un brouillon sur cet appareil : rouvre la note et utilise Enregistrer pour réessayer. Les conversations restent sur cet appareil. Supprimer ton compte efface aussi ses données locales.',
                    );
                  },
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Exporter mes données',
                  subtitle: _isExporting
                      ? 'Préparation…'
                      : 'Compte, notes et conversations dans un fichier JSON',
                  icon: Icons.download_rounded,
                  iconColor: AppColors.primary,
                  onTap: _isExporting ? null : _exportAccount,
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
              children: [
                _SettingsCell(
                  title: 'Version',
                  subtitle: _version,
                  icon: Icons.info_rounded,
                  iconColor: AppColors.primary,
                  onTap: null,
                ),
                _buildDivider(isDark),
                _SettingsCell(
                  title: 'Exporter un diagnostic technique',
                  subtitle: 'Événements techniques sans tes contenus ni tes identifiants',
                  icon: Icons.bug_report_outlined,
                  iconColor: AppColors.primary,
                  onTap: _exportDiagnostics,
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
              padding: const EdgeInsets.all(AppDimensions.spacing20),
              child: LiquidGlassButton(
                label: 'Se déconnecter',
                icon: Icons.logout_rounded,
                style: LiquidGlassButtonStyle.gray,
                isExpanded: true,
                onPressed: () {
                  showLiquidGlassDialog(
                    context: context,
                    title: 'Se déconnecter',
                    child: const Text('Es-tu sûr de vouloir te déconnecter ?'),
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
          const SliverToBoxAdapter(
            child: SizedBox(height: AppDimensions.pageBottomInset),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDiagnostics() async {
    try {
      final data = await AppDiagnostics.export();
      if (mounted) {
        await PrivateExport.share(context, data, title: 'Diagnostic Elyrii');
      }
    } catch (_) {
      if (mounted) {
        _showInfoDialog(
          title: 'Diagnostic indisponible',
          message: 'Impossible de partager le diagnostic. Réessaie.',
        );
      }
    }
  }

  Future<void> _exportAccount() async {
    final approved = await showLiquidGlassDialog<bool>(
      context: context,
      title: 'Exporter mes données',
      child: const Text(
        'Le fichier contient tes notes et conversations lisibles. Choisis où le conserver ou le partager. Une copie temporaire sur cet appareil est supprimée après 24 heures au prochain lancement.',
      ),
      actions: [
        LiquidGlassDialogAction(
          label: 'Annuler',
          onPressed: () => Navigator.pop(context, false),
        ),
        LiquidGlassDialogAction(
          label: 'Préparer le fichier',
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
    if (approved != true || !mounted) return;
    final services = context.read<AppDependencies>();
    final owner = services.auth.accountId;
    final revision = services.auth.sessionRevision;
    if (owner == null) return;
    setState(() => _isExporting = true);
    try {
      await services.chat.flushed;
      final remote = await services.api.get('${ApiConfig.baseUrl}/user/export');
      final local = await services.history.exportOwner(owner);
      final drafts = await services.journalStore.exportDrafts(owner);
      if (!mounted || revision != services.auth.sessionRevision) return;
      await PrivateExport.share(
        context,
        {'server': remote, 'localConversations': local, 'localDrafts': drafts},
        title: 'Mes données Elyrii',
        isCurrentOwner: () =>
            services.auth.accountId == owner &&
            services.auth.sessionRevision == revision,
      );
    } catch (e) {
      if (mounted) {
        _showInfoDialog(
          title: 'Export indisponible',
          message: e is ApiException
              ? e.message
              : 'Impossible de préparer ou partager le fichier. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing24,
        AppDimensions.pageHorizontalPadding,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: AppDimensions.spacing4,
              bottom: AppDimensions.spacing8,
            ),
            child: Text(
              title,
              style: AppTextStyles.overline(color: context.textSecondary),
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
        style: AppTextStyles.bodyMedium(),
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
              Text(
                'Cette action supprimera définitivement ton compte et tes données associées. Entre ton mot de passe pour confirmer.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium(),
              ),
              const SizedBox(height: AppDimensions.spacing16),
              CupertinoTextField(
                controller: passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                placeholder: 'Mot de passe',
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacing16,
                  vertical: AppDimensions.spacing12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppDimensions.radius8),
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
                const SizedBox(height: AppDimensions.spacing8),
                Text(
                  errorText,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.readableAccent(
                      AppColors.error,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    ),
                  ),
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
        : context.textPrimary;

    final content = Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing16,
        vertical: AppDimensions.spacing12,
      ),
      child: Row(
        children: [
          // Pastille douce monotone : une seule teinte d'accent, ton apaisé.
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: BorderRadius.circular(AppDimensions.radius12),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall(color: titleColor)),
                if (subtitle != null) ...[
                  const SizedBox(height: AppDimensions.spacing2),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySmall(color: context.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppDimensions.spacing12),
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
    if (onTap == null || trailing is Switch) {
      return MergeSemantics(child: content);
    }
    return AccessibleAction(
      label: '$title${subtitle == null ? '' : '. $subtitle'}',
      onPressed: onTap,
      child: content,
    );
  }
}
