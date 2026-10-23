import 'package:flutter/material.dart';

import '../../../../core/config/mascot_3d_config.dart';
import '../../../../core/config/mascot_animations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/accueil_scene.dart';
import '../../../../core/widgets/accessible_action.dart';
import '../../../../core/widgets/app_sheet_route.dart';
import '../../../../core/widgets/mascot_with_accessories.dart';
import '../../../../core/widgets/night_painter.dart';
import '../../../dashboard/data/accueil_activities.dart';
import '../../../mascot/data/models/mascot_model.dart';

Future<void> showArrivalInfo(BuildContext context, String title, String copy) =>
    Navigator.of(context, rootNavigator: true).push<void>(
      AppSheetRoute<void>(
        reduced: MediaQuery.disableAnimationsOf(context),
        builder: (sheetContext) => AppSheetPanel(
          title: title,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                copy,
                style: AppTextStyles.bodyMedium(color: context.textSecondary),
              ),
              const SizedBox(height: AppDimensions.spacing24),
              ArrivalButton(
                label: 'Compris',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );

void showArrivalSteps(BuildContext context) => showArrivalInfo(
  context,
  'À ton rythme',
  'Un prénom, ce qui t’amène, ton humeur et ton décor. Tu peux passer les questions et changer tes réponses ensuite dans ton profil.',
);

class ArrivalScene extends StatelessWidget {
  static final _defaultMascot = MascotModel.defaultMascot();
  final MascotDecor decor;
  final MascotModel? mascot;
  final bool launch;
  final double hop;
  final int reaction;
  const ArrivalScene({
    super.key,
    this.decor = MascotDecor.arches,
    this.mascot,
    this.launch = false,
    this.hop = 0,
    this.reaction = 0,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: AccueilScenePainter(decor: decor, dark: dark),
          ),
        ),
        Positioned(
          top: launch
              ? AppDimensions.arrivalLaunchTop
              : AppDimensions.arrivalHeroTop,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.translate(
              offset: Offset(0, hop),
              child: MascotWithAccessories(
                config: const Mascot3DConfig(),
                width: launch
                    ? AppDimensions.arrivalLaunchHero
                    : AppDimensions.arrivalHeroSize,
                height: launch
                    ? AppDimensions.arrivalLaunchHero
                    : AppDimensions.arrivalHeroSize,
                mascot: mascot ?? _defaultMascot,
                animation: reaction == 0
                    ? MascotAnimations.idle
                    : MascotAnimations.greet,
                animationTrigger: reaction,
              ),
            ),
          ),
        ),
        if (launch)
          Positioned(
            top: AppDimensions.arrivalWordTop,
            left: 0,
            right: 0,
            child: Text(
              'elyrii',
              textAlign: TextAlign.center,
              style: AppTextStyles.wordmark(color: context.textPrimary),
            ),
          ),
      ],
    );
  }
}

class ArrivalFrame extends StatefulWidget {
  final String title;
  final Widget child;
  final VoidCallback onBack;
  final VoidCallback? onInfo;
  final String? bubble;
  final MascotModel? mascot;
  final MascotDecor decor;
  final bool scene;
  final double scrollThreshold;
  const ArrivalFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.onInfo,
    this.bubble,
    this.mascot,
    this.decor = MascotDecor.arches,
    this.scene = true,
    this.scrollThreshold = AppDimensions.arrivalAuthThreshold,
  });
  @override
  State<ArrivalFrame> createState() => _ArrivalFrameState();
}

