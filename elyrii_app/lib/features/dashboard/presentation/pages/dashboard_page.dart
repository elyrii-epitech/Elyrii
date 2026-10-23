import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/mascot_contact_shadow.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../../core/widgets/glass/liquid_glass_sheet.dart';
import '../../../../routes/app_routes.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../journal/presentation/widgets/journal_editor_sheet.dart';
import '../../../mascot/data/models/mascot_accessory.dart';
import '../../../mascot/data/models/mascot_appearance.dart';
import '../../../mascot/data/models/mascot_model.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';
import '../../../meditation/data/repositories/meditation_repository.dart';
import '../../../meditation/domain/models/breath_phase.dart';
import '../../../meditation/presentation/controllers/meditation_controller.dart';
import '../../../settings/providers/settings_provider.dart';
import '../../data/accueil_activities.dart';
import '../../domain/accueil_content.dart';
import '../../domain/civil_day.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/mascot_peek.dart';

part 'accueil_frame.dart';
part 'accueil_sections.dart';
part 'accueil_overlays.dart';
part 'accueil_dressing.dart';
part 'accueil_scene.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with WidgetsBindingObserver {
  final _scroll = ScrollController();
  final _visuals = ValueNotifier(const _AccueilScrollVisuals(0));
  final _preview = ValueNotifier<_LookPreview?>(null);
  _AccueilOverlay? _overlay;
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_onScroll);
    _scheduleClock();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_refresh());
    });
  }

  void _onScroll() => _visuals.value = _AccueilScrollVisuals(_scroll.offset);

  void _scheduleClock() {
    _clock?.cancel();
    final local = _now.toLocal();
    final hour = local.hour < 12
        ? 12
        : local.hour < 18
        ? 18
        : 24;
    final next = DateTime(local.year, local.month, local.day, hour);
    _clock = Timer(next.difference(local), _updateClock);
  }

  void _updateClock() {
    if (!mounted) return;
    setState(() => _now = DateTime.now());
    _scheduleClock();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _updateClock();
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<DashboardProvider>().loadDashboardData(),
      context.read<JournalProvider>().loadEntries(),
      context.read<GamificationProvider>().loadAll(force: true),
    ]);
  }

  Future<void> _openOverlay(_AccueilOverlay kind) async {
    if (_overlay != null) return;
    final dashboard = context.read<DashboardProvider>();
    if (kind == _AccueilOverlay.calendar) {
      unawaited(
        dashboard.ensureCalendarHistory(
          CivilMonth.containing(CivilDay.fromLocal(_now)),
        ),
      );
    }
    if (kind == _AccueilOverlay.dressing && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
    var saving = false;
    final route = AppSheetRoute<_AccueilOverlay>(
      reduced: MediaQuery.disableAnimationsOf(context),
      calendar: kind == _AccueilOverlay.calendar,
      transparentVeil: kind == _AccueilOverlay.dressing,
      canDismiss: () => !saving,
      builder: (context) => _accueilOverlayPanel(
        context,
        kind: kind,
        isDark: Theme.of(context).brightness == Brightness.dark,
        now: _now,
        onPreview: (look) => _preview.value = look,
        onBusy: (value) => saving = value,
      ),
    );
    setState(() => _overlay = kind);
    ElyriiHaptics.medium();
    final next = await Navigator.of(context, rootNavigator: true).push(route);
    if (!mounted) return;
    _preview.value = null;
    setState(() => _overlay = null);
    if (next != null) await _openOverlay(next);
  }

  Future<void> _performAction(AccueilAction action) async {
    switch (action) {
      case OpenChat():
        context.go(AppRoutes.chatbot);
      case Breathe(:final duration):
        final controller =
            MeditationController(
                repository: MeditationRepository(
                  client: context.read<ApiClient>(),
                ),
              )
              ..setBreathingType(BreathingType.coherence)
              ..setSessionDuration(duration);
        unawaited(controller.startSession());
        await context.push(AppRoutes.meditationSession, extra: controller);
        controller.dispose();
      case WriteJournal(:final initialPrompt):
        await showLiquidGlassSheet<void>(
          context: context,
          initialChildSize: 0.92,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          useRootNavigator: true,
          child: JournalEditorSheet(
            provider: context.read<JournalProvider>(),
            initialPrompt: initialPrompt,
          ),
        );
      case ContactSomeone():
        final box = context.findRenderObject() as RenderBox?;
        await SharePlus.instance.share(
          ShareParams(
            text: contactShareText,
            sharePositionOrigin: box == null
                ? null
                : box.localToGlobal(Offset.zero) & box.size,
          ),
        );
      case CallHelp():
        if (!await launchUrl(Uri(scheme: 'tel', path: '3114')) && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Appelle le 3114, gratuitement, jour et nuit.'),
            ),
          );
        }
      case OpenReviews():
        await context.push(AppRoutes.reviews);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _scroll.dispose();
    _visuals.dispose();
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AccueilFrame(
    now: _now,
    scroll: _scroll,
    visuals: _visuals,
    preview: _preview,
    calendarOpen: _overlay == _AccueilOverlay.calendar,
    onOpen: _openOverlay,
    onAction: _performAction,
    onRefresh: _refresh,
  );
}

final class _LookPreview {
  final MascotModel model;
  final MascotDecor decor;
  final int pop;
  const _LookPreview(this.model, this.decor, this.pop);
}

final class _AccueilScrollVisuals {
  final double offset;
  const _AccueilScrollVisuals(this.offset);
  double get scrolled => math.max(0, offset);
  double get parallax => -0.45 * scrolled;

  /// The hero lives in the scroll content so it receives taps through the
  /// transparent top of the scroll; this shift brings it back to the
  /// backdrop's parallax speed.
  double get heroCounterShift => 0.55 * scrolled;
  double get heroOpacity => (1 - scrolled / 260).clamp(0, 1);
  bool get pinned =>
      offset >=
      AppDimensions.accueilCapsuleTop - AppDimensions.accueilCapsulePinnedTop;
  double get capsuleTop => math.max(
    AppDimensions.accueilCapsulePinnedTop,
    AppDimensions.accueilCapsuleTop - offset,
  );
}

Duration _motion(BuildContext context, Duration duration) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;

const _weekdays = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
String _frenchDate(String pattern, DateTime date) {
  final value = DateFormat(pattern, 'fr_FR').format(date);
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

extension _CivilDateFormatting on CivilDay {
  DateTime toLocalDateTime() => DateTime(year, month, day);
}
