import 'package:flutter/material.dart';

class AccessibilityService {
  bool reduceMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  bool largeText(BuildContext context) {
    final scaler = MediaQuery.maybeOf(context)?.textScaler;
    return (scaler?.scale(1.0) ?? 1.0) >= 1.25;
  }

  bool highContrast(BuildContext context) {
    return MediaQuery.maybeOf(context)?.highContrast ?? false;
  }
}
