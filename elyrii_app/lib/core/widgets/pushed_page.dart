import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';
import 'night_painter.dart';

final _bandFilter = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(1.7),
  inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
);

class PushedPage extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback? onBack;
  final bool profileHeader;
  const PushedPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onBack,
    this.profileHeader = false,
  });
  @override
  State<PushedPage> createState() => _PushedPageState();
}

class _PushedPageState extends State<PushedPage> {
  final _scroll = ScrollController();
  bool _band = false;
  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final band = _scroll.offset > AppDimensions.profileScrollThreshold;
      if (band != _band) setState(() => _band = band);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.paddingOf(context);
    final visible = !widget.profileHeader || _band;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : AppMotion.bandFade;
    return Scaffold(
      backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: NightPainter(dark)),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppDimensions.maxContentWidth,
              ),
              child: Stack(
                children: [
                  ListView(
                    controller: _scroll,
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.spacing20,
                      safe.top +
                          (widget.profileHeader
                              ? AppDimensions.profileHeaderTop
                              : AppDimensions.profileTop),
                      AppDimensions.spacing20,
                      safe.bottom + AppDimensions.spacing48,
                    ),
                    children: widget.children,
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: visible ? 1 : 0,
                      duration: duration,
                      curve: AppMotion.accueilEase,
                      child: ClipRect(
                        child: BackdropFilter(
                          filter: _bandFilter,
                          child: Container(
                            height: safe.top + AppDimensions.accueilBarHeight,
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.glassBackgroundDark
                                  : AppColors.glassBackgroundLight,
                              border: Border(
                                bottom: BorderSide(
                                  width: AppDimensions.profileHairline,
                                  color: dark
                                      ? AppColors.dividerDark
                                      : AppColors.dividerLight,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: safe.top,
                    left: AppDimensions.spacing20,
                    right: AppDimensions.spacing20,
                    child: SizedBox(
                      height: AppDimensions.accueilBarHeight,
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Retour',
                            onPressed:
                                widget.onBack ??
                                () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: AnimatedOpacity(
                              opacity: visible ? 1 : 0,
                              duration: duration,
                              curve: AppMotion.accueilEase,
                              child: Text(
                                widget.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.navTitle(
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          widget.trailing ??
                              const SizedBox(
                                width: AppDimensions.accueilHeaderControl,
                              ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
