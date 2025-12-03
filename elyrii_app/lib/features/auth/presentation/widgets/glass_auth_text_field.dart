import 'package:flutter/material.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';

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
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FormField<String>(
      validator: widget.validator,
      initialValue: widget.controller.text,
      builder: (FormFieldState<String> state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: _isFocused ? 0.08 : 0.03)
                    : Colors.black.withValues(alpha: _isFocused ? 0.05 : 0.02),
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                border: Border.all(
                  color: state.hasError
                      ? AppColors.error
                      : (_isFocused
                          ? (isDark ? Colors.white : AppColors.primary)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.1))),
                  width: 1.5,
                ),
                boxShadow: _isFocused
                    ? [
                        BoxShadow(
                          color: (state.hasError
                                  ? AppColors.error
                                  : (isDark ? Colors.white : AppColors.primary))
                              .withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    obscureText: widget.isPassword ? _obscureText : false,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    onChanged: (value) {
                      state.didChange(value);
                    },
                    style: AppTextStyles.bodyMedium(
                      color: isDark ? Colors.white : Colors.black,
                    ).copyWith(fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AppTextStyles.inputHint().copyWith(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.4)
                            : Colors.black.withValues(alpha: 0.4),
                      ),
                      prefixIcon: null,
                      suffixIcon: widget.isPassword
                          ? IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : Colors.black.withValues(alpha: 0.6),
                                size: 20,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureText = !_obscureText;
                                });
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
              ),
            ),
            if (state.hasError)
              Padding(
                padding: const EdgeInsets.only(
                    top: AppDimensions.spacingXs,
                    left: AppDimensions.paddingMd),
                child: Text(
                  state.errorText!,
                  style: AppTextStyles.bodySmall(
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
