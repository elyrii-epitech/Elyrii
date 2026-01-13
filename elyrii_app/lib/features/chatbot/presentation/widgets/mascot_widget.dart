import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';

class MascotWidget extends StatefulWidget {
  final bool isMinimized;
  final double lottieHeight;
  final VoidCallback? onTap;
  final MascotAnimation? triggerAnimation;

  const MascotWidget({
    super.key,
    required this.isMinimized,
    this.lottieHeight = 150,
    this.onTap,
    this.triggerAnimation,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  MascotAnimation _currentAnimation = MascotAnimations.idle;
  bool _isPlayingSpecialAnimation = false;
  bool _hasPlayedInitialAnimation = false;
  Timer? _inactivityTimer;
  static const int _inactivityDelaySeconds = 10;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.06,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOutSine,
      ),
    );

    _playOpeningAnimation();
  }

  void _playOpeningAnimation() {
    if (_hasPlayedInitialAnimation) return;

    final openingAnimations = MascotAnimations.openingAnimations;
    if (openingAnimations.isEmpty) {
      _hasPlayedInitialAnimation = true;
      _startInactivityTimer();
      return;
    }

    final animation = MascotAnimations.selectWeightedRandom(openingAnimations);
    if (animation != null) {
      _playAnimation(animation, isInitial: true);
    }
  }

  void _playAnimation(MascotAnimation animation, {bool isInitial = false}) {
    if (_isPlayingSpecialAnimation && !isInitial) return;

    setState(() {
      _currentAnimation = animation;
      _isPlayingSpecialAnimation = true;
      if (isInitial) _hasPlayedInitialAnimation = true;
    });

    Future.delayed(Duration(seconds: animation.durationSeconds), () {
      if (mounted) {
        setState(() {
          _currentAnimation = MascotAnimations.idle;
          _isPlayingSpecialAnimation = false;
        });
        _startInactivityTimer();
      }
    });
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(seconds: _inactivityDelaySeconds), () {
      if (mounted) {
        _playInactivityAnimation();
      }
    });
  }

  void _playInactivityAnimation() {
    final inactivityAnimations = MascotAnimations.inactivityAnimations;
    if (inactivityAnimations.isEmpty) return;

    final animation =
        MascotAnimations.selectWeightedRandom(inactivityAnimations);
    if (animation != null) {
      _playAnimation(animation);
    }
  }

  @override
  void didUpdateWidget(MascotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isMinimized != oldWidget.isMinimized) {
      _startInactivityTimer();
    }

    if (widget.triggerAnimation != null &&
        widget.triggerAnimation != oldWidget.triggerAnimation) {
      _playAnimation(widget.triggerAnimation!);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _inactivityTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.45).clamp(220.0, 350.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: widget.isMinimized ? 80 : maxHeight,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isMinimized ? 1.0 : _pulseAnimation.value,
            child: widget.isMinimized
                ? _buildMinimizedMascot()
                : _buildFullMascot(maxHeight),
          );
        },
      ),
    );
  }

  Widget _buildMinimizedMascot() {
    const double lottieSize = 140;
    const double visibleHeight = 80;
    const double topOffset = -10;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              AppColors.cardDark.withValues(alpha: 0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: lottieSize,
              height: visibleHeight,
              child: ClipRect(
                child: OverflowBox(
                  maxHeight: lottieSize,
                  maxWidth: lottieSize,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, topOffset),
                    child: Lottie.asset(
                      _currentAnimation.assetPath,
                      key: ValueKey('minimized_${_currentAnimation.id}'),
                      width: lottieSize,
                      height: lottieSize,
                      fit: BoxFit.contain,
                      repeat: _currentAnimation.loop,
                      animate: true,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMascotText(true),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textTertiaryDark.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullMascot(double maxHeight) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMascotAvatar(widget.lottieHeight, Icons.favorite_rounded),
        SizedBox(height: maxHeight * 0.04),
        _buildMascotText(false),
      ],
    );
  }

  Widget _buildMascotAvatar(double size, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Lottie.asset(
          _currentAnimation.assetPath,
          key: ValueKey(_currentAnimation.id),
          width: size,
          height: size,
          fit: BoxFit.contain,
          repeat: _currentAnimation.loop,
          animate: true,
        ),
      ),
    );
  }

  Widget _buildMascotText(bool isMinimized) {
    return Column(
      crossAxisAlignment:
          isMinimized ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isMinimized ? 'Elyrii' : 'Discuter avec Elyrii',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AppColors.textPrimaryDark,
            fontSize: isMinimized ? 15 : 26,
            fontWeight: isMinimized ? FontWeight.w600 : FontWeight.w600,
            letterSpacing: isMinimized ? 0.3 : 0.5,
          ),
        ),
        SizedBox(height: isMinimized ? 2 : 12),
        Text(
          isMinimized
              ? 'Je t\'écoute 💜'
              : 'Je suis là pour t\'écouter\nsans jugement',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AppColors.textSecondaryDark,
            fontSize: isMinimized ? 11 : 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
