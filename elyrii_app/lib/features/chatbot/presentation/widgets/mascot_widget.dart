import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/mascot_animations.dart';
import '../providers/chatbot_provider.dart' show ChatbotProvider;
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';

class MascotWidget extends StatefulWidget {
  final bool isMinimized;

  final double lottieHeight;

  final VoidCallback? onTap;

  final bool isUserTyping;

  final bool isCrisis;

  const MascotWidget({
    super.key,
    required this.isMinimized,
    this.lottieHeight = 150,
    this.onTap,
    this.isUserTyping = false,
    this.isCrisis = false,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> {
  ChatbotProvider? _chat;
  String? _lastMessageId;
  MascotAnimation _animation = MascotAnimations.idle;
  int _trigger = 0;
  bool _wasThinking = false;
  bool _wasConnected = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final chat = context.read<ChatbotProvider>();
    if (_chat == chat) return;
    _chat?.removeListener(_onChatChanged);
    _chat = chat;
    _lastMessageId = chat.messages.lastOrNull?.id;
    _wasThinking = chat.isTyping;
    _wasConnected = chat.isConnected;
    _animation = widget.isCrisis
        ? MascotAnimations.reassure
        : chat.isTyping
        ? MascotAnimations.thinking
        : widget.isUserTyping
        ? MascotAnimations.attentive
        : MascotAnimations.idle;
    chat.addListener(_onChatChanged);
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isUserTyping != oldWidget.isUserTyping ||
        widget.isCrisis != oldWidget.isCrisis) {
      _onChatChanged();
    }
  }

  void _onChatChanged() {
    if (!mounted) return;
    final chat = _chat!;
    final last = chat.messages.lastOrNull;
    final replyArrived =
        last != null && !last.isUser && last.id != _lastMessageId;
    final disconnected =
        (_wasConnected || _wasThinking) && !chat.isConnected && !chat.isTyping;
    _lastMessageId = last?.id;
    _wasThinking = chat.isTyping;
    _wasConnected = chat.isConnected;
    final next = widget.isCrisis
        ? MascotAnimations.reassure
        : chat.isTyping
        ? MascotAnimations.thinking
        : disconnected
        ? MascotAnimations.reassure
        : widget.isUserTyping
        ? MascotAnimations.attentive
        : replyArrived
        ? MascotAnimations.acknowledge
        : _animation == MascotAnimations.thinking ||
              _animation == MascotAnimations.attentive ||
              _animation == MascotAnimations.reassure
        ? MascotAnimations.idle
        : _animation;
    if (next != _animation || replyArrived) {
      setState(() {
        _animation = next;
        _trigger++;
      });
    }
  }

  @override
  void dispose() {
    _chat?.removeListener(_onChatChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.45).clamp(220.0, 350.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBotThinking = context.select<ChatbotProvider, bool>(
      (p) => p.isTyping,
    );
    final animation = _animation;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: widget.isMinimized ? 80 : maxHeight,
      child: widget.isMinimized
          ? _buildDynamicIsland(isDark, animation, isBotThinking)
          : _buildFullMascot(maxHeight, animation),
    );
  }

  Widget _buildDynamicIsland(
    bool isDark,
    MascotAnimation animation,
    bool isBotThinking,
  ) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          height: 52,
          padding: const EdgeInsets.only(
            left: AppDimensions.spacing8,
            right: AppDimensions.spacing12,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 52,
                child: Center(
                  child: _ThemedMascot(
                    key: const ValueKey('mascot_3d_mini'),
                    config: const Mascot3DConfig.chatbotMinimized(),
                    animation: animation,
                    animationTrigger: _trigger,
                    width: 56,
                    height: 56,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.25),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Text(
                  isBotThinking ? 'Elyrii réfléchit…' : 'Elyrii t\'écoute…',
                  key: ValueKey<bool>(isBotThinking),
                  style: AppTextStyles.labelMedium(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.spacing8),
              Icon(
                Icons.keyboard_arrow_up_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Construit la mascotte en mode plein écran.
  Widget _buildFullMascot(double maxHeight, MascotAnimation animation) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMascotAvatar(widget.lottieHeight, animation),
        SizedBox(height: maxHeight * 0.04),
        _buildMascotText(),
      ],
    );
  }

  /// Construit le viewer 3D de la mascotte pour le mode plein écran.
  Widget _buildMascotAvatar(double size, MascotAnimation animation) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _ThemedMascot(
          key: const ValueKey('mascot_3d_full'),
          config: const Mascot3DConfig.chatbotFull(),
          animation: animation,
          animationTrigger: _trigger,
          width: size,
          height: size,
        ),
      ),
    );
  }

  /// Construit les textes informatifs accompagnant la mascotte.
  Widget _buildMascotText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Discuter avec Elyrii',
          textAlign: TextAlign.center,
          style: AppTextStyles.headlineSmall(color: context.textPrimary),
        ),
        const SizedBox(height: AppDimensions.spacing12),
        Text(
          'Je suis là pour t\'écouter\nsans jugement',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyLarge(color: context.textSecondary),
        ),
      ],
    );
  }
}

/// Wrapper qui applique automatiquement le thème courant de la mascotte
/// **et** ses accessoires équipés, de façon cohérente avec les autres pages.
class _ThemedMascot extends StatelessWidget {
  final Mascot3DConfig config;
  final MascotAnimation? animation;
  final int animationTrigger;
  final double width;
  final double height;

  const _ThemedMascot({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.animation,
    this.animationTrigger = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Conserve une dépendance au thème pour repeindre si l'utilisateur change
    // de personnalisation pendant la session chatbot.
    context.select<MascotProvider, MascotTheme>((p) => p.currentTheme);
    return MascotWithAccessories(
      config: config,
      width: width,
      height: height,
      animation: animation,
      animationTrigger: animationTrigger,
    );
  }
}
