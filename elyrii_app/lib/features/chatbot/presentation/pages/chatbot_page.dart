import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chatbot_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/mascot_widget.dart';
import '../widgets/conversation_suggestions.dart';
import '../widgets/emergency_resources_button.dart';

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
  bool _isTextFieldFocused = false;
  bool _hasStartedTyping = false;
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
      if (_textController.text.isNotEmpty && !_hasStartedTyping) {
        setState(() => _hasStartedTyping = true);
        _inputAnimationController.repeat(reverse: true);
      } else if (_textController.text.isEmpty && _hasStartedTyping) {
        setState(() => _hasStartedTyping = false);
        _inputAnimationController.stop();
        _inputAnimationController.reset();
      }
    });

    _focusNode.addListener(() {
      setState(() {
        _isTextFieldFocused = _focusNode.hasFocus;
      });
      context.read<ChatbotProvider>().toggleMascotSize(_focusNode.hasFocus);
    });
  }

  @override
  void deactivate() {
    context.read<ChatbotProvider>().resetMascot();
    super.deactivate();
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
      backgroundColor: AppColors.backgroundDark,
      extendBody: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Consumer<ChatbotProvider>(
                builder: (context, provider, child) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.05),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: provider.isMascotMinimized
                        ? Column(
                            key: const ValueKey('minimized'),
                            children: [
                              MascotWidget(
                                isMinimized: true,
                                onTap: () {
                                  _focusNode.unfocus();
                                  provider.resetMascot();
                                },
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const EmergencyResourcesButton(),
                                    if (provider.messages.isNotEmpty)
                                      _buildClearButton(provider),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: provider.messages.isEmpty
                                    ? ConversationSuggestions(
                                        onSuggestionTap: (text) {
                                          _textController.text = text;
                                          _sendMessage();
                                        },
                                      )
                                    : ListView.builder(
                                        controller: _scrollController,
                                        reverse: true,
                                        padding: const EdgeInsets.only(
                                          top: 8,
                                          bottom: 8,
                                        ),
                                        itemCount: provider.messages.length +
                                            (provider.isTyping ? 1 : 0),
                                        itemBuilder: (context, index) {
                                          if (index == 0 && provider.isTyping) {
                                            return const TypingIndicator();
                                          }
                                          final messageIndex = provider.isTyping
                                              ? index - 1
                                              : index;
                                          final message = provider.messages[
                                              provider.messages.length -
                                                  1 -
                                                  messageIndex];
                                          return ChatMessageBubble(
                                            message: message.content,
                                            isUser: message.isUser,
                                            timestamp: message.timestamp,
                                          );
                                        },
                                      ),
                              ),
                            ],
                          )
                        : Center(
                            key: const ValueKey('full'),
                            child: MascotWidget(
                              isMinimized: false,
                            ),
                          ),
                  );
                },
              ),
            ),
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildClearButton(ChatbotProvider provider) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.cardDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Effacer l\'historique',
                style: TextStyle(color: AppColors.textPrimaryDark),
              ),
              content: const Text(
                'Voulez-vous vraiment effacer tout l\'historique de conversation ?',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annuler',
                    style: TextStyle(color: AppColors.textSecondaryDark),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    provider.clearHistory();
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Effacer',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: AppColors.cardDark.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline_rounded,
                size: 14,
                color: AppColors.textTertiaryDark,
              ),
              const SizedBox(width: 4),
              Text(
                'Effacer',
                style: TextStyle(
                  color: AppColors.textTertiaryDark,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 80),
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
                  '💜 Continue, je t\'écoute...',
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
                        color: AppColors.cardDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _hasStartedTyping
                              ? AppColors.primary
                                  .withValues(alpha: _inputGlowAnimation.value)
                              : _isTextFieldFocused
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.borderDark.withValues(alpha: 0.3),
                          width: _hasStartedTyping ? 1.5 : 1,
                        ),
                        boxShadow: _hasStartedTyping
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                      alpha: _inputGlowAnimation.value * 0.3),
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
                      color: AppColors.textPrimaryDark,
                      fontSize: 15,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Partage ce que tu ressens...',
                      hintStyle: TextStyle(
                        color: AppColors.textTertiaryDark,
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
                        ? [
                            AppColors.primary,
                            const Color(0xFF7B5FE0),
                          ]
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
