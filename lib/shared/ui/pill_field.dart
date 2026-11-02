import 'package:druna_app/shared/ui/onest.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Measurements of [PillField] 🟡.
abstract final class PillFieldStyle {
  static const height = 50.0;
  static const fieldWidth = 258.0;

  /// A field that hugs its text is never narrower than this.
  static const nameWidth = 178.0;
  static const fade = Duration(milliseconds: 180);

  static final field = onest(20, weight: FontWeight.w500, height: 1.2);
  static final fieldHint = onest(
    20,
    weight: FontWeight.w500,
    color: const Color(0x73FFFFFF),
    height: 1.2,
  );

  /// The name: bolder, as everywhere (design-system §3).
  static final name = onest(20, weight: FontWeight.w800, height: 1.2);
  static final nameHint = onest(
    20,
    weight: FontWeight.w800,
    color: const Color(0x73FFFFFF),
    height: 1.2,
  );
}

/// The app's text field (design-system §9.9, §9.11): a capsule like the
/// button, the text in the
/// middle, a slot at the right for a spinner, a tick or the eye, and one at
/// the left for a fixed sign (the username's "@").
///
/// In the onboarding ([keepFocus]) the keyboard never goes away on its own:
/// neither the return key nor a tap outside takes the focus. Elsewhere (the
/// settings) a tap outside ends the editing.
class PillField extends StatelessWidget {
  const PillField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.autofillHints,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.obscure = false,
    this.trailing,
    this.leading,
    this.focusNode,
    this.width = PillFieldStyle.fieldWidth,
    this.onSubmitted,
    this.fieldKey,
    this.style,
    this.hintStyle,
    this.keepFocus = true,
    super.key,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final bool obscure;
  final Widget? trailing;
  final Widget? leading;
  final FocusNode? focusNode;

  /// Null hugs the text (the name field), from [PillFieldStyle.nameWidth].
  final double? width;
  final VoidCallback? onSubmitted;
  final Key? fieldKey;

  /// Replace [PillFieldStyle.field] and [PillFieldStyle.fieldHint].
  final TextStyle? style;
  final TextStyle? hintStyle;

  /// True: return and a tap outside leave the focus where it is.
  final bool keepFocus;

  static const _slot = 44.0;

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      key: fieldKey,
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autocorrect: false,
      enableSuggestions: false,
      textAlign: TextAlign.center,
      style: style ?? PillFieldStyle.field,
      cursorColor: Colors.white,
      keyboardAppearance: Brightness.dark,
      onSubmitted: (_) => onSubmitted?.call(),
      // The defaults drop the focus (return on «done», a tap outside).
      onEditingComplete: keepFocus ? () {} : null,
      onTapOutside: keepFocus
          ? (_) {}
          : (_) => (focusNode ?? FocusManager.instance.primaryFocus)?.unfocus(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: hintStyle ?? PillFieldStyle.fieldHint,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        isCollapsed: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: _slot),
      ),
    );
    final body = SizedBox(
      height: PillFieldStyle.height,
      child: PillSurface(
        child: Stack(
          alignment: Alignment.center,
          children: [
            field,
            if (leading != null)
              Positioned(
                left: 4,
                top: 0,
                bottom: 0,
                width: _slot,
                child: IgnorePointer(child: Center(child: leading)),
              ),
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              width: _slot,
              child: Center(
                child: AnimatedSwitcher(
                  duration: PillFieldStyle.fade,
                  child: trailing ?? const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (width != null) return SizedBox(width: width, child: body);
    // Hugs the text: as wide as what is typed, or the hint.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        final text = controller.text.isEmpty ? hint : controller.text;
        final painter = TextPainter(
          text: TextSpan(
            text: text.toUpperCase(),
            style: style ?? PillFieldStyle.field,
          ),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final wide = (painter.width + 2 * _slot + 8).clamp(
          PillFieldStyle.nameWidth,
          PillFieldStyle.fieldWidth,
        );
        painter.dispose();
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          width: wide,
          child: child,
        );
      },
      child: body,
    );
  }
}
