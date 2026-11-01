import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

/// Onest at [weight]: the font is variable, and its `wght` axis follows
/// only an explicit variation, not [FontWeight] alone.
TextStyle onest(
  double size, {
  FontWeight weight = FontWeight.w500,
  Color color = Colors.white,
  double? height,
  double? letterSpacing,
  List<FontFeature>? features,
}) => TextStyle(
  fontFamily: 'Onest',
  fontSize: size,
  fontWeight: weight,
  fontVariations: [FontVariation('wght', weight.value.toDouble())],
  color: color,
  height: height,
  letterSpacing: letterSpacing,
  fontFeatures: features,
);

/// Measurements of the event page (design-system §9.1).
abstract final class EventPageStyle {
  /// The sheet's top corners and its gap under the status bar.
  static const radius = 44.0;
  static const top = 8.0;
  static const gutter = 24.0;

  static const grabber = Size(40, 5);
  static const grabberColor = Color(0x99FFFFFF);

  /// The round buttons at the top corners: the app's one size.
  static const button = PillStyle.size;
  static const buttonInset = 16.0;

  /// The zone at the top that pulls the sheet down.
  static const handleZone = 96.0;

  /// The base under every gradient: near black with a warm tint.
  static const dark = Color(0xFF0A0605);

  static const scrim = Color(0xD9000000);
  static const enter = Duration(milliseconds: 380);
  static const leave = Duration(milliseconds: 220);
  static const fling = Duration(milliseconds: 160);
  static const settle = Duration(milliseconds: 200);
  static const dismissDistance = 110.0;
  static const dismissVelocity = 700.0;

  static const fade = Duration(milliseconds: 180);
  static const motion = Duration(milliseconds: 260);

  /// Title: Unbounded ExtraBold in capitals, fitted to one line
  /// (fit_title.dart). At 46 "ПОЕЗДКА" is about 300 pt wide, as in the
  /// reference, and "НАЗВАНИЕ" fits after a little tracking.
  static const titleSize = 46.0;

  /// The frame around the title, kept while viewing too.
  static const titleInset = EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  /// The font's own line height (ascent 0.995 + descent 0.245), set
  /// explicitly: left empty, a text field takes the theme's 1.5 and its
  /// line no longer fits the title's box (design-system §9.1).
  static const titleHeight = 1.24;
  static const title = TextStyle(
    fontFamily: 'Unbounded',
    fontSize: titleSize,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wght', 800)],
    height: titleHeight,
    leadingDistribution: TextLeadingDistribution.even,
    color: Colors.white,
  );

  static final status = onest(18, color: const Color(0xD9FFFFFF));
  static final description = onest(17, color: const Color(0xCCFFFFFF));

  /// Dates and times: proportional figures — Onest's tabular "1" stands
  /// apart ("1 2 ноя.").
  static final value = onest(24, letterSpacing: -0.2, height: 1.1);
  static final duration = onest(18, weight: FontWeight.w600, height: 1.2);
  static final label = onest(19, weight: FontWeight.w600);
  static final caption = onest(15, color: const Color(0x99FFFFFF));

  /// Blocks over the gradient: see-through dark, so the colours show.
  static const block = BoxDecoration(
    color: Color(0x33000000),
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  /// The frame around the title while it can be edited.
  static const titleFrame = Color(0x99FFFFFF);

  /// The lighter frame around the description field.
  static const fieldFrame = Color(0x4DFFFFFF);
}
