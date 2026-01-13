import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../widgets/glass_auth_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../routes/app_routes.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulate API call
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          // Navigate to home or show success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connexion réussie (Simulation)')),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Mascot
                      Hero(
                        tag: 'mascot',
                        child: Image.asset(
                          'assets/mascotte.png',
                          height:
                              120, // Slightly smaller to match the compact look
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: AppDimensions.spacingXl),

                      Text(
                        'Connexion à Elyrii',
                        style: AppTextStyles.headlineMedium(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ).copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: AppDimensions.spacingXl),

                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Email Field
                            Text(
                              'Adresse email',
                              style: AppTextStyles.bodyMedium(
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            GlassAuthTextField(
                              controller: _emailController,
                              hint: '',
                              prefixIcon: Icons
                                  .email_outlined, // We might remove this if we want strict GitHub copy, but keeping for now
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre email';
                                }
                                if (!EmailValidator.validate(value)) {
                                  return 'Email invalide';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppDimensions.spacingLg),

                            // Password Field
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Mot de passe',
                                  style: AppTextStyles.bodyMedium(
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                  ).copyWith(fontWeight: FontWeight.w600),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Mot de passe oublié ?',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            GlassAuthTextField(
                              controller: _passwordController,
                              hint: '',
                              prefixIcon: Icons.lock_outline,
                              isPassword: true,
                              textInputAction: TextInputAction.done,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre mot de passe';
                                }
                                if (value.length < 6) {
                                  return 'Le mot de passe doit contenir au moins 6 caractères';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppDimensions.spacingXl),

                            // Login Button
                            LiquidGlassButton(
                              label: 'Se connecter',
                              isLoading: _isLoading,
                              isExpanded: true,
                              onPressed: _handleLogin,
                            ),

                            const SizedBox(height: AppDimensions.spacingXl),

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
                                      horizontal: AppDimensions.paddingMd),
                                  child: Text(
                                    'ou',
                                    style: AppTextStyles.bodySmall(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
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

                            const SizedBox(height: AppDimensions.spacingXl),

                            // Social Buttons (Stacked)
                            _buildSocialButtonFull(
                              'Continuer avec Google',
                              'assets/google_logo.png', // Placeholder icon
                              Icons.g_mobiledata,
                              isDark,
                            ),
                            const SizedBox(height: AppDimensions.spacingMd),
                            _buildSocialButtonFull(
                              'Continuer avec Apple',
                              'assets/apple_logo.png', // Placeholder icon
                              Icons.apple,
                              isDark,
                            ),

                            const SizedBox(height: AppDimensions.spacingXl),

                            // Register Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Nouveau sur Elyrii ? ',
                                  style: AppTextStyles.bodySmall(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, AppRoutes.register);
                                  },
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Créer un compte',
                                    style: AppTextStyles.bodySmall(
                                      color: AppColors.primary,
                                    ).copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: AppDimensions.spacingXl),

                            // Bypass Button (Dev)
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                    context, AppRoutes.home);
                              },
                              child: Text(
                                'Passer (Dev)',
                                style: AppTextStyles.bodySmall(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.black.withValues(alpha: 0.3),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                          .animate()
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
      String text, String assetPath, IconData fallbackIcon, bool isDark) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF21262D) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                fallbackIcon,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Text(
                text,
                style: AppTextStyles.bodyMedium(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
