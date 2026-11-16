import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/entities/chat_message.dart';

abstract final class ChatBubbleStyles {
  static const BorderRadius userRadius = BorderRadius.only(
    topLeft: Radius.circular(AppDimensions.radius20),
    topRight: Radius.circular(AppDimensions.radius20),
    bottomLeft: Radius.circular(AppDimensions.radius20),
    bottomRight: Radius.circular(AppDimensions.radius20),
  );

  static BoxDecoration assistant(bool isDark) => BoxDecoration(
    color: isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.045),
    borderRadius: BorderRadius.circular(AppDimensions.radius16),
  );
}

class ChatMessageBubble extends StatelessWidget {
  final String message;
  final bool isUser;
  final DateTime timestamp;
  final MessageDelivery delivery;
  final VoidCallback? onRetry;
  final VoidCallback? onReport;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    required this.timestamp,
    this.delivery = MessageDelivery.delivered,
    this.onRetry,
    this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacing20,
            vertical: AppDimensions.spacing8,
          ),
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing16,
          vertical: AppDimensions.spacing12,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF302C3B) : const Color(0xFFEDEAF5),
          borderRadius: ChatBubbleStyles.userRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: AppTextStyles.bodyLarge(color: context.textPrimary),
            ),
            if (delivery != MessageDelivery.delivered) ...[
              const SizedBox(height: AppDimensions.spacing8),
              Semantics(
                liveRegion: true,
                child: Text(
                  delivery == MessageDelivery.pending
                      ? 'En attente de réponse…'
                      : 'Réponse non reçue',
                  style: AppTextStyles.bodySmall(
                    color: delivery == MessageDelivery.failed
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (delivery == MessageDelivery.failed)
                TextButton(onPressed: onRetry, child: const Text('Réessayer')),
            ],
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
        const SizedBox(width: AppDimensions.spacing12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: AppDimensions.spacing2,
              right: AppDimensions.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elyrii · IA',
                  style: AppTextStyles.overline(color: context.textSecondary),
                ),
                const SizedBox(height: AppDimensions.spacing4),
                Semantics(
                  label: 'Réponse de l’assistant IA',
                  child: SelectableText(
                    message,
                    style: AppTextStyles.bodyLarge(color: context.textPrimary),
                  ),
                ),
                if (onReport != null)
                  TextButton.icon(
                    onPressed: onReport,
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Signaler cette réponse'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
