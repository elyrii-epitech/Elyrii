import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget pour afficher un message dans le chat
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _buildAvatar(isDark),
          if (!isUser) const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    gradient: isUser
                        ? LinearGradient(
                            colors: [
                              AppColors.primary
                                  .withValues(alpha: 0.8), // Plus doux
                              AppColors.primary.withValues(alpha: 0.65),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: isUser
                        ? null
                        : isDark
                            ? AppColors.surfaceDark.withValues(alpha: 0.6)
                            : AppColors.surfaceLight,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(28), // Plus arrondi
                      topRight: const Radius.circular(28),
                      bottomLeft: Radius.circular(isUser ? 28 : 8),
                      bottomRight: Radius.circular(isUser ? 8 : 28),
                    ),
                    border: isUser
                        ? null
                        : Border.all(
                            color: isDark
                                ? AppColors.borderDark.withValues(alpha: 0.3)
                                : AppColors.borderLight.withValues(alpha: 0.5),
                            width: 1,
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black
                                .withValues(alpha: 0.15) // Ombre plus douce
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Text(
                    message,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                      fontSize: 16, // Texte légèrement plus grand
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(timestamp),
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 12),
          if (isUser) _buildAvatar(isDark),
        ],
      ),
    );
  }

  Widget _buildAvatar(bool isDark) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: isUser
            ? LinearGradient(
                colors: [
                  AppColors.secondary.withValues(alpha: 0.9),
                  AppColors.secondary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.85),
                  AppColors.accent.withValues(alpha: 0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: (isUser ? AppColors.secondary : AppColors.primary)
                .withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.favorite_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
