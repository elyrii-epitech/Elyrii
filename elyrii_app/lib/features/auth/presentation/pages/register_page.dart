import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/content/account_information.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/app_routes.dart';
import '../../../settings/providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/arrival_widgets.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _consent = false;
  String? _message;
  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;
    final valid = _form.currentState!.validate();
    if (!_consent) {
      setState(
        () => _message = 'Lis les informations sur Elyrii et tes données avant de créer ton compte.',
      );
    }
    if (!valid || !_consent) return;
    setState(() => _message = null);
    final user = context.read<UserProvider>();
    final name = _name.text.trim();
    final success = await auth.register(
      firstName: name,
      lastName: name,
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      await user.loadProfile();
      if (mounted) context.go(AppRoutes.profileSetup);
      return;
    }
    final error =
        auth.error ?? 'La création du compte n’a pas abouti. Réessaie.';
    final normalized = error.toLowerCase();
    if (normalized.contains('verification required') ||
        normalized.contains('activate your account')) {
      await showArrivalInfo(
        context,
        'Vérifie ton email',
        'Ouvre l’email de confirmation pour activer ton compte, puis connecte-toi.',
      );
      if (mounted) context.go(AppRoutes.login);
    } else {
      setState(() => _message = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final password = _password.text;
    final strength =
        (password.length >= 8 ? 1 : 0) +
        (RegExp(r'[A-Z]').hasMatch(password) ? 1 : 0) +
        (RegExp(r'[0-9]').hasMatch(password) ? 1 : 0);
    return ArrivalFrame(
      title: 'Créer un compte',
      bubble: 'Inscris-toi avec ton email.',
      onBack: () => context.go(AppRoutes.login),
      onInfo: () => showArrivalInfo(
        context,
        'Avec ou sans compte',
        'Connecte-toi ou essaie la démo sans créer de compte.',
      ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ArrivalField(
                controller: _name,
                label: 'Prénom',
                icon: Icons.person_outline_rounded,
                enabled: !busy,
                autofillHints: const [AutofillHints.givenName],
                validator: (value) => (value?.trim().isEmpty ?? true)
                    ? 'Comment peut-on t’appeler ?'
                    : null,
              ),
              const SizedBox(height: AppDimensions.spacing12),
              ArrivalField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                enabled: !busy,
                autofillHints: const [AutofillHints.email],
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    Validators.isValidEmail(value?.trim() ?? '')
                    ? null
                    : 'Entre une adresse email valide.',
              ),
              const SizedBox(height: AppDimensions.spacing12),
              ArrivalField(
                controller: _password,
                label: 'Mot de passe',
                icon: Icons.lock_outline_rounded,
                password: true,
                enabled: !busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _register(),
                validator: (value) {
                  if ((value?.length ?? 0) < 8) {
                    return 'Utilise au moins 8 caractères.';
                  }
                  if (!RegExp(r'[A-Z]').hasMatch(value!)) {
                    return 'Ajoute une majuscule.';
                  }
                  if (!RegExp(r'[0-9]').hasMatch(value)) {
                    return 'Ajoute au moins un chiffre.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Row(
                children: [
                  for (var i = 0; i < 3; i++)
                    Expanded(
                      child: Container(
                        height: AppDimensions.arrivalProgressHeight,
                        margin: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing2,
                        ),
                        decoration: BoxDecoration(
                          color: i < strength
                              ? (dark
                                    ? AppColors.primaryDark
                                    : AppColors.primary)
                              : AppColors.track(dark),
                          borderRadius: BorderRadius.circular(
                            AppDimensions.radius4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacing8),
              Text(
                strength == 3
                    ? 'Les trois règles du mot de passe sont respectées.'
                    : 'Au moins 8 caractères, une majuscule et un chiffre.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
              const SizedBox(height: AppDimensions.spacing12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consent,
                    shape: const CircleBorder(),
                    semanticLabel: 'Confirmer la lecture des informations sur Elyrii et les données',
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _consent = value ?? false),
                  ),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'J’ai lu les ',
                          style: AppTextStyles.bodySmall(
                            color: context.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => showArrivalInfo(
                            context,
                            AccountInformation.serviceTitle,
                            AccountInformation.service,
                          ),
                          child: const Text('informations sur Elyrii'),
                        ),
                        Text(
                          'et les ',
                          style: AppTextStyles.bodySmall(
                            color: context.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => showArrivalInfo(
                            context,
                            AccountInformation.dataTitle,
                            AccountInformation.data,
                          ),
                          child: const Text('informations sur mes données'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              ArrivalFeedback(_message),
              ArrivalButton(
                label: 'Créer mon compte',
                busy: busy,
                onPressed: _register,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Déjà un compte ?',
                    style: AppTextStyles.bodySmall(
                      color: context.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: busy ? null : () => context.go(AppRoutes.login),
                    child: const Text('Se connecter'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
