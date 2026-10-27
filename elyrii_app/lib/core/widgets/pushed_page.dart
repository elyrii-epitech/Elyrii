import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';
import 'glass_bar_button.dart';
import 'night_painter.dart';

final _bandFilter = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(1.7),
  inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
);

class PushedPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  final VoidCallback? onBack;
  const PushedPage({
    super.key,
    required this.title,
    required this.children,
    this.trailing,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.paddingOf(context);
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
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.spacing20,
                      safe.top + AppDimensions.profileTop,
                      AppDimensions.spacing20,
                      safe.bottom + AppDimensions.spacing48,
                    ),
                    children: children,
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
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
                  Positioned(
                    top: safe.top,
                    left: AppDimensions.spacing20,
                    right: AppDimensions.spacing20,
                    child: SizedBox(
                      height: AppDimensions.accueilBarHeight,
                      child: Row(
                        children: [
                          GlassBarButton(
                            icon: Icons.chevron_left_rounded,
                            tooltip: 'Retour',
                            onPressed:
                                onBack ??
                                () => Navigator.of(context).maybePop(),
                          ),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.navTitle(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                          trailing ??
                              const SizedBox(width: AppDimensions.controlSize),
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
