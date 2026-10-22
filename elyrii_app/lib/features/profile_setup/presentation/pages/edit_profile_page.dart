import '../../../../core/accessibility/motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;

import '../../../../core/constants/profile_option_labels.dart';
import '../../../../core/widgets/elyrii_page_header.dart';

import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/accessible_action.dart';
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
    final provider = context.watch<UserProvider>();
    if (!_initialized && provider.profile != null) {
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
            borderRadius: BorderRadius.circular(AppDimensions.radius12),
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
            borderRadius: BorderRadius.circular(AppDimensions.radius12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ElyriiPageFrame.detail(
        title: 'Mon profil',
        leading: const ElyriiBackButton(),
        slivers: !_initialized
            ? [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (context.watch<UserProvider>().error == null)
                          const CupertinoActivityIndicator()
                        else ...[
                          Text(context.watch<UserProvider>().error!),
                          TextButton(
                            onPressed: context.read<UserProvider>().loadProfile,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ]
            : [
                SliverToBoxAdapter(child: _buildAvatarSection(isDark)),

                SliverToBoxAdapter(child: _buildIdentitySection()),

                SliverToBoxAdapter(child: _buildWellnessSection(isDark)),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.pageHorizontalPadding,
                      AppDimensions.spacing24,
                      AppDimensions.pageHorizontalPadding,
                      0,
                    ),
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
    );
  }
  // ==================== Sections ====================

  Widget _buildAvatarSection(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppDimensions.spacing8,
          bottom: AppDimensions.spacing24,
        ),
        child: Column(
          children: [
            AccessibleAction(
                  label: 'Modifier mon avatar',
                  onPressed: _openAvatarPicker,
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
                .animateRespectingMotion(context)
                .fadeIn(duration: 400.ms)
                .scale(
                  begin: const Offset(0.85, 0.85),
                  end: const Offset(1, 1),
                ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              'Touche pour changer',
              style: AppTextStyles.bodySmall(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing16,
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing8,
      ),
      child: Text(
        title,
        style: AppTextStyles.overline(color: context.textSecondary),
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Identite'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
          ),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Prénom *'),
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
                _buildLabel('Pronoms'),
                const SizedBox(height: AppDimensions.spacing8),
                GlassAuthTextField(
                  controller: _pronounsController,
                  label: 'Pronoms (optionnels)',
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
        _buildSectionHeader('Bien-etre'),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.pageHorizontalPadding,
          ),
          child: LiquidGlassCard(
            padding: const EdgeInsets.all(AppDimensions.spacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLabel('Quelques mots sur toi'),
                const SizedBox(height: AppDimensions.spacing8),
                _BioTextField(controller: _bioController, isDark: isDark),
                const SizedBox(height: AppDimensions.spacing16),
                _buildLabel('Genre'),
                const SizedBox(height: AppDimensions.spacing8),
                _DropdownField(
                  value: _selectedGender,
                  hint: 'Optionnel',
                  icon: Icons.wc_rounded,
                  items: _genderOptions,
                  isDark: isDark,
                  onChanged: (v) => setState(() => _selectedGender = v),
                ),
                const SizedBox(height: AppDimensions.spacing16),
                _buildLabel('Ton objectif bien-être'),
                const SizedBox(height: AppDimensions.spacing8),
                _DropdownField(
                  value: _selectedWellnessGoal,
                  hint: 'Qu\'est-ce qui t\'amène ici ?',
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

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMedium(color: context.textPrimary),
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
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(AppDimensions.radius16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        maxLength: 200,
        textInputAction: TextInputAction.newline,
        style: AppTextStyles.bodyMedium(color: context.textPrimary),
        decoration: InputDecoration(
          // Fond du conteneur = surface ; neutralise le blanc opaque
          // du thème global qui dessine des rectangles hors carte.
          filled: true,
          fillColor: Colors.transparent,
          hintText: 'Raconte ce qui te rend unique...',
          hintStyle: AppTextStyles.bodyMedium(color: context.textTertiary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing16,
            vertical: AppDimensions.spacing16,
          ),
          counterStyle: AppTextStyles.bodySmall(color: context.textTertiary),
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
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacing16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(AppDimensions.radius16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: AppDimensions.spacing12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                hint: Text(
                  hint,
                  style: AppTextStyles.bodyMedium(color: context.textTertiary),
                ),
                isExpanded: true,
                items: items.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text(
                      profileOptionLabel(item),
                      style: AppTextStyles.bodyMedium(
                        color: context.textPrimary,
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
