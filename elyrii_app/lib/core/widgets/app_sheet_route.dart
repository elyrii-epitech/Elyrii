import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
  final bool dragDismissible;
  final bool Function()? canDismiss;
  final Rect? cardOrigin;

  AppSheetRoute({
    required this.builder,
    required this.reduced,
    this.transparentVeil = false,
    this.calendar = false,
    this.dragDismissible = true,
    this.canDismiss,
    this.cardOrigin,
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
      child: calendar || !dragDismissible
          ? Builder(builder: builder)
          : Align(
              alignment: cardOrigin == null
                  ? Alignment.bottomCenter
                  : Alignment.center,
              child: _SheetDragDismiss(
                reduced: reduced,
                canDismiss: canDismiss,
                child: Builder(builder: builder),
              ),
            ),
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
            : cardOrigin != null
            ? Transform.translate(
                offset:
                    (cardOrigin!.center -
                        MediaQuery.sizeOf(context).center(Offset.zero)) *
                    (1 - rise),
                child: Transform.scale(
                  scale:
                      AppDimensions.accueilPreviewPopScale +
                      (1 - AppDimensions.accueilPreviewPopScale) * rise,
                  child: Opacity(opacity: k, child: child),
                ),
              )
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
              child: Semantics(
                label: barrierLabel,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: veilAlpha * veil),
                  ),
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

class _SheetDragDismiss extends StatefulWidget {
  final Widget child;
  final bool reduced;
  final bool Function()? canDismiss;

  const _SheetDragDismiss({
    required this.child,
    required this.reduced,
    this.canDismiss,
  });

  @override
  State<_SheetDragDismiss> createState() => _SheetDragDismissState();
}

class _SheetDragDismissState extends State<_SheetDragDismiss>
    with SingleTickerProviderStateMixin {
  final _panel = GlobalKey();
  late final _offset = AnimationController.unbounded(vsync: this);
  int? _pointer;
  Offset _start = Offset.zero;
  VelocityTracker? _velocity;
  bool _blocked = false;
  bool _dragging = false;

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent event) {
    if (_pointer != null) return;
    _offset.stop();
    _pointer = event.pointer;
    _start = event.position - Offset(0, _offset.value);
    _blocked = false;
    _dragging = false;
    _velocity = VelocityTracker.withKind(event.kind)
      ..addPosition(event.timeStamp, event.position);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer) return;
    _velocity?.addPosition(event.timeStamp, event.position);
    final distance = event.position - _start;
    if (_blocked ||
        (!_dragging &&
            (distance.dy <= kTouchSlop ||
                distance.dx.abs() > distance.dy.abs()))) {
      return;
    }
    _dragging = true;
    _offset.value = math.max(0, distance.dy);
  }

  void _restore() {
    if (widget.reduced) {
      _offset.value = 0;
    } else {
      _offset.animateTo(
        0,
        duration: AppMotion.sheetEnter,
        curve: AppMotion.accueilRise,
      );
    }
  }

  Future<void> _up(PointerUpEvent event) async {
    if (event.pointer != _pointer) return;
    _pointer = null;
    final route = ModalRoute.of(context);
    final height = _panel.currentContext?.size?.height ?? double.infinity;
    final velocity = _velocity?.getVelocity().pixelsPerSecond.dy ?? 0;
    final dismiss =
        _dragging &&
        (_offset.value >= height * AppDimensions.sheetDismissFraction ||
            velocity >= AppDimensions.sheetDismissVelocity);
    if (dismiss && (widget.canDismiss?.call() ?? true)) {
      await Navigator.of(context).maybePop();
    }
    if (mounted && route?.isActive == true) _restore();
  }

  bool _scroll(ScrollNotification notification) {
    if (_pointer != null && notification is ScrollStartNotification) {
      // A scroll that starts below the top must never dismiss its sheet.
      _blocked =
          notification.metrics.axis != Axis.vertical ||
          notification.metrics.extentBefore > 0;
      if (_blocked) {
        _dragging = false;
        _offset.value = 0;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _down,
    onPointerMove: _move,
    onPointerUp: _up,
    onPointerCancel: (event) {
      if (event.pointer != _pointer) return;
      _pointer = null;
      _restore();
    },
    child: NotificationListener<ScrollNotification>(
      onNotification: _scroll,
      child: AnimatedBuilder(
        animation: _offset,
        child: KeyedSubtree(key: _panel, child: widget.child),
        builder: (context, child) =>
            Transform.translate(offset: Offset(0, _offset.value), child: child),
      ),
    ),
  );
}

class AppSheetDragHandle extends StatelessWidget {
  final Widget child;
  const AppSheetDragHandle({super.key, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) {
      context.findAncestorStateOfType<_SheetDragDismissState>()?._blocked =
          false;
    },
    child: child,
  );
}

/// The standard opaque sheet with safe content above the home indicator.
class AppSheetPanel extends StatelessWidget {
  final String title;
  final Widget child;
  final bool scrollable;
  const AppSheetPanel({
    super.key,
    required this.title,
    required this.child,
    this.scrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safe = MediaQuery.paddingOf(context);
    const radius = BorderRadius.vertical(
      top: Radius.circular(AppDimensions.radius38),
    );
    return LayoutBuilder(
      builder: (context, constraints) => Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: AppDimensions.maxContentWidth,
              maxHeight:
                  constraints.maxHeight -
                  safe.top -
                  MediaQuery.viewInsetsOf(context).bottom -
                  AppDimensions.spacing24,
            ),
            child: Material(
              color: Colors.transparent,
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title,
                child: Material(
                  color: AppColors.sheetSurface(dark),
                  borderRadius: radius,
                  clipBehavior: Clip.antiAlias,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppDimensions.spacing20,
                      AppDimensions.spacing8,
                      AppDimensions.spacing20,
                      safe.bottom + AppDimensions.spacing24,
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
                              color: context.textTertiary.withValues(alpha: .5),
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
                        Flexible(
                          child: scrollable
                              ? SingleChildScrollView(
                                  physics: const ClampingScrollPhysics(),
                                  child: child,
                                )
                              : child,
                        ),
                      ],
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
