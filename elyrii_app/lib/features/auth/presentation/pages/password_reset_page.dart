import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../widgets/glass_auth_text_field.dart';
import '../widgets/auth_error_banner.dart';

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
  bool _codeStep = false;
  bool _busy = false;
  bool _done = false;
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
      if (_codeStep) {
        await api.post(
          '${ApiConfig.baseUrl}/auth/password-reset/confirm',
          auth: false,
          body: {'code': _code.text.trim(), 'password': _password.text},
        );
        _password.clear();
        _confirmation.clear();
        _code.clear();
        if (mounted) {
          setState(() {
            _done = true;
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
            _codeStep = true;
            _status = 'Si ce compte existe, un code a été envoyé. Il expire après 15 minutes.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'Impossible de terminer la récupération. Réessaie.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ElyriiPageFrame.detail(
      title: 'Retrouver mon compte',
      leading: const ElyriiBackButton(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_status != null)
                      Semantics(liveRegion: true, child: Text(_status!)),
                    if (_error != null) AuthErrorBanner(message: _error!),
                    const SizedBox(height: 16),
                    if (!_done && !_codeStep)
                      GlassAuthTextField(
                        controller: _email,
                        label: 'Adresse email',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) =>
                            value != null &&
                                RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                    .hasMatch(value.trim())
                            ? null
                            : 'Entre une adresse email valide.',
                      ),
                    if (!_done && _codeStep) ...[
                      GlassAuthTextField(
                        controller: _code,
                        label: 'Code reçu par email',
                        prefixIcon: Icons.key_rounded,
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            RegExp(r'^[A-Za-z0-9_-]{43}$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Colle le code complet reçu par email.',
                      ),
                      const SizedBox(height: 16),
                      GlassAuthTextField(
                        controller: _password,
                        label: 'Nouveau mot de passe',
                        helperText: 'Entre 12 et 128 caractères. Une phrase longue est bienvenue.',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !_busy,
                        textInputAction: TextInputAction.next,
                        validator: (value) =>
                            (value?.length ?? 0) >= 12 &&
                                (value?.length ?? 0) <= 128
                            ? null
                            : 'Le mot de passe doit contenir entre 12 et 128 caractères.',
                      ),
                      const SizedBox(height: 16),
                      GlassAuthTextField(
                        controller: _confirmation,
                        label: 'Confirmer le nouveau mot de passe',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        autofillHints: const [AutofillHints.newPassword],
                        enabled: !_busy,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submit(),
                        validator: (value) => value == _password.text
                            ? null
                            : 'Les mots de passe doivent être identiques.',
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (!_done)
                      LiquidGlassButton(
                        label: _codeStep
                            ? 'Modifier mon mot de passe'
                            : 'Recevoir un code',
                        isLoading: _busy,
                        onPressed: _busy ? null : _submit,
                      ),
                    if (!_done)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _codeStep = !_codeStep;
                                _error = null;
                                _status = null;
                              }),
                        child: Text(
                          _codeStep
                              ? 'Demander un nouveau code'
                              : 'J’ai déjà un code',
                        ),
                      ),
                    if (_done)
                      LiquidGlassButton(
                        label: 'Retour à la connexion',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
