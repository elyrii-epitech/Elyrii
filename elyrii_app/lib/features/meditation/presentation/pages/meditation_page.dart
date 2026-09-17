import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/meditation_repository.dart';
import '../controllers/meditation_controller.dart';
import '../widgets/active_breathing_view.dart';
import '../widgets/meditation_catalog_view.dart';
import '../widgets/meditation_summary_view.dart';

export '../../domain/models/breath_phase.dart';
export '../controllers/meditation_controller.dart';

/// Page principale de méditation et cohérence cardiaque.
/// Coordonne le [MeditationController] et les 3 vues modulaires :
/// 1. [MeditationCatalogView] : Catalogue des techniques et choix de durée
/// 2. [ActiveBreathingView] : Session active plein écran avec cercle zen
/// 3. [MeditationSummaryView] : Synthèse, gratitude et sélecteur d'humeur
class MeditationPage extends StatefulWidget {
  const MeditationPage({super.key});

  @override
  State<MeditationPage> createState() => _MeditationPageState();
}

class _MeditationPageState extends State<MeditationPage> {
  late final MeditationController _controller;

  @override
  void initState() {
    super.initState();
    final client = context.read<ApiClient>();
    final repository = MeditationRepository(client: client);
    _controller = MeditationController(repository: repository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          switch (_controller.sessionState) {
            case MeditationSessionState.setup:
              return MeditationCatalogView(controller: _controller);
            case MeditationSessionState.running:
            case MeditationSessionState.paused:
              return SafeArea(
                bottom: false,
                child: ActiveBreathingView(controller: _controller),
              );
            case MeditationSessionState.finished:
              return SafeArea(
                bottom: false,
                child: MeditationSummaryView(controller: _controller),
              );
          }
        },
      ),
    );
  }
}
