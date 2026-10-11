import 'package:flutter/material.dart';

import '../../design_system/haptics/elyrii_haptics.dart';
import '../../theme/app_text_styles.dart';

class LiquidGlassSegmentedControl<T> extends StatelessWidget {
  final Map<T, String> segments;
  final T selectedValue;
  final ValueChanged<T> onValueChanged;
  final double height;

  const LiquidGlassSegmentedControl({
    super.key,
    required this.segments,
    required this.selectedValue,
    required this.onValueChanged,
    this.height = 48,
  });

  @override
  Widget build(BuildContext context) {
    assert(segments.containsKey(selectedValue));
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final entry in segments.entries)
          ChoiceChip(
            label: Text(
              entry.value,
              style: AppTextStyles.labelLarge(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            selectedColor: Theme.of(context).colorScheme.primaryContainer,
            selected: entry.key == selectedValue,
            materialTapTargetSize: MaterialTapTargetSize.padded,
            onSelected: (_) => onValueChanged(entry.key),
          ),
      ],
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
    return Switch.adaptive(
      value: value,
      onChanged: (nextValue) {
        ElyriiHaptics.selection();
        onChanged(nextValue);
      },
      activeThumbColor: activeColor ?? Theme.of(context).primaryColor,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

class LiquidGlassSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;
  final Color? activeColor;
  final String? semanticLabel;

  const LiquidGlassSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.activeColor,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Slider.adaptive(
        value: value,
        min: min,
        max: max,
        activeColor: activeColor ?? Theme.of(context).primaryColor,
        divisions: 100,
        semanticFormatterCallback: (value) =>
            '${((value - min) / (max - min) * 100).round()} pour cent',
        onChanged: onChanged,
      ),
    );
  }
}
