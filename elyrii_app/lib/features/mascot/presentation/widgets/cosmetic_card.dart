import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_card.dart';

class CosmeticCard extends StatelessWidget {
  final String name;
  final String emoji;
  final bool equipped;
  final VoidCallback onTap;

  const CosmeticCard({
    super.key,
    required this.name,
    required this.emoji,
    required this.equipped,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidGlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      borderColor: equipped ? AppColors.primary.withValues(alpha: 0.45) : null,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (equipped)
            const Icon(Icons.check_circle_rounded, color: AppColors.primary),
        ],
      ),
    );
  }
}
