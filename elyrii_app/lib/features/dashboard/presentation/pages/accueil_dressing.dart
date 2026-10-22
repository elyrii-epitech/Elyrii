part of 'dashboard_page.dart';

enum _DressingTab { colors, accessories, decor }

class _Dressing extends StatefulWidget {
  final ValueChanged<_LookPreview?> onPreview;
  final ValueChanged<bool> onBusy;
  const _Dressing({required this.onPreview, required this.onBusy});
  @override
  State<_Dressing> createState() => _DressingState();
}

class _DressingState extends State<_Dressing> {
  late MascotModel _draft;
  late MascotModel _original;
  late MascotDecor _decor;
  late int _session;
  bool _initialized = false;
  bool _saving = false;
  String? _error;
  int _pop = 0;
  _DressingTab _tab = _DressingTab.colors;
  String _slot = 'Tête';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final mascot = context.read<MascotProvider>();
    _draft = _original = mascot.mascot;
    _session = mascot.sessionRevision;
    _decor = context.read<AccueilActivities>().snapshot.decor;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPreview(_LookPreview(_draft, _decor, _pop));
    });
  }

  void _edit(MascotModel model, {bool pop = true}) {
    setState(() {
      _draft = model;
      if (pop) _pop++;
      _error = null;
    });
    widget.onPreview(_LookPreview(_draft, _decor, _pop));
  }

  Future<void> _save() async {
    if (_saving) return;
    final mascot = context.read<MascotProvider>();
    final store = context.read<AccueilActivities>();
    final garden = context.read<GamificationProvider>();
    if (!garden.hasLoadedData ||
        garden.isLoading ||
        garden.error != null ||
        store.snapshot.isLoading) {
      return;
    }
    final count = garden.completedChallenges.length;
    if (!MascotDecorRules.isUnlocked(_decor, count)) return;
    setState(() => _saving = true);
    widget.onBusy(true);
    final saved = await mascot.saveCustomization(
      _draft,
      completedChallenges: count,
      expectedSessionRevision: _session,
    );
    if (!mounted) return;
    if (saved && await store.setDecor(_decor, completedChallenges: count)) {
      widget.onBusy(false);
      _saving = false;
      ElyriiHaptics.success();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (saved && mascot.sessionRevision == _session) {
      await mascot.saveCustomization(
        _original,
        completedChallenges: count,
        expectedSessionRevision: _session,
      );
    }
    if (!mounted) return;
    widget.onBusy(false);
    setState(() {
      _saving = false;
      _error =
          store.snapshot.error ??
          mascot.error ??
          'Le look n’a pas pu être enregistré. Réessaie.';
    });
  }

  void _chooseAccessory(MascotAccessory accessory, int count) {
    if (!accessory.isUnlocked(count)) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(accessory.name),
          content: Text(
            '${accessory.description}\n\nEncore ${accessory.remainingChallenges(count)} défis pour le débloquer.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('D’accord'),
            ),
          ],
        ),
      );
      return;
    }
    final equipped = _draft.equippedCosmetics.contains(accessory.id);
    final selection = _draft.equippedCosmetics
        .where(
          (id) => MascotAccessories.byId(id)?.category != accessory.category,
        )
        .toList();
    if (!equipped) selection.add(accessory.id);
    ElyriiHaptics.selection();
    _edit(
      _draft.copyWith(
        equippedCosmetics: MascotAccessories.sanitizeSelection(selection),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final garden = context.watch<GamificationProvider>();
    final store = context.watch<AccueilActivities>();
    final count = garden.completedChallenges.length;
    final known =
        garden.hasLoadedData &&
        !garden.isLoading &&
        garden.error == null &&
        !store.snapshot.isLoading;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tabs = [
      ('Couleurs', Symbols.palette_rounded),
      ('Accessoires', Symbols.checkroom_rounded),
      ('Décor', Symbols.landscape_rounded),
    ];
    return PopScope(
      canPop: !_saving,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing12,
            ),
            child: _SheetHeader(
              'Tenue d’Elyrii',
              closeEnabled: !_saving,
              trailing: TextButton(
                key: const ValueKey('save_mascot_look'),
                onPressed: _saving || !known ? null : _save,
                child: Text(_saving ? '…' : 'Enregistrer'),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacing16,
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : AppDimensions.spacing4,
                      ),
                      child: AccessibleAction(
                        label: tabs[i].$1,
                        onPressed: _saving
                            ? null
                            : () =>
                                  setState(() => _tab = _DressingTab.values[i]),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing4,
                            vertical: AppDimensions.spacing8,
                          ),
                          decoration: BoxDecoration(
                            color: _tab.index == i
                                ? AppColors.primaryText(dark)
                                : dark
                                ? AppColors.surfaceDark
                                : AppColors.cardLight,
                            borderRadius: BorderRadius.circular(
                              AppDimensions.radius20,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                tabs[i].$2,
                                size: 19,
                                color: _tab.index == i
                                    ? AppColors.onTint(dark)
                                    : context.textSecondary,
                              ),
                              Text(
                                tabs[i].$1,
                                style: AppTextStyles.labelMedium(
                                  color: _tab.index == i
                                      ? AppColors.onTint(dark)
                                      : context.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.spacing16),
              child: AbsorbPointer(
                absorbing: _saving,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) _InlineError(message: _error!),
                    if (!known) ...[
                      if (garden.isLoading || store.snapshot.isLoading)
                        const Center(child: CircularProgressIndicator()),
                      if (garden.error != null)
                        _InlineError(
                          message: garden.error!,
                          retry: () => garden.loadAll(force: true),
                        ),
                    ],
                    switch (_tab) {
                      _DressingTab.colors => _colors(context),
                      _DressingTab.accessories => _accessories(
                        context,
                        count,
                        known,
                      ),
                      _DressingTab.decor => _decors(context, count, known),
                    },
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _colors(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = MascotThemes.getById(_draft.themeId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(11) > 16.5
                ? 2
                : 4;
            final width =
                (constraints.maxWidth -
                    AppDimensions.spacing8 * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppDimensions.spacing8,
              runSpacing: AppDimensions.spacing12,
              children: [
                for (final theme in MascotThemes.all)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: theme.id == _draft.themeId,
                      child: AccessibleAction(
                        label: theme.name,
                        onPressed: () => _edit(
                          _draft.copyWith(
                            themeId: theme.id,
                            appearance: MascotAppearance(
                              finish: _draft.appearance.finish,
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: _motion(context, AppMotion.presetRing),
                              curve: AppMotion.accueilEase,
                              width: 58,
                              height: 58,
                              padding: const EdgeInsets.all(
                                AppDimensions.spacing4,
                              ),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.id == _draft.themeId
                                      ? AppColors.primaryText(dark)
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CustomPaint(
                                painter: _PalettePainter(theme.paletteColors),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacing8),
                            Text(
                              theme.name,
                              textAlign: TextAlign.center,
                              style: AppTextStyles.moodLabelSelected(
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: AppDimensions.spacing16),
        Container(
          padding: const EdgeInsets.all(AppDimensions.spacing12),
          decoration: BoxDecoration(
            color: dark ? AppColors.surfaceDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(AppDimensions.radius16),
          ),
          child: Text(
            '${selected.name} · ${selected.description}',
            style: AppTextStyles.bodySmall(color: context.textSecondary),
          ),
        ),
        const SizedBox(height: AppDimensions.spacing16),
        Text(
          'Finition',
          style: AppTextStyles.titleSmall(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final finish in MascotFinish.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing2),
                  child: AccessibleAction(
                    label: switch (finish) {
                      MascotFinish.velours => 'Velours',
                      MascotFinish.satin => 'Satin',
                      MascotFinish.porcelain => 'Porcelaine',
                    },
                    onPressed: () => _edit(
                      _draft.copyWith(
                        appearance: _draft.appearance.withFinish(finish),
                      ),
                      pop: false,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.spacing8),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.surfaceDark
                            : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius16,
                        ),
                        border: Border.all(
                          color: _draft.appearance.finish == finish
                              ? AppColors.primaryText(dark)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            switch (finish) {
                              MascotFinish.velours => 'Velours',
                              MascotFinish.satin => 'Satin',
                              MascotFinish.porcelain => 'Porcelaine',
                            },
                            style: AppTextStyles.labelMedium(
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            switch (finish) {
                              MascotFinish.velours => 'Doux et mat',
                              MascotFinish.satin => 'Un peu brillant',
                              MascotFinish.porcelain => 'Lisse et clair',
                            },
                            style: AppTextStyles.ritualDetail(
                              color: context.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing12),
        _SmallButton(
          label: 'Revenir au look d’origine',
          plain: true,
          onTap: () => _edit(MascotModel.defaultMascot()),
        ),
      ],
    );
  }

  Widget _accessories(BuildContext context, int count, bool known) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final slots = [
      ('Tête', Symbols.face_rounded),
      ('Visage', Symbols.sentiment_satisfied_rounded),
      ('Cou', Symbols.styler_rounded),
      ('Dos', Symbols.backpack_rounded),
    ];
    final available = MascotAccessories.all.where(
      (item) => item.category == _slot,
    );
    final unlocked = MascotAccessories.all
        .where((item) => item.isUnlocked(count))
        .length;
    final next = MascotAccessories.progression
        .where((item) => !item.isUnlocked(count))
        .firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final (name, icon) in slots)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacing4),
                  child: AccessibleAction(
                    label: name,
                    onPressed: () => setState(() => _slot = name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacing8,
                      ),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.surfaceDark
                            : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius18,
                        ),
                        border: Border.all(
                          color: _slot == name
                              ? AppColors.primaryText(dark)
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(icon, color: context.textSecondary),
                          const SizedBox(height: AppDimensions.spacing4),
                          Text(
                            name,
                            style: AppTextStyles.moodLabelSelected(
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacing16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = MediaQuery.textScalerOf(context).scale(11) > 16.5
                ? 2
                : 4;
            final width =
                (constraints.maxWidth -
                    AppDimensions.spacing8 * (columns - 1)) /
                columns;
            return Wrap(
              spacing: AppDimensions.spacing8,
              runSpacing: AppDimensions.spacing12,
              children: [
                for (final item in available)
                  SizedBox(
                    width: width,
                    child: Semantics(
                      selected: _draft.equippedCosmetics.contains(item.id),
                      child: AccessibleAction(
                        label:
                            '${item.name}${known && !item.isUnlocked(count) ? ', ${item.requiredChallenges} défis' : ''}',
                        onPressed: known
                            ? () => _chooseAccessory(item, count)
                            : null,
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: dark
                                      ? AppColors.surfaceDark
                                      : AppColors.cardLight,
                                  borderRadius: BorderRadius.circular(
                                    AppDimensions.radius20,
                                  ),
                                  border: Border.all(
                                    color:
                                        _draft.equippedCosmetics.contains(
                                          item.id,
                                        )
                                        ? AppColors.primaryText(dark)
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Opacity(
                                      opacity: known && item.isUnlocked(count)
                                          ? 1
                                          : .35,
                                      child: Image.asset(
                                        'assets/accessory_portraits/${item.id}.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    if (known && !item.isUnlocked(count))
                                      const Center(
                                        child: Icon(
                                          Symbols.lock_rounded,
                                          color: Colors.white,
                                          size: 22,
                                        ),
                                      ),
                                    if (_draft.equippedCosmetics.contains(
                                      item.id,
                                    ))
                                      Positioned(
                                        top: AppDimensions.spacing4,
                                        right: AppDimensions.spacing4,
                                        child: Icon(
                                          Symbols.check_circle_rounded,
                                          color: AppColors.primaryText(dark),
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacing4),
                            Text(
                              !known
                                  ? '…'
                                  : item.isUnlocked(count)
                                  ? item.name
                                  : '${item.requiredChallenges} défis',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.moodLabelSelected(
                                color: known && item.isUnlocked(count)
                                    ? context.textPrimary
                                    : context.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (known) ...[
          const SizedBox(height: AppDimensions.spacing16),
          _Surface(
            child: Row(
              children: [
                _SectionIcon(
                  icon: Symbols.lock_open_rounded,
                  color: AppColors.violet(dark),
                ),
                const SizedBox(width: AppDimensions.spacing12),
                Expanded(
                  child: Text(
                    '$unlocked sur ${MascotAccessories.all.length} débloqués.${next == null ? ' Tout le vestiaire est à toi.' : ' Prochain : ${next.name}, dans ${next.remainingChallenges(count)} défis.'}',
                    style: AppTextStyles.bodySmall(
                      color: context.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _decors(BuildContext context, int count, bool known) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - AppDimensions.spacing12) / 2;
        return Wrap(
          spacing: AppDimensions.spacing12,
          runSpacing: AppDimensions.spacing12,
          children: [
            for (final decor in MascotDecor.values)
              SizedBox(
                width: width,
                child: Semantics(
                  selected: _decor == decor,
                  child: AccessibleAction(
                    label:
                        '${_decorName(decor)}${known && !MascotDecorRules.isUnlocked(decor, count) ? ', 10 fleurs' : ''}',
                    onPressed: !known
                        ? null
                        : () {
                            if (!MascotDecorRules.isUnlocked(decor, count)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'La Clairière se dévoile après 10 défis terminés.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setState(() => _decor = decor);
                            widget.onPreview(
                              _LookPreview(_draft, _decor, _pop),
                            );
                          },
                    child: Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.surfaceDark
                            : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radius20,
                        ),
                        border: Border.all(
                          color: _decor == decor
                              ? AppColors.primaryText(dark)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 92,
                            child: Opacity(
                              opacity:
                                  known &&
                                      MascotDecorRules.isUnlocked(decor, count)
                                  ? 1
                                  : .45,
                              child: CustomPaint(
                                size: const Size(double.infinity, 92),
                                painter: _ScenePainter(
                                  decor: decor,
                                  dark: dark,
                                  thumbnail: true,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(
                              AppDimensions.spacing8,
                            ),
                            child: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              spacing: AppDimensions.spacing8,
                              children: [
                                Text(
                                  _decorName(decor),
                                  style: AppTextStyles.labelMedium(
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (known &&
                                    !MascotDecorRules.isUnlocked(decor, count))
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Symbols.lock_rounded,
                                        size: 13,
                                        color: context.textTertiary,
                                      ),
                                      Text(
                                        '10 fleurs',
                                        style: AppTextStyles.ritualDetail(
                                          color: context.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

String _decorName(MascotDecor decor) => switch (decor) {
  MascotDecor.arches => 'Arches',
  MascotDecor.hills => 'Collines',
  MascotDecor.waves => 'Vagues',
  MascotDecor.clearing => 'Clairière',
};

class _PalettePainter extends CustomPainter {
  final List<Color> colors;
  const _PalettePainter(this.colors);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    var start = -math.pi / 2;
    for (var i = 0; i < 3; i++) {
      final sweep = i == 0 ? math.pi : math.pi / 2;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = colors[i]);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_PalettePainter old) => old.colors != colors;
}
