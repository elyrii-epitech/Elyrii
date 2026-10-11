import 'package:flutter/material.dart';

/// Native form semantics connect the visible label, input and validation.
class GlassAuthTextField extends StatefulWidget {
  const GlassAuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint = '',
    required this.prefixIcon,
    this.isPassword = false,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    this.helperText,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData prefixIcon;
  final bool isPassword;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final String? helperText;
  final TextCapitalization textCapitalization;

  @override
  State<GlassAuthTextField> createState() => _GlassAuthTextFieldState();
}

class _GlassAuthTextFieldState extends State<GlassAuthTextField> {
  bool _obscureText = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(GlassAuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      widget.controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: widget.isPassword && _obscureText,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      autocorrect:
          !widget.isPassword &&
          widget.keyboardType != TextInputType.emailAddress,
      enableSuggestions: !widget.isPassword,
      enableIMEPersonalizedLearning: !widget.isPassword,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 16,
        color: scheme.onSurface,
      ),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint.isEmpty ? null : widget.hint,
        helperText: widget.helperText,
        helperMaxLines: 30,
        errorMaxLines: 30,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        errorStyle: TextStyle(color: scheme.error),
        filled: true,
        fillColor: dark
            ? Colors.white.withValues(alpha: .06)
            : Colors.black.withValues(alpha: .035),
        prefixIcon: ExcludeSemantics(
          child: Icon(
            widget.prefixIcon,
            size: 20,
            color: scheme.onSurfaceVariant,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 48,
          minHeight: 48,
        ),
        suffixIcon: widget.isPassword
            ? IconButton(
                tooltip: _obscureText
                    ? 'Afficher le mot de passe'
                    : 'Masquer le mot de passe',
                onPressed: widget.enabled
                    ? () => setState(() => _obscureText = !_obscureText)
                    : null,
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              )
            : widget.controller.text.isNotEmpty
            ? IconButton(
                tooltip: 'Effacer ${widget.label.toLowerCase()}',
                onPressed: widget.enabled ? widget.controller.clear : null,
                icon: const Icon(Icons.cancel_outlined),
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
      ),
    );
  }
}