class _ArrivalFrameState extends State<ArrivalFrame>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final _hop = AnimationController(
    vsync: this,
    duration: AppMotion.mascotHop,
  );
  late final _sceneMotion = Listenable.merge([_scroll, _hop]);
  int _reaction = 0;

  void _react() {
    setState(() => _reaction++);
    if (!MediaQuery.disableAnimationsOf(context)) _hop.forward(from: 0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
      backgroundColor: dark ? AppColors.scaffoldDark : AppColors.scaffoldLight,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppDimensions.maxContentWidth,
          ),
          child: SizedBox.expand(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: NightPainter(dark)),
                  ),
                ),
                if (widget.scene)
                  AnimatedBuilder(
                    animation: _sceneMotion,
                    builder: (context, _) {
                      final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                      final hop = AppMotion.accueilPop.transform(_hop.value);
                      return Transform.translate(
                        offset: Offset(0, -offset * .45),
                        child: Opacity(
                          opacity:
                              (1 - offset / AppDimensions.arrivalHeroFadeRange)
                                  .clamp(0, 1),
                          child: SizedBox(
                            height: AppDimensions.arrivalSceneHeight,
                            child: ArrivalScene(
                              decor: widget.decor,
                              mascot: widget.mascot,
                              reaction: _reaction,
                              hop: reduced || !_hop.isAnimating
                                  ? 0
                                  : -AppDimensions.accueilHopDistance *
                                        (hop < .5 ? hop * 2 : 2 - hop * 2),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                SingleChildScrollView(
                  controller: _scroll,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: widget.scene
                            ? AppDimensions.arrivalSheetTop
                            : AppDimensions.arrivalResetTop,
                        child: widget.scene
                            ? AccessibleAction(
                                label: 'Faire réagir Elyrii',
                                onPressed: _react,
                                child: const SizedBox.expand(),
                              )
                            : null,
                      ),
                      if (widget.bubble != null)
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(
                              bottom: AppDimensions.spacing12,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.spacing16,
                              vertical: AppDimensions.spacing12,
                            ),
                            decoration: BoxDecoration(
                              color: dark
                                  ? AppColors.cardDark
                                  : AppColors.cardLight,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radius18,
                              ),
                            ),
                            child: Text(
                              widget.bubble!,
                              style: AppTextStyles.bodyMedium(
                                color: context.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      Container(
                        constraints: const BoxConstraints(
                          minHeight: AppDimensions.arrivalMinBody,
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppDimensions.spacing20,
                          AppDimensions.spacing24,
                          AppDimensions.spacing20,
                          AppDimensions.spacing48,
                        ),
                        decoration: BoxDecoration(
                          color: widget.scene
                              ? AppColors.sectionBody(dark)
                              : Colors.transparent,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(AppDimensions.radius30),
                          ),
                        ),
                        child: SafeArea(top: false, child: widget.child),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: AnimatedBuilder(
                    animation: _scroll,
                    builder: (context, _) {
                      final band =
                          !widget.scene ||
                          (_scroll.hasClients &&
                              _scroll.offset > widget.scrollThreshold);
                      return AnimatedContainer(
                        duration: reduced ? Duration.zero : AppMotion.bandFade,
                        curve: AppMotion.accueilEase,
                        color: band
                            ? (dark
                                  ? AppColors.glassBackgroundDark
                                  : AppColors.glassBackgroundLight)
                            : Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.spacing12,
                          vertical: AppDimensions.spacing8,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: 'Retour',
                              onPressed: widget.onBack,
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            Expanded(
                              child: TextButton(
                                onPressed: widget.onInfo,
                                child: Text(
                                  widget.title,
                                  style: AppTextStyles.navTitle(
                                    color: context.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'À propos de cette étape',
                              onPressed: widget.onInfo,
                              icon: const Icon(Icons.info_outline_rounded),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ArrivalField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool password;
  final bool enabled;
  final String? helperText;
  final String? Function(String?)? validator;
  final List<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  const ArrivalField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.password = false,
    this.enabled = true,
    this.helperText,
    this.validator,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.onChanged,
  });
  @override
  State<ArrivalField> createState() => _ArrivalFieldState();
}

class _ArrivalFieldState extends State<ArrivalField> {
  bool _visible = false;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radius14),
      borderSide: BorderSide.none,
    );
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.password && !_visible,
      autocorrect: !widget.password,
      enableSuggestions: !widget.password,
      keyboardType: widget.keyboardType,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      textInputAction: widget.textInputAction,
      style: AppTextStyles.bodyLarge(color: context.textPrimary),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        helperMaxLines: 3,
        errorMaxLines: 3,
        filled: true,
        fillColor: dark ? AppColors.cardDark : AppColors.cardLight,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(
            color: dark ? AppColors.primaryDark : AppColors.primary,
            width: AppDimensions.borderWidthMedium,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing12,
          vertical: AppDimensions.spacing16,
        ),
        prefixIcon: Icon(
          widget.icon,
          size: AppDimensions.iconSm,
          color: context.textTertiary,
        ),
        suffixIcon: widget.password
            ? IconButton(
                tooltip: _visible
                    ? 'Masquer le mot de passe'
                    : 'Afficher le mot de passe',
                onPressed: () => setState(() => _visible = !_visible),
                icon: Icon(
                  _visible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: AppDimensions.iconSm,
                ),
              )
            : null,
      ),
    );
  }
}

class ArrivalButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final bool busy;
  final IconData? icon;
  const ArrivalButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.busy = false,
    this.icon,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(
          double.infinity,
          AppDimensions.journalBigButton,
        ),
        backgroundColor: secondary
            ? (dark ? AppColors.cardDark : AppColors.cardLight)
            : (dark ? AppColors.primaryDark : AppColors.primary),
        foregroundColor: secondary
            ? context.textPrimary
            : AppColors.onTint(dark),
        textStyle: AppTextStyles.labelLarge(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacing20,
          vertical: AppDimensions.spacing12,
        ),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(
              dimension: AppDimensions.iconSm,
              child: CircularProgressIndicator(
                strokeWidth: AppDimensions.borderWidthMedium,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(label, textAlign: TextAlign.center)),
                if (icon != null) ...[
                  const SizedBox(width: AppDimensions.spacing8),
                  Icon(icon, size: AppDimensions.iconSm),
                ],
              ],
            ),
    );
  }
}

class ArrivalFeedback extends StatelessWidget {
  final String? message;
  const ArrivalFeedback(this.message, {super.key});
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppDimensions.spacing12,
          ),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: AppTextStyles.bodyMedium(color: context.textSecondary),
            ),
          ),
        );
}
