part of 'dashboard_page.dart';

final _accueilGlassFilter = ui.ImageFilter.compose(
  outer: ColorFilter.saturation(1.7),
  inner: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
);

class _AccueilFrame extends StatelessWidget {
  final DateTime now;
  final ScrollController scroll;
  final ValueNotifier<_AccueilScrollVisuals> visuals;
  final ValueNotifier<_LookPreview?> preview;
  final bool calendarOpen;
  final Future<void> Function(_AccueilOverlay) onOpen;
  final Future<void> Function(AccueilAction) onAction;
  final Future<void> Function() onRefresh;

  const _AccueilFrame({
    required this.now,
    required this.scroll,
    required this.visuals,
    required this.preview,
    required this.calendarOpen,
    required this.onOpen,
    required this.onAction,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final safeTop = MediaQuery.paddingOf(context).top;
    final bottom = AppShell.bottomClearanceOf(context);
    final activities = context.watch<AccueilActivities>().snapshot;
    final dashboard = context.watch<DashboardProvider>();
    final mascot = context.watch<MascotProvider>().mascot;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final hero = ValueListenableBuilder<_LookPreview?>(
      valueListenable: preview,
      builder: (context, look, _) => TweenAnimationBuilder<double>(
        tween: Tween(
          end: look == null ? 0 : -AppDimensions.accueilDressingHeroLift,
        ),
        duration: _motion(context, AppMotion.sheetEnter),
        curve: AppMotion.accueilRise,
        builder: (_, lift, child) =>
            Transform.translate(offset: Offset(0, lift), child: child),
        child: SizedBox(
          width: AppDimensions.accueilHeroSize,
          height: AppDimensions.accueilHeroSize,
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Positioned(
                bottom: AppDimensions.accueilHeroFeetInset,
                child: MascotContactShadow(
                  width: AppDimensions.accueilHeroSize * 0.35,
                  elevation: 0,
                  isDark: dark,
                ),
              ),
              MascotPeek(
                selectedMood: dashboard.selectedMood,
                mascot: look?.model ?? mascot,
                previewPop: look?.pop ?? 0,
              ),
            ],
          ),
        ),
      ),
    );
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
                clipBehavior: Clip.hardEdge,
                children: [
                  ValueListenableBuilder<_AccueilScrollVisuals>(
                    valueListenable: visuals,
                    builder: (context, state, _) => Transform.translate(
                      offset: Offset(
                        0,
                        reduced ? -state.scrolled : state.parallax,
                      ),
                      child: SizedBox(
                        height:
                            safeTop +
                            AppDimensions.accueilSceneHeight -
                            AppDimensions.accueilBarHeight,
                        child: ValueListenableBuilder<_LookPreview?>(
                          valueListenable: preview,
                          builder: (_, look, _) => CustomPaint(
                            size: Size.infinite,
                            painter: AccueilScenePainter(
                              decor: look?.decor ?? activities.decor,
                              dark: dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  RefreshIndicator(
                    onRefresh: onRefresh,
                    child: CustomScrollView(
                      key: const PageStorageKey('accueil-scroll'),
                      scrollBehavior: ScrollConfiguration.of(context)
                          .copyWith(scrollbars: false),
                      controller: scroll,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: ClampingScrollPhysics(),
                      ),
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(
                            height: safeTop + AppDimensions.accueilSheetTop,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: safeTop + AppDimensions.accueilHeroTop,
                                  left: 0,
                                  right: 0,
                                  child:
                                      ValueListenableBuilder<
                                        _AccueilScrollVisuals
                                      >(
                                        valueListenable: visuals,
                                        child: hero,
                                        builder: (_, state, child) =>
                                            Transform.translate(
                                              offset: Offset(
                                                0,
                                                reduced
                                                    ? 0
                                                    : state.heroCounterShift,
                                              ),
                                              child: Center(
                                                child: IgnorePointer(
                                                  ignoring:
                                                      state.heroOpacity == 0,
                                                  child: ExcludeSemantics(
                                                    excluding:
                                                        state.heroOpacity == 0,
                                                    child: Opacity(
                                                      opacity:
                                                          state.heroOpacity,
                                                      child: child,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF15121F)
                                  : const Color(0xFFF4F3F8),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppDimensions.radius30),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                AppDimensions.spacing20,
                                AppDimensions.accueilSheetTopPadding,
                                AppDimensions.spacing20,
                                bottom,
                              ),
                              child: _AccueilSections(
                                now: now,
                                onAction: onAction,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ValueListenableBuilder<_AccueilScrollVisuals>(
                      valueListenable: visuals,
                      builder: (_, state, _) => AnimatedOpacity(
                        opacity: state.pinned ? 1 : 0,
                        duration: _motion(context, AppMotion.bandFade),
                        curve: AppMotion.accueilEase,
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: _accueilGlassFilter,
                            child: Container(
                              height: safeTop + AppDimensions.accueilBarHeight,
                              decoration: BoxDecoration(
                                color: (dark
                                    ? AppColors.glassBackgroundDark
                                    : AppColors.glassBackgroundLight),
                                border: Border(
                                  bottom: BorderSide(
                                    color: dark
                                        ? AppColors.dividerDark
                                        : AppColors.dividerLight,
                                    width: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  ValueListenableBuilder<_AccueilScrollVisuals>(
                    valueListenable: visuals,
                    builder: (_, state, _) => Positioned(
                      top: safeTop + state.capsuleTop,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _AccueilCapsule(
                          now: now,
                          compact: state.pinned,
                          onOpen: onOpen,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: safeTop + AppDimensions.spacing2,
                    left: AppDimensions.spacing20,
                    right: AppDimensions.spacing20,
                    child: _AccueilHeader(
                      now: now,
                      calendarOpen: calendarOpen,
                      onCalendar: () => onOpen(_AccueilOverlay.calendar),
                      onDressing: () => onOpen(_AccueilOverlay.dressing),
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

class _AccueilHeader extends StatelessWidget {
  final DateTime now;
  final bool calendarOpen;
  final VoidCallback onCalendar;
  final Future<void> Function() onDressing;
  const _AccueilHeader({
    required this.now,
    required this.calendarOpen,
    required this.onCalendar,
    required this.onDressing,
  });

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _GlassControl(
          label: 'Profil',
          onTap: () async {
            final exit = await context.push<ProfileExit>(AppRoutes.profile);
            if (context.mounted && exit == ProfileExit.dressing) {
              await onDressing();
            }
          },
          child: ClipOval(
            child: UserAvatar(
              pfp: user.profile?.pfp,
              size: 40,
              showBorder: false,
            ),
          ),
        ),
        Flexible(
          child: _GlassControl(
            label: 'Ouvrir le calendrier',
            onTap: onCalendar,
            wide: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    _frenchDate('EEE d MMMM', now),
                    style: AppTextStyles.navDate(color: context.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing4),
                AnimatedRotation(
                  turns: calendarOpen ? 0.5 : 0,
                  duration: _motion(context, AppMotion.dateChevron),
                  curve: AppMotion.accueilEase,
                  child: Icon(
                    Symbols.expand_more_rounded,
                    size: AppDimensions.iconSm,
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        _GlassControl(
          label: 'Réglages',
          onTap: () => context.push(AppRoutes.settings),
          child: Icon(
            Symbols.settings_rounded,
            size: 22,
            color: context.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _GlassControl extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  final bool wide;
  const _GlassControl({
    required this.label,
    required this.onTap,
    required this.child,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AccessibleAction(
      label: label,
      excludeChildSemantics: true,
      onPressed: onTap,
      child: Align(
        widthFactor: 1,
        heightFactor: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          child: BackdropFilter(
            filter: _accueilGlassFilter,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.accueilHeaderControl,
              ),
              height: wide ? null : AppDimensions.accueilHeaderControl,
              width: wide ? null : AppDimensions.accueilHeaderControl,
              padding: wide
                  ? const EdgeInsets.only(
                      left: AppDimensions.spacing16,
                      right: AppDimensions.spacing12 + AppDimensions.spacing2,
                    )
                  : EdgeInsets.zero,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.glassBackgroundDark
                    : AppColors.glassBackgroundLight,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                border: Border.all(
                  color: dark
                      ? AppColors.glassBorderDark
                      : AppColors.glassBorderLight,
                  width: 0.5,
                ),
              ),
              child: Center(widthFactor: wide ? 1 : null, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccueilCapsule extends StatelessWidget {
  final DateTime now;
  final bool compact;
  final Future<void> Function(_AccueilOverlay) onOpen;
  const _AccueilCapsule({
    required this.now,
    required this.compact,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final garden = context.watch<GamificationProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final known =
        garden.hasLoadedData && !garden.isLoading && garden.error == null;
    final weekFlowers = buildWeekFlowers(
      today: CivilDay.fromLocal(now),
      completedChallenges: garden.completedChallenges,
      activities: context.watch<AccueilActivities>().snapshot,
    );
    final compact =
        this.compact || MediaQuery.textScalerOf(context).scale(14) > 21;
    final capsuleHeight = math.max(
      compact
          ? AppDimensions.accueilCapsuleCompactHeight
          : AppDimensions.accueilCapsuleHeight,
      MediaQuery.textScalerOf(context).scale(14) * 1.5 + AppDimensions.spacing8,
    );
    final duration = _motion(context, AppMotion.capsuleCompact);
    Widget item(
      String semantics,
      IconData icon,
      Color color,
      String value,
      String label,
      _AccueilOverlay target,
    ) => AccessibleAction(
      label: semantics,
      excludeChildSemantics: true,
      onPressed: () => onOpen(target),
      child: AnimatedContainer(
        duration: duration,
        curve: AppMotion.accueilEase,
        height: math.max(AppDimensions.controlSize, capsuleHeight),
        padding: EdgeInsets.symmetric(
          horizontal: compact
              ? AppDimensions.spacing8
              : AppDimensions.spacing12,
        ),
        child: _CapsulePress(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: AppDimensions.iconSm, fill: 1),
              if (value.isNotEmpty) ...[
                const SizedBox(width: AppDimensions.spacing4),
                Text(
                  value,
                  style: AppTextStyles.capsuleValue(color: context.textPrimary),
                ),
              ],
              ClipRect(
                child: _MotionSize(
                  duration: AppMotion.capsuleCompact,
                  child: SizedBox(
                    width: compact ? 0 : null,
                    child: AnimatedOpacity(
                      opacity: compact ? 0 : 1,
                      duration: _motion(context, AppMotion.capsuleLabelFade),
                      curve: AppMotion.accueilEase,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: AppDimensions.spacing4,
                        ),
                        child: Text(
                          label,
                          style: AppTextStyles.capsuleSuffix(
                            color: context.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: AnimatedPadding(
            duration: duration,
            curve: AppMotion.accueilEase,
            padding: EdgeInsets.symmetric(
              vertical: compact ? AppDimensions.spacing2 : 0,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppDimensions.radius26),
              child: BackdropFilter(
                filter: _accueilGlassFilter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xDB242034)
                        : Colors.white.withValues(alpha: 0.86),
                    borderRadius: BorderRadius.circular(AppDimensions.radius26),
                    border: Border.all(
                      color: dark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0x0F140E30),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedPadding(
          duration: duration,
          curve: AppMotion.accueilEase,
          padding: EdgeInsets.symmetric(
            horizontal: compact
                ? AppDimensions.spacing4
                : AppDimensions.spacing4 + AppDimensions.spacing2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              item(
                'Ouvrir la série',
                Symbols.local_fire_department_rounded,
                AppColors.orange(dark),
                dashboard.coverage == null ? '—' : '${dashboard.currentStreak}',
                'jours',
                _AccueilOverlay.streak,
              ),
              _separator(context),
              item(
                'Ouvrir les fleurs',
                Symbols.local_florist_rounded,
                AppColors.green(dark),
                known ? '${weekFlowers.all.length}' : '—',
                'fleurs',
                _AccueilOverlay.flowers,
              ),
              _separator(context),
              item(
                'Ouvrir la tenue',
                Symbols.checkroom_rounded,
                AppColors.violet(dark),
                '',
                'Tenue',
                _AccueilOverlay.dressing,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _separator(BuildContext context) => Container(
    width: 0.5,
    height: AppDimensions.accueilSectionGap,
    color: context.textTertiary.withValues(alpha: 0.3),
  );
}

class _Rise extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration duration;
  final Duration stagger;
  final double distance;
  const _Rise({
    super.key,
    required this.index,
    required this.child,
    this.duration = AppMotion.entryRise,
    this.stagger = AppMotion.entryStagger,
    this.distance = AppDimensions.accueilRiseDistance,
  });
  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  Timer? _delay;
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _delay?.cancel();
      _controller.value = 1;
    } else if (!_started) {
      _started = true;
      _delay = Timer(widget.stagger * widget.index, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (_, child) {
      final value = AppMotion.accueilRise.transform(_controller.value);
      return Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, widget.distance * (1 - value)),
          child: child,
        ),
      );
    },
  );
}

class _CapsulePress extends StatefulWidget {
  final Widget child;
  const _CapsulePress({required this.child});
  @override
  State<_CapsulePress> createState() => _CapsulePressState();
}

class _CapsulePressState extends State<_CapsulePress> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _pressed ? const Color(0x14FFFFFF) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radius20),
      ),
      child: widget.child,
    ),
  );
}

class _MotionSize extends StatelessWidget {
  final Duration duration;
  final Widget child;
  const _MotionSize({required this.duration, required this.child});
  @override
  Widget build(BuildContext context) => MediaQuery.disableAnimationsOf(context)
      ? child
      : AnimatedSize(
          duration: duration,
          curve: AppMotion.accueilEase,
          alignment: Alignment.topCenter,
          child: child,
        );
}
