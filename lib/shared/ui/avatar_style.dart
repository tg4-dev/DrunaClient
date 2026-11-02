import 'package:druna_app/shared/ui/oklab.dart';
import 'package:flutter/material.dart';

/// How a person's avatar looks (design-system §9.11, docs/avatar.md): a
/// circle filled with a 45° gradient of their colour and the first letter
/// of their name in their font, centred by eye.

/// The fill: the colour at the top left, a darker shade of it at the
/// bottom right.
LinearGradient avatarGradient(Color base) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [base, avatarShade(base)],
);

/// [base] darker, the same hue: its OKLab lightness × [avatarShadeFactor].
/// A darker colour holds less chroma; where it would leave sRGB, the chroma
/// shrinks just enough to stay inside — clipping would bend the hue
/// (orange turned red, yellow olive).
Color avatarShade(Color base) {
  final (l, a, b) = oklab(base);
  final dark = l * avatarShadeFactor;
  if (inSrgbGamut((dark, a, b))) return fromOklab((dark, a, b));
  var low = 0.0;
  var high = 1.0;
  for (var i = 0; i < 16; i++) {
    final mid = (low + high) / 2;
    if (inSrgbGamut((dark, a * mid, b * mid))) {
      low = mid;
    } else {
      high = mid;
    }
  }
  return fromOklab((dark, a * low, b * low));
}

const avatarShadeFactor = 0.72;

/// One font of the avatar letter, with everything that fits it to the
/// circle. Tune the numbers on the «Подгонка аватаров» screen (settings →
/// demo data) and paste what it copies; docs/avatar.md has the details.
@immutable
class AvatarFont {
  const AvatarFont({
    required this.id,
    required this.label,
    required this.family,
    required this.capHeight,
    required this.xHeight,
    this.weight = FontWeight.w700,
    this.uppercase = true,
    this.scale = 0.6,
    this.dx = 0,
    this.dy = 0,
    double? ascender,
    this.descender = 0.22,
  }) : ascender = ascender ?? capHeight * 1.04;

  /// Stored as the user's choice: never change it for a font in use.
  final String id;

  /// Read by VoiceOver.
  final String label;
  final String family;

  /// Through the `wght` axis of a variable font.
  final FontWeight weight;

  /// The letter in capitals, or small.
  final bool uppercase;

  /// The font size as a share of the circle's diameter.
  final double scale;

  /// A nudge by eye, as a share of the diameter: + right, + down.
  final double dx;
  final double dy;

  /// Shares of the em, from the font's OS/2 table: the height of a capital,
  /// of a small letter without ascender, of an ascender, and the depth of a
  /// descender. The letter's ink is centred on them.
  final double capHeight;
  final double xHeight;
  final double ascender;
  final double descender;

  /// [letter] in this font's case.
  String cased(String letter) =>
      uppercase ? letter.toUpperCase() : letter.toLowerCase();

  TextStyle style(double fontSize, Color color) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: weight,
    fontVariations: [FontVariation('wght', weight.value.toDouble())],
    color: color,
    height: 1,
  );

  AvatarFont copyWith({double? scale, double? dx, double? dy}) => AvatarFont(
    id: id,
    label: label,
    family: family,
    capHeight: capHeight,
    xHeight: xHeight,
    weight: weight,
    uppercase: uppercase,
    scale: scale ?? this.scale,
    dx: dx ?? this.dx,
    dy: dy ?? this.dy,
    ascender: ascender,
    descender: descender,
  );

  /// The constructor call that recreates this font, for pasting into
  /// [avatarFonts] after tuning.
  String toCode() {
    String n(double v) => v.toStringAsFixed(3);
    return 'AvatarFont(\n'
        "  id: '$id',\n"
        "  label: '$label',\n"
        "  family: '$family',\n"
        '  weight: FontWeight.w${weight.value},\n'
        '  uppercase: $uppercase,\n'
        '  scale: ${n(scale)},\n'
        '  dx: ${n(dx)},\n'
        '  dy: ${n(dy)},\n'
        '  capHeight: ${n(capHeight)},\n'
        '  xHeight: ${n(xHeight)},\n'
        '  ascender: ${n(ascender)},\n'
        '  descender: ${n(descender)},\n'
        '),';
  }
}

