import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Tabs align their title to the start, detail pages center it.
enum ElyriiTitleLevel { tab, detail }

/// Scrolling page with an iOS-style collapsing title.
///
/// At rest the title sits in the button row. Scrolling slides it away while
/// the buttons stay pinned; a glass band and a compact title then fade in.
class ElyriiPageFrame extends StatefulWidget {
  const ElyriiPageFrame.tab({
    super.key,
    required this.title,
    this.eyebrow,
    this.leading,
    this.actions = const [],
    required this.slivers,
    this.controller,
    this.physics,
  }) : level = ElyriiTitleLevel.tab;

  const ElyriiPageFrame.detail({
    super.key,
    required this.title,
    required Widget this.leading,
    this.actions = const [],
    required this.slivers,
    this.controller,
    this.physics,
  }) : level = ElyriiTitleLevel.detail,
       eyebrow = null;

  final ElyriiTitleLevel level;
  final String title;

  /// Small accent line above the title (the home date).
  final String? eyebrow;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  State<ElyriiPageFrame> createState() => _ElyriiPageFrameState();
}

class _ElyriiPageFrameState extends State<ElyriiPageFrame> {
  /// Every effect saturates by this offset, so deeper scrolling rebuilds
  /// nothing.
  static const _collapsedAt = 56.0;
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth == 0 && notification.metrics.axis == Axis.vertical) {
      _offset.value = notification.metrics.pixels.clamp(0, _collapsedAt);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isTab = widget.level == ElyriiTitleLevel.tab;
    final extent = ElyriiHeaderBar.extentOf(context);
    final title = _RestingTitle(
      title: widget.title,
      eyebrow: widget.eyebrow,
      centered: !isTab,
    );
    return SafeArea(
      top: false,
      bottom: false,
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: CustomScrollView(
              controller: widget.controller,
              physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: SizedBox(height: extent)),
                ...widget.slivers,
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: extent,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ValueListenableBuilder<double>(
                    valueListenable: _offset,
                    builder: (context, offset, _) =>
                        _GlassBand(glass: (offset / 12).clamp(0.0, 1.0)),
                  ),
                ),
                if (isTab)
                  ValueListenableBuilder<double>(
                    valueListenable: _offset,
                    builder: (context, offset, _) => _CompactTitle(
                      title: widget.title,
                      opacity: ((offset - 28) / 24).clamp(0.0, 1.0),
                    ),
                  ),
                _ButtonRow(
                  leading: widget.leading,
                  actions: widget.actions,
                  centerMiddle: !isTab,
                  // A centered title already reads as a navigation title, so
                  // it stays put; a tab title leaves with its content.
                  middle: isTab
                      ? ValueListenableBuilder<double>(
                          valueListenable: _offset,
                          child: title,
                          builder: (context, offset, title) => Opacity(
                            opacity: (1 - offset / 32).clamp(0.0, 1.0),
                            child: Transform.translate(
                              offset: Offset(0, -offset),
                              child: title,
                            ),
                          ),
                        )
                      : title,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Permanent top bar (chat): floating buttons around a centered title.
class ElyriiHeaderBar extends StatelessWidget {
  const ElyriiHeaderBar({
    super.key,
    required this.title,
    this.leading,
    this.actions = const [],
  });

  /// Button row height below the status bar, padding included.
  static const rowExtent = 72.0;

  static double extentOf(BuildContext context) =>
      MediaQuery.paddingOf(context).top + rowExtent;

  final String title;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: extentOf(context),
    child: Stack(
      children: [
        _CompactTitle(title: title, opacity: 1),
        _ButtonRow(leading: leading, actions: actions, centerMiddle: true),
      ],
    ),
  );
}

class _ButtonRow extends StatelessWidget {
  const _ButtonRow({
    this.leading,
    required this.actions,
    required this.centerMiddle,
    this.middle,
  });

  final Widget? leading;
  final List<Widget> actions;
  final bool centerMiddle;
  final Widget? middle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 12,
      20,
      12,
    ),
    child: SizedBox(
      height: 48,
      child: NavigationToolbar(
        leading: leading,
        middle: middle,
        trailing: actions.isEmpty
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 8,
                children: actions,
              ),
        centerMiddle: centerMiddle,
        middleSpacing: leading == null ? 0 : 12,
      ),
    ),
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
    return IgnorePointer(
      child: ClipRect(
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
      ),
    );
  }
}

/// Centered across the whole bar, like an iOS navigation title.
class _CompactTitle extends StatelessWidget {
  const _CompactTitle({required this.title, required this.opacity});

  static const _inset = 76.0;

  final String title;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    if (opacity == 0) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _inset,
        MediaQuery.paddingOf(context).top + 12,
        _inset,
        12,
      ),
      child: SizedBox(
        height: 48,
        child: Center(
          child: ExcludeSemantics(
            child: Opacity(
              opacity: opacity,
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleMedium(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
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

/// Title shown in the button row before scrolling. Every tab uses the same
/// large title; centered detail titles use the navigation title.
class _RestingTitle extends StatelessWidget {
  const _RestingTitle({
    required this.title,
    this.eyebrow,
    required this.centered,
  });

  final String title;
  final String? eyebrow;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        textAlign: centered ? TextAlign.center : TextAlign.start,
        style: centered
            ? AppTextStyles.titleMedium(color: primary)
            : AppTextStyles.pageTitle(color: primary),
      ),
    );
    // The row is 48 px tall: long titles and large text scale down to fit.
    return IgnorePointer(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: centered
            ? Alignment.center
            : AlignmentDirectional.centerStart,
        child: eyebrow == null
            ? heading
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow!,
                    style: AppTextStyles.labelMedium(
                      fontWeight: FontWeight.w700,
                      color: AppColors.readableAccent(
                        isDark ? AppColors.primaryDark : AppColors.primary,
                        isDark: isDark,
                      ),
                    ).copyWith(letterSpacing: 1.2, height: 1.15),
                  ),
                  const SizedBox(height: 2),
                  heading,
                ],
              ),
      ),
    );
  }
}

class _DetailTitle extends StatelessWidget {
  const _DetailTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ],
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
    this.subtitle,
    this.trailing = const SizedBox(width: 44),
  });

  final String title;
  final String? subtitle;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        leading,
        const SizedBox(width: 8),
        Expanded(
          child: _DetailTitle(title: title, subtitle: subtitle),
        ),
        const SizedBox(width: 8),
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
