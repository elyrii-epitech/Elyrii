import '../../../../core/accessibility/motion.dart';

import 'package:flutter/cupertino.dart'
    show CupertinoAlertDialog, CupertinoDialogAction, showCupertinoDialog;
import 'package:flutter/material.dart';

import '../../../../core/constants/profile_option_labels.dart';

import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/constants/avatar_options.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../routes/app_routes.dart';
import '../../../auth/presentation/widgets/glass_auth_text_field.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/config/mascot_animations.dart';
import '../widgets/mascot_avatar_preview.dart';

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
  /// Navigation paginée fluide entre les trois étapes (swipe + boutons).
  final PageController _pageController = PageController();
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
    _pageController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _openAvatarPicker() async {
    final result = await context.push(
      AppRoutes.avatarPicker,
      extra: _selectedPfp,
    );
    if (!mounted) return;
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
      // Erreur bloquante : dialogue natif iOS plutôt que SnackBar Android.
      showCupertinoDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => CupertinoAlertDialog(
          title: const Text('Enregistrement impossible'),
          content: Text(userProvider.error ?? 'Une erreur est survenue'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    await storage.setProfileSetupCompleted();

    if (!mounted) return;
    // Notifier le routeur que l'onboarding est terminé (levée du guard).
    context.read<ValueNotifier<bool>>().value = true;
    context.go(AppRoutes.home);
  }

  void _nextStep() {
    ElyriiHaptics.light();
    if (_currentStep < 2) {
      // Transition paginée douce (même courbe que le geste de swipe).
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finish();
    }
  }

  void _skipStep() {
    ElyriiHaptics.light();
    _nextStep();
  }

  void _previousStep() {
    if (_currentStep == 0 || _isSaving) return;
    ElyriiHaptics.light();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
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
                // Navigation paginée iOS : swipe horizontal entre les étapes,
                // transitions glissées douces pilotées par le même contrôleur
                // que les boutons Continuer / retour.
                child: PageView(
                  controller: _pageController,
                  physics: _isSaving
                      ? const NeverScrollableScrollPhysics()
                      : const PageScrollPhysics(),
                  onPageChanged: (page) => setState(() => _currentStep = page),
                  children: [
                    _buildAvatarStep(isDark),
                    _buildIdentityStep(),
                    _buildWelcomeStep(isDark),
                  ],
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Progress ====================

  Widget _buildProgressHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing20,
        AppDimensions.spacing16,
        AppDimensions.spacing20,
        AppDimensions.spacing8,
      ),
      child: SizedBox(
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_currentStep > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: ElyriiBackButton(
                  onPressed: _isSaving ? null : _previousStep,
                  color: context.textPrimary.withValues(
                    alpha: isDark ? 1 : 0.82,
                  ),
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                final isActive = index <= _currentStep;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacing4,
                  ),
                  width: isActive ? 28 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radius4),
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

  // ---- Step 0 : Avatar ----

  Widget _buildAvatarStep(bool isDark) {
    return Center(
      child: SingleChildScrollView(
        key: const ValueKey(0),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing24,
          vertical: AppDimensions.spacing16,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aperçu cliquable : mascotte 3D fidèle avec ombre de contact
            // par défaut, avatar choisi (image) sinon.
            AccessibleAction(
                  label: 'Personnaliser mon avatar',
                  onPressed: _openAvatarPicker,
                  child: isMascotAvatar(_selectedPfp)
                      ? MascotAvatarPreview(
                          width: 220,
                          height: 220,
                          isDark: isDark,
                          animation: MascotAnimations.curious,
                        )
                      : Stack(
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
                .animateRespectingMotion(context)
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            const SizedBox(height: AppDimensions.spacing24),
            Text(
              'Choisis ton avatar',
              style: AppTextStyles.headlineSmall(color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              'Une presence douce pour t\'accompagner. '
              'Tu pourras le changer quand tu veux, '
              'ou importer ta propre photo.',
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacing24),
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

  Widget _buildIdentityStep() {
    return SingleChildScrollView(
      key: const ValueKey(1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing24,
        vertical: AppDimensions.spacing16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.spa_rounded,
            size: 48,
            color: AppColors.primary,
          ).animateRespectingMotion(context).fadeIn(duration: 400.ms),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
            'Dis-m\'en un peu plus',
            style: AppTextStyles.headlineSmall(color: context.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing12),
          Text(
            'Tout est optionnel. Ces infos aident a personnaliser '
            'ton accompagnement.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacing32),

          _buildLabel('Prénom'),
          const SizedBox(height: AppDimensions.spacing8),
          GlassAuthTextField(
            controller: _firstNameController,
            label: 'Prénom',
            autofillHints: const [AutofillHints.givenName],
            hint: 'Ton prenom',
            prefixIcon: Icons.person_outline,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildLabel('Nom'),
          const SizedBox(height: AppDimensions.spacing8),
          GlassAuthTextField(
            controller: _lastNameController,
            label: 'Nom (optionnel)',
            autofillHints: const [AutofillHints.familyName],
            hint: 'Optionnel',
            prefixIcon: Icons.badge_outlined,
            keyboardType: TextInputType.name,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildLabel('Age'),
          const SizedBox(height: AppDimensions.spacing8),
          GlassAuthTextField(
            controller: _ageController,
            label: 'Âge (optionnel)',
            hint: 'Optionnel',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppDimensions.spacing16),

          _buildLabel('Ton objectif bien-être'),
          const SizedBox(height: AppDimensions.spacing8),
          _GoalSelector(
            value: _selectedWellnessGoal,
            onChanged: (v) => setState(() => _selectedWellnessGoal = v),
          ),
        ],
      ),
    );
  }

  // ---- Step 2 : Bienvenue ----

  Widget _buildWelcomeStep(bool isDark) {
    return SingleChildScrollView(
      key: const ValueKey(2),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacing24,
        vertical: AppDimensions.spacing16,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // La mascotte accueille l'utilisateur en 3D (salut bienveillant)
          // ou montre l'avatar choisi s'il s'agit d'une image.
          if (isMascotAvatar(_selectedPfp))
            MascotAvatarPreview(
                  width: 220,
                  height: 220,
                  isDark: isDark,
                  animation: MascotAnimations.greet,
                )
                .animateRespectingMotion(context)
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                )
          else
            UserAvatar(pfp: _selectedPfp, size: 120)
                .animateRespectingMotion(context)
                .fadeIn(duration: 500.ms)
                .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
          const SizedBox(height: AppDimensions.spacing32),
          Text(
                'Ton espace est prêt',
                style: AppTextStyles.headlineMedium(color: context.textPrimary),
                textAlign: TextAlign.center,
              )
              .animateRespectingMotion(context)
              .fadeIn(duration: 500.ms, delay: 200.ms),
          const SizedBox(height: AppDimensions.spacing16),
          Text(
                'Bienvenue dans ton cocon Elyrii. Prends ton temps, '
                'explore à ton rythme et n\'oublie pas : chaque petit pas '
                'compte vers ton bien-être.',
                style: AppTextStyles.bodyMedium(color: context.textSecondary),
                textAlign: TextAlign.center,
              )
              .animateRespectingMotion(context)
              .fadeIn(duration: 500.ms, delay: 350.ms),
        ],
      ),
    );
  }

  // ==================== Helpers ====================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium(color: context.textPrimary),
    );
  }

  Widget _buildFooter() {
    final isLastStep = _currentStep == 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacing12,
        AppDimensions.spacing8,
        AppDimensions.spacing12,
        AppDimensions.spacing16,
      ),
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
            const SizedBox(height: AppDimensions.spacing12),
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
  @override
  Widget build(BuildContext context) => LiquidGlassButton(
    label: widget.label,
    onPressed: widget.onPressed,
    icon: widget.icon,
    isExpanded: widget.isExpanded,
    isLoading: widget.isLoading,
    style: widget.isPrimary
        ? LiquidGlassButtonStyle.filled
        : LiquidGlassButtonStyle.gray,
  );
}

// ==================== Goal Selector (chips) ====================

class _GoalSelector extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const _GoalSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppDimensions.spacing8,
      runSpacing: AppDimensions.spacing8,
      children: _wellnessGoals.map((goal) {
        final isSelected = value == goal;
        return ChoiceChip(
          label: Text(profileOptionLabel(goal)),
          selected: isSelected,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          onSelected: (selected) {
            ElyriiHaptics.selection();
            onChanged(selected ? goal : null);
          },
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
