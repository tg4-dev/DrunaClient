import 'package:druna_app/features/calendar/expand_geometry.dart';

const dayTitleGap = 10.0;
const dayTitleBig = 32.0;
const dayTitleSmall = 16.0;

class DayTitleLayout {
  const DayTitleLayout({
    required this.index,
    required this.travel,
    required this.currentSize,
    required this.nextSize,
    required this.currentMidnight,
    required this.nextMidnight,
    required this.slot,
  });

  final int index;
  final double travel;
  final double currentSize;
  final double nextSize;
  final double currentMidnight;
  final double? nextMidnight;
  final double slot;

  double currentX(double width) {
    final midnight = nextMidnight;
    if (midnight == null) return slot;
    final parked = midnight - dayTitleGap - width;
    return parked < slot ? parked : slot;
  }

  double? nextX() {
    final midnight = nextMidnight;
    if (midnight == null) return null;
    return midnight + dayTitleRide;
  }

  double previousX(double width) => currentMidnight - dayTitleGap - width;
}

double dayWidthOf(double pixelsPerHour) => 24 * pixelsPerHour;

double midnightOf(int dayIndex, double offset, double pixelsPerHour) =>
    dayIndex * dayWidthOf(pixelsPerHour) - offset;

DayTitleLayout dayTitleLayout({
  required double offset,
  required double pixelsPerHour,
  required double bigWidth,
  int maxIndex = 365 * 130 - 1,
}) {
  final width = dayWidthOf(pixelsPerHour);
  final raw = width == 0 ? 0.0 : (offset + dayMidnightInset) / width;
  final index = raw.floor().clamp(0, maxIndex);
  final currentMidnight = midnightOf(index, offset, pixelsPerHour);
  final hasNext = index < maxIndex;
  final nextMidnight = hasNext
      ? midnightOf(index + 1, offset, pixelsPerHour)
      : null;
  final nextLabel = nextMidnight == null
      ? dayTitleSlot
      : nextMidnight + dayTitleRide;
  final distance = nextLabel - dayTitleSlot;
  final window = bigWidth + dayTitleGap;
  final travel = distance >= window
      ? 0.0
      : (1 - distance / window).clamp(0.0, 1.0);
  return DayTitleLayout(
    index: index,
    travel: travel,
    currentSize: dayTitleBig + (dayTitleSmall - dayTitleBig) * travel,
    nextSize: dayTitleSmall + (dayTitleBig - dayTitleSmall) * travel,
    currentMidnight: currentMidnight,
    nextMidnight: nextMidnight,
    slot: dayTitleSlot,
  );
}
