import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass/liquid_glass_sheet.dart';
import '../../data/entities/chat_session.dart';
import '../providers/chatbot_provider.dart';

/// Feuille d'historique des conversations : liste des sessions passées
/// (titre, date relative, taille du fil), reprise au tap, suppression
/// à l'icône corbeille, et démarrage d'une nouvelle conversation.
class ChatHistorySheet extends StatelessWidget {
  const ChatHistorySheet({super.key, this.scrollController});
  final ScrollController? scrollController;

  /// Ouvre la feuille au-dessus de la page chat.
  static Future<void> show(BuildContext context) {
    return showLiquidGlassSheet(
      context: context,
      useRootNavigator: true,
      initialChildSize: 0.7,
      scrollableBuilder: (context, controller) =>
          ChatHistorySheet(scrollController: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<ChatbotProvider>(
      builder: (context, provider, _) {
        final sessions = provider.conversations;
        final activeId = provider.activeSessionId;

        return CustomScrollView(
          controller: scrollController,
          slivers: [
            if (provider.loadingSession)
              const SliverToBoxAdapter(child: LinearProgressIndicator()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    if (sessions.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          ElyriiHaptics.medium();
                          provider.startNewConversation();
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Nouvelle',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (provider.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(provider.error!),
                ),
              ),
            if (provider.hasLegacyHistory)
              SliverToBoxAdapter(
                child: TextButton.icon(
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Récupérer mon ancien historique'),
                  onPressed: () => _importLegacy(context, provider),
                ),
              ),
            if (sessions.isEmpty)
              SliverToBoxAdapter(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                sliver: SliverList.separated(
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final isActive = session.id == activeId;
                    return _buildSessionTile(
                      context,
                      provider: provider,
                      session: session,
                      isActive: isActive,
                      isDark: isDark,
                    );
                  },
                ),
              ),
            if (provider.hasMoreSessions)
              SliverToBoxAdapter(
                child: TextButton(
                  onPressed: provider.loadMoreSessions,
                  child: const Text('Conversations précédentes'),
                ),
              ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.paddingOf(context).bottom + 16,
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importLegacy(
    BuildContext context,
    ChatbotProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Récupérer cet historique ?'),
        content: const Text(
          'Cet ancien historique est enregistré sur cet appareil sans compte associé. Confirme qu’il t’appartient avant de l’importer dans ton compte.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Importer'),
          ),
        ],
      ),
    );
    if (confirmed == true) await provider.importLegacyHistory();
  }

  Widget _buildEmptyState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 72),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.forum_outlined,
            size: 44,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            'Aucune conversation pour l\'instant.\n'
            'Écris ton premier message à Elyrii.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
    BuildContext context, {
    required ChatbotProvider provider,
    required ChatSession session,
    required bool isActive,
    required bool isDark,
  }) {
    final title = session.messageCount == 0
        ? 'Conversation vide'
        : session.title;
    final subtitle = _relativeDate(session.updatedAt);

    return Semantics(
      button: true,
      label: 'Conversation : $title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: provider.loadingSession
              ? null
              : () async {
                  ElyriiHaptics.selection();
                  final selected = await provider.loadSession(session.id);
                  if (selected && context.mounted) Navigator.pop(context);
                },
          borderRadius: BorderRadius.circular(16),
          child: ElyriiGlassSurface(
            lightweight: true,
            role: GlassRole.dialog,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: isActive
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.chat_bubble_rounded : Icons.forum_outlined,
                    size: 20,
                    color: isActive
                        ? AppColors.primary
                        : (isDark
                              ? AppColors.iconDefaultDark
                              : AppColors.iconDefaultLight),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$subtitle · ${session.messageCount} messages',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    tooltip: 'Supprimer la conversation',
                    onPressed: () =>
                        _confirmDelete(context, provider, session.id),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ChatbotProvider provider,
    String sessionId,
  ) async {
    ElyriiHaptics.light();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: const Text(
          'Cette conversation sera définitivement effacée de cet appareil.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await provider.deleteSession(sessionId);
    }
  }

  String _relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    if (diff < 7) return 'Il y a $diff jours';
    return DateFormat('d MMMM', 'fr').format(date);
  }
}
