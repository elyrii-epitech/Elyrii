import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../controllers/meditation_controller.dart';

/// A native countdown wheel: every minute is available, without duration presets.
class MeditationDurationSheet extends StatefulWidget {
  const MeditationDurationSheet({super.key, required this.initialDuration});

  final Duration initialDuration;

  @override
  State<MeditationDurationSheet> createState() =>
      _MeditationDurationSheetState();
}

class _MeditationDurationSheetState extends State<MeditationDurationSheet> {
  late Duration _duration = widget.initialDuration;

  bool get _canChoose =>
      _duration.inMinutes >= MeditationController.minDurationMinutes;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primaryDark : AppColors.primary;

    return ElyriiGlassSurface(
      role: GlassRole.modalSheet,
      borderRadius: BorderRadius.circular(32),
      glassColor: MediaQuery.highContrastOf(context)
          ? null
          : isDark
          ? const Color(0xFF28232F).withValues(alpha: 0.78)
          : const Color(0xFFF8F6FF).withValues(alpha: 0.76),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: secondaryColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Durée',
                      style: AppTextStyles.titleLarge(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('meditation-duration-close'),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close_rounded, color: secondaryColor),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Un moment à ton rythme.',
                  style: AppTextStyles.bodyMedium(color: secondaryColor),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: 'Durée de la séance',
                value: MeditationController.formatDuration(_duration),
                child: CupertinoTheme(
                  data: CupertinoThemeData(
                    brightness: theme.brightness,
                    primaryColor: accent,
                    textTheme: CupertinoTextThemeData(
                      pickerTextStyle: TextStyle(
                        fontFamily: 'CupertinoSystemText',
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: textColor,
                      ),
                    ),
                  ),
                  child: Localizations.override(
                    context: context,
                    locale: const Locale('fr'),
                    delegates: const [GlobalCupertinoLocalizations.delegate],
                    child: CupertinoTimerPicker(
                      key: const Key('meditation-duration-wheel'),
                      mode: CupertinoTimerPickerMode.hm,
                      initialTimerDuration: widget.initialDuration,
                      backgroundColor: Colors.transparent,
                      onTimerDurationChanged: (duration) {
                        setState(() => _duration = duration);
                      },
                      selectionOverlayBuilder:
                          (
                            context, {
                            required selectedIndex,
                            required columnCount,
                          }) {
                            return CupertinoPickerDefaultSelectionOverlay(
                              background: accent.withValues(alpha: 0.08),
                              capStartEdge: selectedIndex == 0,
                              capEndEdge: selectedIndex == columnCount - 1,
                            );
                          },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Semantics(
                liveRegion: true,
                child: Text(
                  _canChoose
                      ? MeditationController.formatDuration(_duration)
                      : 'Choisis au moins une minute.',
                  key: const Key('meditation-duration-value'),
                  style: AppTextStyles.bodyMedium(color: secondaryColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              Semantics(
                button: true,
                enabled: _canChoose,
                child: LiquidGlassButton(
                  key: const Key('meditation-duration-confirm'),
                  label: 'Choisir cette durée',
                  isExpanded: true,
                  onPressed: _canChoose
                      ? () => Navigator.pop<Duration>(context, _duration)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
