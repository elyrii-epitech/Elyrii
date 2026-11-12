import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// Named durations and three curves of Home's v2 motion contract. Sections
/// choose a role here instead of hardcoding durations or curves. Curves come
/// from the mockup's CSS easings: ease is `cubic-bezier(.25,.1,.25,1)`, rise
/// entry uses `cubic-bezier(.22,.8,.24,1)`, and pop bounces use
/// `cubic-bezier(.3,1.4,.5,1)`, including overshoot.
abstract final class AppMotion {
  /// `cubic-bezier(.25,.1,.25,1)` for the band, capsule, response background,
  /// and scrims.
  static const Cubic accueilEase = Cubic(0.25, 0.1, 0.25, 1);

  /// `cubic-bezier(.22,.8,.24,1)` for rise entries, sheets, and calendar.
  static const Cubic accueilRise = Cubic(0.22, 0.8, 0.24, 1);

  /// `cubic-bezier(.3,1.4,.5,1)` for mascot hops, outfit preview pops, and checkmarks.
  static const Cubic accueilPop = Cubic(0.3, 1.4, 0.5, 1);

  static const Cubic meditationBreath = Cubic(.42, 0, .58, 1);

  /// Top glass-band opacity.
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

  /// Capsule compaction: height, padding, and label width.
  static const Duration capsuleCompact = Duration(milliseconds: 250);

  /// Capsule label fade.
  static const Duration capsuleLabelFade = Duration(milliseconds: 200);

  /// Rise entry of a content block.
  static const Duration entryRise = Duration(milliseconds: 550);

  /// Stagger between entering content blocks.
  static const Duration entryStagger = Duration(milliseconds: 70);

  /// Selected mood face scale: 1 to 1.08.
  static const Duration moodFaceTap = Duration(milliseconds: 150);

  /// Response card background transition between surface and soft pink.
  static const Duration answerBackground = Duration(milliseconds: 300);

  /// Response text crossfade.
  static const Duration answerTextFade = Duration(milliseconds: 150);

  /// Intrinsic response card size.
  static const Duration answerSize = Duration(milliseconds: 200);

  /// Vertical mascot hop: 0, -12, 0.
  static const Duration mascotHop = Duration(milliseconds: 420);

  /// Outfit preview pop for an accepted preset or accessory.
  static const Duration previewPop = Duration(milliseconds: 380);

  /// Dressing-room preset selection ring.
  static const Duration presetRing = Duration(milliseconds: 150);

  /// Hero recoloring when the palette changes.
  static const Duration paletteFilter = Duration(milliseconds: 450);

  /// Sheet entry for streak, flowers, and dressing room.
  static const Duration sheetEnter = Duration(milliseconds: 380);

  /// Streak or flowers sheet scrim.
  static const Duration sheetVeil = Duration(milliseconds: 250);

  /// Full-page slide using Cupertino page duration.
  static const Duration pageSlide = Duration(milliseconds: 500);

  /// Modal fade allowed with reduced motion, without translation.
  static const Duration modalFade = Duration(milliseconds: 150);

  /// Calendar panel transform: scale and translation.
  static const Duration calendarTransform = Duration(milliseconds: 280);

  /// Calendar panel and scrim opacity.
  static const Duration calendarFade = Duration(milliseconds: 200);

  /// Date button chevron rotation.
  static const Duration dateChevron = Duration(milliseconds: 250);

  /// Growing ritual checkmark: scale 0.6 to 1.
  static const Duration ritualCheck = Duration(milliseconds: 240);

  /// Garden flower growth: stem, then petals.
  static const Duration flowerGrow = Duration(milliseconds: 420);

  /// Stagger between garden flowers.
  static const Duration flowerStagger = Duration(milliseconds: 60);

  /// Calendar day-row rise.
  static const Duration calendarRowRise = Duration(milliseconds: 220);

  /// Stagger between day rows.
  static const Duration calendarRowStagger = Duration(milliseconds: 25);

  /// Day-count animation in the streak sheet.
  static const Duration countUp = Duration(milliseconds: 900);

  /// Staggered filling of week dots.
  static const Duration weekDotStagger = Duration(milliseconds: 50);

  /// Count-up progress using the mockup's `1-(1-k)^3` formula, where k is
  /// normalized elapsed time.
  static double countUpProgress(double t) {
    final k = t.clamp(0.0, 1.0);
    return 1 - math.pow(1 - k, 3).toDouble();
  }
}
