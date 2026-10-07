const timelinePixelsPerHourLevels = [18.0, 28.0, 46.0, 92.0];
const timelineMinPixelsPerHour = 18.0;
const timelineMaxPixelsPerHour = 92.0;
const defaultPixelsPerHour = 46.0;

double nearestLevel(double value, List<double> levels) {
  var best = levels.first;
  for (final level in levels.skip(1)) {
    if ((level - value).abs() < (best - value).abs()) best = level;
  }
  return best;
}

double nearestTimelinePixels(double pixelsPerHour) =>
    nearestLevel(pixelsPerHour, timelinePixelsPerHourLevels);

/// Keeps the content point under [focal] fixed while the extent changes.
double zoomedOffset({
  required double offset,
  required double focal,
  required double oldExtent,
  required double newExtent,
}) {
  if (oldExtent == 0) return offset;
  return (offset + focal) / oldExtent * newExtent - focal;
}

double hourLineOpacity(int hour, double pixelsPerHour) {
  if (hour % 4 == 0) return 1;
  if (hour % 2 == 0) {
    return ((pixelsPerHour - 18) / 10).clamp(0, 1).toDouble();
  }
  return ((pixelsPerHour - 28) / 18).clamp(0, 1).toDouble();
}

double halfHourOpacity(double pixelsPerHour) =>
    ((pixelsPerHour - 46) / 46).clamp(0, 1).toDouble();
