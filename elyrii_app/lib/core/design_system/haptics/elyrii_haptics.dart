import 'package:flutter/services.dart';

/// Central haptic system respecting user preferences. All app haptic feedback
/// MUST use this API.
abstract final class ElyriiHaptics {
  static bool _enabled = true;

  /// Whether haptic feedback is currently enabled.
  static bool get isEnabled => _enabled;

  /// Sets global haptic feedback activation, synchronized with settings.
  static void setEnabled(bool enabled) => _enabled = enabled;

  /// Light selection click for tabs, chips, and toggles.
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }

  /// Subtle impact for standard buttons and opening details.
  static void light() {
    if (!_enabled) return;
    HapticFeedback.lightImpact();
  }

  /// Medium impact for confirmation and mood saving.
  static void medium() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Success feedback for completed breathing sessions and challenges.
  static void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_enabled) HapticFeedback.lightImpact();
    });
  }

  /// Warning or session exit.
  static void warning() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
  }
}