/// The fonts to choose from, in the picker's order. Add at the end; the
/// user's choice is kept by [AvatarFont.id].
const avatarFonts = <AvatarFont>[
  defaultAvatarFont,
  AvatarFont(
    id: 'playfair',
    label: 'Антиква',
    family: 'PlayfairDisplay',
    uppercase: false,
    scale: 0.84,
    capHeight: 0.708,
    xHeight: 0.514,
    descender: 0.25,
  ),
  AvatarFont(
    id: 'lobster',
    label: 'Рукописный',
    family: 'Lobster',
    weight: FontWeight.w400,
    uppercase: false,
    scale: 0.82,
    capHeight: 0.748,
    xHeight: 0.5,
    descender: 0.24,
  ),
  AvatarFont(
    id: 'oswald',
    label: 'Узкий',
    family: 'Oswald',
    weight: FontWeight.w600,
    scale: 0.54,
    capHeight: 0.81,
    xHeight: 0.578,
  ),
  AvatarFont(
    id: 'unbounded',
    label: 'Широкий',
    family: 'Unbounded',
    scale: 0.5,
    capHeight: 0.75,
    xHeight: 0.566,
  ),
  AvatarFont(
    id: 'comfortaa',
    label: 'Скруглённый',
    family: 'Comfortaa',
    uppercase: false,
    scale: 0.76,
    capHeight: 0.781,
    xHeight: 0.547,
  ),
];

/// The default, and what friends get until the server tells their choice.
const defaultAvatarFont = AvatarFont(
  id: 'onest',
  label: 'Гротеск',
  family: 'Onest',
  weight: FontWeight.w800,
  scale: 0.6,
  capHeight: 0.707,
  xHeight: 0.527,
);

AvatarFont avatarFontById(String? id) => avatarFonts.firstWhere(
  (font) => font.id == id,
  orElse: () => defaultAvatarFont,
);

/// Small letters that rise to the capitals' height.
const _ascenders =
    'bdfhklt'
    'бё';

/// Letters that hang below the baseline.
const _descenders =
    'gjpqy'
    'друфцщ'
    'ДЦЩ';

/// Where [letter]'s ink lies, in ems above (+) and below (−) the baseline.
(double top, double bottom) inkBox(AvatarFont font, String letter) {
  final small = letter != letter.toUpperCase();
  final top = !small
      ? font.capHeight
      : _ascenders.contains(letter)
      ? font.ascender
      : font.xHeight;
  final bottom = _descenders.contains(letter) ? -font.descender : 0.0;
  return (top, bottom);
}

/// [letter] in [font], its ink centred in a [size] box (the circle).
class AvatarLetter extends StatelessWidget {
  const AvatarLetter({
    required this.letter,
    required this.font,
    required this.size,
    this.color = Colors.white,
    this.guides = false,
    super.key,
  });

  /// Already in the font's case ([AvatarFont.cased]).
  final String letter;
  final AvatarFont font;
  final double size;
  final Color color;

  /// The tuning screen: the centre lines and the ink's frame.
  final bool guides;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _LetterPainter(letter, font, color, guides)),
  );
}

class _LetterPainter extends CustomPainter {
  _LetterPainter(this.letter, this.font, this.color, this.guides);

  final String letter;
  final AvatarFont font;
  final Color color;
  final bool guides;

  @override
  void paint(Canvas canvas, Size size) {
    final d = size.shortestSide;
    final fontSize = d * font.scale;
    final painter = TextPainter(
      text: TextSpan(text: letter, style: font.style(fontSize, color)),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final baseline = painter.computeDistanceToActualBaseline(
      TextBaseline.alphabetic,
    );
    final (top, bottom) = inkBox(font, letter);
    // The baseline goes where the ink's middle meets the centre.
    final baselineY = d / 2 + (top + bottom) / 2 * fontSize + font.dy * d;
    final offset = Offset(
      (d - painter.width) / 2 + font.dx * d,
      baselineY - baseline,
    );
    painter.paint(canvas, offset);
    if (guides) {
      final line = Paint()
        ..color = const Color(0x80FFFFFF)
        ..strokeWidth = 0.5;
      canvas
        ..drawLine(Offset(d / 2, 0), Offset(d / 2, d), line)
        ..drawLine(Offset(0, d / 2), Offset(d, d / 2), line)
        ..drawRect(
          Rect.fromLTRB(
            offset.dx,
            baselineY - top * fontSize,
            offset.dx + painter.width,
            baselineY - bottom * fontSize,
          ),
          line..style = PaintingStyle.stroke,
        );
    }
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _LetterPainter old) =>
      old.letter != letter ||
      old.font != font ||
      old.color != color ||
      old.guides != guides;
}
