/// Zoom levels of the day timeline, in pixels per hour. Their divisions —
/// the hours that get a line and a label — are 6 h, 4 h, 2 h, 1 h and 30 min.
const timelinePixelsPerHourLevels = [12.0, 18.0, 28.0, 46.0, 92.0];
const timelineMinPixelsPerHour = 12.0;

/// Hours between labelled lines at each level; the last adds half hours via
/// [halfHourOpacity].
const timelineDivisionHours = [6, 4, 2, 1, 1];

/// Drawing and moving snap to this many minutes at each level: coarse when
/// zoomed out, so a finger lands where it means to.
const timelineStepMinutes = [120, 60, 60, 30, 30];

/// The minutes between labelled lines at each level.
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

int _levelIndex(double pixelsPerHour) =>
    timelinePixelsPerHourLevels.indexOf(nearestTimelinePixels(pixelsPerHour));

int timelineStepFor(double pixelsPerHour) =>
    timelineStepMinutes[_levelIndex(pixelsPerHour)];

int timelineDivisionFor(double pixelsPerHour) =>
    timelineDivisionMinutes[_levelIndex(pixelsPerHour)];

/// How strongly the line of [hour] shows at [pixelsPerHour]: fully on the
/// levels whose division includes it, fading between levels. Hours 6 and 18
/// belong to the 6 h level but not the 4 h one, so they fade out from 12 to
/// 18 px and back in by 28.
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

/// Where a dragged time lands, in minutes from the same origin as [raw]:
///
/// - on the nearest [step];
/// - on a labelled line ([division]) when the finger is within 30% of a step
///   of it, so a whole hour is easy to hit even with a 30-minute step;
/// - and it stays on [current] until the finger is 60% of a step away, so
///   it does not flicker on a boundary.
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
