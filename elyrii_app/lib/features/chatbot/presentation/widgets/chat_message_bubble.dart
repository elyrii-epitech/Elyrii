import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

abstract final class ChatBubbleStyles {
  static const BorderRadius userRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(20),
  );

  static BoxDecoration assistant(bool isDark) => BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.045),
    borderRadius: BorderRadius.circular(18),
  );
}

class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: isUser
              ? _buildUserMessage(context, isDark)
              : _buildAssistantMessage(context, isDark),
        ),
      ),
    );
  }

  Widget _buildUserMessage(BuildContext context, bool isDark) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: (MediaQuery.sizeOf(context).width * 0.78).clamp(220, 560),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF302C3B) : const Color(0xFFEDEAF5),
          borderRadius: ChatBubbleStyles.userRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 16,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssistantMessage(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const ImageIcon(
            AssetImage('assets/brand/navbar_app_icon.png'),
            size: 20,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2, right: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elyrii',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  message,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontSize: 15.5,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
