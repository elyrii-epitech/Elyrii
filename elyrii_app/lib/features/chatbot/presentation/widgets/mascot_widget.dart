import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/config/mascot_animations.dart';
import '../providers/chatbot_provider.dart' show ChatbotProvider;
import '../../../../core/config/mascot_themes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../mascot/presentation/providers/mascot_provider.dart';

/// Widget d'affichage de la mascotte Elyrii dans le chatbot.
///
/// Aucune pulsation artificielle : la vie du personnage vient des clips
/// natifs du GLB — `thinking` pendant la génération de la réponse,
/// `attentive` pendant la saisie de l'utilisateur, `idle` au repos.
/// En mode réduit, la bannière devient une pilule « Dynamic Island »
/// compacte et flottante, centrée au-dessus de la conversation.
class MascotWidget extends StatefulWidget {
  /// Indique si la mascotte doit être affichée en mode réduit.
  final bool isMinimized;

  /// Hauteur de la mascotte en mode plein écran.
  final double lottieHeight;

  /// Action déclenchée au clic sur la mascotte.
  final VoidCallback? onTap;

  /// Vrai pendant que l'utilisateur saisit un message : la mascotte
  /// passe en écoute attentive (`MascotAnimations.attentive`).
  final bool isUserTyping;

  const MascotWidget({
    super.key,
    required this.isMinimized,
    this.lottieHeight = 150,
    this.onTap,
    this.isUserTyping = false,
  });

  @override
  State<MascotWidget> createState() => _MascotWidgetState();
}

class _MascotWidgetState extends State<MascotWidget> {
  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = (screenHeight * 0.45).clamp(220.0, 350.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Réflexion pendant la génération, écoute attentive pendant la saisie,
    // présence calme sinon — uniquement des clips du modèle 3D.
    final isBotThinking = context.select<ChatbotProvider, bool>(
      (p) => p.isTyping,
    );
    final MascotAnimation animation;
    if (isBotThinking) {
      animation = MascotAnimations.thinking;
    } else if (widget.isUserTyping) {
      animation = MascotAnimations.attentive;
    } else {
      animation = MascotAnimations.idle;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
      height: widget.isMinimized ? 80 : maxHeight,
      child: widget.isMinimized
          ? _buildDynamicIsland(isDark, animation, isBotThinking)
          : _buildFullMascot(maxHeight, isDark, animation),
    );
  }

  /// Construit la pilule « Dynamic Island » du mode réduit.
  ///
  /// Compacte, centrée, flottante au-dessus de la conversation : un tap
  /// la redéploie en mascotte plein écran. Le statut de présence change
  /// en douceur selon l'état de la mascotte.
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
          padding: const EdgeInsets.only(left: 6, right: 12),
          decoration: BoxDecoration(
            // Pilule charbon profond façon Dynamic Island : discrets
            // reflets de bord, aucune couleur criarde.
            color: isDark
                ? Colors.black.withValues(alpha: 0.55)
                : Colors.black.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(26),
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
                    width: 56,
                    height: 56,
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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
  Widget _buildFullMascot(
    double maxHeight,
    bool isDark,
    MascotAnimation animation,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMascotAvatar(widget.lottieHeight, animation),
        SizedBox(height: maxHeight * 0.04),
        _buildMascotText(isDark),
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
          width: size,
          height: size,
        ),
      ),
    );
  }

  /// Construit les textes informatifs accompagnant la mascotte.
  Widget _buildMascotText(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Discuter avec Elyrii',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
            fontSize: 26,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Je suis là pour t\'écouter\nsans jugement',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
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
  final double width;
  final double height;

  const _ThemedMascot({
    super.key,
    required this.config,
    required this.width,
    required this.height,
    this.animation,
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
    );
  }
}
