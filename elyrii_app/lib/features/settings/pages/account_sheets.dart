import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/config/api_config.dart';
import '../../../core/diagnostics/app_diagnostics.dart';
import '../../../core/export/private_export.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_sheet_route.dart';
import '../../../routes/app_routes.dart';
import '../../profile_setup/presentation/widgets/profile_controls.dart';
import '../providers/settings_provider.dart';

const localDataExplanation =
    'Les notes enregistrées sur le serveur ont une copie locale protégée. Hors connexion, les modifications restent dans un brouillon sur cet appareil : rouvre la note et utilise Enregistrer pour réessayer. Les conversations restent sur cet appareil. Supprimer ton compte efface aussi ses données locales.';
const exportConsent =
    'Le fichier contient tes notes et conversations lisibles. Choisis où le conserver ou le partager. Une copie temporaire sur cet appareil est supprimée après 24 heures au prochain lancement.';

Future<void> showProfileInfo(
  BuildContext context,
  String title,
  String message,
) async {
  await profileSheet<void>(
    context,
    title,
    Builder(
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: AppTextStyles.bodyMedium(color: sheet.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ProfileButton(
            label: 'Compris',
            filled: false,
            onPressed: () => Navigator.pop(sheet),
          ),
        ],
      ),
    ),
  );
}

Future<void> showAccountData(BuildContext context) async {
  final user = context.read<UserProvider>();
  final next = await profileSheet<String>(
    context,
    'Mes données',
    ListenableBuilder(
      listenable: user,
      builder: (sheet, _) {
        final dark = Theme.of(sheet).brightness == Brightness.dark;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ton profil, tes écrits et tes conversations sont personnels.',
              style: AppTextStyles.bodyMedium(color: sheet.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacing16),
            ProfileGroup(
              children: [
                ProfileRow(
                  title: 'Exporter mes données',
                  icon: Icons.download_rounded,
                  color: AppColors.green(dark),
                  onTap: () => Navigator.pop(sheet, 'export'),
                ),
                ProfileRow(
                  title: 'Confidentialité stricte',
                  icon: Icons.shield_rounded,
                  color: AppColors.violet(dark),
                  value: user.settings?.privacyMode == 'STRICT'
                      ? 'Activée'
                      : 'Désactivée',
                  onTap: () => Navigator.pop(sheet, 'strict'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacing16),
            Text(
              localDataExplanation,
              style: AppTextStyles.profileFootnote(color: sheet.textSecondary),
            ),
          ],
        );
      },
    ),
  );
  if (!context.mounted) return;
  if (next == 'export') {
    await exportAccount(context);
  } else if (next == 'strict') {
    await showProfileInfo(
      context,
      'Confidentialité stricte',
      'Cette option limite les usages de tes données. Tes écrits restent personnels.',
    );
  }
}

Future<void> exportAccount(BuildContext context) async {
  final approved = await profileSheet<bool>(
    context,
    'Exporter mes données',
    Builder(
      builder: (sheet) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ton compte, tes notes et tes conversations dans un fichier JSON, à garder pour toi.',
            style: AppTextStyles.bodyMedium(color: sheet.textPrimary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            exportConsent,
            style: AppTextStyles.bodyMedium(color: sheet.textSecondary),
          ),
          const SizedBox(height: AppDimensions.spacing16),
          ProfileButton(
            label: 'Préparer le fichier',
            onPressed: () => Navigator.pop(sheet, true),
          ),
        ],
      ),
    ),
  );
  if (approved != true || !context.mounted) return;
  final services = context.read<AppDependencies>();
  final owner = services.auth.accountId;
  final revision = services.auth.sessionRevision;
  if (owner == null) return;
  try {
    await services.chat.flushed;
    final remote = await services.api.get('${ApiConfig.baseUrl}/user/export');
    final local = await services.history.exportOwner(owner);
    final drafts = await services.journalStore.exportDrafts(owner);
    if (!context.mounted ||
        services.auth.accountId != owner ||
        revision != services.auth.sessionRevision) {
      return;
    }
    await PrivateExport.share(
      context,
      {'server': remote, 'localConversations': local, 'localDrafts': drafts},
      title: 'Mes données Elyrii',
      isCurrentOwner: () =>
          services.auth.accountId == owner &&
          services.auth.sessionRevision == revision,
    );
  } catch (error) {
    if (context.mounted) {
      await showProfileInfo(
        context,
        'Export indisponible',
        error is ApiException
            ? error.message
            : 'Impossible de préparer ou partager le fichier. Réessaie.',
      );
    }
  }
}

