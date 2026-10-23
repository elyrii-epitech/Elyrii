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
            'Défis à réaliser',
            style: AppTextStyles.titleLarge(color: context.textPrimary),
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
            if (provider.activeChallenges.isNotEmpty)
              Text(
                'En cours',
                style: AppTextStyles.titleMedium(color: context.textPrimary),
              ),
            if (provider.activeChallenges.isEmpty)
              Text(
                provider.proposals.isEmpty &&
                        provider.availableChallenges.isEmpty
                    ? 'Aucun défi à réaliser pour le moment.'
                    : 'Aucun défi en cours. Choisis une idée qui te fait du bien.',
                style: AppTextStyles.bodySmall(color: context.textSecondary),
              ),
            for (final challenge in provider.activeChallenges)
              _ChallengeIdea(
                title: challenge.displayTitle,
                description: challenge.displayDescription,
                progress: challenge,
              ),
            if (provider.proposals.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                initiallyExpanded: provider.proposals.length <= 3,
                title: Text(
                  'Les idées d’Elyrii (${provider.proposals.length})',
                  style: AppTextStyles.titleMedium(color: context.textPrimary),
                ),
                children: [
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
                ],
              ),
            if (provider.availableChallenges.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  initiallyExpanded: false,
                  title: Text(
                    'Idées de défis (${provider.availableChallenges.length})',
                    style: AppTextStyles.titleMedium(
                      color: context.textPrimary,
                    ),
                  ),
                  children: [
                    for (final challenge in provider.availableChallenges)
                      Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppDimensions.spacing8,
                        ),
                        child: _ChallengeIdea(
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
                      ),
                  ],
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
