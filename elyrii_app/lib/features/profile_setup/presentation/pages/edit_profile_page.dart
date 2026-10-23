import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/avatar_options.dart';
import '../../../../core/constants/profile_option_labels.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/pushed_page.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../routes/app_routes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../widgets/profile_controls.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _form = GlobalKey<FormState>();
  final _firstFocus = FocusNode();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _age = TextEditingController();
  final _pronouns = TextEditingController();
  final _bio = TextEditingController();
  bool _initialized = false;
  bool _saving = false;
  String? _pfp;
  String? _gender;
  String? _goal;
  static const _genders = [
    'Homme',
    'Femme',
    'Non binaire',
    'Autre',
    'Je préfère ne pas le dire',
  ];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final profile = context.watch<UserProvider>().profile;
    if (_initialized || profile == null) return;
    _firstName.text = profile.firstName ?? '';
    _lastName.text = profile.lastName ?? '';
    _age.text = profile.age?.toString() ?? '';
    _pronouns.text = profile.pronouns ?? '';
    _bio.text = profile.bio ?? '';
    _pfp = profile.pfp;
    _goal = profile.wellnessGoal;
    _gender = switch (profile.gender) {
      'Feminin' => 'Femme',
      'Masculin' => 'Homme',
      'Non-binaire' => 'Non binaire',
      'Je prefere ne pas le dire' => 'Je préfère ne pas le dire',
      final value => value,
    };
    _initialized = true;
  }

  @override
  void dispose() {
    _firstFocus.dispose();
    for (final controller in [_firstName, _lastName, _age, _pronouns, _bio]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _avatar() async {
    final result = await context.push<String>(
      AppRoutes.avatarPicker,
      extra: _pfp,
    );
    if (mounted && result != kAvatarPickerCancelled) {
      setState(() => _pfp = result);
    }
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty) {
      _firstFocus.requestFocus();
      profileToast(context, 'Ajoute ton prénom pour enregistrer.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final user = context.read<UserProvider>();
    final success = await user.updateProfile(
      firstName: _firstName.text.trim(),
      lastName: _lastName.text.trim().isEmpty ? null : _lastName.text.trim(),
      age: int.tryParse(_age.text),
      pfp: _pfp,
      clearPfp: _pfp == null && user.profile?.pfp != null,
      bio: _bio.text.trim(),
      gender: _gender,
      pronouns: _pronouns.text.trim(),
      wellnessGoal: _goal,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    profileToast(
      context,
      success ? 'Profil enregistré.' : user.error ?? 'Une erreur est survenue',
    );
    if (success) context.pop();
  }

  static const _inputDecoration = InputDecoration(
    hintText: 'Facultatif',
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.symmetric(vertical: AppDimensions.spacing12),
    isDense: true,
    counterText: '',
  );
  Widget _field(
    String label,
    TextEditingController controller, {
    FocusNode? focus,
    bool numeric = false,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppDimensions.spacing16,
      vertical: AppDimensions.spacing8,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: AppDimensions.profileFieldLabel,
          child: Padding(
            padding: const EdgeInsets.only(top: AppDimensions.spacing12),
            child: ExcludeSemantics(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium(color: context.textPrimary),
              ),
            ),
          ),
        ),
        Expanded(
          child: Semantics(
            label: label.replaceAll(' *', ''),
            child: TextFormField(
              controller: controller,
              focusNode: focus,
              textAlign: TextAlign.right,
              maxLength: maxLength,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              inputFormatters: numeric
                  ? [FilteringTextInputFormatter.digitsOnly]
                  : null,
              style: AppTextStyles.bodyMedium(color: context.textPrimary),
              decoration: _inputDecoration,
              validator: numeric
                  ? (text) {
                      if (text == null || text.isEmpty) return null;
                      final age = int.tryParse(text);
                      return age == null || age < 1 || age > 120
                          ? 'Entre 1 et 120 ans.'
                          : null;
                    }
                  : null,
            ),
          ),
        ),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return PushedPage(
      title: 'Mon profil',
      trailing: _saving
          ? const CupertinoActivityIndicator()
          : TextButton(
              onPressed: _initialized ? _save : null,
              child: Text(
                'Enregistrer',
                style: AppTextStyles.pillLabel(
                  color: AppColors.primaryText(dark),
                ),
              ),
            ),
      children: [
        if (!_initialized)
          Center(
            child: user.error == null
                ? const CupertinoActivityIndicator()
                : Column(
                    children: [
                      Text(user.error!),
                      TextButton(
                        onPressed: user.loadProfile,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
          )
        else
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Changer mon avatar',
                      onPressed: _avatar,
                      icon: UserAvatar(
                        pfp: _pfp,
                        size: AppDimensions.profileEditAvatar,
                        showBorder: false,
                      ),
                    ),
                    TextButton(
                      onPressed: _avatar,
                      child: const Text("Changer l'avatar"),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacing20),
                ProfileSection(
                  title: 'Identité',
                  footer: 'À part ton prénom, tout est facultatif.',
                  child: ProfileCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _field(
                          'Prénom *',
                          _firstName,
                          focus: _firstFocus,
                          maxLength: 40,
                        ),
                        const Divider(height: AppDimensions.profileHairline),
                        _field('Nom', _lastName),
                        const Divider(height: AppDimensions.profileHairline),
                        _field('Âge', _age, numeric: true),
                        const Divider(height: AppDimensions.profileHairline),
                        _field('Pronoms', _pronouns, maxLength: 80),
                        const Divider(height: AppDimensions.profileHairline),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing16,
                            vertical: AppDimensions.spacing8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: AppDimensions.profileFieldLabel,
                                child: ExcludeSemantics(
                                  child: Text(
                                    'Genre',
                                    style: AppTextStyles.bodyMedium(
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Semantics(
                                  label: 'Genre',
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _gender,
                                    isExpanded: true,
                                    decoration: _inputDecoration,
                                    style: AppTextStyles.bodyMedium(
                                      color: context.textSecondary,
                                    ),
                                    items: [
                                      const DropdownMenuItem<String>(
                                        value: null,
                                        child: Text('Non renseigné'),
                                      ),
                                      for (final value in {
                                        ..._genders,
                                        ?_gender,
                                      })
                                        DropdownMenuItem(
                                          value: value,
                                          child: Text(value),
                                        ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => _gender = value),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ProfileCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Quelques mots sur toi',
                        style: AppTextStyles.titleSmall(
                          color: context.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacing8),
                      TextFormField(
                        controller: _bio,
                        maxLength: 200,
                        minLines: 3,
                        maxLines: 5,
                        style: AppTextStyles.bodyMedium(
                          color: context.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          filled: false,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          hintText: 'Quelques mots sur toi',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacing20),
                ProfileGroup(
                  children: [
                    ProfileRow(
                      title: 'Objectif bien-être',
                      icon: Icons.favorite_rounded,
                      color: AppColors.pink(dark),
                      value: _goal == null ? null : profileOptionLabel(_goal!),
                      onTap: () async {
                        final goal = await chooseWellnessGoal(context, _goal);
                        if (mounted && goal != null) {
                          setState(() => _goal = goal);
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
