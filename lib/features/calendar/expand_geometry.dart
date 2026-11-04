import 'package:flutter/animation.dart';

const dayMidnightInset = 40.0;
const dayTitleRide = 6.0;
const dayTitleSlot = dayMidnightInset + dayTitleRide;
const expandOpenDuration = Duration(milliseconds: 360);

const expandVeilCurve = Interval(0, 0.28, curve: Curves.easeOutCubic);

class ExpandLayout {
  const ExpandLayout({
    required this.motion,
    required this.top,
    required this.bottom,
    required this.veil,
  });

  final double motion;

  final double top;
  final double bottom;

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
    veil: expandVeilCurve.transform(motion),
  );
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
