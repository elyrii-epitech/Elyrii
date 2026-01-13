import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) _buildAvatar(isDark),
          if (!isUser) const SizedBox(width: 10),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [
                          AppColors.primary,
                          Color(0xFF7B5FE0),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : AppColors.cardDark,
                borderRadius: BorderRadius.circular(18),
                border: isUser
                    ? null
                    : Border.all(
                        color: AppColors.borderDark.withValues(alpha: 0.2),
                        width: 1,
                      ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      color: isUser ? Colors.white : AppColors.textPrimaryDark,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(timestamp),
                    style: TextStyle(
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppColors.textTertiaryDark,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 10),
          if (isUser) _buildAvatar(isDark),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser
            ? AppColors.surfaceDark
            : AppColors.primary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.smart_toy_rounded,
        color: isUser ? AppColors.textSecondaryDark : AppColors.primary,
        size: 18,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
