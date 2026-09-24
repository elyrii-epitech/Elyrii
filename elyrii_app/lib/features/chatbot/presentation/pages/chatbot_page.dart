import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/chatbot_provider.dart';
import '../widgets/chat_history_sheet.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/conversation_suggestions.dart';
import '../widgets/crisis_detection_banner.dart';
import '../widgets/emergency_resources_button.dart';
import '../widgets/typing_indicator.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});
  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  bool _hasText = false;
  bool _submitting = false;
  bool _showCrisisBanner = false;
  bool _keyboardWasOpen = false;
  int _lastMessageCount = 0;
  String? _lastSessionId;
  bool _loadingOlderMessages = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    final text = _textController.text;
    final hasText = text.trim().isNotEmpty;
    final showCrisisBanner = text.isNotEmpty && containsCrisisKeyword(text);
    if (_hasText != hasText || _showCrisisBanner != showCrisisBanner) {
      setState(() {
        _hasText = hasText;
        _showCrisisBanner = showCrisisBanner;
      });
    }
  }

  @override
  void dispose() {
    _textController
      ..removeListener(_handleTextChanged)
      ..dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final provider = context.read<ChatbotProvider>();
    if (text.isEmpty || _submitting || provider.loadingSession) return;
    ElyriiHaptics.selection();
    setState(() => _submitting = true);
    try {
      final accepted = await provider.sendMessage(text);
      if (!mounted) return;
      if (accepted && _textController.text.trim() == text) {
        _textController.clear();
      }
      if (accepted) _scrollToLatestMessage();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToLatestMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients || !mounted) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _useSuggestion(String text) {
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _focusNode.requestFocus();
  }

  void _showActions() {
    _focusNode.unfocus();
    final provider = context.read<ChatbotProvider>();
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_square),
                title: const Text('Nouvelle conversation'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _textController.clear();
                  provider.startNewConversation();
                },
              ),
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: const Text('Historique des conversations'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  ChatHistorySheet.show(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (keyboardOpen != _keyboardWasOpen) {
      _keyboardWasOpen = keyboardOpen;
      if (!_scrollController.hasClients ||
          _scrollController.position.extentAfter < 100) {
        _scrollToLatestMessage();
      }
    }
    // With extendBody, the shell supplies the actual navbar height here.
    // Standalone, this is simply the device's home-indicator safe area.
    final bottomClearance = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? const Color(0xFF141416)
          : const Color(0xFFFAFAFA),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark),
            Selector<ChatbotProvider, String?>(
              selector: (_, provider) => provider.error,
              builder: (_, error, _) => error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
            ),
            Expanded(
              child: Consumer<ChatbotProvider>(
                builder: (context, provider, _) => provider.messages.isEmpty
                    ? _buildWelcomeState(isDark, keyboardOpen)
                    : _buildConversation(provider, isDark),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 780,
                  maxHeight:
                      (MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom) *
                      0.25,
                ),
                child: SingleChildScrollView(
                  child: CrisisDetectionBanner(
                    visible: _showCrisisBanner,
                    onDismiss: () => setState(() => _showCrisisBanner = false),
                  ),
                ),
              ),
            ),
            _buildComposer(isDark, keyboardOpen ? 8 : bottomClearance + 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Historique des conversations',
                onPressed: () {
                  _focusNode.unfocus();
                  ChatHistorySheet.show(context);
                },
                style: IconButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.surfaceDark
                      : AppColors.surfaceLight,
                  foregroundColor: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  minimumSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.menu_rounded, size: 23),
              ),
              Expanded(
                child: Text(
                  'Elyrii',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const EmergencyResourcesButton(compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeState(bool isDark, bool keyboardOpen) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: (constraints.maxHeight - 32).clamp(0, double.infinity),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ImageIcon(
                    const AssetImage('assets/brand/navbar_app_icon.png'),
                    size: keyboardOpen ? 40 : 52,
                    color: isDark ? AppColors.primaryDark : AppColors.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Un moment pour toi.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      height: 1.2,
                      letterSpacing: -0.8,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Qu’as-tu en tête aujourd’hui ?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  if (!keyboardOpen) ...[
                    const SizedBox(height: 28),
                    ConversationSuggestions(onSuggestionTap: _useSuggestion),
                    const SizedBox(height: 22),
                    Text(
                      'Un soutien au quotidien, pas un suivi médical.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.4,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversation(ChatbotProvider provider, bool isDark) {
    final messages = provider.messages;
    final olderOffset = provider.hasMoreMessages ? 1 : 0;
    final itemCount =
        messages.length + olderOffset + (provider.isTyping ? 1 : 0);
    if (_lastMessageCount != itemCount ||
        _lastSessionId != provider.activeSessionId) {
      final followLatest =
          _lastSessionId != provider.activeSessionId ||
          !_scrollController.hasClients ||
          _scrollController.position.extentAfter < 100;
      _lastMessageCount = itemCount;
      _lastSessionId = provider.activeSessionId;
      if (followLatest && !_loadingOlderMessages) _scrollToLatestMessage();
    }
    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (olderOffset == 1 && index == 0) {
          return TextButton(
            onPressed: provider.loadingOlder
                ? null
                : () => _loadOlder(provider),
            child: Text(
              provider.loadingOlder ? 'Chargement…' : 'Messages précédents',
            ),
          );
        }
        final messageIndex = index - olderOffset;
        if (messageIndex == messages.length) return const TypingIndicator();
        final message = messages[messageIndex];
        final showDate =
            messageIndex == 0 ||
            !DateUtils.isSameDay(
              message.timestamp,
              messages[messageIndex - 1].timestamp,
            );
        return Column(
          children: [
            if (showDate) _buildDateLabel(message.timestamp, isDark),
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

  Future<void> _loadOlder(ChatbotProvider provider) async {
    _loadingOlderMessages = true;
    final before = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final offset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;
    final sessionId = provider.activeSessionId;
    await provider.loadOlderMessages();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _scrollController.hasClients &&
          provider.activeSessionId == sessionId) {
        final position = _scrollController.position;
        _scrollController.jumpTo(
          (offset + position.maxScrollExtent - before).clamp(
            0.0,
            position.maxScrollExtent,
          ),
        );
      }
      _loadingOlderMessages = false;
    });
  }

  Widget _buildDateLabel(DateTime date, bool isDark) {
    final difference = DateUtils.dateOnly(
      DateTime.now(),
    ).difference(DateUtils.dateOnly(date)).inDays;
    final label = difference == 0
        ? 'Aujourd’hui'
        : difference == 1
        ? 'Hier'
        : '${date.day}/${date.month}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }

  Widget _buildComposer(bool isDark, double bottomClearance) {
    final loadingSession = context.select<ChatbotProvider, bool>(
      (p) => p.loadingSession,
    );
    final foreground = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimaryLight;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, bottomClearance),
          child: Container(
            key: const ValueKey('chat-composer'),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252527) : const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(29),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF39393C)
                    : const Color(0xFFE2E2E6),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: _showActions,
                  tooltip: 'Actions de conversation',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: foreground,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 28),
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines:
                        MediaQuery.sizeOf(context).height -
                                MediaQuery.viewInsetsOf(context).bottom <
                            400
                        ? 3
                        : 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    cursorColor: isDark
                        ? AppColors.primaryDark
                        : AppColors.primary,
                    style: TextStyle(
                      fontSize: 17,
                      height: 1.4,
                      letterSpacing: 0,
                      color: foreground,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message à Elyrii',
                      hintMaxLines: 1,
                      hintStyle: TextStyle(
                        color: isDark
                            ? const Color(0xFFAAA9AF)
                            : const Color(0xFF77767D),
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                      ),
                      // Override all form defaults: the pill is the only
                      // surface and border, including while focused.
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  onPressed: _hasText && !_submitting && !loadingSession
                      ? _sendMessage
                      : null,
                  tooltip: 'Envoyer le message',
                  style: IconButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    backgroundColor: foreground,
                    foregroundColor: isDark
                        ? const Color(0xFF242426)
                        : Colors.white,
                    disabledBackgroundColor: isDark
                        ? const Color(0xFF353537)
                        : const Color(0xFFE1E1E5),
                    disabledForegroundColor: isDark
                        ? const Color(0xFF77777D)
                        : const Color(0xFF99989F),
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 23),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
