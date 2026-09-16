import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/design_system/haptics/elyrii_haptics.dart';

/// Widget de bulle de dialogue avec effet glassmorphism et animation de typing
class MascotSpeechBubble extends StatefulWidget {
  final String message;
  final bool isDark;
  final VoidCallback? onTap;

  const MascotSpeechBubble({
    super.key,
    required this.message,
    this.isDark = false,
    this.onTap,
  });

  @override
  State<MascotSpeechBubble> createState() => _MascotSpeechBubbleState();
}

class _MascotSpeechBubbleState extends State<MascotSpeechBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _typingController;
  Timer? _typingTimer;
  String _displayedText = '';
  int _charIndex = 0;
  bool _isTypingComplete = false;
  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 50),
      vsync: this,
    );
    _startTypingAnimation();
  }

  @override
  void didUpdateWidget(MascotSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.message != oldWidget.message) {
      _resetTyping();
      _startTypingAnimation();
    }
  }

  void _resetTyping() {
    _displayedText = '';
    _charIndex = 0;
    _isTypingComplete = false;
  }

  void _startTypingAnimation() {
    _typingTimer?.cancel();
    if (_charIndex < widget.message.characters.length) {
      _typingTimer = Timer(
        Duration(milliseconds: 30 + (_charIndex % 3) * 10),
        () {
          if (mounted && _charIndex < widget.message.characters.length) {
            setState(() {
              _displayedText = widget.message.characters
                  .take(_charIndex + 1)
                  .toString();
              _charIndex++;
            });
            _startTypingAnimation();
          } else if (mounted) {
            setState(() {
              _isTypingComplete = true;
            });
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _typingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ElyriiHaptics.light();
        widget.onTap?.call();
      },
      child: AnimatedOpacity(
        opacity: _displayedText.isEmpty ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Bulle principale
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingMd,
                vertical: AppDimensions.paddingSm,
              ),
              constraints: const BoxConstraints(maxWidth: 280, minHeight: 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? [
                          AppColors.primary.withValues(alpha: 0.25),
                          AppColors.primary.withValues(alpha: 0.15),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.9),
                          AppColors.primaryLight.withValues(alpha: 0.7),
                        ],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                border: Border.all(
                  color: widget.isDark
                      ? AppColors.primary.withValues(alpha: 0.25)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      _displayedText,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: widget.isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                        height: 1.3,
                      ),
                    ),
                  ),
                  // Curseur clignotant pendant le typing
                  if (!_isTypingComplete) _TypingCursor(isDark: widget.isDark),
                ],
              ),
            ),
            // Petite attache arrondie vers la mascotte — douce, sans
            // pointe triangulaire agressive.
            Positioned(
              top: -6,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 16,
                  height: 8,
                  decoration: BoxDecoration(
                    color: widget.isDark
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Curseur clignotant pendant le typing
class _TypingCursor extends StatefulWidget {
  final bool isDark;

  const _TypingCursor({required this.isDark});

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Container(
            width: 2,
            height: 16,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(
              color: widget.isDark
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}
