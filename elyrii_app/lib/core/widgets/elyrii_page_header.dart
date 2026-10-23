import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_text_styles.dart';

/// Tabs open on a large title, detail pages center their title in the bar.
enum ElyriiTitleLevel { tab, detail }

/// Scrolling page under a pinned button bar, laid out like iOS.
///
/// A tab starts with its large title as the first row of content. Scrolling
/// past it fades in a glass band and the same title, centered in the bar.
/// A detail page keeps its centered title in the bar from the start. The
/// frame also owns the bottom inset, which clears the dock on tabs because
/// the shell reports the dock height as bottom padding.
class ElyriiPageFrame extends StatefulWidget {
  const ElyriiPageFrame.tab({
    super.key,
    required this.title,
    this.eyebrow,
    this.leading,
    this.actions = const [],
    required this.slivers,
    this.controller,
  }) : level = ElyriiTitleLevel.tab;

  const ElyriiPageFrame.detail({
    super.key,
    required this.title,
    required Widget this.leading,
    this.actions = const [],
    required this.slivers,
    this.controller,
  }) : level = ElyriiTitleLevel.detail,
       eyebrow = null;

  final ElyriiTitleLevel level;
  final String title;

  /// Small accent line above the large title (the home date).
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> slivers;
  final ScrollController? controller;

  @override
  State<ElyriiPageFrame> createState() => _ElyriiPageFrameState();
}

class _ElyriiPageFrameState extends State<ElyriiPageFrame> {
  static const _collapsedAt = 56.0;
  static const _barTitleStartsAt = 24.0;
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  void _track(ScrollMetrics metrics, int depth) {
    if (depth == 0 && metrics.axis == Axis.vertical) {
      _offset.value = metrics.pixels.clamp(0, _collapsedAt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTab = widget.level == ElyriiTitleLevel.tab;
    final extent = ElyriiHeaderBar.extentOf(context);
    final barTitle = _BarTitle(title: widget.title);
    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          // Content shrinking under a collapsed bar moves the offset without
          // a scroll notification.
          NotificationListener<ScrollMetricsNotification>(
            onNotification: (n) {
              _track(n.metrics, n.depth);
              return false;
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                _track(n.metrics, n.depth);
                return false;
              },
              child: CustomScrollView(
                controller: widget.controller,
                physics: const ClampingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: SizedBox(height: extent)),
                  if (isTab)
                    SliverToBoxAdapter(
                      child: ValueListenableBuilder<double>(
                        valueListenable: _offset,
                        child: _LargeTitle(
                          title: widget.title,
                          eyebrow: widget.eyebrow,
                        ),
                        builder: (context, offset, title) => ExcludeSemantics(
                          excluding: offset > _barTitleStartsAt,
                          child: title,
                        ),
                      ),
                    ),
                  ...widget.slivers,
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height:
                          MediaQuery.paddingOf(context).bottom +
                          AppDimensions.spacing24,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: extent,
            child: _Bar(
              offset: _offset,
              leading: widget.leading,
              actions: widget.actions,
              middle: isTab
                  ? ValueListenableBuilder<double>(
                      valueListenable: _offset,
                      child: barTitle,
                      builder: (context, offset, title) {
                        final opacity = ((offset - _barTitleStartsAt) / 24)
                            .clamp(0.0, 1.0);
                        return opacity == 0
                            ? const SizedBox.shrink()
                            : Opacity(opacity: opacity, child: title);
                      },
                    )
                  : barTitle,
            ),
          ),
        ],
      ),
    );
  }
}

/// Permanent top bar (chat): glass behind floating buttons and a centered
/// title.
class ElyriiHeaderBar extends StatelessWidget {
  const ElyriiHeaderBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  /// Button row height below the status bar, padding included.
  static const rowExtent =
      AppDimensions.spacing12 +
      AppDimensions.controlSize +
      AppDimensions.spacing12;

  static double extentOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + rowExtent;

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: extentOf(context),
    child: _Bar(
      leading: leading,
      actions: actions,
      middle: _BarTitle(title: title),
    ),
  );
}

