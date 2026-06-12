import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/widgets/mascot_3d_viewer.dart';

/// Widget d'affichage de la mascotte Elyrii dans le chatbot.
///
/// Gère la transition animée entre les modes réduit (bannière) et plein écran,
/// avec un effet de pulsation visuelle.
class MascotWidget extends StatefulWidget {
  /// Indique si la mascotte doit être affichée en mode réduit.
  final bool isMinimized;

  /// Hauteur de la mascotte en mode plein écran.
  final double lottieHeight;

  /// Action déclenchée au clic sur la mascotte.
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

    // Animation de pulsation lente pour donner de la vie au modèle 3D
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
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
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Transform.scale(
            scale: widget.isMinimized ? 1.0 : _pulseAnimation.value,
            child: widget.isMinimized
                ? _buildMinimizedMascot(isDark)
                : _buildFullMascot(maxHeight, isDark),
          );
        },
      ),
    );
  }

  /// Construit la mascotte en mode réduit (bannière horizontale).
  Widget _buildMinimizedMascot(bool isDark) {
    const double visibleHeight = 80;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withValues(alpha: 0.15),
              (isDark ? AppColors.cardDark : AppColors.cardLight).withValues(
                alpha: 0.95,
              ),
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
            const SizedBox(
              width: 100,
              height: visibleHeight,
              child: Center(
                child: Mascot3DViewer(
                  key: ValueKey('mascot_3d_mini'),
                  config: Mascot3DConfig.chatbotMinimized(),
                  width: 80,
                  height: 80,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: _buildMascotText(true, isDark)),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: (isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight)
                    .withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construit la mascotte en mode plein écran.
  Widget _buildFullMascot(double maxHeight, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMascotAvatar(widget.lottieHeight),
        SizedBox(height: maxHeight * 0.04),
        _buildMascotText(false, isDark),
      ],
    );
  }

  /// Construit le viewer 3D de la mascotte pour le mode plein écran.
  Widget _buildMascotAvatar(double size) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: size,
      height: size,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: Mascot3DViewer(
          key: const ValueKey('mascot_3d_full'),
          config: const Mascot3DConfig.chatbotFull(),
          width: size,
          height: size,
        ),
      ),
    );
  }

  /// Construit les textes informatifs accompagnant la mascotte.
  Widget _buildMascotText(bool isMinimized, bool isDark) {
    return Column(
      crossAxisAlignment:
          isMinimized ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          isMinimized ? 'Elyrii' : 'Discuter avec Elyrii',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color:
                isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontSize: isMinimized ? 15 : 26,
            fontWeight: FontWeight.w600,
            letterSpacing: isMinimized ? 0.3 : 0.5,
          ),
        ),
        SizedBox(height: isMinimized ? 2 : 12),
        Text(
          isMinimized
              ? 'Je t\'écoute'
              : 'Je suis là pour t\'écouter\nsans jugement',
          textAlign: isMinimized ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: isMinimized ? 11 : 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
