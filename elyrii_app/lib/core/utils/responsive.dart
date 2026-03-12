import 'package:flutter/material.dart';

/// Breakpoint definitions following Material Design 3 guidelines
/// Adapted for mobile-first approach with foldable device support
enum Breakpoint {
  /// Compact phones (< 360dp) - small SE-style devices
  compact,

  /// Standard phones (360-599dp) - most phones
  phone,

  /// Large phones/Foldables expanded (600-839dp)
  foldable,

  /// Tablets (840-1199dp)
  tablet,

  /// Large tablets/Desktop (≥ 1200dp)
  desktop,
}

/// Breakpoint thresholds in logical pixels
class BreakpointThresholds {
  static const double compact = 360;
  static const double phone = 600;
  static const double foldable = 840;
  static const double tablet = 1200;
}

/// Responsive utilities for adaptive layouts
class Responsive {
  /// Get the current breakpoint based on screen width
  static Breakpoint getBreakpoint(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return getBreakpointFromWidth(width);
  }

  /// Get breakpoint from a specific width value
  static Breakpoint getBreakpointFromWidth(double width) {
    if (width < BreakpointThresholds.compact) return Breakpoint.compact;
    if (width < BreakpointThresholds.phone) return Breakpoint.phone;
    if (width < BreakpointThresholds.foldable) return Breakpoint.foldable;
    if (width < BreakpointThresholds.tablet) return Breakpoint.tablet;
    return Breakpoint.desktop;
  }

  /// Check if current device is a phone (compact or standard)
  static bool isPhone(BuildContext context) {
    final bp = getBreakpoint(context);
    return bp == Breakpoint.compact || bp == Breakpoint.phone;
  }

  /// Check if current device is tablet or larger
  static bool isTablet(BuildContext context) {
    final bp = getBreakpoint(context);
    return bp == Breakpoint.tablet || bp == Breakpoint.desktop;
  }

  /// Check if device is in foldable/large phone range
  static bool isFoldable(BuildContext context) {
    return getBreakpoint(context) == Breakpoint.foldable;
  }

  /// Check if device is larger than phone
  static bool isLargerThanPhone(BuildContext context) {
    final bp = getBreakpoint(context);
    return bp == Breakpoint.foldable ||
        bp == Breakpoint.tablet ||
        bp == Breakpoint.desktop;
  }

  /// Get appropriate column count for grids
  static int getGridColumns(BuildContext context) {
    switch (getBreakpoint(context)) {
      case Breakpoint.compact:
        return 1;
      case Breakpoint.phone:
        return 2;
      case Breakpoint.foldable:
        return 3;
      case Breakpoint.tablet:
        return 4;
      case Breakpoint.desktop:
        return 6;
    }
  }

  /// Get horizontal padding based on screen size
  static double getHorizontalPadding(BuildContext context) {
    switch (getBreakpoint(context)) {
      case Breakpoint.compact:
        return 12;
      case Breakpoint.phone:
        return 16;
      case Breakpoint.foldable:
        return 24;
      case Breakpoint.tablet:
        return 32;
      case Breakpoint.desktop:
        return 48;
    }
  }

  /// Get content max width for centering on large screens
  static double? getMaxContentWidth(BuildContext context) {
    switch (getBreakpoint(context)) {
      case Breakpoint.compact:
      case Breakpoint.phone:
      case Breakpoint.foldable:
        return null; // Full width
      case Breakpoint.tablet:
        return 800;
      case Breakpoint.desktop:
        return 1200;
    }
  }
}

/// Widget for building responsive layouts with different builders per breakpoint
class ResponsiveBuilder extends StatelessWidget {
  /// Builder for compact phones
  final Widget Function(BuildContext context)? compact;

  /// Builder for standard phones (required, used as fallback)
  final Widget Function(BuildContext context) phone;

  /// Builder for foldable/large phones
  final Widget Function(BuildContext context)? foldable;

  /// Builder for tablets
  final Widget Function(BuildContext context)? tablet;

  /// Builder for desktop
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveBuilder({
    super.key,
    this.compact,
    required this.phone,
    this.foldable,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final breakpoint = Responsive.getBreakpoint(context);

    switch (breakpoint) {
      case Breakpoint.compact:
        return (compact ?? phone)(context);
      case Breakpoint.phone:
        return phone(context);
      case Breakpoint.foldable:
        return (foldable ?? phone)(context);
      case Breakpoint.tablet:
        return (tablet ?? foldable ?? phone)(context);
      case Breakpoint.desktop:
        return (desktop ?? tablet ?? foldable ?? phone)(context);
    }
  }
}

/// Widget that constrains content width on larger screens
class ResponsiveConstrainedBox extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveConstrainedBox({
    super.key,
    required this.child,
    this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth =
        maxWidth ?? Responsive.getMaxContentWidth(context);

    if (effectiveMaxWidth == null) {
      return child;
    }

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: child,
      ),
    );
  }
}

/// Widget that applies responsive horizontal padding
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double? verticalPadding;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.verticalPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.getHorizontalPadding(context),
        vertical: verticalPadding ?? 0,
      ),
      child: child,
    );
  }
}

/// Extension methods for easy access in widgets
extension ResponsiveContext on BuildContext {
  /// Current breakpoint
  Breakpoint get breakpoint => Responsive.getBreakpoint(this);

  /// Is phone (compact or standard)
  bool get isPhone => Responsive.isPhone(this);

  /// Is tablet or larger
  bool get isTablet => Responsive.isTablet(this);

  /// Is foldable device
  bool get isFoldable => Responsive.isFoldable(this);

  /// Is larger than phone
  bool get isLargerThanPhone => Responsive.isLargerThanPhone(this);

  /// Grid column count for current screen
  int get gridColumns => Responsive.getGridColumns(this);

  /// Horizontal padding for current screen
  double get horizontalPadding => Responsive.getHorizontalPadding(this);

  /// Max content width (null for full width)
  double? get maxContentWidth => Responsive.getMaxContentWidth(this);
}
