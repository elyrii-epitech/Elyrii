import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';
import '../../data/models/mascot_accessory.dart';

class MascotProgressCard extends StatelessWidget {
  const MascotProgressCard({
    super.key,
    required this.completedCount,
    required this.savedSelection,
    required this.onChallenges,
    this.onTryNext,
  });
  final int completedCount;
  final List<String> savedSelection;
  final VoidCallback onChallenges;
  final ValueChanged<MascotAccessory>? onTryNext;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = dark ? AppColors.primaryDark : AppColors.primary;
    final available = MascotAccessories.all
        .where(
          (piece) =>
              piece.isUnlocked(completedCount) ||
              savedSelection.contains(piece.id),
        )
        .length;
    final next = MascotAccessories.progression
        .where(
          (piece) =>
              !piece.isUnlocked(completedCount) &&
              !savedSelection.contains(piece.id),
        )
        .firstOrNull;
    final previous = next == null
        ? 0
        : MascotAccessories.progression
                  .where(
                    (piece) =>
                        piece.requiredChallenges < next.requiredChallenges,
                  )
                  .lastOrNull
                  ?.requiredChallenges ??
              0;
    final progress = next == null
        ? 1.0
        : ((completedCount - previous) / (next.requiredChallenges - previous))
              .clamp(0.0, 1.0);
    return LiquidGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Ta collection',
                  style: AppTextStyles.titleSmall(
                    color: primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '$available / ${MascotAccessories.all.length}',
                style: AppTextStyles.labelMedium(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (next != null) ...[
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: Container(
                    width: 64,
                    height: 76,
                    color: dark
                        ? Colors.white.withValues(alpha: 0.07)
                        : Colors.white.withValues(alpha: 0.7),
                    child: Image.asset(
                      'assets/accessory_portraits/${next.id}.png',
                      fit: BoxFit.contain,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prochain palier',
                        style: AppTextStyles.labelSmall(color: secondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        next.name,
                        style: AppTextStyles.titleSmall(
                          color: primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Encore ${next.remainingChallenges(completedCount)} ${next.remainingChallenges(completedCount) == 1 ? 'défi' : 'défis'} à ton rythme',
                        style: AppTextStyles.bodySmall(color: secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Semantics(
              label:
                  'Prochain palier, $completedCount sur ${next.requiredChallenges} défis terminés',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  color: accent,
                  backgroundColor: accent.withValues(alpha: 0.12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$completedCount / ${next.requiredChallenges} défis terminés',
              style: AppTextStyles.labelSmall(color: secondary),
            ),
          ] else ...[
            Text(
              'Toute la collection est à toi.',
              style: AppTextStyles.titleMedium(
                color: primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${MascotAccessories.all.length} pièces, des centaines de looks. Compose celui qui te ressemble.',
              style: AppTextStyles.bodySmall(color: secondary),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: onChallenges,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Voir mes défis'),
              ),
              if (next != null && onTryNext != null)
                TextButton(
                  onPressed: () => onTryNext!(next),
                  child: const Text('Essayer la récompense'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class MascotCollectionPanel extends StatefulWidget {
  const MascotCollectionPanel({
    super.key,
    required this.selection,
    required this.savedSelection,
    required this.completedCount,
    required this.onSelect,
    this.tryOnId,
  });
  final List<String> selection;
  final List<String> savedSelection;
  final int completedCount;
  final ValueChanged<MascotAccessory> onSelect;
  final String? tryOnId;

  @override
  State<MascotCollectionPanel> createState() => _MascotCollectionPanelState();
}

class _MascotCollectionPanelState extends State<MascotCollectionPanel> {
  String _category = 'Tous';
  bool _availableOnly = false;

  bool _available(MascotAccessory piece) =>
      piece.isUnlocked(widget.completedCount) ||
      widget.savedSelection.contains(piece.id);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final visible = MascotAccessories.progression
        .where(
          (piece) =>
              (_category == 'Tous' || piece.category == _category) &&
              (!_availableOnly || _available(piece)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Les pièces de ton histoire',
          style: AppTextStyles.titleMedium(
            color: primary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Une pièce par zone. Combine-les pour créer ta signature.',
          style: AppTextStyles.bodySmall(color: secondary),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final category in const [
              'Tous',
              'Tête',
              'Visage',
              'Cou',
              'Dos',
            ])
              ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category),
                    if (category != 'Tous' &&
                        widget.selection.any(
                          (id) =>
                              MascotAccessories.byId(id)?.category == category,
                        )) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: 'Une pièce de cette zone est portée',
                        excludeFromSemantics: true,
                        child: Icon(
                          Icons.circle,
                          size: 6,
                          color: dark
                              ? AppColors.primaryDark
                              : AppColors.primary,
                        ),
                      ),
                    ],
                  ],
                ),
                selected: category == _category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '${visible.length} ${visible.length == 1 ? 'pièce' : 'pièces'}',
                style: AppTextStyles.labelSmall(color: secondary),
              ),
            ),
            FilterChip(
              label: const Text('Disponibles'),
              selected: _availableOnly,
              onSelected: (value) => setState(() => _availableOnly = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Tes premières pièces t’attendent. Termine des défis pour enrichir ta collection, à ton rythme.',
              style: AppTextStyles.bodyMedium(color: secondary),
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth < 310 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3
                ? 1
                : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final piece in visible)
                  SizedBox(
                    width: width,
                    child: _CollectionTile(
                      piece: piece,
                      equipped: widget.selection.contains(piece.id),
                      trying: widget.tryOnId == piece.id,
                      locked: !_available(piece),
                      completedCount: widget.completedCount,
                      onTap: () => widget.onSelect(piece),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.piece,
    required this.equipped,
    required this.trying,
    required this.locked,
    required this.completedCount,
    required this.onTap,
  });
  final MascotAccessory piece;
  final bool equipped;
  final bool trying;
  final bool locked;
  final int completedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    final secondary = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accent = dark ? AppColors.primaryDark : AppColors.primary;
    final active = equipped || trying;
    final label = trying
        ? 'En essai'
        : equipped
        ? 'Équipé'
        : locked
        ? '${piece.requiredChallenges} défis'
        : 'Disponible';
    return Semantics(
      button: true,
      selected: equipped,
      label:
          '${piece.name}. ${piece.description}. ${locked
              ? '${piece.remainingChallenges(completedCount)} défis restants. Essayer.'
              : equipped
              ? 'Retirer.'
              : 'Équiper.'}',
      child: ExcludeSemantics(
        child: LiquidGlassCard(
          padding: EdgeInsets.zero,
          borderColor: active ? accent.withValues(alpha: 0.55) : null,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            piece.category,
                            style: AppTextStyles.labelSmall(color: secondary),
                          ),
                        ),
                        Icon(
                          equipped
                              ? Icons.check_circle_rounded
                              : locked
                              ? Icons.lock_outline_rounded
                              : Icons.add_rounded,
                          size: 17,
                          color: active ? accent : secondary,
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 118,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/accessory_portraits/${piece.id}.png',
                        fit: BoxFit.contain,
                        excludeFromSemantics: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      piece.name,
                      style: AppTextStyles.labelMedium(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      label,
                      style: AppTextStyles.labelSmall(
                        color: active ? accent : secondary,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (completedCount / piece.requiredChallenges)
                              .clamp(0, 1),
                          minHeight: 3,
                          color: accent.withValues(alpha: 0.7),
                          backgroundColor: accent.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
