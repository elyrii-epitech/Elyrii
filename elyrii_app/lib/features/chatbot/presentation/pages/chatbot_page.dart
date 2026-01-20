import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/chatbot_provider.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/mascot_widget.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  bool _isTextFieldFocused = false;

  @override
  void initState() {
    super.initState();

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
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      extendBody: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    AppColors.backgroundDark,
                    AppColors.primaryDark.withValues(alpha: 0.05),
                  ]
                : [
                    AppColors.backgroundLight,
                    AppColors.primary.withValues(alpha: 0.05),
                  ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Zone mascotte ou messages
              Expanded(
                child: Consumer<ChatbotProvider>(
                  builder: (context, provider, child) {
                    return Stack(
                      children: [
                        // Liste des messages (visible uniquement si focus ou messages)
                        if (provider.isMascotMinimized)
                          Positioned.fill(
                            child: Column(
                              children: [
                                Expanded(
                                  child: ListView.builder(
                                    controller: _scrollController,
                                    reverse: true,
                                    padding: const EdgeInsets.only(
                                      top: 20,
                                      bottom: 20,
                                    ),
                                    itemCount: provider.messages.length +
                                        (provider.isTyping ? 1 : 0),
                                    itemBuilder: (context, index) {
                                      if (index == 0 && provider.isTyping) {
                                        return const Padding(
                                          padding: EdgeInsets.only(left: 20),
                                          child: TypingIndicator(),
                                        );
                                      }
                                      final messageIndex =
                                          provider.isTyping ? index - 1 : index;
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
                            ),
                          ),
                        // Mascotte positionnée
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOutCubic,
                          top: provider.isMascotMinimized ? 0 : null,
                          left: provider.isMascotMinimized ? 0 : 16,
                          right: provider.isMascotMinimized ? 0 : 16,
                          bottom: provider.isMascotMinimized ? null : 150,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              MascotWidget(
                                isMinimized: provider.isMascotMinimized,
                              ),
                              // Bouton effacer historique (uniquement en mode minimisé)
                              if (provider.isMascotMinimized)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Material(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                    'Effacer l\'historique'),
                                                content: const Text(
                                                  'Voulez-vous vraiment effacer tout l\'historique de conversation ?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child:
                                                        const Text('Annuler'),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      provider.clearHistory();
                                                      Navigator.pop(context);
                                                    },
                                                    child:
                                                        const Text('Effacer'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.delete_outline_rounded,
                                                  size: 16,
                                                  color: isDark
                                                      ? AppColors
                                                          .textSecondaryDark
                                                      : AppColors
                                                          .textSecondaryLight,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Effacer',
                                                  style: TextStyle(
                                                    color: isDark
                                                        ? AppColors
                                                            .textSecondaryDark
                                                        : AppColors
                                                            .textSecondaryLight,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // Zone de saisie
              _buildInputArea(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 80),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                .withValues(alpha: 0.0),
            (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                .withValues(alpha: 0.95),
            isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ],
          stops: const [0.0, 0.3, 1.0],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: _isTextFieldFocused
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : (isDark
                          ? AppColors.borderDark.withValues(alpha: 0.3)
                          : AppColors.borderLight.withValues(alpha: 0.4)),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.1)
                        : AppColors.primary.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                  fontSize: 16,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.2,
                ),
                decoration: InputDecoration(
                  hintText: 'Partage ce que tu ressens...',
                  hintStyle: TextStyle(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    fontWeight: FontWeight.w300,
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  isDense: true,
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.9),
                  AppColors.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _sendMessage,
                borderRadius: BorderRadius.circular(28),
                child: Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