/// The pinned bar: it owns every tap inside its bounds, so content scrolled
/// underneath never receives them.
class _Bar extends StatelessWidget {
  const _Bar({
    this.offset,
    this.leading,
    required this.actions,
    required this.middle,
  });

  /// Scroll offset that fades the glass in over the first 12 px. Without
  /// one, the glass is always on.
  final ValueListenable<double>? offset;
  final Widget? leading;
  final List<Widget> actions;
  final Widget middle;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
      Positioned.fill(
        child: switch (offset) {
          final offset? => ValueListenableBuilder<double>(
            valueListenable: offset,
            builder: (context, pixels, _) =>
                _GlassBand(glass: (pixels / 12).clamp(0.0, 1.0)),
          ),
          null => const _GlassBand(glass: 1),
        },
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(
          AppDimensions.pageHorizontalPadding,
          MediaQuery.paddingOf(context).top + AppDimensions.spacing12,
          AppDimensions.pageHorizontalPadding,
          AppDimensions.spacing12,
        ),
        child: SizedBox(
          height: AppDimensions.controlSize,
          child: NavigationToolbar(
            leading: leading,
            middle: middle,
            trailing: actions.isEmpty
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: AppDimensions.spacing8,
                    children: actions,
                  ),
            middleSpacing: AppDimensions.spacing12,
          ),
        ),
      ),
    ],
  );
}

class _GlassBand extends StatelessWidget {
  const _GlassBand({required this.glass});

  final double glass;

  @override
  Widget build(BuildContext context) {
    if (glass == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = isDark ? AppColors.scaffoldDark : AppColors.scaffoldLight;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20 * glass, sigmaY: 20 * glass),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.62 * glass),
            border: Border(
              bottom: BorderSide(
                width: 0.5,
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.1 * glass,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Centered title in the bar. Long titles end with an ellipsis instead of
/// shrinking, so every bar title keeps one size.
class _BarTitle extends StatelessWidget {
  const _BarTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: AppTextStyles.navTitle(color: context.textPrimary),
      ),
    ),
  );
}

/// First row of a tab: the large title, which wraps and follows the text
/// size instead of shrinking to fit beside the buttons.
class _LargeTitle extends StatelessWidget {
  const _LargeTitle({required this.title, this.eyebrow});

  final String title;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.pageHorizontalPadding,
        0,
        AppDimensions.pageHorizontalPadding,
        AppDimensions.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow case final eyebrow?)
            Text(
              eyebrow,
              style: AppTextStyles.overline(
                color: AppColors.readableAccent(
                  isDark ? AppColors.primaryDark : AppColors.primary,
                  isDark: isDark,
                ),
              ),
            ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.pageTitle(color: context.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-scrolling screens (live sessions, the mascot workshop) keep their
/// title beside the buttons.
class ElyriiPageHeader extends StatelessWidget {
  const ElyriiPageHeader({
    super.key,
    required this.title,
    required this.leading,
    this.trailing = const SizedBox(width: AppDimensions.controlSize),
  });

  final String title;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: AppDimensions.spacing8),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.navTitle(color: context.textPrimary),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacing8),
        trailing,
      ],
    );
  }
}

/// Fixed header above a body that manages its own scrolling. Large text or a
/// short screen scrolls the header away instead of overflowing.
class ElyriiFixedHeaderFrame extends StatelessWidget {
  const ElyriiFixedHeaderFrame({
    super.key,
    required this.header,
    required this.child,
  });

  final ElyriiPageHeader header;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.pageHorizontalPadding,
            AppDimensions.spacing12,
            AppDimensions.pageHorizontalPadding,
            AppDimensions.spacing12,
          ),
          child: header,
        );
        if (MediaQuery.textScalerOf(context).scale(14) <= 21 &&
            constraints.maxHeight >= 400) {
          return Column(
            children: [
              title,
              Expanded(child: child),
            ],
          );
        }
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: title),
            SliverFillRemaining(hasScrollBody: true, child: child),
          ],
        );
      },
    ),
  );
}
