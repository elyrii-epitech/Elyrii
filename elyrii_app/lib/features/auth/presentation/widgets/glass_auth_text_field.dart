import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Champ de formulaire d'authentification au style iOS natif.
///
/// - Bordures subtiles (1 px) sans halo au focus,
/// - icône de préfixe, effacement rapide du texte (✕),
/// - bascule de visibilité pour les mots de passe,
/// - validation inline sous le champ.
class GlassAuthTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;

  const GlassAuthTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
  });

  @override
  State<GlassAuthTextField> createState() => _GlassAuthTextFieldState();
}

class _GlassAuthTextFieldState extends State<GlassAuthTextField> {
  bool _obscureText = true;
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) {
        setState(() => _isFocused = _focusNode.hasFocus);
      }
    });
    // Rebuild léger pour afficher/masquer le bouton d'effacement.
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasText = widget.controller.text.isNotEmpty;

    return FormField<String>(
      validator: widget.validator,
      initialValue: widget.controller.text,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: state.hasError
                      ? AppColors.error
                      : (_isFocused
                            ? AppColors.primary
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.10))),
                  width: _isFocused || state.hasError ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                obscureText: widget.isPassword ? _obscureText : false,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                onChanged: state.didChange,
                style: AppTextStyles.bodyMedium(
                  color: isDark ? Colors.white : Colors.black,
                ).copyWith(fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppTextStyles.inputHint().copyWith(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.35),
                  ),
                  prefixIcon: Icon(
                    widget.prefixIcon,
                    size: 20,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.45)
                        : Colors.black.withValues(alpha: 0.40),
                  ),
                  suffixIcon: widget.isPassword
                      ? IconButton(
                          icon: Icon(
                            _obscureText
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.55)
                                : Colors.black.withValues(alpha: 0.55),
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscureText = !_obscureText;
                            });
                          },
                        )
                      : hasText
                      ? IconButton(
                          tooltip: 'Effacer',
                          icon: Icon(
                            Icons.cancel_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.black.withValues(alpha: 0.30),
                          ),
                          onPressed: () {
                            widget.controller.clear();
                            state.didChange('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.paddingLg,
                    vertical: AppDimensions.paddingMd,
                  ),
                ),
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(
                  top: AppDimensions.spacingXs,
                  left: AppDimensions.paddingMd,
                ),
                child: Text(
                  state.errorText!,
                  style: AppTextStyles.bodySmall(color: AppColors.error),
                ),
              ),
          ],
        );
      },
    );
  }
}