Future<void> exportDiagnostics(BuildContext context) async {
  try {
    final data = await AppDiagnostics.export();
    if (context.mounted) {
      await PrivateExport.share(context, data, title: 'Diagnostic Elyrii');
    }
  } catch (_) {
    if (context.mounted) {
      await showProfileInfo(
        context,
        'Diagnostic indisponible',
        'Impossible de partager le diagnostic. Réessaie.',
      );
    }
  }
}

sealed class _DeletionChoice {
  const _DeletionChoice();
}

final class _ExportBeforeDeletion extends _DeletionChoice {
  const _ExportBeforeDeletion();
}

final class _ConfirmDeletion extends _DeletionChoice {
  final String password;
  const _ConfirmDeletion(this.password);
}

Future<void> confirmAccountDeletion(BuildContext context) async {
  final controller = TextEditingController();
  String? error;
  var allowClose = false;
  final route = AppSheetRoute<_DeletionChoice>(
    reduced: MediaQuery.disableAnimationsOf(context),
    canDismiss: () => allowClose,
    dragDismissible: false,
    cardOrigin: Offset.zero & MediaQuery.sizeOf(context),
    builder: (dialog) => Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: Material(
            color: Colors.transparent,
            child: ProfileCard(
              color: AppColors.sheetSurface(
                Theme.of(dialog).brightness == Brightness.dark,
              ),
              radius: AppDimensions.radius28,
              padding: const EdgeInsets.all(AppDimensions.spacing24),
              child: StatefulBuilder(
                builder: (dialog, setState) => SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.delete_rounded,
                        color: AppColors.profileDanger(
                          Theme.of(dialog).brightness == Brightness.dark,
                        ),
                        size: AppDimensions.accueilHeaderControl,
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      Text(
                        'Supprimer ton compte ?',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.titleLarge(
                          color: dialog.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      Text(
                        "Tes écrits, ton jardin et tes conversations seront effacés. Tu peux d'abord exporter tes données.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium(
                          color: dialog.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing12),
                      TextField(
                        controller: controller,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          errorText: error,
                        ),
                        onChanged: (_) {
                          if (error != null) setState(() => error = null);
                        },
                      ),
                      const SizedBox(height: AppDimensions.spacing16),
                      ProfileButton(
                        label: "Exporter d'abord",
                        filled: false,
                        onPressed: () {
                          allowClose = true;
                          Navigator.pop(dialog, const _ExportBeforeDeletion());
                        },
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      ProfileButton(
                        label: 'Supprimer',
                        danger: true,
                        onPressed: () {
                          if (controller.text.trim().isEmpty) {
                            setState(
                              () => error =
                                  'Entre ton mot de passe pour confirmer.',
                            );
                            return;
                          }
                          allowClose = true;
                          Navigator.pop(
                            dialog,
                            _ConfirmDeletion(controller.text.trim()),
                          );
                        },
                      ),
                      TextButton(
                        onPressed: () {
                          allowClose = true;
                          Navigator.pop(dialog);
                        },
                        child: const Text('Annuler'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final choice = await Navigator.of(context, rootNavigator: true).push(route);
  await route.completed;
  controller.dispose();
  if (!context.mounted || choice == null) return;
  if (choice is _ExportBeforeDeletion) {
    await exportAccount(context);
    return;
  }
  final password = (choice as _ConfirmDeletion).password;
  final user = context.read<UserProvider>();
  bool success = false;
  String? localError;
  try {
    success = await context.read<AppDependencies>().deleteAccount(password);
  } catch (_) {
    localError = 'Le compte a été supprimé, mais le nettoyage local a échoué. Redémarre Elyrii pour réessayer le nettoyage.';
  }
  if (!context.mounted) return;
  if (success) {
    context.go(AppRoutes.login);
    return;
  }
  await showProfileInfo(
    context,
    'Suppression impossible',
    localError ?? user.error ?? 'Impossible de supprimer le compte. Vérifie ton mot de passe et réessaie.',
  );
}
