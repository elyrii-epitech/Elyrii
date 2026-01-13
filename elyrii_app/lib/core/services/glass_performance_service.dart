import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer les performances des effets Liquid Glass
/// Permet de désactiver les effets visuels pour les appareils bas de gamme
/// ou pour économiser la batterie
class GlassPerformanceService extends ChangeNotifier {
  static const String _reduceEffectsKey = 'reduce_glass_effects';
  static const String _adaptiveBlurKey = 'adaptive_blur_on_scroll';

  bool _reduceEffects = false;
  bool _adaptiveBlurOnScroll = true;
  bool _isLowEndDevice = false;
  bool _initialized = false;
  SharedPreferences? _prefs;

  /// Singleton instance
  static final GlassPerformanceService _instance =
      GlassPerformanceService._internal();

  factory GlassPerformanceService() => _instance;

  GlassPerformanceService._internal();

  /// Initialise le service avec les préférences sauvegardées
  Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _reduceEffects = _prefs?.getBool(_reduceEffectsKey) ?? false;
    _adaptiveBlurOnScroll = _prefs?.getBool(_adaptiveBlurKey) ?? true;
    await _detectLowEndDevice();
    _initialized = true;
    notifyListeners();
  }

  /// Détecte si l'appareil est bas de gamme
  /// Utilise des heuristiques basées sur la plateforme et les caractéristiques
  Future<void> _detectLowEndDevice() async {
    if (kIsWeb) {
      _isLowEndDevice = false;
      return;
    }

    try {
      if (Platform.isAndroid) {
        // Heuristique pour Android: vérifier le nombre de processeurs
        // Les appareils bas de gamme ont généralement 4 cores ou moins
        // et les appareils modernes performants ont 6-8+ cores
        final processorCount = Platform.numberOfProcessors;

        // Considérer bas de gamme si moins de 4 cores
        // ou si l'appareil a exactement 4 cores (souvent entrée de gamme)
        _isLowEndDevice = processorCount <= 4;

        debugPrint(
            'GlassPerformanceService: Detected $processorCount processors, '
            'isLowEndDevice: $_isLowEndDevice');
      } else if (Platform.isIOS) {
        // iOS: les appareils Apple sont généralement performants
        // Mais on peut détecter les anciens modèles via le nombre de processeurs
        final processorCount = Platform.numberOfProcessors;

        // Les anciens iPhones (6, 6s, SE 1ère gen) ont 2 cores
        // iPhone 7+ ont 4+ cores et sont performants
        _isLowEndDevice = processorCount < 4;

        debugPrint(
            'GlassPerformanceService: iOS with $processorCount processors, '
            'isLowEndDevice: $_isLowEndDevice');
      } else {
        // Desktop platforms are generally powerful enough
        _isLowEndDevice = false;
      }
    } catch (e) {
      debugPrint('GlassPerformanceService: Error detecting device: $e');
      _isLowEndDevice = false;
    }
  }

  /// Indique si les effets visuels doivent être réduits
  bool get reduceEffects => _reduceEffects || _isLowEndDevice;

  /// Indique si le blur doit s'adapter au scroll
  bool get adaptiveBlurOnScroll => _adaptiveBlurOnScroll && !reduceEffects;

  /// Indique si l'appareil est détecté comme bas de gamme
  bool get isLowEndDevice => _isLowEndDevice;

  /// Active/désactive la réduction des effets
  Future<void> setReduceEffects(bool value) async {
    _reduceEffects = value;
    await _prefs?.setBool(_reduceEffectsKey, value);
    notifyListeners();
  }

  /// Active/désactive le blur adaptatif au scroll
  Future<void> setAdaptiveBlurOnScroll(bool value) async {
    _adaptiveBlurOnScroll = value;
    await _prefs?.setBool(_adaptiveBlurKey, value);
    notifyListeners();
  }

  /// Retourne le blur sigma effectif selon l'état du service
  /// [baseSigma] est la valeur de blur souhaitée normalement
  double getEffectiveBlurSigma(double baseSigma) {
    if (reduceEffects) {
      return 0.0; // Pas de blur si effets réduits
    }
    return baseSigma;
  }

  /// Retourne le blur sigma adapté au scroll
  /// [baseSigma] valeur de base
  /// [scrollVelocity] vitesse de scroll (0.0 à 1.0 normalisée)
  double getScrollAdaptedBlurSigma(double baseSigma, double scrollVelocity) {
    if (!adaptiveBlurOnScroll) {
      return getEffectiveBlurSigma(baseSigma);
    }

    // Réduire le blur proportionnellement à la vitesse de scroll
    // Plus on scroll vite, moins on applique de blur (performance)
    final velocityFactor = (1.0 - scrollVelocity.clamp(0.0, 0.8));
    return getEffectiveBlurSigma(baseSigma * velocityFactor);
  }

  /// Indique si le glass doit afficher les effets spéculaires
  bool get showSpecularHighlight => !reduceEffects;

  /// Indique si les animations de transition doivent être affichées
  bool get showTransitionAnimations => !reduceEffects;

  /// Indique si le gradient adaptatif doit être activé
  bool get showAdaptiveGradient => !reduceEffects;
}
