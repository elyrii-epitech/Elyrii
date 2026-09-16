import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../../design_system/haptics/elyrii_haptics.dart';

class LiquidGlassSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> segments;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;

  const LiquidGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final entries = segments.entries.toList(growable: false);
    final selectedIndex = entries.indexWhere(
      (entry) => entry.key == selectedValue,
    );
    assert(selectedIndex >= 0, 'selectedValue must exist in segments');

    return GlassSegmentedControl(
      segments: [for (final entry in entries) GlassSegment(label: entry.value)],
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onSegmentSelected: (index) => onValueChanged(entries[index].key),
      height: 36,
      borderRadius: 10,
      useOwnLayer: true,
    );
  }
}

class LiquidGlassSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;

  const LiquidGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSwitch(
      value: value,
      onChanged: (nextValue) {
        ElyriiHaptics.selection();
        onChanged(nextValue);
      },
      activeColor: activeColor ?? Theme.of(context).primaryColor,
      width: 51,
      height: 31,
      useOwnLayer: true,
      enableHaptics: false,
    );
  }
}

class LiquidGlassSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color? activeColor;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GlassSlider(
      value: value,
      min: min,
      max: max,
      activeColor: activeColor ?? Theme.of(context).primaryColor,
      useOwnLayer: true,
      onChanged: onChanged,
    );
  }
}
