import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/mascot_animations.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/glass/elyrii_back_button.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../../../core/widgets/glass/liquid_glass_controls.dart';
import '../../../../core/widgets/glass/liquid_glass_sheet.dart';
import '../../../../core/widgets/glass/liquid_glass_dialog.dart';
import '../../../../routes/app_routes.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../data/models/mascot_accessory.dart';
import '../../data/models/mascot_model.dart';
import '../providers/mascot_provider.dart';
import '../widgets/mascot_collection_panel.dart';
import '../widgets/mascot_color_editor.dart';
import '../widgets/mascot_studio_preview.dart';
import '../widgets/mascot_style_editor.dart';
import '../widgets/unlock_celebration_dialog.dart';

enum _StudioTab { style, colors, collection }

enum _ExitChoice { discard, save }

class MascotCustomizationPage extends StatefulWidget {
  const MascotCustomizationPage({super.key});

  @override
  State<MascotCustomizationPage> createState() =>
      _MascotCustomizationPageState();
}

class _MascotCustomizationPageState extends State<MascotCustomizationPage> {
  String get _seenUnlocksKey =>
      'elyrii_seen_cosmetic_unlocks_${context.read<MascotProvider>().storageScope}';
  final _history = <MascotModel>[];
  final _editorScroll = ScrollController();
  MascotModel _draft = MascotModel.defaultMascot();
  MascotAccessory? _tryOn;
  _StudioTab _tab = _StudioTab.style;
  MascotAnimation _animation = MascotAnimations.idle;
  int _trigger = 0;
  double _angle = 0;
  bool _loaded = false;
  bool _saving = false;
  bool _allowExit = false;
  bool _failedSave = false;
  MascotModel? _colorGestureStart;
  bool _colorGestureRecorded = false;
  int? _loadedSession;

