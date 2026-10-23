import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../controllers/meditation_controller.dart';
import '../widgets/meditation_session_view.dart';
import '../widgets/meditation_summary_sheet.dart';

class MeditationSessionPage extends StatefulWidget {
  final MeditationController controller;
  const MeditationSessionPage({super.key, required this.controller});

  @override
  State<MeditationSessionPage> createState() => _MeditationSessionPageState();
}

class _MeditationSessionPageState extends State<MeditationSessionPage>
    with WidgetsBindingObserver {
  bool _summaryOpen = false;
  bool _exitOpen = false;
  bool _finishedObserved = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_onChanged);
    if (widget.controller.isFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onChanged());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    if (widget.controller.isSetup) {
      if (context.canPop()) context.pop();
      return;
    }
    if (widget.controller.isFinished && !_finishedObserved) {
      _finishedObserved = true;
      context.read<MascotProvider>().react(MascotAnimations.settle);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSummary();
      });
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) widget.controller.pauseSession();
  }

  Future<void> _confirmExit() async {
    if (_exitOpen) return;
    if (widget.controller.isFinished) {
      widget.controller.resetToSetup();
      return;
    }
    _exitOpen = true;
    final wasRunning = widget.controller.isRunning;
    widget.controller.pauseSession();
    if (widget.controller.isFinished) {
      _exitOpen = false;
      return;
    }
    final leave = await Navigator.of(context, rootNavigator: true).push<bool>(
      AppSheetRoute<bool>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (sheetContext) => AppSheetPanel(
          title: 'Quitter la séance ?',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'La séance en cours sera interrompue et non comptabilisée.',
                style: AppTextStyles.bodyMedium(
                  color: sheetContext.textSecondary,
                ),
              ),
              const SizedBox(height: AppDimensions.spacing20),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: const Text('Reprendre la séance'),
              ),
              const SizedBox(height: AppDimensions.spacing8),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.errorText(
                    Theme.of(sheetContext).brightness == Brightness.dark,
                  ),
                ),
                child: const Text('Interrompre'),
              ),
            ],
          ),
        ),
      ),
    );
    _exitOpen = false;
    if (!mounted) return;
    if (leave == true) {
      await widget.controller.stopSession();
    } else if (wasRunning) {
      widget.controller.resumeSession();
    }
  }

  void _finish() {
    if (widget.controller.isFinished) {
      _showSummary();
    } else {
      widget.controller.pauseSession();
      unawaited(widget.controller.stopSession(finished: true));
    }
  }

  Future<void> _showSummary() async {
    if (_summaryOpen || !mounted) return;
    _summaryOpen = true;
    final done = await Navigator.of(context, rootNavigator: true).push<bool>(
      AppSheetRoute<bool>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (_) => MeditationSummarySheet(controller: widget.controller),
      ),
    );
    _summaryOpen = false;
    if (mounted && done == true) widget.controller.resetToSetup();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: widget.controller.isFinished,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmExit();
    },
    child: Scaffold(
      backgroundColor: AppColors.sectionSky(
        Theme.of(context).brightness == Brightness.dark,
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: SectionSkyBackdrop(scene: SectionSkyScene.water),
          ),
          if (!widget.controller.isSetup)
            Positioned.fill(
              child: MeditationSessionView(
                controller: widget.controller,
                onExit: _confirmExit,
                onFinish: _finish,
              ),
            ),
        ],
      ),
    ),
  );
}
