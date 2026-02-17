import 'package:flutter/material.dart';
import 'package:email_validator/email_validator.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/liquid_glass_kit.dart';
import '../widgets/glass_auth_text_field.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../routes/app_routes.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _acceptTerms = false;
  bool get _isLoading => context.read<AuthProvider>().isLoading;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez accepter les conditions d\'utilisation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.first;
    final lastName =
        nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: firstName,
      lastName: lastName,
    );
    if (!mounted) return;
    if (success) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error ?? 'Registration failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: SafeArea(
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
                      height: 100,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .slideY(begin: 0.2, end: 0),

                  const SizedBox(height: AppDimensions.spacingLg),

                  Text(
                    'Créer un compte',
                    style: AppTextStyles.headlineMedium(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ).copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppDimensions.spacingMd),

                  Text(
                    'Rejoins la communauté Elyrii',
                    style: AppTextStyles.bodyMedium(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppDimensions.spacingXl),

                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Name Field
                        Text(
                          'Prénom',
                          style: AppTextStyles.bodyMedium(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        GlassAuthTextField(
                          controller: _nameController,
                          hint: '',
                          prefixIcon: Icons.person_outline,
                          keyboardType: TextInputType.name,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre prénom';
                            }
                            if (value.length < 2) {
                              return 'Le prénom doit contenir au moins 2 caractères';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),

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
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
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
                        const SizedBox(height: AppDimensions.spacingMd),

                        // Password Field
                        Text(
                          'Mot de passe',
                          style: AppTextStyles.bodyMedium(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        GlassAuthTextField(
                          controller: _passwordController,
                          hint: '',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer un mot de passe';
                            }
                            if (value.length < 8) {
                              return 'Le mot de passe doit contenir au moins 8 caractères';
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                              return 'Le mot de passe doit contenir au moins une majuscule';
                            }
                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                              return 'Le mot de passe doit contenir au moins un chiffre';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppDimensions.spacingMd),

                        // Confirm Password Field
                        Text(
                          'Confirmer le mot de passe',
                          style: AppTextStyles.bodyMedium(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        GlassAuthTextField(
                          controller: _confirmPasswordController,
                          hint: '',
                          prefixIcon: Icons.lock_outline,
                          isPassword: true,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez confirmer votre mot de passe';
                            }
                            if (value != _passwordController.text) {
                              return 'Les mots de passe ne correspondent pas';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: AppDimensions.spacingLg),

                        // Terms and Conditions
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: _acceptTerms,
                                onChanged: (value) {
                                  setState(() {
                                    _acceptTerms = value ?? false;
                                  });
                                },
                                activeColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.spacingSm),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _acceptTerms = !_acceptTerms;
                                  });
                                },
                                child: Text.rich(
                                  TextSpan(
                                    text: 'J\'accepte les ',
                                    style: AppTextStyles.bodySmall(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: 'conditions d\'utilisation',
                                        style: AppTextStyles.bodySmall(
                                          color: AppColors.primary,
                                        ).copyWith(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppDimensions.spacingXl),

                        // Register Button
                        LiquidGlassButton(
                          label: 'Créer mon compte',
                          isLoading: _isLoading,
                          isExpanded: true,
                          onPressed: _handleRegister,
                        ),

                        const SizedBox(height: AppDimensions.spacingXl),

                        // Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Déjà un compte ? ',
                              style: AppTextStyles.bodySmall(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Se connecter',
                                style: AppTextStyles.bodySmall(
                                  color: AppColors.primary,
                                ).copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
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
    );
  }
}
