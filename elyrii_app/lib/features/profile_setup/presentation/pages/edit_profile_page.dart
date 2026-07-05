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
import '../../../../routes/app_routes.dart';
import '../../../auth/presentation/widgets/glass_auth_text_field.dart';
import '../../../settings/providers/settings_provider.dart';

/// Page d'edition du profil, accessible depuis Parametres > Profil.
///
/// Tous les champs sont optionnels sauf le prenom (demande a l'inscription).
/// L'avatar est modifiable en tapant dessus -> ouvre [AvatarPickerPage].
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _pronounsController = TextEditingController();

  String? _selectedPfp;
  String? _selectedGender;
  String? _selectedWellnessGoal;
  bool _isSaving = false;
  bool _initialized = false;

  static const List<String> _genderOptions = [
    'Feminin',
    'Masculin',
    'Non-binaire',
    'Je prefere ne pas le dire',
  ];

  static const List<String> _wellnessGoals = [
    'Gerer mon stress',
    'Ameliorer mon sommeil',
    'Cultiver ma mindfulness',
    'Developper ma confiance',
    'Prendre soin de moi',
    'Retrouver du calme',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _prefillFromProfile();
      _initialized = true;
    }
  }

  void _prefillFromProfile() {
    final profile = context.read<UserProvider>().profile;
    if (profile != null) {
      _firstNameController.text = profile.firstName ?? '';
      _lastNameController.text = profile.lastName ?? '';
      _ageController.text = profile.age != null ? profile.age.toString() : '';
      _bioController.text = profile.bio ?? '';
      _pronounsController.text = profile.pronouns ?? '';
      _selectedPfp = profile.pfp;
      _selectedGender = profile.gender;
      _selectedWellnessGoal = profile.wellnessGoal;
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _pronounsController.dispose();
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

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    final userProvider = context.read<UserProvider>();
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
      gender: _selectedGender,
      pronouns: _pronounsController.text.trim(),
      wellnessGoal: _selectedWellnessGoal,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profil mis a jour'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
    } else {
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: topPadding + 70)),

              // Avatar cliquable
              SliverToBoxAdapter(child: _buildAvatarSection(isDark)),

              // Identite
              SliverToBoxAdapter(child: _buildIdentitySection(isDark)),

              // Bien-etre
              SliverToBoxAdapter(child: _buildWellnessSection(isDark)),

              // Save
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
                  child: LiquidGlassButton(
                    label: 'Enregistrer',
                    icon: Icons.check_rounded,
                    isLoading: _isSaving,
                    isExpanded: true,
                    onPressed: _isSaving ? null : _saveProfile,
                  ),
                ),
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: topPadding + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                _BackButton(
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                ),
                Expanded(
                  child: Text(
                    'Mon profil',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 44),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Sections ====================

  Widget _buildAvatarSection(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        child: Column(
          children: [
            GestureDetector(
                  onTap: _openAvatarPicker,
                  child: Stack(
                    children: [
                      UserAvatar(pfp: _selectedPfp, size: 110),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 36,
                          height: 36,
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
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Toucher pour changer',
              style: AppTextStyles.bodySmall(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.5)
              : Colors.black.withValues(alpha: 0.4),
        ),
      ),
    );
  }

  Widget _buildIdentitySection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Identite', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Prenom *', isDark),
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
                _buildLabel('Pronoms', isDark),
                const SizedBox(height: AppDimensions.spacingXs),
                GlassAuthTextField(
                  controller: _pronounsController,
                  hint: 'ex: elle/iel, il/lui...',
                  prefixIcon: Icons.favorite_outline,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWellnessSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Bien-etre', isDark),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Quelques mots sur toi', isDark),
                const SizedBox(height: AppDimensions.spacingXs),
                _BioTextField(controller: _bioController, isDark: isDark),
                const SizedBox(height: AppDimensions.spacingMd),
                _buildLabel('Genre', isDark),
                const SizedBox(height: AppDimensions.spacingXs),
                _DropdownField(
                  value: _selectedGender,
                  hint: 'Optionnel',
                  icon: Icons.wc_rounded,
                  items: _genderOptions,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                _buildLabel('Ton objectif bien-etre', isDark),
                const SizedBox(height: AppDimensions.spacingXs),
                _DropdownField(
                  value: _selectedWellnessGoal,
                  hint: 'Qu\'est-ce qui t\'amene ici ?',
                  icon: Icons.spa_rounded,
                  items: _wellnessGoals,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _selectedWellnessGoal = v),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }
}

// ==================== Bio TextField (multiline) ====================

class _BioTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;

  const _BioTextField({required this.controller, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 200,
        textInputAction: TextInputAction.newline,
        style: AppTextStyles.bodyMedium(
          color: isDark ? Colors.white : Colors.black,
        ),
        decoration: InputDecoration(
          hintText: 'Raconte ce qui te rend unique...',
          hintStyle: AppTextStyles.bodyMedium(
            color: isDark
                ? Colors.white.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.4),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(AppDimensions.paddingLg),
          counterStyle: AppTextStyles.bodySmall(
            color: isDark
                ? Colors.white.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

// ==================== Dropdown Field ====================

class _DropdownField extends StatelessWidget {
  final String? value;
  final String hint;
  final IconData icon;
  final List<String> items;
  final bool isDark;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.value,
    required this.hint,
    required this.icon,
    required this.items,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: AppTextStyles.bodyMedium(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      item,
                      style: AppTextStyles.bodyMedium(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Back Button ====================

class _BackButton extends StatefulWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _BackButton({required this.isDark, required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: widget.isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
    );
  }
}
