import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/gamification_models.dart';
import '../providers/gamification_provider.dart';

class ChallengeCollection extends StatefulWidget {
  final GamificationProvider provider;
  const ChallengeCollection({super.key, required this.provider});

  @override
  State<ChallengeCollection> createState() => _ChallengeCollectionState();
}

class _ChallengeCollectionState extends State<ChallengeCollection> {
  bool _busy = false;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.provider.loadAll());
    });
  }

  Future<void> _perform(Future<bool> Function() command, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    final saved = await command();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _feedback = saved
          ? success
          : widget.provider.error ??
                'Le changement n’a pas été enregistré. Réessaie.';
    });
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.provider,
    builder: (context, child) {
      final provider = widget.provider;
      final dark = Theme.of(context).brightness == Brightness.dark;
      final commandsDisabled =
          _busy || provider.isLoading || provider.error != null;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: AppDimensions.spacing16,
        children: [
          Text(
            'Un petit pas à ton rythme. Les défis terminés font pousser les fleurs de ton jardin.',
            style: AppTextStyles.bodyMedium(color: context.textSecondary),
          ),
          if (_feedback != null && provider.error == null)
            Semantics(
              liveRegion: true,
              child: Text(
                _feedback!,
                style: AppTextStyles.bodySmall(color: context.textPrimary),
              ),
            ),
          if (provider.isLoading)
            const Center(child: CircularProgressIndicator()),
          if (provider.error != null) ...[
            Semantics(
              liveRegion: true,
              child: Text(
                provider.error!,
                style: AppTextStyles.bodyMedium(
                  color: AppColors.errorText(dark),
                ),
              ),
            ),
            TextButton(
              onPressed: _busy ? null : () => provider.loadAll(force: true),
              child: const Text('Réessayer'),
            ),
          ],
          if (provider.hasLoadedData) ...[
            Text(
              'En cours',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.activeChallenges.isEmpty)
              Text(
                'Aucun défi en cours. Choisis une idée qui te fait du bien.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final challenge in provider.activeChallenges)
              _ChallengeIdea(
                title: challenge.displayTitle,
                description: challenge.displayDescription,
                progress: challenge,
              ),
            Text(
              'Les idées d’Elyrii',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.proposals.isEmpty)
              Text(
                'Pas de proposition pour le moment.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final proposal in provider.proposals)
              _ChallengeIdea(
                title: proposal.displayTitle,
                description: proposal.displayDescription,
                action: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: AppDimensions.spacing8,
                  children: [
                    TextButton(
                      onPressed: commandsDisabled
                          ? null
                          : () => _perform(
                              () => provider.rejectChallenge(proposal.id),
                              'La proposition a été retirée.',
                            ),
                      child: const Text('Refuser'),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryText(dark),
                        foregroundColor: AppColors.onTint(dark),
                      ),
                      onPressed: commandsDisabled
                          ? null
                          : () => _perform(
                              () => provider.acceptChallenge(proposal.id),
                              'Ton défi est en cours.',
                            ),
                      child: const Text('Accepter'),
                    ),
                  ],
                ),
              ),
            Text(
              'Idées de défis',
              style: AppTextStyles.titleMedium(color: context.textPrimary),
            ),
            if (provider.availableChallenges.isEmpty)
              Text(
                'Les prochains défis apparaîtront ici.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final challenge in provider.availableChallenges)
              _ChallengeIdea(
                title: challenge.title,
                description: challenge.description ?? '',
                action: TextButton.icon(
                  onPressed: commandsDisabled
                      ? null
                      : () => _perform(
                          () => provider.startChallenge(challenge.id),
                          'Ton défi est en cours.',
                        ),
                  icon: const Icon(Symbols.add_rounded),
                  label: const Text('Commencer'),
                ),
              ),
          ],
        ],
      );
    },
  );
}

class _ChallengeIdea extends StatelessWidget {
  final String title;
  final String description;
  final UserChallenge? progress;
  final Widget? action;
  const _ChallengeIdea({
    required this.title,
    required this.description,
    this.progress,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final challenge = progress;
    return Material(
      color: AppColors.gardenGroup(dark),
      borderRadius: BorderRadius.circular(AppDimensions.radius16),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacing12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: AppDimensions.spacing8,
          children: [
            Row(
              children: [
                Icon(
                  Symbols.eco_rounded,
                  size: AppDimensions.iconSm,
                  color: AppColors.green(dark),
                ),
                const SizedBox(width: AppDimensions.spacing8),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleSmall(color: context.textPrimary),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty)
              Text(
                description,
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            if (challenge != null && challenge.progress != null) ...[
              Text(
                challenge.progressText,
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
              LinearProgressIndicator(
                value: challenge.progressFraction,
                color: AppColors.green(dark),
                backgroundColor: AppColors.track(dark),
              ),
            ],
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}
