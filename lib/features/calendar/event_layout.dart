import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';

/// Pinching down through this height snaps the month to [monthRowMin].
final monthBarSnapThreshold = (monthRowLevels[0] + monthRowLevels[1]) / 2;

final monthDetailThreshold = (monthRowLevels[1] + monthRowLevels[2]) / 2;

const monthEventHeader = 34.0;

/// Gap between the last chip and the week divider.
const monthEventBottomPad = 12.0;

class EventDensity {
  const EventDensity({
    required this.bars,
    required this.showTime,
    required this.itemHeight,
    required this.gap,
  });

  final bool bars;
  final bool showTime;
  final double itemHeight;
  final double gap;

  bool get showTitle => !bars;

  double get slot => itemHeight + gap;
}

const barDensity = EventDensity(
  bars: true,
  showTime: false,
  itemHeight: 6,
  gap: 2,
);

const titleDensity = EventDensity(
  bars: false,
  showTime: false,
  itemHeight: 18,
  gap: 2,
);

const detailDensity = EventDensity(
  bars: false,
  showTime: true,
  itemHeight: 32,
  gap: 3,
);

EventDensity densityForRowHeight(double height) {
  if (height <= monthBarSnapThreshold) return barDensity;
  if (height < monthDetailThreshold) return titleDensity;
  return detailDensity;
}

int monthEventCapacity(double rowHeight, EventDensity density) {
  final available = rowHeight - monthEventHeader - monthEventBottomPad;
  if (available < density.itemHeight) return 1;
  final count = ((available + density.gap) / density.slot).floor();
  return count.clamp(1, 16);
}

bool columnVisible({
  required MonthStripKind kind,
  required int firstOfMonth,
  required int column,
}) {
  return switch (kind) {
    MonthStripKind.full => true,
    MonthStripKind.tail => firstOfMonth > 0 && column < firstOfMonth,
    MonthStripKind.fresh => firstOfMonth >= 0 && column >= firstOfMonth,
  };
}

