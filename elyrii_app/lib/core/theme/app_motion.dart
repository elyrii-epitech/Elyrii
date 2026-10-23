import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Les durées nommées et les trois courbes du contrat de mouvement de
/// l'Accueil v2. Aucune section n'écrit une durée ou une courbe en dur :
/// elle choisit un rôle ici.
///
/// Les trois courbes viennent des easings CSS de la maquette :
/// ease est `cubic-bezier(.25,.1,.25,1)`, l'entrée rise est
/// `cubic-bezier(.22,.8,.24,1)` et les rebonds pop utilisent
/// `cubic-bezier(.3,1.4,.5,1)`, overshoot compris.
abstract final class AppMotion {
  // ==================== COURBES ====================

  /// `cubic-bezier(.25,.1,.25,1)` : bande, capsule, fond de réponse, voiles.
  static const Cubic accueilEase = Cubic(0.25, 0.1, 0.25, 1);

  /// `cubic-bezier(.22,.8,.24,1)` : entrées rise, feuilles, calendrier.
  static const Cubic accueilRise = Cubic(0.22, 0.8, 0.24, 1);

  /// `cubic-bezier(.3,1.4,.5,1)` : hop de mascotte, pops d'essayage, check.
  static const Cubic accueilPop = Cubic(0.3, 1.4, 0.5, 1);

  static const Cubic meditationBreath = Cubic(.42, 0, .58, 1);

  // ==================== DURÉES ====================

  /// Opacité de la bande de verre supérieure.
  static const Duration bandFade = Duration(milliseconds: 200);

  static const Duration dockPress = Duration(milliseconds: 180);
  static const Duration dockBubblePress = Duration(milliseconds: 100);
  static const Curve dockPressCurve = Curves.easeOutCubic;

  static const Duration gardenSegment = Duration(milliseconds: 150);
  static const Duration gardenTodayScroll = Duration(milliseconds: 445);
  static const Duration gardenToast = Duration(milliseconds: 2500);

  /// Journal confirmations stay 3 s, then disappear without a fade.
  static const Duration journalToast = Duration(seconds: 3);
  static const Duration profileToast = Duration(milliseconds: 3200);
  static const Duration profileSegment = Duration(milliseconds: 150);
  static const Duration profileToggle = Duration(milliseconds: 200);
  static const Duration gardenBreathPhase = Duration(seconds: 4);
  static const Duration gardenBreathSession = Duration(minutes: 2);

  /// Compaction de la capsule (hauteur, padding, largeur des labels).
  static const Duration capsuleCompact = Duration(milliseconds: 250);

  /// Fondu des labels de la capsule.
  static const Duration capsuleLabelFade = Duration(milliseconds: 200);

  /// Entrée rise d'un bloc de contenu.
  static const Duration entryRise = Duration(milliseconds: 550);

  /// Écart entre deux blocs de contenu qui entrent.
  static const Duration entryStagger = Duration(milliseconds: 70);

  /// Face d'humeur sélectionnée (scale 1 → 1,08).
  static const Duration moodFaceTap = Duration(milliseconds: 150);

  /// Fond de la carte réponse entre surface et soft pink.
  static const Duration answerBackground = Duration(milliseconds: 300);

  /// Fondu croisé du texte de la réponse.
  static const Duration answerTextFade = Duration(milliseconds: 150);

  /// Taille intrinsèque de la carte réponse.
  static const Duration answerSize = Duration(milliseconds: 200);

  /// Hop vertical de la mascotte (0, -12, 0).
  static const Duration mascotHop = Duration(milliseconds: 420);

  /// Pop d'essayage d'un preset ou d'un accessoire accepté.
  static const Duration previewPop = Duration(milliseconds: 380);

  /// Anneau de sélection d'un preset du dressing.
  static const Duration presetRing = Duration(milliseconds: 150);

  /// Recoloration du héros au changement de palette.
  static const Duration paletteFilter = Duration(milliseconds: 450);

  /// Entrée d'une feuille (Série, Fleurs, dressing).
  static const Duration sheetEnter = Duration(milliseconds: 380);

  /// Voile d'une feuille Série ou Fleurs.
  static const Duration sheetVeil = Duration(milliseconds: 250);

  /// Glissement d'une page entière, la durée d'une page Cupertino.
  static const Duration pageSlide = Duration(milliseconds: 500);

  /// Fondu modal autorisé en mouvement réduit : aucune translation.
  static const Duration modalFade = Duration(milliseconds: 150);

  /// Transformée du panneau calendrier (scale + translation).
  static const Duration calendarTransform = Duration(milliseconds: 280);

  /// Opacité du panneau et du voile calendrier.
  static const Duration calendarFade = Duration(milliseconds: 200);

  /// Rotation du chevron du bouton date.
  static const Duration dateChevron = Duration(milliseconds: 250);

  /// Check d'un rituel qui grossit (0,6 → 1).
  static const Duration ritualCheck = Duration(milliseconds: 240);

  /// Croissance d'une fleur du parterre (tige puis pétales).
  static const Duration flowerGrow = Duration(milliseconds: 420);

  /// Écart entre deux fleurs du parterre.
  static const Duration flowerStagger = Duration(milliseconds: 60);

  /// Montée d'une rangée de jours du calendrier.
  static const Duration calendarRowRise = Duration(milliseconds: 220);

  /// Écart entre deux rangées de jours.
  static const Duration calendarRowStagger = Duration(milliseconds: 25);

  /// Count-up du « N jours » de la feuille Série.
  static const Duration countUp = Duration(milliseconds: 900);

  /// Remplissage décalé des points de semaine.
  static const Duration weekDotStagger = Duration(milliseconds: 50);

  /// Progression du count-up selon la formule de la maquette
  /// `1-(1-k)^3`, avec k le temps écoulé normalisé.
  static double countUpProgress(double t) {
    final k = t.clamp(0.0, 1.0);
    return 1 - math.pow(1 - k, 3).toDouble();
  }
}
