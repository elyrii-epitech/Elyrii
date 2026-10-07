import 'package:provider/provider.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../../routes/app_routes.dart';

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;

  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  // Keyed account changes can mount a new boundary before disposing the old
  // one. A shared dispatcher keeps the global hook owned by active scopes.
  static final List<_GlobalErrorBoundaryState> _active = [];
  static ErrorWidgetBuilder? _defaultErrorBuilder;
  static Widget _dispatcher(FlutterErrorDetails details) {
    final boundary = _active.lastOrNull;
    return boundary?._buildErrorWidget(details) ??
        ErrorWidget(details.exception);
  }

  void _register() {
    if (_active.contains(this)) return;
    final first = _active.isEmpty;
    if (first) _defaultErrorBuilder = ErrorWidget.builder;
    _active.add(this);
    if (first) ErrorWidget.builder = _dispatcher;
  }

  void _unregister() {
    if (!_active.remove(this) || _active.isNotEmpty) return;
    final original = _defaultErrorBuilder;
    if (ErrorWidget.builder == _dispatcher && original != null) {
      ErrorWidget.builder = original;
    }
    _defaultErrorBuilder = null;
  }

  @override
  void initState() {
    super.initState();
    _register();
  }

  @override
  void activate() {
    super.activate();
    _register();
  }

  @override
  void deactivate() {
    _unregister();
    super.deactivate();
  }

  @override
  void dispose() {
    _unregister();
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
                Icon(
                  Icons.self_improvement_rounded,
                  color: AppColors.primary.withValues(alpha: 0.6),
                  size: 64,
                ),
                const SizedBox(height: 24),
                Text(
                  'Oups, un petit souci...',
                  style: AppTextStyles.headlineSmall(
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Ce n\'est rien de grave. On recommence ensemble ?',
                  style: AppTextStyles.bodyMedium(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () async {
                    await context.read<AuthProvider>().clearLocalSession();
                    if (mounted) context.go(AppRoutes.login);
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
                  child: const Text('Recommencer'),
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
