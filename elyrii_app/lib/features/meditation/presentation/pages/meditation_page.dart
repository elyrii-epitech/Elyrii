import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/meditation_repository.dart';
import '../controllers/meditation_controller.dart';
import '../widgets/meditation_library.dart';

export '../../domain/models/breath_phase.dart';
export '../controllers/meditation_controller.dart';

class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  late final MeditationController _controller;
  bool _sessionRouteOpen = false;

  @override
  void initState() {
    super.initState();
    final client = context.read<ApiClient>();
    final repository = MeditationRepository(client: client);
    _controller = MeditationController(repository: repository);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    final running = _controller.isRunning || _controller.isPaused;
    if (running && !_sessionRouteOpen) {
      _sessionRouteOpen = true;
      context.push(AppRoutes.meditationSession, extra: _controller).then((_) {
        if (mounted) {
          _sessionRouteOpen = false;
          if (!_controller.isSetup) _controller.resetToSetup();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.sectionBody(isDark),
      body: MeditationLibrary(controller: _controller),
    );
  }
}
