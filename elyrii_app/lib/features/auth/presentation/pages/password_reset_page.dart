import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/validators.dart';
import '../../../../routes/app_routes.dart';
import '../widgets/arrival_widgets.dart';

enum _ResetStep { request, confirm, done }

class PasswordResetPage extends StatefulWidget {
  const PasswordResetPage({super.key});
  @override
  State<PasswordResetPage> createState() => _PasswordResetPageState();
}

class _PasswordResetPageState extends State<PasswordResetPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  _ResetStep _step = _ResetStep.request;
  bool _busy = false;
  String? _error;
  String? _status;
  @override
  void dispose() {
    for (final field in [_email, _code, _password, _confirmation]) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final api = context.read<ApiClient>();
      if (_step == _ResetStep.confirm) {
        await api.post(
          '${ApiConfig.baseUrl}/auth/password-reset/confirm',
          auth: false,
          body: {'code': _code.text.trim(), 'password': _password.text},
        );
        if (!mounted) return;
        _password.clear();
        _confirmation.clear();
        _code.clear();
        if (mounted) {
          setState(() {
            _step = _ResetStep.done;
            _status = 'Mot de passe modifié. Tu peux te reconnecter.';
          });
        }
      } else {
        await api.post(
          '${ApiConfig.baseUrl}/auth/password-reset/request',
          auth: false,
          body: {'email': _email.text.trim()},
        );
        if (mounted) {
          setState(() {
            _step = _ResetStep.confirm;
            _status = 'Si ce compte existe, un code a été envoyé. Il expire après 15 minutes.';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is ApiException
              ? error.message
              : 'Impossible de terminer la récupération. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ArrivalFrame(
    title: 'Réinitialiser le mot de passe',
    scene: false,
    onBack: () => context.go(AppRoutes.login),
    onInfo: () => showArrivalInfo(
      context,
      'Réinitialiser le mot de passe',
      'Utilise le code reçu par email pour choisir un nouveau mot de passe. Il expire après 15 minutes.',
    ),
    child: AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Image.asset(
                'assets/splash_icon.png',
                width: AppDimensions.profileEditAvatar,
                height: AppDimensions.profileEditAvatar,
              ),
            ),
            const SizedBox(height: AppDimensions.spacing24),
            Text(
              _step == _ResetStep.confirm
                  ? 'Nouveau mot de passe'
                  : 'Mot de passe oublié ?',
              textAlign: TextAlign.center,
              style: AppTextStyles.titleLarge(color: context.textPrimary),
            ),
            const SizedBox(height: AppDimensions.spacing12),
            Text(
              _step == _ResetStep.confirm
                  ? 'Colle le code reçu par email, puis choisis ton nouveau mot de passe.'
                  : 'Entre ton email pour recevoir un code de réinitialisation.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
            ),
            const SizedBox(height: AppDimensions.spacing24),
            ArrivalFeedback(_status),
            ArrivalFeedback(_error),
            if (_step == _ResetStep.request)
              ArrivalField(
                controller: _email,
                label: 'Email du compte',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                enabled: !_busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) =>
                    Validators.isValidEmail(value?.trim() ?? '')
                    ? null
                    : 'Entre une adresse email valide.',
              ),
            if (_step == _ResetStep.confirm) ...[
              ArrivalField(
                controller: _code,
                label: 'Code reçu par email',
                icon: Icons.key_rounded,
                enabled: !_busy,
                validator: (value) =>
                    RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Colle le code complet reçu par email.',
              ),
              const SizedBox(height: AppDimensions.spacing12),
              ArrivalField(
                controller: _password,
                label: 'Nouveau mot de passe',
                icon: Icons.lock_outline_rounded,
                helperText: 'Entre 12 et 128 caractères. Une phrase longue est bienvenue.',
                password: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) =>
                    (value?.length ?? 0) >= 12 && (value?.length ?? 0) <= 128
                    ? null
                    : 'Le mot de passe doit contenir entre 12 et 128 caractères.',
              ),
              const SizedBox(height: AppDimensions.spacing12),
              ArrivalField(
                controller: _confirmation,
                label: 'Confirmer le nouveau mot de passe',
                icon: Icons.lock_outline_rounded,
                password: true,
                enabled: !_busy,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (value) => value == _password.text
                    ? null
                    : 'Les mots de passe doivent être identiques.',
              ),
            ],
            const SizedBox(height: AppDimensions.spacing12),
            if (_step != _ResetStep.done) ...[
              ArrivalButton(
                label: _step == _ResetStep.confirm
                    ? 'Modifier mon mot de passe'
                    : 'Recevoir le code',
                busy: _busy,
                onPressed: _submit,
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _step = _step == _ResetStep.confirm
                            ? _ResetStep.request
                            : _ResetStep.confirm;
                        _form.currentState?.reset();
                        _error = null;
                        _status = null;
                      }),
                child: Text(
                  _step == _ResetStep.confirm
                      ? 'Demander un nouveau code'
                      : 'J’ai déjà un code',
                ),
              ),
            ] else
              ArrivalButton(
                label: 'Retour à la connexion',
                onPressed: () => context.go(AppRoutes.login),
              ),
          ],
        ),
      ),
    ),
  );
}
