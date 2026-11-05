import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/onest.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class PillFieldStyle {
  static const height = 50.0;
  static const fieldWidth = 258.0;

  static const fitMinSize = 12.0;

  static const nameWidth = 178.0;
  static const fade = Motion.short;

  static final field = onest(20, weight: FontWeight.w500, height: 1.2);
  static final fieldHint = onest(
    20,
    weight: FontWeight.w500,
    color: const Color(0x73FFFFFF),
    height: 1.2,
  );

  static final name = onest(20, weight: FontWeight.w800, height: 1.2);
  static final nameHint = onest(
    20,
    weight: FontWeight.w800,
    color: const Color(0x73FFFFFF),
    height: 1.2,
  );
}

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
    this.onChanged,
    this.fieldKey,
    this.style,
    this.hintStyle,
    this.keepFocus = true,
    this.fitText = false,
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

  final double? width;
  final VoidCallback? onSubmitted;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;

  final TextStyle? style;
  final TextStyle? hintStyle;

  final bool keepFocus;

  final bool fitText;

  static const _slot = 44.0;

  @override
  Widget build(BuildContext context) {
    if (!fitText || width == null) return _build(context, style);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _build(context, _fitted(context)),
    );
  }

  TextStyle _fitted(BuildContext context) {
    final base = style ?? PillFieldStyle.field;
    final length = controller.text.characters.length;
    if (length == 0) return base;
    final shown = obscure ? '•' * length : controller.text;
    final painter = TextPainter(
      text: TextSpan(text: shown, style: base),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final natural = painter.width;
    painter.dispose();
    final room = width! - 2 * _slot - 4;
    if (natural <= room) return base;
    final size = base.fontSize ?? PillFieldStyle.field.fontSize!;
    return base.copyWith(
      fontSize: (size * room / natural).clamp(PillFieldStyle.fitMinSize, size),
    );
  }

  Widget _build(BuildContext context, TextStyle? style) {
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
      onChanged: onChanged,
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
          duration: Motion.medium,
          curve: Curves.easeOutCubic,
          width: wide,
          child: child,
        );
      },
      child: body,
    );
  }
}
