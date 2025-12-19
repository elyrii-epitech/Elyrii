import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/theme/app_colors.dart';

class MascotWidget extends StatefulWidget {
  final bool isMinimized;
  final double lottieHeight;
  final VoidCallback? onTap;

  const MascotWidget({
    super.key,
    required this.isMinimized,
    this.lottieHeight = 150,
    this.onTap,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardDark.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.borderDark.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            _buildMascotAvatar(50, Icons.waving_hand_rounded),
            const SizedBox(width: 14),
            Expanded(
              child: _buildMascotText(true),
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
      child: Lottie.asset(
        'assets/animations/breath.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        repeat: true,
        animate: true,
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
