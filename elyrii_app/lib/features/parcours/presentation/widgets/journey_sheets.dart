import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../routes/app_routes.dart';
import '../../../gamification/presentation/providers/gamification_provider.dart';
import '../../../gamification/presentation/widgets/challenge_collection.dart';
import '../../../journal/presentation/providers/journal_provider.dart';
import '../../../journal/presentation/widgets/journal_sheets.dart';
import '../../../meditation/data/repositories/meditation_repository.dart';
import '../../../meditation/presentation/controllers/meditation_controller.dart';
import '../../../meditation/presentation/meditation_practices.dart';
import '../../../meditation/presentation/widgets/meditation_practice_preview.dart';
import '../../domain/journey.dart';
import '../providers/journey_provider.dart';
import 'journey_widgets.dart';

Future<T?> showJourneySheet<T>(
  BuildContext context, {
  required String title,
  required Widget child,
}) => Navigator.of(context, rootNavigator: true).push<T>(
  AppSheetRoute<T>(
    reduced: MediaQuery.disableAnimationsOf(context),
    builder: (_) => Focus(
      autofocus: true,
      child: AppSheetPanel(title: title, child: child),
    ),
  ),
);

void _announceJourney(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(content: Text(message)),
    snackBarAnimationStyle: MediaQuery.disableAnimationsOf(context)
        ? AnimationStyle.noAnimation
        : null,
  );
}

Future<bool?> showJourneyDetail(
  BuildContext context,
  JourneyProvider provider,
  JourneyPath path,
) => showJourneySheet<bool>(
  context,
  title: path.title,
  child: _JourneyDetail(provider: provider, path: path),
);

