import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../routes/app_routes.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/widgets/mascot_bounce.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/widgets/mascot_warm_placeholder.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';

/// Velours en posture d'écoute sur la page Coach.
///
/// Réplique le contrat tactile de `MascotPeek` (dashboard) sans la dépendance
/// à l'humeur : tap = réaction courte + rotation du message de la bulle,
/// maintien = moment de douceur. Consomme aussi les réactions globales
/// publiées par les autres parcours tant que l'onglet Coach est actif, pour
/// que le geste déclenché ailleurs soit visible au retour.
class CoachMascot extends StatefulWidget {
  final VoidCallback? onTap;
  final double size;

  const CoachMascot({super.key, this.onTap, this.size = 200});

  @override
  State<CoachMascot> createState() => _CoachMascotState();
}

class _CoachMascotState extends State<CoachMascot> {
  MascotAnimation _animation = MascotAnimations.attentive;
  int _trigger = 0;
  int _bounceTrigger = 0;
  int _tapCount = 0;
  final Stopwatch _clock = Stopwatch()..start();
  int _lastTouch = -4000;
  int _lastGlobalTrigger = 0;
  bool _activated = false;

  void _react(MascotAnimation animation) {
    setState(() {
      _animation = animation;
      _trigger++;
      _bounceTrigger++;
    });
  }

  void _touch({bool cuddle = false}) {
    if (!cuddle) widget.onTap?.call();
    // Le message de la bulle reste utilisable même quand le geste est
    // encore en cours de throttle.
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
    label: 'Velours, ton coach',
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
    final coachVisible =
        router == null ||
        router.routerDelegate.currentConfiguration.uri.path == AppRoutes.coach;
    if (coachVisible && !_activated) {
      _activated = true;
    }

    if (!_activated) {
      return SizedBox(
        width: widget.size,
        height: widget.size,
        child: MascotWarmPlaceholder(
          width: widget.size,
          height: widget.size,
        ),
      );
    }
    final globalReactionPending =
        coachVisible &&
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
        width: widget.size,
        height: widget.size,
      ),
    );
  }
}
