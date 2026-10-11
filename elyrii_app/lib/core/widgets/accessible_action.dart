import 'package:flutter/material.dart';

import '../design_system/haptics/elyrii_haptics.dart';

/// The same action is available to touch, keyboard and assistive technologies.
class AccessibleAction extends StatefulWidget {
  const AccessibleAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.selected,
    this.value,
    this.hint,
    this.excludeChildSemantics = false,
    this.liveRegion = false,
    required this.child,
  });

  final String? label;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final Widget child;
  final bool? selected;
  final String? value;
  final String? hint;
  final bool excludeChildSemantics;
  final bool liveRegion;

  @override
  State<AccessibleAction> createState() => AccessibleActionState();
}

class AccessibleActionState extends State<AccessibleAction> {
  bool _isPressed = false;
  bool _showFocus = false;

  void _activate() {
    if (widget.onPressed == null) return;
    ElyriiHaptics.light();
    widget.onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final duration = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Semantics(
      container: widget.label != null,
      excludeSemantics: widget.excludeChildSemantics,
      explicitChildNodes: widget.label != null && !widget.excludeChildSemantics,
      button: true,
      enabled: enabled,
      label: widget.label,
      selected: widget.selected,
      value: widget.value,
      hint: widget.hint,
      liveRegion: widget.liveRegion,
      onTap: enabled ? _activate : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        onShowFocusHighlight: (value) => setState(() => _showFocus = value),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              _activate();
              return null;
            },
          ),
        },
        child: GestureDetector(
          excludeFromSemantics: true,
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: enabled ? (_) => setState(() => _isPressed = false) : null,
          onTapCancel: enabled
              ? () => setState(() => _isPressed = false)
              : null,
          onTap: enabled ? _activate : null,
          child: AnimatedScale(
            scale: _isPressed && enabled && !reduceMotion ? 0.97 : 1,
            duration: duration,
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              duration: duration,
              // Press feedback must not lower the contrast of active labels.
              opacity: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  // Two contrasting rings remain visible on both filled and
                  // transparent controls, without covering their content.
                  boxShadow: _showFocus && enabled
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.onSurface,
                            spreadRadius: 4,
                          ),
                          BoxShadow(
                            color: Theme.of(context).colorScheme.surface,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                  border: _showFocus && enabled
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
