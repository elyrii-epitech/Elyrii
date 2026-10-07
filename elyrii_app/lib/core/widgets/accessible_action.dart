import 'package:flutter/material.dart';

import '../design_system/haptics/elyrii_haptics.dart';

/// The same action is available to touch, keyboard and assistive technologies.
class AccessibleAction extends StatefulWidget {
  const AccessibleAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    required this.child,
  });

  final String? label;
  final VoidCallback? onPressed;
  final BorderRadius borderRadius;
  final Widget child;

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
      container: true,
      excludeSemantics: widget.label != null,
      button: true,
      enabled: enabled,
      label: widget.label,
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
              opacity: _isPressed && enabled ? 0.7 : 1,
              child: DecoratedBox(
                position: DecorationPosition.foreground,
                decoration: BoxDecoration(
                  borderRadius: widget.borderRadius,
                  border: _showFocus && enabled
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
