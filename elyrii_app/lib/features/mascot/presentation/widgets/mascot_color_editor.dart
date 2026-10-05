import 'package:flutter/material.dart';

import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../data/models/mascot_appearance.dart';
import '../../data/models/mascot_model.dart';

class MascotColorEditor extends StatefulWidget {
  const MascotColorEditor({
    super.key,
    required this.mascot,
    required this.onChanged,
    this.onEditStart,
    this.onEditEnd,
  });
  final MascotModel mascot;
  final ValueChanged<MascotModel> onChanged;
  final VoidCallback? onEditStart;
  final VoidCallback? onEditEnd;

  @override
  State<MascotColorEditor> createState() => _MascotColorEditorState();
}

class _MascotColorEditorState extends State<MascotColorEditor> {
  MascotColorPart _part = MascotColorPart.body;
  final _hex = TextEditingController();
  final _hexFocus = FocusNode();
  String? _error;

  static const _labels = {
    MascotColorPart.body: 'Corps',
    MascotColorPart.details: 'Détails',
    MascotColorPart.ears: 'Oreilles & joues',
    MascotColorPart.eyes: 'Yeux',
    MascotColorPart.accessories: 'Accessoires',
  };
  static const _defaults = {
    'body': '#EBCFAE',
    'details': '#F1EEE8',
    'ears': '#FE9186',
    'eyes': '#543349',
    'accessories': '#ADA0CE',
  };
  static const _swatches = {
    'Crème': '#EBCFAE',
    'Lavande': '#B8A3DC',
    'Rose': '#E4A9BD',
    'Pêche': '#E8AE8D',
    'Sauge': '#A4BA9C',
    'Menthe': '#91C5BD',
    'Ciel': '#9DAFD7',
    'Prune': '#6D456F',
    'Ivoire': '#F1EEE8',
    'Encre': '#3B3549',
  };

  String get _currentHex =>
      widget.mascot.appearance.colors[_part.name] ??
      MascotThemes.colorsFor(widget.mascot.themeId)[_part.name] ??
      _defaults[_part.name]!;
  Color get _color =>
      Color(int.parse(_currentHex.substring(1), radix: 16) + 0xFF000000);

  @override
  void initState() {
    super.initState();
    _hex.text = _currentHex.substring(1);
  }

  @override
  void didUpdateWidget(MascotColorEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hexFocus.hasFocus) _hex.text = _currentHex.substring(1);
  }

  @override
  void dispose() {
    _hex.dispose();
    _hexFocus.dispose();
    super.dispose();
  }

  void _change(String hex) {
    setState(() {
      _error = null;
      _hex.text = hex.substring(1);
    });
    widget.onChanged(
      widget.mascot.copyWith(
        appearance: widget.mascot.appearance.withColor(_part, hex),
      ),
    );
  }

  void _applyHex() {
    final normalized = MascotAppearance.normalizeHex(_hex.text);
    if (normalized == null) {
      setState(() => _error = 'Saisis 6 caractères, par exemple B8A3DC.');
      return;
    }
    _hexFocus.unfocus();
    _change(normalized);
  }

  String _toHex(Color color) =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final hsv = HSVColor.fromColor(_color);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ta palette, sans limites',
          style: AppTextStyles.titleMedium(
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Chaque détail a sa couleur. Toutes les nuances sont libres.',
          style: AppTextStyles.bodySmall(color: secondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in _labels.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == _part,
                onSelected: (_) => setState(() {
                  _part = entry.key;
                  _error = null;
                  _hex.text = _currentHex.substring(1);
                  _hexFocus.unfocus();
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        LiquidGlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: dark ? Colors.white30 : Colors.black12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _labels[_part]!,
                      style: AppTextStyles.titleSmall(color: primary),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        widget.mascot.appearance.colors.containsKey(_part.name)
                        ? () {
                            _hexFocus.unfocus();
                            widget.onChanged(
                              widget.mascot.copyWith(
                                appearance: widget.mascot.appearance.withColor(
                                  _part,
                                  null,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: const Text('D’origine'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final entry in _swatches.entries)
                    _ColorSwatch(
                      name: entry.key,
                      hex: entry.value,
                      selected: _currentHex == entry.value,
                      onTap: () => _change(entry.value),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _slider(
                'Teinte',
                hsv.hue,
                360,
                (value) => _change(_toHex(hsv.withHue(value).toColor())),
                primary,
                gradient: const [
                  Colors.red,
                  Colors.yellow,
                  Colors.green,
                  Colors.cyan,
                  Colors.blue,
                  Colors.purple,
                  Colors.red,
                ],
              ),
              _slider(
                'Saturation',
                hsv.saturation,
                1,
                (value) => _change(_toHex(hsv.withSaturation(value).toColor())),
                primary,
              ),
              _slider(
                'Luminosité',
                hsv.value,
                1,
                (value) => _change(_toHex(hsv.withValue(value).toColor())),
                primary,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('mascot_hex_color'),
                controller: _hex,
                focusNode: _hexFocus,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
                maxLength: 7,
                style: AppTextStyles.bodyMedium(color: primary),
                onSubmitted: (_) => _applyHex(),
                decoration: InputDecoration(
                  labelText: 'Code couleur',
                  prefixText: '# ',
                  counterText: '',
                  errorText: _error,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  suffixIcon: IconButton(
                    tooltip: 'Appliquer la couleur',
                    onPressed: _applyHex,
                    icon: const Icon(Icons.check_rounded),
                  ),
                ),
              ),
              if (_part == MascotColorPart.accessories) ...[
                const SizedBox(height: 12),
                Text(
                  'La teinte s’applique aux tissus et aux surfaces colorées. Les détails dorés et les montures gardent leur contraste.',
                  style: AppTextStyles.bodySmall(color: secondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double max,
    ValueChanged<double> onChanged,
    Color text, {
    List<Color>? gradient,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: AppTextStyles.labelMedium(color: text)),
            ),
            Text(
              max == 360 ? '${value.round()}°' : '${(value * 100).round()} %',
              style: AppTextStyles.labelSmall(color: text),
            ),
          ],
        ),
        Semantics(
          label: label,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (gradient != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(colors: gradient),
                    ),
                  ),
                ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: gradient == null
                      ? null
                      : Colors.transparent,
                  inactiveTrackColor: gradient == null
                      ? null
                      : Colors.transparent,
                  thumbColor: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.primaryDark
                      : AppColors.primary,
                ),
                child: Slider(
                  value: value,
                  max: max,
                  onChangeStart: (_) => widget.onEditStart?.call(),
                  onChangeEnd: (_) => widget.onEditEnd?.call(),
                  onChanged: onChanged,
                  semanticFormatterCallback: (value) => max == 360
                      ? '${value.round()} degrés'
                      : '${(value * 100).round()} pour cent',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.name,
    required this.hex,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final String hex;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(int.parse(hex.substring(1), radix: 16) + 0xFF000000);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $hex',
      child: Tooltip(
        message: name,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                    border: Border.all(
                      width: selected ? 2 : 1,
                      color: selected ? AppColors.primary : Colors.black12,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color:
                              ThemeData.estimateBrightnessForColor(color) ==
                                  Brightness.dark
                              ? Colors.white
                              : const Color(0xFF302C39),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
