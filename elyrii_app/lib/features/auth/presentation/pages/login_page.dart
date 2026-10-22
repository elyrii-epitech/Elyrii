import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/accessibility/motion.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/validators.dart';

import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_kit.dart';
import '../widgets/glass_auth_text_field.dart';
import '../widgets/auth_error_banner.dart';

import 'package:flutter_animate/flutter_animate.dart';

import '../../../../routes/app_routes.dart';
import '../providers/auth_provider.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorBanner;
  MascotAnimation _mascotAnimation = MascotAnimations.greet;
  int _mascotTrigger = 0;
  bool get _isLoading => context.watch<AuthProvider>().isLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (context.read<AuthProvider>().isLoading) return;
    if (!_formKey.currentState!.validate()) return;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (success) {
      setState(() {
        _mascotAnimation = MascotAnimations.delight;
        _mascotTrigger++;
      });
      context.go(AppRoutes.home);
    } else {
      // Bannière contextuelle en haut de formulaire (pas de SnackBar).
      setState(() {
        _errorBanner =
            authProvider.error ??
            'Oops, petit souci de connexion. Réessaie quand tu es prêt.';
        _mascotAnimation = MascotAnimations.reassure;
        _mascotTrigger++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.spacing24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mascotte cadrée par la caméra (cameraTarget du
                      // config authPage) — aucun décalage de layout.
                      AccessibleAction(
                            label: 'Faire réagir la mascotte Elyrii',
                            onPressed: () {
                              ElyriiHaptics.light();
                              setState(() {
                                _mascotAnimation = MascotAnimations.greet;
                                _mascotTrigger++;
                              });
                            },
                            child: Mascot3DViewer(
                              config: const Mascot3DConfig.authPage(),
                              animation: _mascotAnimation,
                              animationTrigger: _mascotTrigger,
                              width: 250,
                              height: 250,
                            ),
                          )
                          .animateRespectingMotion(context)
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: AppDimensions.spacing48),

                      Text(
                        'Connexion à Elyrii',
                        style: AppTextStyles.headlineMedium(
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppDimensions.spacing32),

                      if (_errorBanner != null) ...[
                        AuthErrorBanner(message: _errorBanner!),
                        const SizedBox(height: AppDimensions.spacing24),
                      ],

                      AutofillGroup(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Email Field
                                  Text(
                                    'Adresse email',
                                    style: AppTextStyles.labelMedium(
                                      color: context.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing8,
                                  ),
                                  GlassAuthTextField(
                                    controller: _emailController,
                                    label: 'Adresse email',
                                    autofillHints: const [AutofillHints.email],
                                    hint: '',
                                    prefixIcon: Icons.email_outlined, // We might remove this if we want strict GitHub copy, but keeping for now
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Entre ton email';
                                      }
                                      if (!Validators.isValidEmail(value)) {
                                        return 'Email invalide';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing24,
                                  ),

                                  // Password Field
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Mot de passe',
                                        style: AppTextStyles.labelMedium(
                                          color: context.textPrimary,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => context.push(
                                          AppRoutes.passwordReset,
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(48, 48),
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                        ),
                                        child: Text(
                                          'Mot de passe oublié ?',
                                          style: AppTextStyles.bodySmall(
                                            color: context.textTertiary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing8,
                                  ),
                                  GlassAuthTextField(
                                    controller: _passwordController,
                                    label: 'Mot de passe',
                                    onSubmitted: (_) {
                                      _handleLogin();
                                    },
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    hint: '',
                                    prefixIcon: Icons.lock_outline,
                                    isPassword: true,
                                    textInputAction: TextInputAction.done,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Entre ton mot de passe';
                                      }
                                      if (value.length < 6) {
                                        return 'Le mot de passe doit contenir au moins 6 caractères';
                                      }
                                      return null;
                                    },
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacing32,
                                  ),

                                  // Login Button
                                  LiquidGlassButton(
                                    label: 'Se connecter',
                                    isLoading: _isLoading,
                                    isExpanded: true,
                                    onPressed: _handleLogin,
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacing12,
                                  ),
                                  LiquidGlassButton(
                                    label: 'Découvrir Elyrii',
                                    icon: Icons.bolt_rounded,
                                    style: LiquidGlassButtonStyle.tinted,
                                    isExpanded: true,
                                    onPressed: () async {
                                      ElyriiHaptics.medium();
                                      await context
                                          .read<AuthProvider>()
                                          .startDemoSession();
                                      if (!context.mounted) return;
                                      context
                                              .read<ValueNotifier<bool>>()
                                              .value =
                                          true;
                                      context.go(AppRoutes.home);
                                    },
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacing32,
                                  ),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? const Color(0xFF30363D)
                                              : AppColors.dividerLight,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppDimensions.spacing16,
                                        ),
                                        child: Text(
                                          'ou',
                                          style: AppTextStyles.bodySmall(
                                            color: context.textSecondary,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: isDark
                                              ? const Color(0xFF30363D)
                                              : AppColors.dividerLight,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacing32,
                                  ),

                                  // Social Buttons (Stacked)
                                  _buildSocialButtonFull(
                                    'Google bientôt disponible',
                                    Icons.g_mobiledata,
                                    isDark,
                                  ),
                                  const SizedBox(
                                    height: AppDimensions.spacing16,
                                  ),
                                  _buildSocialButtonFull(
                                    'Apple bientôt disponible',
                                    Icons.apple,
                                    isDark,
                                  ),

                                  const SizedBox(
                                    height: AppDimensions.spacing32,
                                  ),

                                  // Register Link
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Nouveau sur Elyrii ? ',
                                        style: AppTextStyles.bodySmall(
                                          color: context.textSecondary,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          context.push(AppRoutes.register);
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(48, 48),
                                          tapTargetSize:
                                              MaterialTapTargetSize.padded,
                                        ),
                                        child: Text(
                                          'Créer un compte',
                                          style: AppTextStyles.labelMedium(
                                            color: AppColors.readableAccent(
                                              AppColors.primary,
                                              isDark:
                                                  Theme.of(context)
                                                      .brightness ==
                                                  Brightness.dark,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          )
                          .animateRespectingMotion(context)
                          .fadeIn(duration: 800.ms, delay: 200.ms)
                          .slideY(begin: 0.2, end: 0),
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

  Widget _buildSocialButtonFull(
    String text,
    IconData fallbackIcon,
    bool isDark,
  ) {
    return LiquidGlassCard(
      padding: EdgeInsets.zero,
      color: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.white.withValues(alpha: 0.4),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(fallbackIcon, color: context.textPrimary, size: 20),
            const SizedBox(width: AppDimensions.spacing16),
            Flexible(
              child: Text(
                text,
                style: AppTextStyles.labelLarge(color: context.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
