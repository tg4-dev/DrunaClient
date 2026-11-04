import 'package:flutter/painting.dart';

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

class WeekBand {
  const WeekBand({
    required this.left,
    required this.right,
    required this.colors,
    required this.stops,
  });

  final double left;
  final double right;

  final List<Color> colors;
  final List<double> stops;

  double get width => right - left;
}

const bandJoinGap = 6.0;

const bandMinColorSpacing = 0.5;

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
