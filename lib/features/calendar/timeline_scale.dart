const timelinePixelsPerHourLevels = [12.0, 18.0, 28.0, 46.0, 92.0];
const timelineMinPixelsPerHour = 12.0;

const timelineDivisionHours = [6, 4, 2, 1, 1];

const timelineStepMinutes = [120, 60, 60, 30, 30];

const timelineDivisionMinutes = [360, 240, 120, 60, 30];
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

double zoomedOffset({
  required double offset,
  required double focal,
  required double oldExtent,
  required double newExtent,
}) {
  if (oldExtent == 0) return offset;
  return (offset + focal) / oldExtent * newExtent - focal;
}

int _levelIndex(double pixelsPerHour) =>
    timelinePixelsPerHourLevels.indexOf(nearestTimelinePixels(pixelsPerHour));

int timelineStepFor(double pixelsPerHour) =>
    timelineStepMinutes[_levelIndex(pixelsPerHour)];

int timelineDivisionFor(double pixelsPerHour) =>
    timelineDivisionMinutes[_levelIndex(pixelsPerHour)];

double hourLineOpacity(int hour, double pixelsPerHour) {
  double on(int level) => hour % timelineDivisionHours[level] == 0 ? 1.0 : 0.0;
  const levels = timelinePixelsPerHourLevels;
  if (pixelsPerHour <= levels.first) return on(0);
  for (var i = 0; i < levels.length - 1; i++) {
    if (pixelsPerHour > levels[i + 1]) continue;
    final t = (pixelsPerHour - levels[i]) / (levels[i + 1] - levels[i]);
    return on(i) + (on(i + 1) - on(i)) * t;
  }
  return on(levels.length - 1);
}

double halfHourOpacity(double pixelsPerHour) =>
    ((pixelsPerHour - 46) / 46).clamp(0, 1).toDouble();

int snapWithMagnet({
  required double raw,
  required int? current,
  required int step,
  required int division,
}) {
  var next = (raw / step).round() * step;
  final line = (raw / division).round() * division;
  if ((raw - line).abs() <= step * 0.3) next = line;
  if (current != null &&
      next != current &&
      (raw - current).abs() <= step * 0.6) {
    return current;
  }
  return next;
}
