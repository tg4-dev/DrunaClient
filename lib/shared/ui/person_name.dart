import 'package:druna_app/shared/ui/onest.dart';
import 'package:flutter/widgets.dart';

String shownName(String name) => name.trim().toUpperCase();

TextStyle nameStyle(TextStyle base) => base.merge(
  onest(
    base.fontSize ?? 17,
    weight: FontWeight.w800,
    color: base.color ?? const Color(0xFFFFFFFF),
    height: base.height,
    letterSpacing: base.letterSpacing,
  ),
);

class NameText extends StatelessWidget {
  const NameText({
    required this.parts,
    required this.names,
    required this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
    super.key,
  });

  final List<String> parts;
  final Set<int> names;
  final TextStyle style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      style: style,
      children: [
        for (var i = 0; i < parts.length; i++)
          TextSpan(
            text: parts[i],
            style: names.contains(i) ? nameStyle(style) : null,
          ),
      ],
    ),
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class UpperCaseNameController extends TextEditingController {
  UpperCaseNameController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final span = super.buildTextSpan(
      context: context,
      style: style,
      withComposing: withComposing,
    );
    return _upper(span);
  }

  static TextSpan _upper(TextSpan span) => TextSpan(
    text: span.text == null ? null : upperSameLength(span.text!),
    style: span.style,
    children: [
      for (final child in span.children ?? const <InlineSpan>[])
        child is TextSpan ? _upper(child) : child,
    ],
  );
}

String upperSameLength(String text) {
  final out = StringBuffer();
  for (final unit in text.runes) {
    final letter = String.fromCharCode(unit);
    final upper = letter.toUpperCase();
    out.write(upper.length == letter.length ? upper : letter);
  }
  return out.toString();
}