class SpanPlacement {
  const SpanPlacement({
    required this.eventId,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final String eventId;
  final int startColumn;
  final int endColumn;
  final int lane;
  final bool continuesBefore;
  final bool continuesAfter;

  bool covers(int column) => column >= startColumn && column <= endColumn;
}

class ChipPlacement {
  const ChipPlacement(this.eventId, this.lane);

  final String eventId;
  final int lane;
}

class ColumnLayout {
  const ColumnLayout({
    required this.chips,
    required this.overflow,
    required this.overflowLane,
  });

  final List<ChipPlacement> chips;
  final int overflow;
  final int? overflowLane;
}

class MonthWeekLayout {
  const MonthWeekLayout({required this.spans, required this.columns});

  final List<SpanPlacement> spans;
  final List<ColumnLayout> columns;
}

MonthWeekLayout layoutWeek({
  required List<CalendarEvent> events,
  required List<DateTime> days,
  required int visibleStart,
  required int visibleEnd,
  required int capacity,
}) {
  final segments = <_Segment>[];
  final timedByColumn = List<List<CalendarEvent>>.generate(7, (_) => []);
  for (final event in events) {
    if (eventIsBar(event)) {
      final segment = _segmentFor(
        event: event,
        days: days,
        visibleStart: visibleStart,
        visibleEnd: visibleEnd,
      );
      if (segment != null) segments.add(segment);
      continue;
    }
    for (var column = visibleStart; column <= visibleEnd; column++) {
      if (eventOccursOn(event, days[column])) {
        timedByColumn[column].add(event);
      }
    }
  }
  segments.sort((a, b) {
    final byStart = a.startColumn.compareTo(b.startColumn);
    if (byStart != 0) return byStart;
    final byLength = (b.endColumn - b.startColumn).compareTo(
      a.endColumn - a.startColumn,
    );
    if (byLength != 0) return byLength;
    return a.eventId.compareTo(b.eventId);
  });
  for (final column in timedByColumn) {
    column.sort((a, b) {
      final byStart = a.start.compareTo(b.start);
      if (byStart != 0) return byStart;
      return a.id.compareTo(b.id);
    });
  }

  final placed = <SpanPlacement>[];
  for (final segment in segments) {
    placed.add(
      SpanPlacement(
        eventId: segment.eventId,
        startColumn: segment.startColumn,
        endColumn: segment.endColumn,
        lane: _freeLane(placed, segment.startColumn, segment.endColumn),
        continuesBefore: segment.continuesBefore,
        continuesAfter: segment.continuesAfter,
      ),
    );
  }

  return MonthWeekLayout(
    spans: placed,
    columns: [
      for (var column = 0; column < 7; column++)
        _columnLayout(
          column: column,
          visible: column >= visibleStart && column <= visibleEnd,
          spans: placed,
          timed: timedByColumn[column],
          capacity: capacity,
        ),
    ],
  );
}

class TimedSpan {
  const TimedSpan({required this.id, required this.start, required this.end});

  final String id;
  final DateTime start;
  final DateTime end;
}

class LaneAssignment {
  const LaneAssignment(this.id, this.lane);

  final String id;
  final int lane;
}

List<LaneAssignment> assignLanes(List<TimedSpan> items) {
  final order = [for (var index = 0; index < items.length; index++) index]
    ..sort((a, b) {
      final byStart = items[a].start.compareTo(items[b].start);
      if (byStart != 0) return byStart;
      final byEnd = items[a].end.compareTo(items[b].end);
      if (byEnd != 0) return byEnd;
      return items[a].id.compareTo(items[b].id);
    });
  final laneOf = List<int>.filled(items.length, 0);
  final laneEnds = <DateTime>[];
  for (final index in order) {
    final item = items[index];
    var lane = 0;
    for (; lane < laneEnds.length; lane++) {
      if (!laneEnds[lane].isAfter(item.start)) break;
    }
    if (lane == laneEnds.length) {
      laneEnds.add(item.end);
    } else {
      laneEnds[lane] = item.end;
    }
    laneOf[index] = lane;
  }
  return [
    for (var index = 0; index < items.length; index++)
      LaneAssignment(items[index].id, laneOf[index]),
  ];
}

class EventDaySlice {
  const EventDaySlice(this.startHour, this.endHour);

  final double startHour;
  final double endHour;
}

EventDaySlice? sliceOnDay(CalendarEvent event, DateTime day) {
  final date = dateOnly(day);
  if (!eventOccursOn(event, date)) return null;
  if (event.allDay) return const EventDaySlice(0, 24);
  final next = addCalendarDays(date, 1);
  final dayEnd = DateTime(next.year, next.month, next.day);
  final start = event.start.isBefore(date) ? date : event.start;
  final end = event.end.isAfter(dayEnd) ? dayEnd : event.end;
  if (!end.isAfter(start)) return null;
  return EventDaySlice(_hourOn(start, date), _hourOn(end, date));
}

/// X of the title inside [sliceLeft, sliceRight), or null when another slice
/// owns the sticky point.
double? stickyTitleOffset({
  required double eventLeft,
  required double eventRight,
  required double viewportLeft,
  required double sliceLeft,
  required double sliceRight,
  required double titleWidth,
  required double padding,
}) {
  if (sliceRight <= sliceLeft || eventRight <= eventLeft) return null;
  final visibleLeft = math.max(eventLeft, viewportLeft);
  if (visibleLeft >= eventRight) return null;
  var anchor = visibleLeft + padding;
  final minAnchor = eventLeft + padding;
  final maxAnchor = eventRight - padding - titleWidth;
  if (maxAnchor >= minAnchor) {
    anchor = anchor.clamp(minAnchor, maxAnchor);
  } else {
    anchor = minAnchor;
  }
  if (anchor < sliceLeft || anchor >= sliceRight) return null;
  return anchor - sliceLeft;
}

class _Segment {
  const _Segment({
    required this.eventId,
    required this.startColumn,
    required this.endColumn,
    required this.continuesBefore,
    required this.continuesAfter,
  });

  final String eventId;
  final int startColumn;
  final int endColumn;
  final bool continuesBefore;
  final bool continuesAfter;
}

_Segment? _segmentFor({
  required CalendarEvent event,
  required List<DateTime> days,
  required int visibleStart,
  required int visibleEnd,
}) {
  final first = eventFirstDay(event);
  final last = eventLastDay(event);
  int? startColumn;
  int? endColumn;
  for (var column = visibleStart; column <= visibleEnd; column++) {
    final day = days[column];
    if (day.isBefore(first) || day.isAfter(last)) continue;
    startColumn ??= column;
    endColumn = column;
  }
  if (startColumn == null || endColumn == null) return null;
  return _Segment(
    eventId: event.id,
    startColumn: startColumn,
    endColumn: endColumn,
    continuesBefore: first.isBefore(days[startColumn]),
    continuesAfter: last.isAfter(days[endColumn]),
  );
}

int _freeLane(List<SpanPlacement> placed, int start, int end) {
  var lane = 0;
  while (placed.any(
    (span) =>
        span.lane == lane && span.startColumn <= end && start <= span.endColumn,
  )) {
    lane++;
  }
  return lane;
}

ColumnLayout _columnLayout({
  required int column,
  required bool visible,
  required List<SpanPlacement> spans,
  required List<CalendarEvent> timed,
  required int capacity,
}) {
  if (!visible) {
    return const ColumnLayout(chips: [], overflow: 0, overflowLane: null);
  }
  final used = <int>{
    for (final span in spans)
      if (span.covers(column) && span.lane < capacity) span.lane,
  };
  final hiddenSpans = spans
      .where((span) => span.covers(column) && span.lane >= capacity)
      .length;
  final free = [
    for (var lane = 0; lane < capacity; lane++)
      if (!used.contains(lane)) lane,
  ];
  final extras = hiddenSpans + timed.length;
  if (extras <= free.length) {
    return ColumnLayout(
      chips: [
        for (var index = 0; index < timed.length; index++)
          ChipPlacement(timed[index].id, free[index]),
      ],
      overflow: 0,
      overflowLane: null,
    );
  }
  if (free.isEmpty) {
    return ColumnLayout(chips: const [], overflow: extras, overflowLane: null);
  }
  final shown = free.length - 1;
  return ColumnLayout(
    chips: [
      for (var index = 0; index < shown; index++)
        ChipPlacement(timed[index].id, free[index]),
    ],
    overflow: extras - shown,
    overflowLane: free[shown],
  );
}

double _hourOn(DateTime time, DateTime day) {
  if (!sameDay(time, day)) return 24;
  return time.hour + time.minute / 60.0 + time.second / 3600.0;
}
