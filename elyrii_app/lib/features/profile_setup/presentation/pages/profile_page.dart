import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/avatar_options.dart';
import '../../../../core/constants/profile_option_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/pushed_page.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../dashboard/domain/accueil_content.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../settings/pages/account_sheets.dart';
import '../../../settings/providers/settings_provider.dart';
import '../widgets/profile_controls.dart';

enum ProfileExit { dressing }

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _savingAvatar = false;
  Future<void> _avatar() async {
    final user = context.read<UserProvider>();
    final owner = user.profile?.id;
    final result = await context.push<String>(
      AppRoutes.avatarPicker,
      extra: user.profile?.pfp,
    );
    if (!mounted ||
        result == kAvatarPickerCancelled ||
        user.profile?.id != owner) {
      return;
    }
    setState(() => _savingAvatar = true);
    final saved = await user.updateProfile(
      pfp: result,
      clearPfp: result == null && user.profile?.pfp != null,
    );
    if (!mounted) return;
    setState(() => _savingAvatar = false);
    profileToast(
      context,
      saved ? 'Avatar enregistré.' : user.error ?? 'Une erreur est survenue',
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final profile = user.profile;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final dashboard = context.watch<DashboardProvider>();
    final garden = context.watch<GamificationProvider>();
    final journal = context.watch<JournalProvider>();
    final activities = context.watch<AccueilActivities>().snapshot;
    final flowers = garden.hasLoadedData
        ? buildGardenFlowers(
            completedChallenges: garden.completedChallenges,
            activities: activities,
          ).length
        : null;
    final streak = dashboard.coverage == null ? null : dashboard.currentStreak;
    final writes = journal.totalCount;
    void bilan() => context.push(AppRoutes.reviews);
    return PushedPage(
      title: 'Profil',
      profileHeader: true,
      trailing: IconButton(
        tooltip: 'Réglages',
        onPressed: () => context.push(AppRoutes.settings),
        icon: const Icon(Icons.settings_rounded),
      ),
      children: [
        if (profile == null)
          Center(
            child: user.error == null
                ? const CupertinoActivityIndicator()
                : Column(
                    children: [
                      Text(
                        user.error!,
                        style: AppTextStyles.bodyMedium(
                          color: context.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: user.loadProfile,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
          )
        else ...[
          Center(
            child: AccessibleAction(
              label: 'Modifier mon avatar',
              onPressed: _savingAvatar ? null : _avatar,
              child: Container(
                width: AppDimensions.profileAvatar,
                height: AppDimensions.profileAvatar,
                padding: const EdgeInsets.all(AppDimensions.spacing8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.profileAvatar(dark),
                ),
                child: _savingAvatar
                    ? const CupertinoActivityIndicator()
                    : UserAvatar(
                        pfp: profile.pfp,
                        size:
                            AppDimensions.profileAvatar -
                            AppDimensions.spacing16,
                        showBorder: false,
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            profile.firstName ?? profile.displayName,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge(color: context.textPrimary),
          ),
          if (profile.createdAt != null) ...[
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              'Avec Elyrii depuis le ${_joined(profile.createdAt!)}',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(color: context.textSecondary),
            ),
          ],
        ],
        const SizedBox(height: AppDimensions.radius30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            _Stat(
              label: streak == null
                  ? '— jours'
                  : '$streak ${streak == 1 ? 'jour' : 'jours'}',
              icon: Icons.local_fire_department_rounded,
              color: AppColors.orange(dark),
              ink: AppColors.onTint(true),
              onTap: bilan,
            ),
            _Stat(
              label: flowers == null
                  ? '— fleurs'
                  : '$flowers ${flowers == 1 ? 'fleur' : 'fleurs'}',
              icon: Icons.local_florist_rounded,
              color: AppColors.green(dark),
              onTap: () async {
                final garden = await profileSheet<bool>(
                  context,
                  flowers == null
                      ? 'Ton jardin'
                      : '$flowers ${flowers == 1 ? 'fleur dans ton jardin' : 'fleurs dans ton jardin'}',
                  Builder(
                    builder: (sheet) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Elles gardent une trace des petits gestes que tu fais pour toi. Tu n'as rien à rattraper.",
                          style: AppTextStyles.bodyMedium(
                            color: sheet.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacing16),
                        ProfileButton(
                          label: 'Voir mon jardin',
                          filled: false,
                          onPressed: () => Navigator.pop(sheet, true),
                        ),
                      ],
                    ),
                  ),
                );
                if (context.mounted && garden == true) {
                  context.go(AppRoutes.challenges);
                }
              },
            ),
            _Stat(
              label: writes == null
                  ? '— écrits'
                  : '$writes ${writes == 1 ? 'écrit' : 'écrits'}',
              icon: Icons.edit_note_rounded,
              color: AppColors.yellow(dark),
              onTap: bilan,
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.radius30),
        ProfileGroup(
          children: [
            ProfileRow(
              title: 'Mon profil',
              icon: Icons.person_rounded,
              color: AppColors.violet(dark),
              onTap: () => context.push(AppRoutes.editProfile),
            ),
            ProfileRow(
              title: "Tenue d'Elyrii",
              icon: Icons.checkroom_rounded,
              color: AppColors.violet(dark),
              onTap: () => context.pop(ProfileExit.dressing),
            ),
            ProfileRow(
              title: 'Mon bilan',
              icon: Icons.bar_chart_rounded,
              color: AppColors.teal(dark),
              onTap: bilan,
            ),
            ProfileRow(
              title: 'Mes données',
              icon: Icons.storage_rounded,
              color: AppColors.teal(dark),
              onTap: () => showAccountData(context),
            ),
          ],
        ),
        const SizedBox(height: AppDimensions.radius30),
        ProfileCard(
          color: Color.alphaBlend(
            AppColors.violet(dark).withValues(alpha: dark ? .17 : .13),
            dark ? AppColors.scaffoldDark : Colors.white,
          ),
          padding: const EdgeInsets.all(AppDimensions.spacing20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ce qui compte pour toi',
                      style: AppTextStyles.titleMedium(
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: profile == null
                        ? null
                        : () async {
                            final goal = await chooseWellnessGoal(
                              context,
                              profile.wellnessGoal,
                            );
                            if (!context.mounted || goal == null) return;
                            final saved = await user.updateProfile(
                              wellnessGoal: goal,
                            );
                            if (context.mounted) {
                              profileToast(
                                context,
                                saved
                                    ? 'Tes objectifs ont été mis à jour.'
                                    : user.error ?? 'Une erreur est survenue',
                              );
                            }
                          },
                    child: Text(
                      'Modifier',
                      style: AppTextStyles.buttonSmall(
                        color: AppColors.primaryText(dark),
                      ),
                    ),
                  ),
                ],
              ),
              if (profile?.wellnessGoal != null &&
                  profile!.wellnessGoal!.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacing8),
                Chip(
                  label: Text(
                    profileOptionLabel(profile.wellnessGoal!),
                    style: AppTextStyles.pillLabel(
                      color: context.textSecondary,
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: dark
                      ? AppColors.cardDark
                      : AppColors.cardLight,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _joined(DateTime date) {
    final local = date.toLocal();
    return '${local.day == 1 ? '1er' : local.day} ${DateFormat('MMMM', 'fr_FR').format(local)}';
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color? ink;
  final VoidCallback onTap;
  const _Stat({
    required this.label,
    required this.icon,
    required this.color,
    this.ink,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => AccessibleAction(
    label: label,
    onPressed: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: AppDimensions.controlSize),
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppDimensions.iconSm,
            color: ink ?? AppColors.onTint(true),
          ),
          const SizedBox(width: AppDimensions.spacing4),
          Text(
            label,
            style: AppTextStyles.pillLabel(
              color: ink ?? AppColors.onTint(true),
            ),
          ),
        ],
      ),
    ),
  );
}
