import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../routes/app_routes.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../mascot/data/models/mascot_model.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/dashboard_provider.dart';

class MascotPeek extends StatefulWidget {
  final MoodType? selectedMood;
  final MascotModel? mascot;
  final int previewPop;

  const MascotPeek({
    super.key,
    this.selectedMood,
    this.mascot,
    this.previewPop = 0,
  });

  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek> with TickerProviderStateMixin {
  MascotAnimation _animation = MascotAnimations.idle;
  int _trigger = 0;
  late final _hop = AnimationController(
    vsync: this,
    duration: AppMotion.mascotHop,
  );
  late final _pop = AnimationController(
    vsync: this,
    duration: AppMotion.previewPop,
  );
  int _tapCount = 0;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastTouch = -4000;
  bool _arrived = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_arrived) {
      _arrived = true;
      _animation = context.read<MascotProvider>().takeGreeting()
          ? MascotAnimations.greet
          : MascotAnimations.idle;
    }
  }

  @override
  void dispose() {
    _hop.dispose();
    _pop.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(MascotPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedMood != oldWidget.selectedMood &&
        widget.selectedMood != null) {
      final reaction = switch (widget.selectedMood!) {
        MoodType.verySad || MoodType.sad => MascotAnimations.reassure,
        MoodType.happy || MoodType.veryHappy => MascotAnimations.delight,
        MoodType.neutral => MascotAnimations.acknowledge,
      };
      _react(reaction);
    }
    if (widget.previewPop != oldWidget.previewPop &&
        !MediaQuery.disableAnimationsOf(context)) {
      _pop.forward(from: 0);
    }
  }

  void _react(MascotAnimation animation) {
    setState(() {
      _animation = animation;
      _trigger++;
      if (!MediaQuery.disableAnimationsOf(context)) _hop.forward(from: 0);
    });
  }

  void _touch({bool cuddle = false}) {
    if (_clock.elapsedMilliseconds - _lastTouch < 1400) return;
    _lastTouch = _clock.elapsedMilliseconds;
    ElyriiHaptics.light();
    if (cuddle) {
      _react(MascotAnimations.nuzzle);
    } else {
      const reactions = [
        MascotAnimations.acknowledge,
        MascotAnimations.delight,
        MascotAnimations.curious,
      ];
      _react(reactions[_tapCount++ % reactions.length]);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Elyrii, ta mascotte',
    hint: 'Touche pour une réaction, maintiens pour un moment de douceur',
    button: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _touch,
      onLongPress: () => _touch(cuddle: true),
      child: _buildMascot(context),
    ),
  );

  Widget _buildMascot(BuildContext context) {
    final provider = context.watch<MascotProvider>();
    final router = GoRouter.maybeOf(context);
    final dashboardVisible =
        router == null ||
        router.routerDelegate.currentConfiguration.uri.path == AppRoutes.home;
    final globalReactionPending =
        dashboardVisible &&
        TickerMode.valuesOf(context).enabled &&
        provider.reactionTrigger > _lastGlobalTrigger;
    final animation = globalReactionPending ? provider.reaction : _animation;
    final trigger = globalReactionPending ? provider.reactionTrigger : _trigger;

    if (globalReactionPending) {
      // Consommer après le build permet de répondre aux événements reçus
      // pendant qu'un autre onglet était affiché, sans setState dans build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && provider.reactionTrigger > _lastGlobalTrigger) {
          setState(() {
            _lastGlobalTrigger = provider.reactionTrigger;
            _animation = provider.reaction;
            _trigger = provider.reactionTrigger;
            if (!MediaQuery.disableAnimationsOf(context)) _hop.forward(from: 0);
          });
        }
      });
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_hop, _pop]),
      child: MascotWithAccessories(
        mascot: widget.mascot,
        config: const Mascot3DConfig(),
        animation: animation,
        animationTrigger: trigger,
        width: AppDimensions.accueilHeroSize,
        height: AppDimensions.accueilHeroSize,
      ),
      builder: (_, child) {
        final hop = AppMotion.accueilPop.transform(_hop.value);
        final dy = _hop.isAnimating
            ? -AppDimensions.accueilHopDistance *
                  (hop < .5 ? hop * 2 : 2 - hop * 2)
            : 0.0;
        final pop = AppMotion.accueilPop.transform(_pop.value);
        final scale = !_pop.isAnimating
            ? 1.0
            : pop < .5
            ? AppDimensions.accueilPreviewPopScale +
                  (AppDimensions.accueilPreviewPopPeakScale -
                          AppDimensions.accueilPreviewPopScale) *
                      pop *
                      2
            : AppDimensions.accueilPreviewPopPeakScale +
                  (1 - AppDimensions.accueilPreviewPopPeakScale) *
                      (pop - .5) *
                      2;
        final reduced = MediaQuery.disableAnimationsOf(context);
        return Transform.translate(
          offset: Offset(0, reduced ? 0 : dy),
          child: Transform.scale(
            scale: reduced ? 1 : scale,
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
    );
  }

  int _lastGlobalTrigger = 0;
}
