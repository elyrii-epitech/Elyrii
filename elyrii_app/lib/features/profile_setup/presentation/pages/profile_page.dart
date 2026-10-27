import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/avatar_options.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/accueil_scene.dart';
import '../../../../core/widgets/glass_bar_button.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../settings/pages/account_sheets.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../settings/providers/settings_provider.dart';
import '../widgets/profile_controls.dart';

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
    final safe = MediaQuery.paddingOf(context);
    const bodyTop =
        AppDimensions.sectionSkyHeight - AppDimensions.sectionBodyOverlap;
    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                SingleChildScrollView(
                  child: Stack(
                    children: [
                      SizedBox(
                        height: AppDimensions.sectionSkyHeight,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              top: -AppDimensions.profileSceneLift,
                              left: 0,
                              right: 0,
                              height: AppDimensions.accueilSceneHeight,
                              child: CustomPaint(
                                painter: AccueilScenePainter(
                                  decor: context
                                      .watch<AccueilActivities>()
                                      .snapshot
                                      .decor,
                                  dark: dark,
                                ),
                              ),
                            ),
                            if (profile != null)
                              Positioned(
                                left: AppDimensions.pageHorizontalPadding,
                                right: AppDimensions.pageHorizontalPadding,
                                bottom: AppDimensions.sectionTitleBottom,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AccessibleAction(
                                      label: 'Modifier mon avatar',
                                      onPressed: _savingAvatar ? null : _avatar,
                                      child: Container(
                                        width: AppDimensions.profileAvatar,
                                        height: AppDimensions.profileAvatar,
                                        padding: const EdgeInsets.all(
                                          AppDimensions.spacing8,
                                        ),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppColors.profileAvatar(dark),
                                        ),
                                        child: _savingAvatar
                                            ? const CupertinoActivityIndicator()
                                            : UserAvatar(
                                                pfp: profile.pfp,
                                                size:
                                                    AppDimensions
                                                        .profileAvatar -
                                                    AppDimensions.spacing16,
                                                showBorder: false,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(
                                      height: AppDimensions.spacing12,
                                    ),
                                    Text(
                                      profile.firstName ?? profile.displayName,
                                      textAlign: TextAlign.center,
                                      style: AppTextStyles.titleLarge(
                                        color: dark
                                            ? Colors.white
                                            : context.textPrimary,
                                      ),
                                    ),
                                    if (profile.createdAt != null) ...[
                                      const SizedBox(
                                        height: AppDimensions.spacing12,
                                      ),
                                      Text(
                                        'Avec Elyrii depuis le ${_joined(profile.createdAt!)}',
                                        textAlign: TextAlign.center,
                                        style: AppTextStyles.bodySmall(
                                          color: dark
                                              ? Colors.white.withValues(
                                                  alpha: .78,
                                                )
                                              : context.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: bodyTop),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - bodyTop,
                            ),
                          ),
                          child: SectionSkyBody(
                            bottomPadding:
                                safe.bottom + AppDimensions.spacing32,
                            child: profile == null
                                ? Center(
                                    child: user.error == null
                                        ? const CupertinoActivityIndicator()
                                        : Column(
                                            mainAxisSize: MainAxisSize.min,
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
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ProfileGroup(
                                        children: [
                                          ProfileRow(
                                            title: 'Mon profil',
                                            icon: Icons.person_rounded,
                                            color: AppColors.violet(dark),
                                            onTap: () => context.push(
                                              AppRoutes.editProfile,
                                            ),
                                          ),
                                          ProfileRow(
                                            title: 'Réglages',
                                            icon: Icons.settings_rounded,
                                            color: AppColors.violet(dark),
                                            onTap: () => context.push(
                                              AppRoutes.settings,
                                            ),
                                          ),
                                          ProfileRow(
                                            title: 'Mon bilan',
                                            icon: Icons.bar_chart_rounded,
                                            color: AppColors.teal(dark),
                                            onTap: () =>
                                                context.push(AppRoutes.reviews),
                                          ),
                                          ProfileRow(
                                            title: 'Mes données',
                                            icon: Icons.storage_rounded,
                                            color: AppColors.teal(dark),
                                            onTap: () =>
                                                showAccountData(context),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: safe.top,
                  left: AppDimensions.pageHorizontalPadding,
                  child: SizedBox(
                    width: AppDimensions.controlSize,
                    height: AppDimensions.accueilBarHeight,
                    child: Center(
                      child: GlassBarButton(
                        icon: Icons.chevron_left_rounded,
                        tooltip: 'Retour',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _joined(DateTime date) {
    final local = date.toLocal();
    return '${local.day == 1 ? '1er' : local.day} ${DateFormat('MMMM', 'fr_FR').format(local)}';
  }
}
