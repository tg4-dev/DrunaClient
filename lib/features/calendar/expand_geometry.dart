import 'package:flutter/animation.dart';

const dayMidnightInset = 40.0;
const dayTitleRide = 6.0;
const dayTitleSlot = dayMidnightInset + dayTitleRide;
const expandOpenDuration = Duration(milliseconds: 360);
const expandAlignDuration = Duration(milliseconds: 180);

class ExpandLayout {
  const ExpandLayout({
    required this.motion,
    required this.top,
    required this.bottom,
    required this.veil,
  });

  /// Raw progress, 0 at the month and 1 when the day fills the screen.
  final double motion;

  /// Top of the day sheet. Follows [motion] from the tapped week to the screen.
  final double top;
  final double bottom;

  /// Sheet opacity. It settles early so the rest of the move is just the sheet.
  final double veil;
}

ExpandLayout expandLayout({
  required double t,
  required Rect week,
  required double screenHeight,
}) {
  final motion = t.clamp(0.0, 1.0);
  return ExpandLayout(
    motion: motion,
    top: _lerp(week.top, 0, motion),
    bottom: _lerp(week.bottom, screenHeight, motion),
    veil: _phase(motion, 0, 0.28),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _phase(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.easeOutCubic,
]) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}
