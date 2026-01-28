import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

import 'package:flutter/foundation.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({
    super.key,
    required this.child,
  });

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  ErrorWidgetBuilder? _defaultErrorBuilder;

  @override
  void initState() {
    super.initState();
    _defaultErrorBuilder = ErrorWidget.builder;
    ErrorWidget.builder = _buildErrorWidget;
  }

  @override
  void dispose() {
    if (_defaultErrorBuilder != null) {
      ErrorWidget.builder = _defaultErrorBuilder!;
    }
    super.dispose();
  }

  Widget _buildErrorWidget(FlutterErrorDetails details) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Oups ! Une erreur est survenue.',
                  style: AppTextStyles.headlineSmall(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Nous avons rencontré un problème inattendu.\nNe vous inquiétez pas, nos robots travaillent déjà dessus !',
                  style: AppTextStyles.bodyMedium(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Simple reload attempt by navigating to root
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        '/',
                        (route) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Retour à l\'accueil'),
                ),
                if (kDebugMode && details.exceptionAsString().isNotEmpty) ...[
                  const SizedBox(height: 48),
                  ExpansionTile(
                    title: Text(
                      'Détails techniques (Debug only)',
                      style: AppTextStyles.labelMedium(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          details.exceptionAsString(),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
