import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Widget mascotte placeholder animé
class MascotWidget extends StatefulWidget {
  final bool isMinimized;

  const MascotWidget({
    super.key,
    required this.isMinimized,
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
    final maxHeight = (screenHeight * 0.5).clamp(250.0, 400.0);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: widget.isMinimized ? 100 : maxHeight,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isMinimized ? 1.0 : _pulseAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.9),
                    AppColors.accent.withValues(alpha: 0.85),
                    AppColors.secondary.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius:
                    BorderRadius.circular(widget.isMinimized ? 22 : 32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: widget.isMinimized ? 16 : 32,
                    offset: const Offset(0, 8),
                    spreadRadius: widget.isMinimized ? 0 : 2,
                  ),
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    blurRadius: widget.isMinimized ? 24 : 48,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: widget.isMinimized ? 10 : 30,
                    right: widget.isMinimized ? 10 : 30,
                    child: Container(
                      width: widget.isMinimized ? 20 : 60,
                      height: widget.isMinimized ? 20 : 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: widget.isMinimized ? 15 : 50,
                    left: widget.isMinimized ? 15 : 40,
                    child: Container(
                      width: widget.isMinimized ? 15 : 40,
                      height: widget.isMinimized ? 15 : 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isMinimized ? 20 : 32,
                      vertical: widget.isMinimized ? 12 : 20,
                    ),
                    child: widget.isMinimized
                        ? Row(
                            children: [
                              _buildMascotAvatar(50, Icons.waving_hand_rounded),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _buildMascotText(true),
                              ),
                            ],
                          )
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _buildMascotAvatar(
                                    (maxHeight * 0.35).clamp(80.0, 120.0),
                                    Icons.favorite_rounded),
                                SizedBox(height: maxHeight * 0.06),
                                _buildMascotText(false),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMascotAvatar(double size, IconData icon) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: size * 0.5,
          color: Colors.white,
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
          isMinimized ? 'Elyrii' : 'Bienvenue chez Elyrii',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isMinimized ? 15 : 32,
            fontWeight: isMinimized ? FontWeight.w600 : FontWeight.w300,
            letterSpacing: isMinimized ? 0.3 : 2.0,
          ),
        ),
        SizedBox(height: isMinimized ? 2 : 16),
        Text(
          isMinimized
              ? 'Je t\'écoute 💜'
              : 'Je suis là pour t\'écouter\nsans jugement',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.95),
            fontSize: isMinimized ? 11 : 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        if (!isMinimized) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✨ Prends ton temps',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
