import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/meditation_controller.dart';
import '../widgets/active_breathing_view.dart';
import '../widgets/meditation_summary_view.dart';

/// Page immersive plein écran pour une session de respiration en cours.
///
/// Hors du shell de navigation : aucun dock, aucune distraction.
/// - Fond radial teinté par la technique active (ambiance apaisante).
/// - Retour système bloqué pendant la séance (confirmation bienveillante).
/// - Retour automatique au catalogue dès que la session se termine ou est
///   interrompue (état `setup`).
class MeditationSessionPage extends StatefulWidget {
  final MeditationController controller;

  const MeditationSessionPage({super.key, required this.controller});

  @override
  State<MeditationSessionPage> createState() => _MeditationSessionPageState();
}

class _MeditationSessionPageState extends State<MeditationSessionPage> {
  bool _hasReactedFinished = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.isFinished && !_hasReactedFinished) {
      _hasReactedFinished = true;
      context.read<MascotProvider>().react(MascotAnimations.settle);
    }
    // Fin ou interruption : la session redevient `setup` → retour au catalogue.
    if (widget.controller.isSetup && context.canPop()) {
      context.pop();
    }
  }

  /// Confirmation bienveillante avant d'interrompre la séance.
  void _confirmExit() {
    widget.controller.pauseSession();
    showCupertinoModalPopup<bool>(
      context: context,
      builder: (modalContext) => CupertinoActionSheet(
        title: const Text('Quitter la séance ?'),
        message: const Text(
          'La séance en cours sera interrompue et non comptabilisée.',
        ),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () {
            Navigator.pop(modalContext, true);
            widget.controller.resumeSession();
          },
          child: const Text('Reprendre la séance'),
        ),
        actions: [
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(modalContext, false);
              widget.controller.stopSession(finished: false);
            },
            child: const Text('Interrompre'),
          ),
        ],
      ),
    ).then((result) {
      // Rejet hors boutons (tap à l'extérieur) : la séance reprend.
      if (result == null && widget.controller.isPaused) {
        widget.controller.resumeSession();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.controller.selectedBreathingType!.color;
    final isFinished = widget.controller.isFinished;

    return PopScope(
      // Retour autorisé uniquement sur l'écran de synthèse.
      canPop: isFinished,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        backgroundColor: isDark
            ? AppColors.scaffoldDark
            : AppColors.scaffoldLight,
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.35),
              radius: 1.2,
              colors: [
                accent.withValues(alpha: isDark ? 0.14 : 0.09),
                isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
              ],
              stops: const [0.0, 1.0],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListenableBuilder(
              listenable: widget.controller,
              builder: (context, _) {
                if (widget.controller.isFinished) {
                  return MeditationSummaryView(controller: widget.controller);
                }
                return ActiveBreathingView(
                  controller: widget.controller,
                  onRequestExit: _confirmExit,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
