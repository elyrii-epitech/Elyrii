import 'package:flutter/material.dart';
import '../../../../routes/app_routes.dart';
import '../../../../main.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeSwitcher = ThemeSwitcher.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF171719) : const Color(0xFFE8E8EB),
      body: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Thème & Design System',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configuration terminée ✅',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Bouton Principal'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Bouton Outlined'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {},
                    child: const Text('Bouton Text'),
                  ),
                  const SizedBox(height: 32),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Exemple de Card',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Le design system est maintenant prêt à être utilisé dans toute l\'application.',
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bouton de changement de thème en haut à droite
          if (themeSwitcher != null)
            Positioned(
              top: 48,
              right: 16,
              child: Material(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(16),
                elevation: 4,
                child: InkWell(
                  onTap: themeSwitcher.toggleTheme,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}
