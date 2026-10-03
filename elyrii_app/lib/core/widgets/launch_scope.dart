import 'package:flutter/widgets.dart';

/// Lets platform views wait until the launch overlay has fully disappeared.
/// Routed pages can still mount and restore their state during the reveal.
class LaunchScope extends InheritedWidget {
  const LaunchScope({
    super.key,
    required this.isRevealing,
    required super.child,
  });

  final bool isRevealing;

  static bool isRevealingOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LaunchScope>()?.isRevealing ??
      false;

  @override
  bool updateShouldNotify(LaunchScope oldWidget) =>
      isRevealing != oldWidget.isRevealing;
}
