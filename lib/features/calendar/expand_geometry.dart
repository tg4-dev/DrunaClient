import 'package:flutter/animation.dart';

const dayMidnightInset = 40.0;
const dayTitleRide = 6.0;
const dayTitleSlot = dayMidnightInset + dayTitleRide;
const expandOpenDuration = Duration(milliseconds: 360);
const expandAlignDuration = Duration(milliseconds: 180);

class ExpandLayout {
  const ExpandLayout({
    required this.motion,
    required this.settled,
    required this.slot,
    required this.columnWidth,
    required this.dayWidth,
    required this.anchor,
    required this.top,
    required this.bottom,
    required this.rowBottom,
    required this.contentTop,
    required this.selectedSize,
    required this.otherSize,
    required this.selectedWeight,
    required this.otherOpacity,
    required this.weekdayOpacity,
    required this.todayOpacity,
    required this.chromeOpacity,
    required this.gridOpacity,
    required this.hourLabelOpacity,
    required this.headerOpacity,
    required this.gridSlide,
    required this.topShift,
    required this.bottomShift,
    required this.screenWidth,
  });

  final double motion;
  final double settled;
  final int slot;
  final double columnWidth;
  final double dayWidth;
  final double anchor;
  final double top;
  final double bottom;
  final double rowBottom;
  final double contentTop;
  final double selectedSize;
  final double otherSize;
  final double selectedWeight;
  final double otherOpacity;
  final double weekdayOpacity;
  final double todayOpacity;
  final double chromeOpacity;
  final double gridOpacity;
  final double hourLabelOpacity;
  final double headerOpacity;
  final double gridSlide;
  final double topShift;
  final double bottomShift;
  final double screenWidth;

  double dateX(int column, double textWidth) {
    final cell = column * columnWidth + (columnWidth - textWidth) / 2;
    if (column != slot) return cell;
    // Horizontal motion lags the rise, so the date arcs into its slot.
    return _lerp(cell, dayTitleSlot, settled * settled);
  }

  double dateTop(int column, double size) => rowBottom - size;
}

ExpandLayout expandLayout({
  required double t,
  required Rect week,
  required int slot,
  required double screenWidth,
  required double screenHeight,
  required double headerBottom,
  required double pixelsPerHour,
  double contentTop = 0,
}) {
  final clamped = t.clamp(0.0, 1.0);
  final motion = clamped;
  final settled = _phase(clamped, 0, 0.6);
  final columnWidth = screenWidth / 7;
  final startBottom = contentTop + 17;
  return ExpandLayout(
    motion: motion,
    settled: settled,
    slot: slot,
    columnWidth: columnWidth,
    dayWidth: columnWidth,
    anchor: _lerp(slot * columnWidth, dayMidnightInset, settled),
    top: _lerp(week.top, headerBottom, motion),
    bottom: _lerp(week.bottom, screenHeight, motion),
    rowBottom: _lerp(startBottom, headerBottom, settled),
    contentTop: contentTop,
    selectedSize: _lerp(17, 32, settled),
    otherSize: 17,
    selectedWeight: settled,
    otherOpacity: 1 - _phase(clamped, 0, 0.6, Curves.easeInOut),
    weekdayOpacity: _phase(clamped, 0.2, 0.6),
    todayOpacity: 1 - settled,
    chromeOpacity: 1 - motion,
    gridOpacity: _phase(clamped, 0.15, 1, Curves.easeInOut),
    hourLabelOpacity: _phase(clamped, 0.3, 1, Curves.easeInOut),
    headerOpacity: _phase(clamped, 0.6, 1),
    gridSlide: _lerp(screenWidth, 0, motion),
    topShift: motion * (week.top - headerBottom),
    bottomShift: motion * (screenHeight - week.bottom),
    screenWidth: screenWidth,
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
