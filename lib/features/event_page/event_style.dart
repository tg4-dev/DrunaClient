import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/onest.dart';
import 'package:flutter/material.dart';

export 'package:druna_app/shared/ui/onest.dart';

abstract final class EventPageStyle {
  static const radius = 44.0;
  static const top = 8.0;
  static const gutter = 24.0;

  static const grabber = Size(40, 5);
  static const grabberColor = Color(0x99FFFFFF);

  static const button = PillStyle.size;
  static const buttonInset = 16.0;

  static const handleZone = 96.0;

  static const dark = Color(0xFF0A0605);

  static const scrim = Color(0xD9000000);
  static const enter = Motion.long;
  static const leave = Motion.medium;
  static const fling = Duration(milliseconds: 160);
  static const settle = Motion.medium;
  static const dismissDistance = 110.0;
  static const dismissVelocity = 700.0;

  static const fade = Motion.short;
  static const motion = Duration(milliseconds: 260);

  static const titleSize = 46.0;

  static const titleInset = EdgeInsets.symmetric(horizontal: 10, vertical: 6);

  static const statusGap = 10.0;
  static const descriptionGap = statusGap;

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

  static final status = onest(17, color: const Color(0xD9FFFFFF));
  static final description = onest(17, color: const Color(0xCCFFFFFF));

  static final label = onest(20, weight: FontWeight.w600);
  static final caption = onest(15, color: const Color(0x99FFFFFF));

  static const block = BoxDecoration(
    color: Color(0x33000000),
    borderRadius: BorderRadius.all(Radius.circular(24)),
  );

  static const titleFrame = Color(0x99FFFFFF);

  static const fieldFrame = Color(0x4DFFFFFF);
}
