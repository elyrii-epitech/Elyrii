import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../config/mascot_animations.dart';

/// Orchestre les intentions de Velours sans dépendre du lecteur 3D.
///
/// Une intention remplace immédiatement la précédente. Les événements courts
/// sont consommés une fois ; [trigger] permet de rejouer le même geste. Aucun
/// événement en attente ne ressurgit après une interruption ou un arrière-plan.
class MascotMotionController extends ChangeNotifier {
  MascotMotionController({Random? random}) : _random = random ?? Random();

  final Random _random;
  Timer? _timer;
  MascotAnimation _requested = MascotAnimations.idle;
  MascotAnimation _current = MascotAnimations.holdPose;
  int _trigger = 0;
  int _revision = 0;
  bool _enabled = false;
  bool _hasPlayed = false;
  int _lastAmbient = -1;

  MascotAnimation get current => _current;
  int get revision => _revision;

  void setAnimation(MascotAnimation animation, {int trigger = 0}) {
    if (_requested == animation && _trigger == trigger) return;
    _requested = animation;
    _trigger = trigger;
    if (_enabled) _beginRequest();
  }

  /// À activer uniquement quand le modèle est prêt, visible et le mouvement
  /// autorisé. Les timers ne tournent ni hors écran ni en mouvement réduit.
  void setPlaybackEnabled(bool enabled) {
    // Une première présentation en mouvement réduit consomme aussi l'arrivée.
    // Le chargement, lui, n'appelle pas cette méthode avant d'être prêt.
    if (!enabled) _hasPlayed = true;
    if (_enabled == enabled) return;
    _enabled = enabled;
    _timer?.cancel();
    if (!enabled) {
      _emit(MascotAnimations.holdPose);
    } else if (_hasPlayed && _requested.mode == MascotAnimationMode.once) {
      _rest();
    } else {
      _hasPlayed = true;
      _beginRequest();
    }
  }

  void _beginRequest() {
    _timer?.cancel();
    if (_requested == MascotAnimations.thinking) {
      // Les réponses instantanées n'engendrent pas un flash de réflexion.
      _emit(MascotAnimations.attentive);
      _timer = Timer(const Duration(milliseconds: 400), () {
        _emit(MascotAnimations.thinking);
        _timer = Timer(MascotAnimations.thinking.duration * 2, () {
          // Une attente longue ne fait pas paraître Velours impatiente.
          _emit(MascotAnimations.idle);
        });
      });
    } else if (_requested == MascotAnimations.idle) {
      _rest();
    } else {
      _emit(_requested);
      if (_requested.mode == MascotAnimationMode.once) {
        _timer = Timer(_requested.duration, _rest);
      }
    }
  }

  void _rest() {
    _emit(MascotAnimations.idle);
    // Du silence entre les petits gestes. Jamais deux fois le même de suite.
    _timer = Timer(Duration(seconds: 14 + _random.nextInt(11)), () {
      const variations = [
        MascotAnimations.curious,
        MascotAnimations.cozy,
        MascotAnimations.stretch,
      ];
      final next = (_lastAmbient + 1 + _random.nextInt(2)) % variations.length;
      _lastAmbient = next;
      final variation = variations[next];
      _emit(variation);
      _timer = Timer(variation.duration, _rest);
    });
  }

  void _emit(MascotAnimation animation) {
    _current = animation;
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
