import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/constants/avatar_options.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/presentation/widgets/glass_auth_text_field.dart';
import '../../../settings/providers/settings_provider.dart';

/// Page d'onboarding proposee juste apres la creation de compte.
///
/// Trois etapes : avatar (cliquable -> picker), identite + preferences,
/// puis ecran de bienvenue. Tout est skippable ; la mascotte est l'avatar
/// par defaut. Le prenom est demande a l'inscription donc pre-rempli.
class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  int _currentStep = 0;
  bool _isSaving = false;

  // Avatar
  String? _selectedPfp;

  // Identite
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();

  // Preferences
  String? _selectedWellnessGoal;

  @override
  void initState() {
    super.initState();
    _prefillFromProfile();
  }

  void _prefillFromProfile() {
    final profile = context.read<UserProvider>().profile;
    if (profile != null) {
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _ageController.text = profile.age != null ? profile.age.toString() : '';
      _bioController.text = profile.bio ?? '';
      _selectedPfp = profile.pfp;
      _selectedWellnessGoal = profile.wellnessGoal;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _openAvatarPicker() async {
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.avatarPicker,
      arguments: _selectedPfp,
    );
    // Ignorer si l'utilisateur a annule (back)
    if (result != kAvatarPickerCancelled) {
      setState(() => _selectedPfp = result as String?);
    }
  }

  Future<void> _finish() async {
    setState(() => _isSaving = true);

    final userProvider = context.read<UserProvider>();
    final storage = context.read<SecureStorageService>();

    // ┌──────────────────────────────────────────────────────────────────┐
    // │ BACKEND TEAM: Sauvegarde du profil via PUT /user/me              │
    // │ Voir annotations detaillees dans data/settings_repository.dart.  │
    // │ [pfp] = null => mascotte | path local => upload requis.          │
    // │ Nouveaux champs: bio, wellnessGoal (support backend necessaire). │
    // └──────────────────────────────────────────────────────────────────┘
    await userProvider.updateProfile(
      firstName: _firstNameController.text.trim().isNotEmpty
          ? _firstNameController.text.trim()
          : null,
      lastName: _lastNameController.text.trim().isNotEmpty
          ? _lastNameController.text.trim()
          : null,
      age: int.tryParse(_ageController.text.trim()),
      pfp: _selectedPfp,
      bio: _bioController.text.trim().isNotEmpty
          ? _bioController.text.trim()
          : null,
      wellnessGoal: _selectedWellnessGoal,
    );

    await storage.setProfileSetupCompleted();

    if (!mounted) return;
    setState(() => _isSaving = false);

    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.home,
      (route) => false,
    );
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _finish();
    }
  }

  void _skipStep() {
    HapticFeedback.lightImpact();
    _nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: SafeArea(
        child: Column(
          children: [
            _buildProgressHeader(isDark),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.05, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _buildStepContent(isDark),
              ),
            ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  // ==================== Progress ====================

  Widget _buildProgressHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isActive = index <= _currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 28 : 8,
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: isActive
                  ? AppColors.primary
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : Colors.black.withValues(alpha: 0.1)),
            ),
          );
        }),
      ),
    );
  }

  // ==================== Steps ====================

  Widget _buildStepContent(bool isDark) {
    switch (_currentStep) {
      case 0:
        return _buildAvatarStep(isDark);
      case 1:
        return _buildIdentityStep(isDark);
      case 2:
        return _buildWelcomeStep(isDark);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---- Step 0 : Avatar ----

  Widget _buildAvatarStep(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
          vertical: AppDimensions.paddingMd,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar cliquable
            GestureDetector(
                  onTap: _openAvatarPicker,
                  child: Stack(
                    children: [
                      UserAvatar(pfp: _selectedPfp, size: 120),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.surfaceDark
                                  : Colors.white,
                              width: 2.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Choisis ton avatar',
              style: AppTextStyles.headlineSmall(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ).copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Une presence douce pour t\'accompagner. '
              'Tu pourras le changer quand tu veux, '
              'ou importer ta propre photo.',
              style: AppTextStyles.bodyMedium(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            LiquidGlassButton(
              label: 'Personnaliser mon avatar',
              icon: Icons.palette_rounded,
              style: LiquidGlassButtonStyle.tinted,
              isExpanded: true,
              onPressed: _openAvatarPicker,
            ),
          ],
        ),
      ),
    );
  }

  // ---- Step 1 : Identite + preferences ----

  Widget _buildIdentityStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingLg,
        vertical: AppDimensions.paddingMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.spa_rounded,
            size: 48,
            color: AppColors.primary,
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Dis-m\'en un peu plus',
            style: AppTextStyles.headlineSmall(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ).copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Tout est optionnel. Ces infos aident a personnaliser '
            'ton accompagnement.',
            style: AppTextStyles.bodyMedium(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          _buildLabel('Prenom', isDark),
          const SizedBox(height: AppDimensions.spacingXs),
          GlassAuthTextField(
            controller: _firstNameController,
            hint: 'Ton prenom',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          _buildLabel('Nom', isDark),
          const SizedBox(height: AppDimensions.spacingXs),
          GlassAuthTextField(
            controller: _lastNameController,
            hint: 'Optionnel',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          _buildLabel('Age', isDark),
          const SizedBox(height: AppDimensions.spacingXs),
          GlassAuthTextField(
            controller: _ageController,
            hint: 'Optionnel',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          _buildLabel('Ton objectif bien-etre', isDark),
          const SizedBox(height: AppDimensions.spacingXs),
          _GoalSelector(
            value: _selectedWellnessGoal,
            isDark: isDark,
            onChanged: (v) => setState(() => _selectedWellnessGoal = v),
          ),
        ],
      ),
    );
  }

  // ---- Step 2 : Bienvenue ----

  Widget _buildWelcomeStep(bool isDark) {
    return Center(
      key: const ValueKey(2),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingLg,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            UserAvatar(pfp: _selectedPfp, size: 120)
                .animate()
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              'Ton espace est pret',
              style: AppTextStyles.headlineMedium(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ).copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 500.ms, delay: 200.ms),
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              'Bienvenue dans ton cocon Elyrii. Prends ton temps, '
              'explore a ton rythme et n\'oublie pas : chaque petit pas '
              'compte vers ton bien-etre.',
              style: AppTextStyles.bodyMedium(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ).copyWith(height: 1.6),
              textAlign: TextAlign.center,
            ).animate().fadeIn(duration: 500.ms, delay: 350.ms),
          ],
        ),
      ),
    );
  }

  // ==================== Helpers ====================

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildFooter(bool isDark) {
    final isLastStep = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          LiquidGlassButton(
            label: isLastStep ? 'Commencer mon parcours' : 'Continuer',
            icon: isLastStep ? Icons.favorite_rounded : null,
            isLoading: _isSaving,
            isExpanded: true,
            onPressed: _isSaving ? null : _nextStep,
          ),
          if (!isLastStep) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            TextButton(
              onPressed: _isSaving ? null : _skipStep,
              child: Text(
                'Passer pour l\'instant',
                style: AppTextStyles.bodyMedium(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================== Goal Selector (chips) ====================

class _GoalSelector extends StatelessWidget {
  final String? value;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _GoalSelector({
    required this.value,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _wellnessGoals.map((goal) {
        final isSelected = value == goal;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(isSelected ? null : goal);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04)),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.08)),
              ),
            ),
            child: Text(
              goal,
              style: AppTextStyles.bodyMedium(
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ).copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        );
      }).toList(),
    );
  }

  static const List<String> _wellnessGoals = [
    'Gerer mon stress',
    'Ameliorer mon sommeil',
    'Cultiver ma mindfulness',
    'Developper ma confiance',
    'Prendre soin de moi',
    'Retrouver du calme',
  ];
}
