import 'package:flutter/painting.dart';

/// One event's place along a week, in grid x.
class BandChip {
  const BandChip({
    required this.left,
    required this.right,
    required this.color,
  });

  final double left;
  final double right;
  final Color color;

  double get center => (left + right) / 2;
  double get weight => right - left;
}

/// A run of busy time along a week: one band with a horizontal gradient.
class WeekBand {
  const WeekBand({
    required this.left,
    required this.right,
    required this.colors,
    required this.stops,
  });

  final double left;
  final double right;

  /// Gradient colours and their positions, 0 at [left] and 1 at [right].
  final List<Color> colors;
  final List<double> stops;

  double get width => right - left;
}

/// Chips this close (with their 2 pt insets, days in a row are 4 pt apart)
/// make one band.
const bandJoinGap = 6.0;

/// Colour points closer than this share of a day merge into one.
const bandMinColorSpacing = 0.5;

/// Busy time of a week as bands, the way the hidden layer of the month is
/// drawn: consecutive days run together; along a band, each event puts its
/// colour at its centre and the gradient blends neighbours in plain RGB.
/// (OKLab/OKLCH invent a third hue — yellow and blue meet as green — which
/// reads as someone else.) Points closer than half a day merge, the longer
/// event winning, so a busy day shows at most about two colours.
List<WeekBand> buildWeekBands(
  List<BandChip> chips, {
  required double columnWidth,
}) {
  if (chips.isEmpty) return const [];
  final sorted = [...chips]..sort((a, b) => a.left.compareTo(b.left));
  final runs = <List<BandChip>>[];
  var right = double.negativeInfinity;
  for (final chip in sorted) {
    if (runs.isEmpty || chip.left > right + bandJoinGap) {
      runs.add([chip]);
      right = chip.right;
    } else {
      runs.last.add(chip);
      if (chip.right > right) right = chip.right;
    }
  }
  return [
    for (final run in runs) _band(run, columnWidth * bandMinColorSpacing),
  ];
}

WeekBand _band(List<BandChip> run, double minSpacing) {
  final left = run.map((chip) => chip.left).reduce((a, b) => a < b ? a : b);
  final right = run.map((chip) => chip.right).reduce((a, b) => a > b ? a : b);
  final points = [...run]..sort((a, b) => a.center.compareTo(b.center));
  var merged = true;
  while (merged && points.length > 1) {
    merged = false;
    for (var i = 0; i < points.length - 1; i++) {
      if (points[i + 1].center - points[i].center >= minSpacing) continue;
      final a = points[i];
      final b = points[i + 1];
      // Longer wins; on a tie the earlier one stays.
      points.removeAt(b.weight > a.weight ? i : i + 1);
      merged = true;
      break;
    }
  }
  final width = right - left;
  double at(double x) => width <= 0 ? 0 : ((x - left) / width).clamp(0.0, 1.0);
  if (points.length == 1) {
    final color = points.single.color;
    return WeekBand(
      left: left,
      right: right,
      colors: [color, color],
      stops: const [0, 1],
    );
  }
  final colors = <Color>[
    points.first.color,
    for (final point in points) point.color,
    points.last.color,
  ];
  final stops = <double>[0, for (final point in points) at(point.center), 1];
  return WeekBand(left: left, right: right, colors: colors, stops: stops);
}

/// A band of one colour per run, for the user's own events.
List<WeekBand> buildSolidBands(List<BandChip> chips, Color color) {
  return [
    for (final band in buildWeekBands([
      for (final chip in chips)
        BandChip(left: chip.left, right: chip.right, color: color),
    ], columnWidth: double.infinity))
      WeekBand(
        left: band.left,
        right: band.right,
        colors: [color, color],
        stops: const [0, 1],
      ),
  ];
}
