import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../routes/app_routes.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/widgets/mascot_bounce.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../providers/dashboard_provider.dart';

/// Velours réagit avec son corps : salut, connivence au toucher, douceur au
/// maintien et accueil de l'humeur. Ses pieds restent posés, sans déformation
/// du viewer ni cumul de flottements avec les mouvements du modèle.
class MascotPeek extends StatefulWidget {
  final MoodType? selectedMood;
  final VoidCallback? onTap;
  final bool isDark;

  const MascotPeek({
    super.key,
    this.selectedMood,
    this.onTap,
    this.isDark = false,
  });

  @override
  State<MascotPeek> createState() => _MascotPeekState();
}

class _MascotPeekState extends State<MascotPeek> {
  MascotAnimation _animation = MascotAnimations.idle;
  int _trigger = 0;
  int _bounceTrigger = 0;
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
  }

  void _react(MascotAnimation animation) {
    setState(() {
      _animation = animation;
      _trigger++;
      _bounceTrigger++;
    });
  }

  void _touch({bool cuddle = false}) {
    if (!cuddle) widget.onTap?.call();
    // Le texte reste utilisable, même lorsque le geste se termine.
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
    label: 'Velours, ta mascotte',
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
            _bounceTrigger++;
          });
        }
      });
    }

    return MascotBounce(
      trigger: _bounceTrigger,
      child: MascotWithAccessories(
        config: const Mascot3DConfig(),
        animation: animation,
        animationTrigger: trigger,
        width: 220,
        height: 220,
      ),
    );
  }

  int _lastGlobalTrigger = 0;
}
