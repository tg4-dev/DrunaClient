import 'package:druna_app/shared/ui/onest.dart';
import 'package:flutter/widgets.dart';

/// A person's name as the app shows it: in capitals, everywhere
/// (design-system §3). The server keeps the name as it was typed; only the
/// display changes, so other clients and old accounts are not affected.
String shownName(String name) => name.trim().toUpperCase();

/// A person's name is set bold everywhere, as in the registration's name
/// field (design-system §3): [base] in Onest w800.
TextStyle nameStyle(TextStyle base) => base.merge(
  onest(
    base.fontSize ?? 17,
    weight: FontWeight.w800,
    color: base.color ?? const Color(0xFFFFFFFF),
    height: base.height,
    letterSpacing: base.letterSpacing,
  ),
);

/// A phrase with names in it: the names bold ([nameStyle]), the rest
/// [style]. Give the parts in order; a part in [names] is a name.
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

/// A name field that draws the text in capitals but keeps the value as
/// typed. A letter whose capital is longer (ß → SS) stays as it is, so the
/// cursor never drifts from the text.
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

/// [text] in capitals, letter by letter, keeping its length.
String upperSameLength(String text) {
  final out = StringBuffer();
  for (final unit in text.runes) {
    final letter = String.fromCharCode(unit);
    final upper = letter.toUpperCase();
    out.write(upper.length == letter.length ? upper : letter);
  }
  return out.toString();
}
