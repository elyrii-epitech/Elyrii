import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../widgets/arrival_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _welcome = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading || !_form.currentState!.validate()) return;
    setState(() => _error = null);
    final success = await auth.login(
      email: _email.text.trim(),
      password: _password.text,
    );
    if (!mounted) return;
    if (success) {
      context.go(AppRoutes.home);
    } else {
      setState(
        () => _error = auth.error ?? 'La connexion n’a pas abouti. Réessaie.',
      );
    }
  }

  Future<void> _demo() async {
    final auth = context.read<AuthProvider>();
    if (auth.isLoading) return;
    await auth.startDemoSession();
    if (!mounted) return;
    context.read<ValueNotifier<bool>>().value = false;
    context.go(AppRoutes.profileSetup);
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AuthProvider>().isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (_welcome) {
      return Scaffold(
        backgroundColor: dark
            ? AppColors.scaffoldDark
            : AppColors.scaffoldLight,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                const ArrivalScene(launch: true),
                Positioned.fill(
                  child: Semantics(
                    button: true,
                    label: 'Entrer dans Elyrii',
                    child: InkWell(
                      onTap: () => setState(() => _welcome = false),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ArrivalFrame(
      title: 'Connexion',
      bubble: 'Content de te revoir.',
      onBack: () => setState(() => _welcome = true),
      onInfo: () => showArrivalInfo(
        context,
        'Un compte, ou juste un premier pas',
        'Ton compte te permet de retrouver ton espace. Tu peux aussi découvrir Elyrii sans compte et décider plus tard.',
      ),
      child: AutofillGroup(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Ton espace t’attend',
                style: AppTextStyles.titleLarge(color: context.textPrimary),
              ),
              const SizedBox(height: AppDimensions.spacing20),
              ArrivalField(
                controller: _email,
                label: 'Email',
                icon: Icons.mail_outline_rounded,
                enabled: !busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
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
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                validator: (value) => value == null || value.isEmpty
                    ? 'Entre ton mot de passe.'
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy
                      ? null
                      : () => context.push(AppRoutes.passwordReset),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              ArrivalFeedback(_error),
              ArrivalButton(
                label: 'Se connecter',
                busy: busy,
                onPressed: _login,
              ),
              const SizedBox(height: AppDimensions.spacing12),
              ArrivalButton(
                label: 'Découvrir sans compte',
                secondary: true,
                onPressed: busy ? null : _demo,
                icon: Icons.arrow_forward_rounded,
              ),
              const SizedBox(height: AppDimensions.spacing16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Pas encore de compte ?',
                    style: AppTextStyles.bodySmall(
                      color: context.textSecondary,
                    ),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => context.push(AppRoutes.register),
                    child: const Text('Créer un compte'),
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
