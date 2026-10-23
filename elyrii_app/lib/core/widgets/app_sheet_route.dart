import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_motion.dart';
import '../theme/app_text_styles.dart';

/// The app's single modal route: sheets slide up over a veil, the Accueil
/// calendar drops from the bar, and reduced motion only fades.
class AppSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final bool reduced;

  /// Previews such as the dressing keep the page visible behind the sheet.
  final bool transparentVeil;
  final bool calendar;
  final bool Function()? canDismiss;

  AppSheetRoute({
    required this.builder,
    required this.reduced,
    this.transparentVeil = false,
    this.calendar = false,
    this.canDismiss,
  });

  @override
  bool didPop(T? result) =>
      (canDismiss?.call() ?? true) && super.didPop(result);
  @override
  Color get barrierColor => Colors.transparent;
  @override
  bool get barrierDismissible => true;
  @override
  String get barrierLabel => 'Fermer la présentation';
  @override
  Duration get transitionDuration => reduced
      ? AppMotion.modalFade
      : calendar
      ? AppMotion.calendarTransform
      : AppMotion.sheetEnter;

  double _share(double k, Duration part) =>
      (k * transitionDuration.inMicroseconds / math.max(1, part.inMicroseconds))
          .clamp(0, 1);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final veilAlpha = transparentVeil
        ? 0.0
        : calendar
        ? (dark ? .35 : .15)
        : (dark ? .42 : .20);
    return AnimatedBuilder(
      animation: animation,
      child: Builder(builder: builder),
      builder: (context, child) {
        final k = animation.value;
        final rise = AppMotion.accueilRise.transform(k);
        final veil = reduced
            ? k
            : AppMotion.accueilEase.transform(
                _share(
                  k,
                  calendar ? AppMotion.calendarFade : AppMotion.sheetVeil,
                ),
              );
        final panel = reduced
            ? Opacity(opacity: k, child: child)
            : calendar
            ? Transform.translate(
                offset: Offset(
                  0,
                  -AppDimensions.accueilCalendarRiseDistance * (1 - rise),
                ),
                child: Transform.scale(
                  scale: .94 + .06 * rise,
                  alignment: Alignment.topCenter,
                  child: Opacity(
                    opacity: AppMotion.accueilEase.transform(
                      _share(k, AppMotion.calendarFade),
                    ),
                    child: child,
                  ),
                ),
              )
            : FractionalTranslation(
                translation: Offset(0, 1.05 * (1 - rise)),
                child: child,
              );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).maybePop(),
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: veilAlpha * veil),
                ),
              ),
            ),
            panel,
          ],
        );
      },
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

final _glass = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(1.7),
  inner: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
);

/// The standard glass sheet of the v2 boards: grabber, title, close button.
class AppSheetPanel extends StatelessWidget {
  final String title;
  final Widget child;
  const AppSheetPanel({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.paddingOf(context);
    final radius = BorderRadius.circular(AppDimensions.radius38);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.spacing8,
          0,
          AppDimensions.spacing8,
          safe.bottom + AppDimensions.spacing8,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
            maxHeight:
                MediaQuery.sizeOf(context).height -
                safe.top -
                AppDimensions.spacing24,
          ),
          child: Material(
            color: Colors.transparent,
            child: Semantics(
              scopesRoute: true,
              namesRoute: true,
              explicitChildNodes: true,
              label: title,
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: _glass,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.sheetGlass(dark),
                      borderRadius: radius,
                      border: Border.all(
                        color: dark
                            ? AppColors.glassBorderDark
                            : AppColors.glassBorderLight,
                        width: .5,
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.spacing20,
                        AppDimensions.spacing8,
                        AppDimensions.spacing20,
                        AppDimensions.spacing24,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: AppDimensions.grabberWidth,
                              height: AppDimensions.grabberHeight,
                              decoration: BoxDecoration(
                                color: context.textTertiary.withValues(
                                  alpha: .5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppDimensions.radius4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: AppDimensions.accueilHeaderControl,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.titleLarge(
                                      color: context.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Fermer',
                                  onPressed: () =>
                                      Navigator.of(context).maybePop(),
                                  style: IconButton.styleFrom(
                                    backgroundColor: dark
                                        ? AppColors.cardDark
                                        : AppColors.cardLight,
                                  ),
                                  icon: Icon(
                                    Symbols.close_rounded,
                                    size: AppDimensions.iconSm,
                                    color: context.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacing16),
                          child,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
