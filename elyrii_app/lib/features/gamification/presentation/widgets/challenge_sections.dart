import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/gamification_provider.dart';
import 'ai_proposal_card.dart';
import 'challenge_card.dart';
import 'quest_tile.dart';

/// Slivers build only visible rows, including large completed histories.
class ChallengeQuestsSliver extends StatelessWidget {
  const ChallengeQuestsSliver({
    super.key,
    required this.provider,
    required this.onStart,
    required this.onAccept,
    required this.onReject,
    this.startingId,
    this.processingId,
  });
  final GamificationProvider provider;
  final ValueChanged<String> onStart;
  final ValueChanged<String> onAccept;
  final ValueChanged<String> onReject;
  final String? startingId;
  final String? processingId;
  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      const SliverToBoxAdapter(child: _SectionTitle('Rituels en cours')),
      if (provider.activeChallenges.isEmpty)
        const SliverToBoxAdapter(
          child: ChallengeEmptyCard(
            key: ValueKey('quests_empty_subview'),
            title: 'Aucun rituel actif aujourd’hui',
            subtitle: 'Choisis une graine ci-dessous pour faire grandir ton jardin, ou avance à ton propre rythme.',
          ),
        )
      else
        SliverList.builder(
          itemCount: provider.activeChallenges.length,
          itemBuilder: (_, index) {
            final item = provider.activeChallenges[index];
            return QuestTile(
              key: ValueKey(item.id),
              title: item.displayTitle,
              subtitle: _shortDescription(item.displayDescription),
              icon: item.displayIcon,
              xpReward: item.template?.rewardPoints ?? 50,
              isCompleted: false,
              progressFraction: item.progressFraction,
              progressText: item.progressText,
            );
          },
        ),
      if (provider.proposals.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _SectionTitle('Graines proposées par ton Coach IA'),
        ),
        SliverList.builder(
          itemCount: provider.proposals.length,
          itemBuilder: (_, index) {
            final item = provider.proposals[index];
            return AiProposalCard(
              key: ValueKey(item.id),
              proposal: item,
              isProcessing: processingId == item.id,
              onAccept: () => onAccept(item.id),
              onReject: () => onReject(item.id),
            );
          },
        ),
      ],
      if (provider.availableChallenges.isNotEmpty) ...[
        const SliverToBoxAdapter(
          child: _SectionTitle('À découvrir dans le sanctuaire'),
        ),
        SliverList.builder(
          itemCount: provider.availableChallenges.length,
          itemBuilder: (_, index) {
            final item = provider.availableChallenges[index];
            return ChallengeAvailableCard(
              key: ValueKey(item.id),
              challenge: item,
              isStarting: startingId == item.id,
              onStart: () => onStart(item.id),
            );
          },
        ),
      ],
    ],
  );
}

class ChallengeHistorySliver extends StatelessWidget {
  const ChallengeHistorySliver({super.key, required this.provider});
  final GamificationProvider provider;
  @override
  Widget build(BuildContext context) {
    if (provider.completedChallenges.isEmpty) {
      return const SliverToBoxAdapter(
        child: ChallengeEmptyCard(
          key: ValueKey('history_empty_subview'),
          title: 'Ton herbier est encore vierge',
          subtitle: 'Chaque rituel mené à son terme laissera ici une trace douce de ton chemin.',
        ),
      );
    }
    return SliverList.builder(
      key: const ValueKey('history_list_subview'),
      itemCount: provider.completedChallenges.length,
      itemBuilder: (_, index) {
        final item = provider.completedChallenges[index];
        return QuestTile(
          key: ValueKey(item.id),
          title: item.displayTitle,
          subtitle: _shortDescription(item.displayDescription),
          icon: item.displayIcon,
          xpReward: item.template?.rewardPoints ?? 50,
          isCompleted: true,
        );
      },
    );
  }
}

class ChallengeEmptyCard extends StatelessWidget {
  const ChallengeEmptyCard({
    super.key,
    required this.title,
    required this.subtitle,
  });
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(
      children: [
        const Icon(Icons.spa_rounded),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 10),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight,
      ),
    ),
  );
}

String _shortDescription(String value) =>
    value.characters.length <= 48 ? value : '${value.characters.take(48)}…';
