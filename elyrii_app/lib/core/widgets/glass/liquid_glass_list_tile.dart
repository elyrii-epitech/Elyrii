// iOS 26 Liquid Glass List Tile & Chip
// Part of the Liquid Glass Widget Kit

import 'package:flutter/material.dart';

import '../../glass/elyrii_glass_surface.dart';
import '../accessible_action.dart';

// =============================================================================
// LIQUID GLASS LIST TILE
// =============================================================================

class LiquidGlassListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leadingIcon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;

  const LiquidGlassListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                leadingIcon,
                size: 18,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
          if (trailing == null && showChevron && onTap != null)
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.25),
            ),
        ],
      ),
    );
    if (onTap == null) return content;
    return AccessibleAction(
      label: subtitle == null ? title : '$title, $subtitle',
      onPressed: onTap,
      child: content,
    );
  }
}

// =============================================================================
// LIQUID GLASS CHIP
// =============================================================================

class LiquidGlassChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;

  const LiquidGlassChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Semantics(
      selected: isSelected,
      child: AccessibleAction(
        label: label,
        onPressed: onTap,
        borderRadius: BorderRadius.circular(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            glassColor: isSelected ? primaryColor : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? Colors.white
                              : Colors.black.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : (isDark
                              ? Colors.white
                              : Colors.black.withValues(alpha: 0.7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
