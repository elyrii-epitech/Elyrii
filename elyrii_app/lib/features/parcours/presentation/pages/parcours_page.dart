import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_shell.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/section_sky_header.dart';
import '../../../../routes/app_routes.dart';
import '../../domain/journey.dart';
import '../providers/journey_provider.dart';
import '../widgets/journey_sheets.dart';
import '../widgets/journey_widgets.dart';

class ParcoursPage extends StatefulWidget {
  const ParcoursPage({super.key});

  @override
  State<ParcoursPage> createState() => _ParcoursPageState();
}

class _ParcoursPageState extends State<ParcoursPage> {
  JourneyTopic? _topic;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<JourneyProvider>().load());
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pauseOrResume(
    JourneyProvider provider, {
    required bool resume,
  }) async {
    if (!provider.canWrite) return;
    final result = await (resume ? provider.resume() : provider.pause());
    if (!mounted || result != JourneyCommandResult.changed) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resume
              ? 'Programme repris à la même étape.'
              : 'Programme en pause. Ta position est conservée.',
        ),
      ),
      snackBarAnimationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<JourneyProvider>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    const bodyTop =
        AppDimensions.sectionSkyHeight - AppDimensions.sectionBodyOverlap;
    return Scaffold(
      backgroundColor: AppColors.sectionBody(dark),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                SingleChildScrollView(
                  controller: _scroll,
                  child: Stack(
                    children: [
                      const SectionSkyHeader(
                        title: 'Programmes',
                        scene: SectionSkyScene.arches,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: bodyTop),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: math.max(
                              0,
                              constraints.maxHeight - bodyTop,
                            ),
                          ),
                          child: SectionSkyBody(
                            bottomPadding:
                                AppShell.bottomClearanceOf(context) +
                                AppDimensions.spacing24,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: AppDimensions.spacing16,
                              children: [
                                JourneyFeedback(
                                  error: provider.error,
                                  loading: provider.isLoading,
                                  writing: provider.isWriting,
                                  onRetry: () => provider.load(force: true),
                                ),
                                const JourneyNote(
                                  'Ta progression est enregistrée sur cet appareil.',
                                ),
                                if (!provider.hasLoadedData) ...[
                                  if (provider.isLoading)
                                    const JourneyNote(
                                      'Chargement de tes programmes…',
                                      live: true,
                                    )
                                  else if (provider.error == null) ...[
                                    const JourneyNote(
                                      'Tes programmes ne sont pas disponibles pour le moment.',
                                    ),
                                    JourneyButton(
                                      label: 'Réessayer',
                                      primary: false,
                                      onPressed: () =>
                                          provider.load(force: true),
                                    ),
                                  ],
                                ] else if (provider.current case final current?)
                                  _currentBoard(context, provider, current)
                                else
                                  _catalog(context, provider),
                                _secondary(context, provider),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SectionSkyBar(
                  scroll: _scroll,
                  title: 'Programmes',
                  trailing: const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _catalog(BuildContext context, JourneyProvider provider) {
    final paths = provider.catalog
        .where((path) => _topic == null || path.topic == _topic)
        .toList();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Text(
          'Choisis un programme',
          style: AppTextStyles.titleMedium(color: context.textPrimary),
        ),
        const JourneyNote(
          'Des programmes en plusieurs étapes. Choisis celui qui te convient.',
        ),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing4,
          children: [
            for (final topic in <JourneyTopic?>[null, ...JourneyTopic.values])
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppDimensions.controlSize,
                ),
                child: ChoiceChip(
                  label: Text(
                    topic == null ? 'Tout' : journeyTopicLabel(topic),
                  ),
                  selected: _topic == topic,
                  onSelected: (_) => setState(() => _topic = topic),
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                  labelStyle: AppTextStyles.labelMedium(
                    color: _topic == topic
                        ? AppColors.primaryText(dark)
                        : context.textSecondary,
                  ),
                  selectedColor: AppColors.tintSoft(dark),
                ),
              ),
          ],
        ),
        if (provider.catalog.isEmpty)
          JourneyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppDimensions.spacing8,
              children: [
                const JourneyNote('Aucun programme disponible pour le moment.'),
                JourneyButton(
                  label: 'Actualiser le catalogue',
                  primary: false,
                  onPressed: provider.isLoading || provider.isWriting
                      ? null
                      : () => provider.load(force: true),
                ),
              ],
            ),
          )
        else if (paths.isEmpty)
          JourneyCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: AppDimensions.spacing8,
              children: [
                const JourneyNote(
                  'Aucun programme ne correspond à ce besoin pour le moment.',
                ),
                JourneyButton(
                  label: 'Enlever le filtre',
                  primary: false,
                  onPressed: () => setState(() => _topic = null),
                ),
              ],
            ),
          )
        else
          for (final path in paths)
            JourneyPathTile(
              path: path,
              onTap: provider.isWriting
                  ? null
                  : () => showJourneyDetail(context, provider, path),
            ),
      ],
    );
  }

  Widget _currentBoard(
    BuildContext context,
    JourneyProvider provider,
    JourneyEnrollment current,
  ) {
    final paused = current.status == JourneyStatus.paused;
    final completed = current.status == JourneyStatus.completed;
    final writable = provider.canWrite;
    final step = current.currentStep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing16,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(
            completed
                ? 'Programme terminé'
                : paused
                ? 'Ton programme est en pause'
                : 'Ton programme',
            style: AppTextStyles.titleMedium(color: context.textPrimary),
          ),
        ),
        JourneyCard(
          accented: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: AppDimensions.spacing12,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  JourneyTopicMark(topic: current.path.topic),
                  const SizedBox(width: AppDimensions.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: AppDimensions.spacing4,
                      children: [
                        Text(
                          current.path.title,
                          style: AppTextStyles.titleMedium(
                            color: context.textPrimary,
                          ),
                        ),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            completed
                                ? '${current.path.steps.length} étapes réalisées'
                                : 'Étape ${current.currentStepNumber} sur ${current.path.steps.length}',
                            style: AppTextStyles.bodySmall(
                              color: context.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              _progress(context, current),
              if (completed) ...[
                const JourneyNote(
                  'Programme terminé. Tu peux revoir les étapes ou en choisir un autre.',
                ),
                JourneyButton(
                  label: 'Voir les défis',
                  onPressed: () => context.go(AppRoutes.challenges),
                ),
              ] else if (paused) ...[
                const JourneyNote(
                  'Ta progression est conservée. Reprends quand tu veux.',
                ),
                if (step != null)
                  Text(
                    step.title,
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                JourneyButton(
                  label: 'Reprendre',
                  onPressed: writable
                      ? () => _pauseOrResume(provider, resume: true)
                      : null,
                ),
              ] else if (step != null) ...[
                Text(
                  step.title,
                  style: AppTextStyles.titleSmall(color: context.textPrimary),
                ),
                JourneyNote('${step.durationMinutes} min environ'),
                JourneyButton(
                  label: 'Continuer',
                  onPressed: provider.isWriting
                      ? null
                      : () => showJourneyStep(context, provider),
                ),
              ],
              JourneyButton(
                label: 'Voir les étapes',
                primary: false,
                onPressed: () => showJourneySteps(context, provider),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: AppDimensions.spacing8,
          runSpacing: AppDimensions.spacing8,
          children: [
            _link(
              label: 'Changer de programme',
              onPressed: provider.isWriting
                  ? null
                  : () => showJourneyPicker(context, provider),
            ),
            if (!paused && !completed)
              _link(
                label: 'Mettre en pause',
                onPressed: writable
                    ? () => _pauseOrResume(provider, resume: false)
                    : null,
              ),
            _link(
              label: 'Parler à Elyrii',
              onPressed: () => context.push(AppRoutes.chatbot),
            ),
          ],
        ),
        const JourneyNote(
          'Valide chaque étape avec le bouton « Terminer l’étape ».',
        ),
      ],
    );
  }

  Widget _progress(BuildContext context, JourneyEnrollment current) {
    final pink = AppColors.pink(
      Theme.of(context).brightness == Brightness.dark,
    );
    return ExcludeSemantics(
      child: Wrap(
        spacing: AppDimensions.spacing8,
        runSpacing: AppDimensions.spacing8,
        children: [
          for (var index = 0; index < current.path.steps.length; index++)
            Container(
              width: AppDimensions.spacing12,
              height: AppDimensions.spacing12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < current.completedStepCount
                    ? pink
                    : pink.withValues(alpha: .16),
                border:
                    index == current.completedStepCount &&
                        current.status != JourneyStatus.completed
                    ? Border.all(
                        color: pink,
                        width: AppDimensions.borderWidthMedium,
                      )
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _link({required String label, required VoidCallback? onPressed}) =>
      TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          minimumSize: const Size(
            AppDimensions.controlSize,
            AppDimensions.controlSize,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing12,
            vertical: AppDimensions.spacing8,
          ),
          textStyle: AppTextStyles.buttonSmall(),
        ),
        child: Text(label),
      );

  Widget _secondary(BuildContext context, JourneyProvider provider) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing8,
      children: [
        const Divider(),
        JourneyButton(
          label: 'Mes défis',
          primary: false,
          onPressed: () => showJourneyChallenges(context),
        ),
        if (provider.current == null)
          JourneyButton(
            label: 'Parler à Elyrii · facultatif',
            primary: false,
            onPressed: () => context.push(AppRoutes.chatbot),
          ),
        TextButton.icon(
          onPressed: () => showJourneyHelp(context),
          style: TextButton.styleFrom(
            minimumSize: const Size.fromHeight(AppDimensions.controlSize),
            padding: const EdgeInsets.all(AppDimensions.spacing12),
            backgroundColor: AppColors.pink(dark).withValues(alpha: .10),
            foregroundColor: context.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radius16),
            ),
          ),
          icon: const Icon(Symbols.support_agent_rounded),
          label: const Text('Besoin d’aide maintenant ?'),
        ),
      ],
    );
  }
}