  bool get _dirty =>
      _loaded &&
      _loadedSession == context.read<MascotProvider>().sessionRevision &&
      _draft != context.read<MascotProvider>().mascot;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    final mascot = context.read<MascotProvider>();
    final progress = context.read<GamificationProvider>();
    final session = mascot.sessionRevision;
    await Future.wait([mascot.loadMascot(), progress.loadAll()]);
    if (!mounted || mascot.sessionRevision != session) return;
    setState(() {
      _draft = mascot.mascot;
      _loaded = true;
      _loadedSession = session;
    });
    if (progress.error == null) {
      await _celebrateNewRewards(progress.completedChallenges.length);
    }
  }

  @override
  void dispose() {
    _editorScroll.dispose();
    super.dispose();
  }

  void _edit(MascotModel next, {bool react = true}) {
    if (next == _draft || _saving || !_loaded) return;
    if (react) ElyriiHaptics.selection();
    setState(() {
      if (_colorGestureStart == null || !_colorGestureRecorded) {
        if (_history.length == 30) _history.removeAt(0);
        _history.add(_draft);
        _colorGestureRecorded = _colorGestureStart != null;
      }
      _draft = next;
      _failedSave = false;
      _tryOn = null;
      if (react) {
        _animation = MascotAnimations.proud;
        _trigger++;
      }
    });
  }

  void _beginColorEdit() {
    _colorGestureStart = _draft;
    _colorGestureRecorded = false;
  }

  void _endColorEdit() {
    setState(() {
      if (_colorGestureRecorded && _draft == _colorGestureStart) {
        _history.removeLast();
      }
      _colorGestureStart = null;
      _colorGestureRecorded = false;
    });
  }

  void _undo() {
    if (_history.isEmpty || _saving) return;
    ElyriiHaptics.selection();
    setState(() {
      _draft = _history.removeLast();
      _tryOn = null;
    });
  }

  void _selectAccessory(MascotAccessory piece) {
    final progress = context.read<GamificationProvider>();
    final saved = context.read<MascotProvider>().mascot.equippedCosmetics;
    if (!piece.isUnlocked(progress.completedChallenges.length) &&
        !saved.contains(piece.id)) {
      _showReward(piece);
      return;
    }
    final equipped = _draft.equippedCosmetics.contains(piece.id);
    final ids = _draft.equippedCosmetics
        .where((id) => MascotAccessories.byId(id)?.category != piece.category)
        .toList();
    if (!equipped) ids.add(piece.id);
    _edit(
      _draft.copyWith(
        equippedCosmetics: MascotAccessories.sanitizeSelection(ids),
      ),
    );
    if (!equipped && piece.category == 'Dos') setState(() => _angle = 180);
  }

  void _startTryOn(MascotAccessory piece) {
    ElyriiHaptics.selection();
    setState(() {
      _tryOn = piece;
      _angle = piece.category == 'Dos' ? 180 : 0;
    });
  }

  MascotModel get _preview {
    if (_loadedSession != context.read<MascotProvider>().sessionRevision) {
      return context.read<MascotProvider>().mascot;
    }
    if (_tryOn == null) return _draft;
    return _draft.copyWith(
      equippedCosmetics: MascotAccessories.sanitizeSelection([
        ..._draft.equippedCosmetics,
        _tryOn!.id,
      ]),
    );
  }

  Future<bool> _save() async {
    if (!_loaded || _saving) return false;
    setState(() => _saving = true);
    final provider = context.read<MascotProvider>();
    final saved = await provider.saveCustomization(
      _draft,
      expectedSessionRevision: _loadedSession,
      completedChallenges: context
          .read<GamificationProvider>()
          .completedChallenges
          .length,
    );
    if (!mounted) return saved;
    setState(() {
      _saving = false;
      _failedSave = !saved;
      if (saved) {
        _draft = provider.mascot;
        _history.clear();
        _tryOn = null;
        _animation = MascotAnimations.celebrate;
        _trigger++;
      }
    });
    if (saved) ElyriiHaptics.success();
    return saved;
  }

  Future<void> _exit({bool challenges = false}) async {
    if (_saving) return;
    if (_dirty) {
      final choice = await showLiquidGlassDialog<_ExitChoice>(
        context: context,
        title: 'Garder ce look ?',
        child: Text(
          'Tes essais ne sont pas encore enregistrés. Tu peux revenir à l’atelier ou enregistrer ton look avant de partir.',
          style: AppTextStyles.bodyMedium(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        actions: [
          LiquidGlassDialogAction(
            label: 'Continuer',
            onPressed: () => Navigator.pop(context),
          ),
          LiquidGlassDialogAction(
            label: 'Quitter sans enregistrer',
            onPressed: () => Navigator.pop(context, _ExitChoice.discard),
          ),
          LiquidGlassDialogAction(
            label: 'Enregistrer',
            isDefault: true,
            onPressed: () => Navigator.pop(context, _ExitChoice.save),
          ),
        ],
      );
      if (choice == null) return;
      if (choice == _ExitChoice.save && !await _save()) return;
    }
    if (!mounted) return;
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final router = GoRouter.maybeOf(context);
    if (challenges) {
      router?.go(AppRoutes.challenges);
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      router?.go(AppRoutes.home);
    }
  }

  Future<void> _celebrateNewRewards(int count) async {
    final provider = context.read<MascotProvider>();
    final session = provider.sessionRevision;
    final scope = provider.storageScope;
    final seenKey = _seenUnlocksKey;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || session != provider.sessionRevision) return;
    final seen =
        prefs.getStringList(seenKey) ??
        (scope == 'guest' &&
                prefs.getString('elyrii_mascot_legacy_owner') == null
            ? prefs.getStringList('elyrii_seen_cosmetic_unlocks')
            : null) ??
        const <String>[];
    final seenIds = seen
        .map((id) => MascotAccessories.byId(id)?.id ?? id)
        .toSet();
    final rewards = MascotAccessories.progression
        .where(
          (piece) => piece.isUnlocked(count) && !seenIds.contains(piece.id),
        )
        .toList();
    if (rewards.isEmpty) return;
    await prefs.setStringList(
      seenKey,
      {...seen, ...rewards.map((piece) => piece.id)}.toList(),
    );
    if (!mounted || session != provider.sessionRevision) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (dialogContext) => UnlockCelebrationDialog(
        accessory: rewards.last,
        unlockedCount: rewards.length,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onEquip: () {
          Navigator.pop(dialogContext);
          if (session != provider.sessionRevision) return;
          _selectAccessory(rewards.last);
        },
      ),
    );
  }

  Future<void> _showReward(MascotAccessory piece) async {
    final progress = context.read<GamificationProvider>();
    final count = progress.completedChallenges.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showLiquidGlassSheet<void>(
      context: context,
      initialChildSize: 0.68,
      minChildSize: 0.4,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            'assets/accessory_portraits/${piece.id}.png',
            height: 160,
            excludeFromSemantics: true,
          ),
          Text(
            piece.name,
            textAlign: TextAlign.center,
            style: AppTextStyles.titleLarge(
              color: dark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            piece.description,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium(
              color: dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            progress.error == null
                ? 'Encore ${piece.remainingChallenges(count)} ${piece.remainingChallenges(count) == 1 ? 'défi' : 'défis'} à terminer · ${piece.unlockLabel}'
                : 'À débloquer après ${piece.unlockLabel}',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall(
              color: dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          LiquidGlassButton(
            label: 'Essayer sur ma mascotte',
            icon: Icons.visibility_outlined,
            isExpanded: true,
            onPressed: () {
              Navigator.pop(context);
              _startTryOn(piece);
            },
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _exit(challenges: true);
            },
            child: const Text('Voir mes défis'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.primaryDark : AppColors.primary;
    return ChipTheme(
      data: ChipTheme.of(context).copyWith(
        backgroundColor: Colors.transparent,
        selectedColor: accent.withValues(alpha: 0.10),
        secondarySelectedColor: accent.withValues(alpha: 0.10),
        surfaceTintColor: Colors.transparent,
        showCheckmark: false,
        labelStyle: AppTextStyles.labelMedium(
          color: dark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
        secondaryLabelStyle: AppTextStyles.labelMedium(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? accent.withValues(alpha: 0.22)
                : Colors.transparent,
          ),
        ),
        shape: const StadiumBorder(),
      ),
      child: Consumer2<MascotProvider, GamificationProvider>(
        builder: (context, provider, progress, _) => PopScope(
          canPop: !_dirty || _allowExit,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_exit());
          },
          child: Scaffold(
            backgroundColor: dark
                ? AppColors.scaffoldDark
                : AppColors.scaffoldLight,
            body: ElyriiPageFrame(
              header: ElyriiPageHeader(
                title: 'Atelier Elyrii',
                subtitle: 'Un compagnon, à ton image.',
                leading: ElyriiBackButton(onPressed: () => _exit()),
                trailing: LiquidGlassIconButton(
                  tooltip: 'Annuler la dernière modification',
                  onPressed: _history.isEmpty || _saving ? null : _undo,
                  icon: Icons.undo_rounded,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final compact = constraints.maxHeight < 450;
                  final hidePreview = !wide && constraints.maxHeight < 240;
                  final previewHeight = wide
                      ? (constraints.maxHeight - 115).clamp(80.0, 560.0)
                      : compact
                      ? (constraints.maxHeight * 0.20).clamp(40.0, 90.0)
                      : (constraints.maxHeight * 0.30).clamp(110.0, 230.0);
                  final preview = MascotStudioPreview(
                    mascot: _preview,
                    height: previewHeight,
                    angle: _angle,
                    onAngleChanged: (angle) => setState(() => _angle = angle),
                    animation: _animation,
                    animationTrigger: _trigger,
                    tryOn: _tryOn,
                    onEndTryOn: () => setState(() => _tryOn = null),
                    compact: compact,
                  );
                  final editor = Column(
                    children: [
                      _tabBar(),
                      const SizedBox(height: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _editorScroll,
                          padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
                          child: IgnorePointer(
                            ignoring: !_loaded || _saving,
                            child: _editor(provider, progress, dark),
                          ),
                        ),
                      ),
                    ],
                  );
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDimensions.pageHorizontalPadding,
                      0,
                      AppDimensions.pageHorizontalPadding,
                      0,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: wide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: preview),
                                  const SizedBox(width: 28),
                                  Expanded(child: editor),
                                ],
                              )
                            : Column(
                                children: [
                                  Offstage(
                                    offstage: hidePreview,
                                    child: preview,
                                  ),
                                  SizedBox(
                                    height: hidePreview
                                        ? 0
                                        : compact
                                        ? 8
                                        : 16,
                                  ),
                                  Expanded(child: editor),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            bottomNavigationBar: _saveBar(provider, dark),
          ),
        ),
      ),
    );
  }

  Widget _tabBar() => LiquidGlassSegmentedControl<_StudioTab>(
    segments: const {
      _StudioTab.style: 'Style',
      _StudioTab.colors: 'Couleurs',
      _StudioTab.collection: 'Collection',
    },
    selectedValue: _tab,
    height: AppDimensions.buttonHeight,
    onValueChanged: (tab) {
      ElyriiHaptics.selection();
      setState(() => _tab = tab);
      if (_editorScroll.hasClients) _editorScroll.jumpTo(0);
    },
  );

  Widget _editor(
    MascotProvider provider,
    GamificationProvider progress,
    bool dark,
  ) {
    final progressCard = _loaded && progress.error == null
        ? MascotProgressCard(
            completedCount: progress.completedChallenges.length,
            savedSelection: provider.mascot.equippedCosmetics,
            onChallenges: () => _exit(challenges: true),
            onTryNext: _startTryOn,
          )
        : LiquidGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  !_loaded
                      ? 'Ta collection se prépare…'
                      : 'Progression indisponible',
                  style: AppTextStyles.titleSmall(
                    color: dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (_loaded) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Tes couleurs et ton look restent disponibles. Recharge tes défis pour retrouver tes paliers.',
                    style: AppTextStyles.bodyMedium(
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await progress.loadAll();
                      if (mounted && progress.error == null) {
                        await _celebrateNewRewards(
                          progress.completedChallenges.length,
                        );
                      }
                    },
                    child: const Text('Recharger les défis'),
                  ),
                ],
              ],
            ),
          );
    return switch (_tab) {
      _StudioTab.style => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MascotStyleEditor(mascot: _draft, onChanged: _edit),
          const SizedBox(height: 28),
          progressCard,
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => _edit(MascotModel.defaultMascot()),
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Revenir au look d’origine'),
          ),
        ],
      ),
      _StudioTab.colors => MascotColorEditor(
        mascot: _draft,
        onChanged: (next) => _edit(next, react: false),
        onEditStart: _beginColorEdit,
        onEditEnd: _endColorEdit,
      ),
      _StudioTab.collection => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          progressCard,
          const SizedBox(height: 28),
          MascotCollectionPanel(
            selection: _draft.equippedCosmetics,
            savedSelection: provider.mascot.equippedCosmetics,
            completedCount: progress.completedChallenges.length,
            onSelect: _selectAccessory,
            tryOnId: _tryOn?.id,
          ),
        ],
      ),
    };
  }

  Widget _saveBar(MascotProvider provider, bool dark) => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
        border: Border(
          top: BorderSide(
            color: dark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1160),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                liveRegion: true,
                child: Text(
                  _failedSave && provider.error != null
                      ? provider.error!
                      : !_loaded
                      ? 'Chargement de ton look…'
                      : _saving
                      ? 'Enregistrement…'
                      : _dirty
                      ? 'Tes essais restent privés jusqu’à l’enregistrement'
                      : provider.isSyncing
                      ? 'Look enregistré · synchronisation…'
                      : provider.error != null
                      ? 'Look disponible sur cet appareil'
                      : 'Ton look est enregistré',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.labelSmall(
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
              if (provider.error != null && _loaded && !_dirty)
                TextButton(
                  onPressed: provider.retrySync,
                  child: const Text('Réessayer la synchronisation'),
                ),
              const SizedBox(height: 8),
              LiquidGlassButton(
                key: const ValueKey('save_mascot_look'),
                label: _saving
                    ? 'Enregistrement…'
                    : _dirty
                    ? 'Enregistrer mon look'
                    : 'Look enregistré',
                icon: _dirty
                    ? Icons.check_rounded
                    : Icons.check_circle_outline_rounded,
                isExpanded: true,
                isLoading: _saving,
                onPressed: _loaded && _dirty && !_saving ? _save : null,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
