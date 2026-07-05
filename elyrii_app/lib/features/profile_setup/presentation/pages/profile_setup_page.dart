import 'dart:ui';

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
import '../../../../core/services/glass_performance_service.dart';
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
    final previousPfp = userProvider.profile?.pfp;
    final clearPfp = _selectedPfp == null && previousPfp != null;

    final success = await userProvider.updateProfile(
      firstName: _firstNameController.text.trim().isNotEmpty
          ? _firstNameController.text.trim()
          : null,
      lastName: _lastNameController.text.trim().isNotEmpty
          ? _lastNameController.text.trim()
          : null,
      age: int.tryParse(_ageController.text.trim()),
      pfp: _selectedPfp,
      clearPfp: clearPfp,
      bio: _bioController.text.trim(),
      wellnessGoal: _selectedWellnessGoal,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userProvider.error ?? 'Une erreur est survenue'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final navigator = Navigator.of(context);
    await storage.setProfileSetupCompleted();

    navigator.pushNamedAndRemoveUntil(
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

  void _previousStep() {
    if (_currentStep == 0 || _isSaving) return;
    HapticFeedback.lightImpact();
    setState(() => _currentStep--);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _currentStep == 0 && !_isSaving,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || _currentStep == 0 || _isSaving) return;
        _previousStep();
      },
      child: Scaffold(
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
      ),
    );
  }

  // ==================== Progress ====================

  Widget _buildProgressHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_currentStep > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: LiquidGlassIconButton(
                  icon: Icons.arrow_back_rounded,
                  size: 40,
                  onPressed: _isSaving ? null : _previousStep,
                  color: isDark
                      ? Colors.white
                      : AppColors.textPrimaryLight.withValues(alpha: 0.82),
                ),
              ),
            Row(
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
          ],
        ),
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
          _ProfileSetupGlassButton(
            label: isLastStep ? 'Commencer mon parcours' : 'Continuer',
            icon: isLastStep ? Icons.favorite_rounded : null,
            isLoading: _isSaving,
            isExpanded: true,
            isPrimary: true,
            onPressed: _isSaving ? null : _nextStep,
          ),
          if (!isLastStep) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            _ProfileSetupGlassButton(
              label: 'Passer pour l\'instant',
              onPressed: _isSaving ? null : _skipStep,
              isExpanded: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileSetupGlassButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isExpanded;
  final bool isLoading;
  final bool isPrimary;

  const _ProfileSetupGlassButton({
    required this.label,
    this.onPressed,
    this.icon,
    this.isExpanded = false,
    this.isLoading = false,
    this.isPrimary = false,
  });

  @override
  State<_ProfileSetupGlassButton> createState() =>
      _ProfileSetupGlassButtonState();
}

class _ProfileSetupGlassButtonState extends State<_ProfileSetupGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final blurSigma = GlassPerformanceService().getEffectiveBlurSigma(
      AppDimensions.blurSigmaLiquidGlass,
    );
    final radius = BorderRadius.circular(AppDimensions.radiusLiquidGlassButton);
    const primary = AppColors.primary;
    final textColor = widget.isPrimary
        ? (isDark ? Colors.white : primary.withValues(alpha: 0.92))
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final button = Container(
      width: widget.isExpanded ? double.infinity : null,
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: widget.isPrimary
              ? [
                  primary.withValues(alpha: isDark ? 0.30 : 0.18),
                  Colors.white.withValues(alpha: isDark ? 0.08 : 0.58),
                  primary.withValues(alpha: isDark ? 0.18 : 0.10),
                ]
              : [
                  Colors.white.withValues(alpha: isDark ? 0.10 : 0.50),
                  Colors.white.withValues(alpha: isDark ? 0.05 : 0.26),
                ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.18 : 0.42),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: isDark ? 0.04 : 0.35),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(child: _buildContent(textColor)),
    );

    return Semantics(
      button: true,
      enabled: !isDisabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: isDisabled ? null : (_) => setState(() => _isPressed = true),
        onTapUp: isDisabled ? null : (_) => setState(() => _isPressed = false),
        onTapCancel: isDisabled
            ? null
            : () => setState(() => _isPressed = false),
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : 1,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: isDisabled ? 0.55 : (_isPressed ? 0.78 : 1),
            child: RepaintBoundary(
              child: ClipRRect(
                borderRadius: radius,
                child: blurSigma > 0
                    ? BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: button,
                      )
                    : button,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(Color textColor) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation(textColor),
        ),
      );
    }

    return Row(
      mainAxisSize: widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 20, color: textColor),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: AppTextStyles.bodyLarge(
            color: textColor,
          ).copyWith(fontWeight: FontWeight.w700),
        ),
      ],
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
