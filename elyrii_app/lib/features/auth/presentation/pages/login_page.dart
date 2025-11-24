import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:elyrii_app/core/theme/app_colors.dart';
import 'package:elyrii_app/core/theme/app_text_styles.dart';
import 'package:elyrii_app/core/theme/app_dimensions.dart';
import 'package:elyrii_app/routes/app_routes.dart';

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

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      // Simulation d'authentification
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        setState(() => _isLoading = false);
        // Pour l'instant, on redirige vers la home
        // TODO: Implémenter la logique de redirection (Home vs Chatbot)
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    }
  }

  void _handleSocialLogin(String provider) async {
    setState(() => _isLoading = true);
    
    // Simulation d'authentification sociale
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isLoading = false);
      // Simulation: Nouvel utilisateur -> Chatbot (Index 5 dans HomeNavigation)
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.home,
        arguments: 5,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark 
              ? [AppColors.backgroundDark, AppColors.surfaceDark]
              : [AppColors.primaryLight, AppColors.backgroundLight],
          ),
        ),
        child: Stack(
          children: [
            // Background Elements (Blobs)
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).fadeIn(),
            
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withOpacity(0.3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondary.withOpacity(0.2),
                      blurRadius: 100,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ).animate().scale(duration: 2.seconds, delay: 500.ms, curve: Curves.easeInOut).fadeIn(),

            // Main Content
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.paddingLg),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo / Title
                    Text(
                      'Elyrii',
                      style: AppTextStyles.displayLarge(
                        color: AppColors.primary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.5, end: 0),
                    
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Login Card
                    GlassmorphicContainer(
                      width: double.infinity,
                      height: 550,
                      borderRadius: AppDimensions.radiusXl,
                      blur: 20,
                      alignment: Alignment.center,
                      border: 2,
                      linearGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.5),
                          isDark ? Colors.white.withOpacity(0.05) : Colors.white.withOpacity(0.2),
                        ],
                      ),
                      borderGradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          isDark ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.8),
                          isDark ? Colors.white.withOpacity(0.1) : Colors.white.withOpacity(0.2),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppDimensions.paddingLg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Bienvenue',
                                style: AppTextStyles.headlineMedium(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppDimensions.spacingLg),
                              
                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer votre email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppDimensions.spacingMd),
                              
                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Mot de passe',
                                  prefixIcon: Icon(Icons.lock_outline),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez entrer votre mot de passe';
                                  }
                                  return null;
                                },
                              ),
                              
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {},
                                  child: const Text('Mot de passe oublié ?'),
                                ),
                              ),
                              
                              const SizedBox(height: AppDimensions.spacingMd),
                              
                              // Login Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _handleLogin,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                                  ),
                                ),
                                child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Se connecter'),
                              ),

                              const SizedBox(height: AppDimensions.spacingLg),
                              
                              // Divider
                              Row(
                                children: [
                                  Expanded(child: Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      'Ou continuer avec',
                                      style: AppTextStyles.bodySmall(
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                                  Expanded(child: Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight)),
                                ],
                              ),
                              
                              const SizedBox(height: AppDimensions.spacingLg),
                              
                              // Social Buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _SocialButton(
                                    icon: Icons.g_mobiledata, // Placeholder for Google
                                    label: "Google",
                                    onTap: () => _handleSocialLogin('google'),
                                    isDark: isDark,
                                  ),
                                  _SocialButton(
                                    icon: Icons.apple,
                                    label: "Apple",
                                    onTap: () => _handleSocialLogin('apple'),
                                    isDark: isDark,
                                  ),
                                  _SocialButton(
                                    icon: Icons.facebook,
                                    label: "Facebook",
                                    onTap: () => _handleSocialLogin('facebook'),
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate().fadeIn(duration: 800.ms, delay: 200.ms).slideY(begin: 0.2, end: 0),
                    
                    const SizedBox(height: AppDimensions.spacingLg),
                    
                    // Sign Up Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Pas encore de compte ? ",
                          style: AppTextStyles.bodyMedium(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('S\'inscrire'),
                        ),
                      ],
                    ).animate().fadeIn(delay: 600.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusCircular),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.surfaceDark : Colors.white,
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        child: Icon(
          icon,
          size: 28,
          color: isDark ? Colors.white : AppColors.textPrimaryLight,
        ),
      ),
    );
  }
}
