import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Styles de bulles iMessage partagés entre les messages et l'indicateur
/// de frappe, pour une apparence strictement identique.
abstract final class ChatBubbleStyles {
  /// Rayons squircle asymétriques : le coin bas côté expéditeur est
  /// resserré (queue de bulle iMessage), les autres restent pleins.
  static const BorderRadius userRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(20),
    bottomRight: Radius.circular(6),
  );

  static const BorderRadius assistantRadius = BorderRadius.only(
    topLeft: Radius.circular(20),
    topRight: Radius.circular(20),
    bottomLeft: Radius.circular(6),
    bottomRight: Radius.circular(20),
  );

  /// Bulle utilisateur : dégradé lavande doux (primary -> primaryDark).
  static const BoxDecoration user = BoxDecoration(
    gradient: LinearGradient(
      colors: [AppColors.primary, AppColors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: userRadius,
  );

  /// Bulle assistante : verre translucide clair, sans ombre criarde.
  static BoxDecoration assistant(bool isDark) => BoxDecoration(
    color: isDark
        ? const Color(0xFF232026).withValues(alpha: 0.9)
        : Colors.white.withValues(alpha: 0.82),
    borderRadius: assistantRadius,
    border: Border.all(
      color: isDark
          ? Colors.white.withValues(alpha: 0.10)
          : Colors.black.withValues(alpha: 0.05),
      width: 0.8,
    ),
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

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        // Espacement iMessage : respiration horizontale large, groupe
        // vertical serré pour lire la conversation comme un flux.
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: isUser
              ? ChatBubbleStyles.user
              : ChatBubbleStyles.assistant(isDark),
          child: _buildMessageContent(isDark),
        ),
      ),
    );
  }

  Widget _buildMessageContent(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(
            color: isUser
                ? Colors.white
                : (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight),
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
                : (isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