Future<void> showJourneyPicker(
  BuildContext context,
  JourneyProvider provider,
) => showJourneySheet<void>(
  context,
  title: 'Changer de programme',
  child: AnimatedBuilder(
    animation: provider,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: AppDimensions.spacing12,
      children: [
        const JourneyNote(
          'Choisis un programme. Une confirmation te sera demandée pour remplacer celui en cours.',
        ),
        JourneyFeedback(
          error: provider.error,
          loading: provider.isLoading,
          writing: provider.isWriting,
          onRetry: () => provider.load(force: true),
        ),
        if (provider.hasLoadedData && provider.catalog.isEmpty)
          const JourneyNote('Aucun programme n’est disponible pour le moment.'),
        for (final path in provider.catalog)
          JourneyPathTile(
            path: path,
            onTap: provider.isWriting
                ? null
                : () async {
                    final chosen = await showJourneyDetail(
                      context,
                      provider,
                      path,
                    );
                    if (chosen == true && context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
      ],
    ),
  ),
);

class _JourneyDetail extends StatefulWidget {
  final JourneyProvider provider;
  final JourneyPath path;
  const _JourneyDetail({required this.provider, required this.path});

  @override
  State<_JourneyDetail> createState() => _JourneyDetailState();
}

class _JourneyDetailState extends State<_JourneyDetail> {
  late final String? _originalEnrollmentId =
      widget.provider.current?.enrollmentId;
  late final int? _originalRevision = widget.provider.current?.revision;
  bool _confirming = false;

  bool get _samePosition =>
      widget.provider.current?.enrollmentId == _originalEnrollmentId &&
      widget.provider.current?.revision == _originalRevision;

  Future<void> _choose() async {
    if (!_samePosition || !widget.provider.canWrite) return;
    final result = await widget.provider.choose(widget.path);
    if (!mounted || result == JourneyCommandResult.failed) return;
    if (result == JourneyCommandResult.changed) {
      _announceJourney(context, 'Programme choisi.');
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.provider,
    builder: (context, _) {
      final provider = widget.provider;
      final current = provider.current;
      final path = widget.path;
      final available =
          provider.hasLoadedData &&
          provider.catalog.any(
            (item) =>
                item.pathId == path.pathId &&
                item.contentVersion == path.contentVersion,
          );
      final alreadyChosen =
          current?.path.pathId == path.pathId &&
          current?.path.contentVersion == path.contentVersion;
      final canChoose =
          available && _samePosition && !alreadyChosen && provider.canWrite;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing16,
        children: [
          JourneyNote(path.description),
          JourneyNote(
            '${journeyTopicLabel(path.topic)} · ${path.steps.length} étapes ',
          ),
          const JourneyNote(
            'Les durées sont indicatives. Tu peux mettre ce programme en pause à tout moment.',
          ),
          JourneyStepList(path: path),
          JourneyFeedback(
            error: provider.error,
            loading: provider.isLoading,
            writing: provider.isWriting,
            onRetry: () => provider.load(force: true),
          ),
          if (!_samePosition)
            const JourneyNote(
              'Le programme a changé. Ferme cette fiche et actualise ta progression.',
              live: true,
            ),
          if (!available && !provider.isLoading)
            const JourneyNote(
              'Ce contenu n’est plus disponible. Ferme cette fiche et actualise le catalogue.',
            ),
          if (alreadyChosen)
            const JourneyNote(
              'Programme déjà sélectionné. Ta progression est conservée.',
            ),
          if (_confirming && current != null && _samePosition) ...[
            JourneyCard(
              accented: true,
              child: JourneyNote(
                'Remplacer « ${current.path.title} » par « ${path.title} » ? Ta progression actuelle sera remplacée. Tes notes et tes défis seront conservés.',
              ),
            ),
            JourneyButton(
              label: 'Confirmer le changement',
              onPressed: canChoose ? _choose : null,
            ),
            JourneyButton(
              label: 'Garder mon programme',
              primary: false,
              onPressed: provider.isWriting
                  ? null
                  : () => Navigator.of(context).pop(false),
            ),
          ] else
            JourneyButton(
              label: alreadyChosen
                  ? 'Programme déjà choisi'
                  : 'Choisir ce programme',
              onPressed: !canChoose
                  ? null
                  : () {
                      if (current == null) {
                        _choose();
                      } else {
                        setState(() => _confirming = true);
                      }
                    },
            ),
        ],
      );
    },
  );
}

Future<void> showJourneySteps(BuildContext context, JourneyProvider provider) {
  final enrollmentId = provider.current?.enrollmentId;
  return showJourneySheet<void>(
    context,
    title: 'Les étapes du programme',
    child: AnimatedBuilder(
      animation: provider,
      builder: (context, _) {
        final current = provider.current;
        if (current == null || current.enrollmentId != enrollmentId) {
          return const JourneyNote(
            'Le programme a changé. Reviens à la page Programmes.',
            live: true,
          );
        }
        return JourneyStepList(
          path: current.path,
          completedCount: current.completedStepCount,
          paused: current.status == JourneyStatus.paused,
          onCurrent: () => showJourneyStep(context, provider),
        );
      },
    ),
  );
}

Future<void> showJourneyStep(BuildContext context, JourneyProvider provider) {
  final current = provider.current;
  final step = current?.currentStep;
  if (current == null || step == null) return Future.value();
  return showJourneySheet<void>(
    context,
    title: 'L’étape du programme',
    child: _JourneyStepSheet(
      provider: provider,
      enrollmentId: current.enrollmentId,
      step: step,
    ),
  );
}

class _JourneyStepSheet extends StatefulWidget {
  final JourneyProvider provider;
  final String enrollmentId;
  final JourneyStep step;
  const _JourneyStepSheet({
    required this.provider,
    required this.enrollmentId,
    required this.step,
  });

  @override
  State<_JourneyStepSheet> createState() => _JourneyStepSheetState();
}

class _JourneyStepSheetState extends State<_JourneyStepSheet> {
  bool _launching = false;

  bool get _sameStep {
    final current = widget.provider.current;
    return current?.enrollmentId == widget.enrollmentId &&
        current?.status == JourneyStatus.active &&
        current?.currentStep?.stepId == widget.step.stepId;
  }

  Future<void> _complete() async {
    if (!_sameStep || !widget.provider.canWrite || _launching) return;
    final result = await widget.provider.completeStep(widget.step.stepId);
    if (!mounted || result == JourneyCommandResult.failed) return;
    if (result == JourneyCommandResult.changed) {
      _announceJourney(
        context,
        widget.provider.current?.status == JourneyStatus.completed
            ? 'Programme terminé. Toutes les étapes sont réalisées.'
            : 'Étape réalisée. Ta progression est enregistrée.',
      );
    }
    Navigator.of(context).pop();
  }

  Future<void> _launch(JourneyAction action) async {
    if (!_sameStep || _launching) return;
    setState(() => _launching = true);
    try {
      switch (action) {
        case JourneyJournalAction(:final prompt):
          await showJournalEditor(
            context,
            provider: context.read<JournalProvider>(),
            initialPrompt: prompt,
          );
        case JourneyMeditationAction(:final programId, :final durationMinutes):
          final practice = MeditationPractice.forId(programId);
          if (practice == null ||
              !practice.durations.contains(durationMinutes)) {
            await context.push(AppRoutes.meditation);
            break;
          }
          final start = await Navigator.of(context, rootNavigator: true)
              .push<bool>(
                AppSheetRoute<bool>(
                  reduced: MediaQuery.disableAnimationsOf(context),
                  builder: (_) => MeditationPracticePreview(
                    practice: practice,
                    duration: durationMinutes,
                  ),
                ),
              );
          if (!mounted || start != true || !_sameStep) return;
          final controller = MeditationController(
            repository: MeditationRepository(client: context.read<ApiClient>()),
          )..setExercise(practice.exercise);
          controller.setDuration(durationMinutes);
          try {
            unawaited(controller.startSession());
            await context.push(AppRoutes.meditationSession, extra: controller);
          } finally {
            controller.dispose();
          }
        case JourneyNoAction():
          break;
      }
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.provider,
    builder: (context, _) {
      final provider = widget.provider;
      final current = provider.current;
      if (current == null || current.enrollmentId != widget.enrollmentId) {
        return const JourneyNote(
          'Le programme a changé. Reviens à la page Programmes.',
          live: true,
        );
      }
      final step = widget.step;
      final stepNumber =
          current.path.steps.indexWhere((item) => item.stepId == step.stepId) +
          1;
      final done = current.path.steps
          .take(current.completedStepCount)
          .any((item) => item.stepId == step.stepId);
      final enabled = _sameStep && provider.canWrite && !_launching;
      final canLaunch = _sameStep && !provider.isWriting && !_launching;
      final actionLabel = switch (step.action) {
        JourneyJournalAction() => 'Ouvrir mon Journal',
        JourneyMeditationAction(:final programId) =>
          'Ouvrir ${MeditationPractice.forId(programId)?.title ?? 'Méditer'}',
        JourneyNoAction() => null,
      };
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing16,
        children: [
          Text(
            step.title,
            style: AppTextStyles.titleMedium(color: context.textPrimary),
          ),
          JourneyNote(
            'Étape $stepNumber sur ${current.path.steps.length} · ${step.durationMinutes} min environ. Tu peux t’arrêter quand tu veux.',
          ),
          Text(
            step.instructions,
            style: AppTextStyles.bodyLarge(color: context.textPrimary),
          ),
          if (actionLabel != null) ...[
            JourneyButton(
              label: actionLabel,
              primary: false,
              onPressed: canLaunch ? () => _launch(step.action) : null,
            ),
            const JourneyNote(
              'Après l’activité, reviens ici pour terminer l’étape.',
            ),
          ],
          JourneyFeedback(
            error: provider.error,
            loading: provider.isLoading,
            writing: provider.isWriting,
            onRetry: () => provider.load(force: true),
          ),
          if (done)
            const JourneyNote('Cette étape est déjà terminée.', live: true)
          else if (current.status == JourneyStatus.paused)
            const JourneyNote(
              'Ton programme est en pause. Reprends-le depuis la page Programmes avant de valider.',
            ),
          if (!done)
            JourneyButton(
              label: 'Terminer l’étape',
              onPressed: enabled ? _complete : null,
            ),
          JourneyButton(
            label: 'Fermer',
            primary: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    },
  );
}

Future<void> showJourneyChallenges(BuildContext context) =>
    showJourneySheet<void>(
      context,
      title: 'Mes défis',
      child: ChallengeCollection(
        provider: context.read<GamificationProvider>(),
      ),
    );

Future<void> showJourneyHelp(BuildContext context) => showJourneySheet<void>(
  context,
  title: 'Besoin d’aide maintenant ?',
  child: const _JourneyHelp(),
);

class _JourneyHelp extends StatefulWidget {
  const _JourneyHelp();

  @override
  State<_JourneyHelp> createState() => _JourneyHelpState();
}

class _JourneyHelpState extends State<_JourneyHelp> {
  String? _message;

  Future<void> _call(String number) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: number))) return;
    } catch (_) {
      // A desktop browser may not have a phone application.
    }
    if (mounted) {
      setState(() => _message = 'Compose le $number depuis un téléphone.');
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppDimensions.spacing16,
    children: [
      const JourneyNote('Tu peux contacter ces services directement.'),
      const JourneyNote(
        'En France, le 3114 est le numéro national de prévention du suicide. Il est gratuit et accessible 24 h/24, 7 j/7.',
      ),
      JourneyButton(label: 'Appeler le 3114', onPressed: () => _call('3114')),
      const JourneyNote(
        'En cas de danger immédiat, contacte les urgences au 112, dans l’Union européenne.',
      ),
      JourneyButton(
        label: 'Appeler les urgences · 112',
        primary: false,
        onPressed: () => _call('112'),
      ),
      if (_message != null) JourneyNote(_message!, live: true),
      const JourneyNote(
        'L’ouverture de cette aide ne lance aucun appel. Seul un bouton « Appeler » ouvre le téléphone.',
      ),
    ],
  );
}
