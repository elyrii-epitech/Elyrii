import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/haptics/elyrii_haptics.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/elyrii_page_header.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/glass/liquid_glass_button.dart';
import '../providers/chatbot_provider.dart';
import '../widgets/chat_history_sheet.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/conversation_suggestions.dart';
import '../widgets/crisis_detection_banner.dart';
import '../widgets/ai_report_sheet.dart';
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
    final showCrisisBanner = _showCrisisBanner || containsCrisisKeyword(text);
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
        0,
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
    Navigator.of(context, rootNavigator: true).push<void>(
      AppSheetRoute<void>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (sheetContext) => AppSheetPanel(
          title: 'Conversation',
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
          _scrollController.position.extentBefore < 100) {
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
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: Consumer<ChatbotProvider>(
                    builder: (context, provider, _) => provider.messages.isEmpty
                        ? _buildWelcomeState(isDark, keyboardOpen)
                        : _buildConversation(provider, isDark),
                  ),
                ),
                Selector<ChatbotProvider, String?>(
                  selector: (_, provider) => provider.error,
                  builder: (_, error, _) => error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppDimensions.spacing20,
                            vertical: AppDimensions.spacing8,
                          ),
                          child: Text(
                            error,
                            style: AppTextStyles.bodySmall(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
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
                        onDismiss: () =>
                            setState(() => _showCrisisBanner = false),
                      ),
                    ),
                  ),
                ),
                _buildComposer(
                  isDark,
                  keyboardOpen
                      ? AppDimensions.spacing8
                      : bottomClearance + AppDimensions.spacing12,
                ),
              ],
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ElyriiHeaderBar(
                title: 'Elyrii',
                leading: LiquidGlassIconButton(
                  tooltip: 'Historique des conversations',
                  icon: Icons.menu_rounded,
                  size: 48,
                  onPressed: () {
                    _focusNode.unfocus();
                    ChatHistorySheet.show(context);
                  },
                ),
                actions: const [EmergencyResourcesButton(compact: true)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeState(bool isDark, bool keyboardOpen) {
    final topPadding =
        ElyriiHeaderBar.extentOf(context) + AppDimensions.spacing16;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          AppDimensions.spacing24,
          topPadding,
          AppDimensions.spacing24,
          AppDimensions.spacing16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight:
                (constraints.maxHeight - topPadding - AppDimensions.spacing16)
                    .clamp(0, double.infinity),
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
                  const SizedBox(height: AppDimensions.spacing20),
                  Text(
                    'Un moment pour toi.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineSmall(
                      color: context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacing8),
                  Text(
                    'Qu’as-tu en tête aujourd’hui ?',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyLarge(
                      color: context.textSecondary,
                    ),
                  ),
                  if (!keyboardOpen) ...[
                    const SizedBox(height: AppDimensions.spacing24),
                    ConversationSuggestions(onSuggestionTap: _useSuggestion),
                    const SizedBox(height: AppDimensions.spacing24),
                    Text(
                      'Un soutien au quotidien, pas un suivi médical.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium(
                        color: context.textTertiary,
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
    final typingOffset = provider.isTyping ? 1 : 0;
    final itemCount = messages.length + olderOffset + typingOffset;
    if (_lastMessageCount != itemCount ||
        _lastSessionId != provider.activeSessionId) {
      final followLatest =
          _lastSessionId != provider.activeSessionId ||
          !_scrollController.hasClients ||
          _scrollController.position.extentBefore < 100;
      _lastMessageCount = itemCount;
      _lastSessionId = provider.activeSessionId;
      if (followLatest && !_loadingOlderMessages) _scrollToLatestMessage();
    }
    return ListView.builder(
      controller: _scrollController,
      // Zero is the newest message. Opening a long conversation now lays out
      // only the visible tail, and older pages extend the far end of the list.
      reverse: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(
        top: ElyriiHeaderBar.extentOf(context) + AppDimensions.spacing16,
        bottom: AppDimensions.spacing12,
      ),
      itemCount: itemCount,
      findChildIndexCallback: (key) {
        if (key == const ValueKey('chat-typing')) {
          return typingOffset == 1 ? 0 : null;
        }
        if (key == const ValueKey('chat-older-page')) {
          return olderOffset == 1 ? itemCount - 1 : null;
        }
        if (key is! ValueKey<String>) return null;
        final index = messages.indexWhere((message) => message.id == key.value);
        return index < 0 ? null : messages.length - 1 - index + typingOffset;
      },
      itemBuilder: (context, index) {
        if (typingOffset == 1 && index == 0) {
          return const TypingIndicator(key: ValueKey('chat-typing'));
        }
        if (olderOffset == 1 && index == itemCount - 1) {
          return TextButton(
            key: const ValueKey('chat-older-page'),
            onPressed: provider.loadingOlder
                ? null
                : () => _loadOlder(provider),
            child: Text(
              provider.loadingOlder ? 'Chargement…' : 'Messages précédents',
            ),
          );
        }
        final messageIndex = messages.length - 1 - index + typingOffset;
        final message = messages[messageIndex];
        final showDate =
            messageIndex == 0 ||
            !DateUtils.isSameDay(
              message.timestamp,
              messages[messageIndex - 1].timestamp,
            );
        return Column(
          key: ValueKey(message.id),
          children: [
            if (showDate) _buildDateLabel(message.timestamp),
            ChatMessageBubble(
              key: ValueKey(message.id),
              delivery: message.delivery,
              onReport: message.isUser
                  ? null
                  : () => Navigator.of(context, rootNavigator: true).push<void>(
                      AppSheetRoute<void>(
                        reduced: MediaQuery.disableAnimationsOf(context),
                        builder: (_) => AiReportSheet(
                          message: message,
                          conversationId:
                              context.read<ChatbotProvider>().activeSessionId ??
                              'default',
                        ),
                      ),
                    ),
              onRetry: () =>
                  context.read<ChatbotProvider>().retryMessage(message.id),
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
    if (_loadingOlderMessages || provider.loadingOlder) return;
    _loadingOlderMessages = true;
    await provider.loadOlderMessages();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Existing reversed-list indices and offsets stay stable when older
      // messages arrive. An estimated maxScrollExtent must not move the reader.
      _loadingOlderMessages = false;
    });
  }

  Widget _buildDateLabel(DateTime date) {
    final difference = DateUtils.dateOnly(DateTime.now())
        .difference(DateUtils.dateOnly(date))
        .inDays;
    final label = difference == 0
        ? 'Aujourd’hui'
        : difference == 1
        ? 'Hier'
        : '${date.day}/${date.month}/${date.year}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.spacing20),
      child: Text(
        label,
        style: AppTextStyles.bodySmall(color: context.textTertiary),
      ),
    );
  }

  Widget _buildComposer(bool isDark, double bottomClearance) {
    final loadingSession = context.select<ChatbotProvider, bool>(
      (p) => p.loadingSession,
    );
    final foreground = context.textPrimary;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 780),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppDimensions.spacing12,
            AppDimensions.spacing8,
            AppDimensions.spacing12,
            bottomClearance,
          ),
          child: Container(
            key: const ValueKey('chat-composer'),
            padding: const EdgeInsets.all(AppDimensions.spacing4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF252527) : const Color(0xFFF0F0F2),
              borderRadius: BorderRadius.circular(AppDimensions.radius28),
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
                    style: AppTextStyles.bodyLarge(color: foreground),
                    decoration: InputDecoration(
                      labelText: 'Message à l’assistant IA',
                      hintText: 'Message à Elyrii',
                      hintMaxLines: 1,
                      hintStyle: AppTextStyles.bodyLarge(
                        color: isDark
                            ? const Color(0xFFAAA9AF)
                            : const Color(0xFF77767D),
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
                        horizontal: AppDimensions.spacing8,
                        vertical: AppDimensions.spacing16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacing8),
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
