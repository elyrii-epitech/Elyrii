import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/glass/elyrii_glass_surface.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chatbot_provider.dart';
import '../widgets/chat_history_sheet.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/conversation_suggestions.dart';
import '../widgets/crisis_detection_banner.dart';
import '../widgets/emergency_resources_button.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/typing_indicator.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Page Chat : interface conversationnelle standard — en-tête présence
/// (avatar logo, statut), fil iMessage, historique local, ressources
/// d'urgence santé mentale toujours accessibles.
class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _hasStartedTyping = false;
  bool _showCrisisBanner = false;
  late AnimationController _inputAnimationController;
  late Animation<double> _inputGlowAnimation;

  @override
  void initState() {
    super.initState();

    _inputAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _inputGlowAnimation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(
        parent: _inputAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _textController.addListener(() {
      final text = _textController.text;
      if (text.isNotEmpty && !_hasStartedTyping) {
        setState(() => _hasStartedTyping = true);
        _inputAnimationController.repeat(reverse: true);
      } else if (text.isEmpty && _hasStartedTyping) {
        setState(() => _hasStartedTyping = false);
        _inputAnimationController.stop();
        _inputAnimationController.reset();
      }

      // Crisis keyword detection
      final shouldShowCrisisBanner =
          text.isNotEmpty && containsCrisisKeyword(text);
      if (_showCrisisBanner != shouldShowCrisisBanner) {
        setState(() => _showCrisisBanner = shouldShowCrisisBanner);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _inputAnimationController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients && mounted) {
          _scrollController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    context.read<ChatbotProvider>().sendMessage(text);
    _textController.clear();
    _scrollToBottom();

    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.scaffoldDark
          : AppColors.scaffoldLight,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: Consumer<ChatbotProvider>(
                builder: (context, provider, child) {
                  if (provider.messages.isEmpty) {
                    return _buildEmptyState(provider, isDark);
                  }
                  return _buildMessageList(provider);
                },
              ),
            ),
            CrisisDetectionBanner(
              visible: _showCrisisBanner,
              onDismiss: () => setState(() => _showCrisisBanner = false),
            ),
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  /// En-tête standard de chat : avatar logo monochrome, nom + statut de
  /// présence, accès historique et ressources d'urgence en permanence.
  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: (isDark ? AppColors.borderDark : AppColors.borderLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Avatar : logo monochrome dans une pastille de verre.
          ElyriiGlassSurface(
            role: GlassRole.floatingControl,
            borderRadius: BorderRadius.circular(22),
            width: 44,
            height: 44,
            child: const Center(
              child: ImageIcon(
                AssetImage('assets/brand/logo_monochrome.png'),
                size: 28,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Elyrii',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                _PresenceIndicator(
                  isTyping: context.select<ChatbotProvider, bool>(
                    (p) => p.isTyping,
                  ),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Icons.history_rounded,
            tooltip: 'Historique des conversations',
            isDark: isDark,
            onTap: () {
              ElyriiHaptics.light();
              ChatHistorySheet.show(context);
            },
          ),
          const SizedBox(width: 8),
          const EmergencyResourcesButton(),
        ],
      ),
    );
  }

  /// État vide : mascotte 3D d'accueil + suggestions de conversation.
  Widget _buildEmptyState(ChatbotProvider provider, bool isDark) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          MascotWidget(isMinimized: false, isUserTyping: _hasStartedTyping),
          ConversationSuggestions(
            onSuggestionTap: (text) {
              _textController.text = text;
              _sendMessage();
            },
          ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 100),
        ],
      ),
    );
  }

  /// Fil de messages inversé (iMessage), avec séparateurs de date.
  Widget _buildMessageList(ChatbotProvider provider) {
    final itemCount = provider.messages.length + (provider.isTyping ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index == 0 && provider.isTyping) {
          return const TypingIndicator();
        }
        final messageIndex = provider.isTyping ? index - 1 : index;
        final message =
            provider.messages[provider.messages.length - 1 - messageIndex];

        // Dans la liste inversée, l'index suivant est le message plus ancien.
        final showDateChip =
            messageIndex == provider.messages.length - 1 ||
            !_isSameDay(
              message.timestamp,
              provider
                  .messages[provider.messages.length - 2 - messageIndex]
                  .timestamp,
            );

        return Column(
          children: [
            if (showDateChip) _buildDateChip(message.timestamp, index),
            ChatMessageBubble(
              message: message.content,
              isUser: message.isUser,
              timestamp: message.timestamp,
            ),
          ],
        );
      },
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Widget _buildDateChip(DateTime date, int animationKey) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _dateChipLabel(date);

    return Padding(
      key: ValueKey('date_$animationKey'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(
              alpha: 0.06,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  String _dateChipLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Aujourd\'hui';
    if (diff == 1) return 'Hier';
    return '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}';
  }

  Widget _buildInputArea(bool isDark) {
    final navbarClearance = MediaQuery.paddingOf(context).bottom > 0
        ? 92.0
        : 88.0;
    return Container(
      margin: EdgeInsets.only(bottom: navbarClearance),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_hasStartedTyping)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AnimatedOpacity(
                opacity: _hasStartedTyping ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Text(
                  'Continue, je t\'écoute...',
                  style: TextStyle(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _inputGlowAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardDark
                            : AppColors.cardLight,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _hasStartedTyping
                              ? AppColors.primary.withValues(
                                  alpha: _inputGlowAnimation.value,
                                )
                              : _focusNode.hasFocus
                              ? AppColors.primary.withValues(alpha: 0.5)
                              : (isDark
                                        ? AppColors.borderDark
                                        : AppColors.borderLight)
                                    .withValues(alpha: 0.3),
                          width: _hasStartedTyping ? 1.5 : 1,
                        ),
                        boxShadow: _hasStartedTyping
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: _inputGlowAnimation.value * 0.3,
                                  ),
                                  blurRadius: 12,
                                  spreadRadius: 0,
                                ),
                              ]
                            : null,
                      ),
                      child: child,
                    );
                  },
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Partage ce que tu ressens...',
                      hintStyle: TextStyle(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                        fontWeight: FontWeight.w400,
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _hasStartedTyping
                        ? [AppColors.primary, const Color(0xFF7B5FE0)]
                        : [
                            AppColors.primary.withValues(alpha: 0.6),
                            const Color(0xFF7B5FE0).withValues(alpha: 0.6),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: _hasStartedTyping
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _sendMessage,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Point de présence dans l'en-tête : point vert « En ligne », point
/// primaire animé « En train d'écrire… ».
class _PresenceIndicator extends StatelessWidget {
  final bool isTyping;
  final bool isDark;

  const _PresenceIndicator({required this.isTyping, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final dotColor = isTyping ? AppColors.primary : AppColors.success;
    final label = isTyping ? 'En train d\'écrire…' : 'En ligne — je t\'écoute';

    return Row(
      children: [
        if (isTyping)
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          )
              .animate(onPlay: (controller) => controller.repeat(reverse: true))
              .fadeIn(duration: 500.ms)
              .fadeOut(duration: 500.ms)
        else
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        const SizedBox(width: 6),
        Text(
          label,
          key: ValueKey<bool>(isTyping),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

/// Bouton d'icône circulaire discret pour les actions d'en-tête.
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isDark;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: isDark
                  ? AppColors.iconDefaultDark
                  : AppColors.iconDefaultLight,
            ),
          ),
        ),
      ),
    );
  }
}
