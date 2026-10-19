import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Rounder month chips: half the height for thin bars, at most 8.
double monthChipRadius(EventDensity density) =>
    (density.itemHeight / 2).clamp(3.0, 8.0);

/// Days a dragged event would cover if dropped now.
class DropRange {
  const DropRange(this.first, this.last, {required this.moving});

  final DateTime first;
  final DateTime last;

  /// An existing event is being moved, not a new one placed.
  final bool moving;

  bool covers(DateTime day) => !day.isBefore(first) && !day.isAfter(last);

  @override
  bool operator ==(Object other) =>
      other is DropRange &&
      other.first == first &&
      other.last == last &&
      other.moving == moving;

  @override
  int get hashCode => Object.hash(first, last, moving);
}

class MonthWeekGrid extends StatelessWidget {
  const MonthWeekGrid({
    required this.strip,
    required this.rowKey,
    required this.today,
    required this.onDayTap,
    required this.index,
    this.hiddenEventId,
    this.dimmedEventId,
    this.hoverDay,
    this.onEventTap,
    this.onHoldStart,
    super.key,
  });

  final MonthStrip strip;
  final String rowKey;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final CalendarEventIndex index;
  final String? hiddenEventId;

  /// The event being dragged stays in place, faded, until it is dropped.
  final String? dimmedEventId;

  /// The day under a dragged event; only the matching column repaints.
  final ValueListenable<DropRange?>? hoverDay;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(strip.weekIndex);
    final firstOfMonth = days.indexWhere((day) => day.day == 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final rowHeight = constraints.maxHeight;
        final density = densityForRowHeight(rowHeight);
        final capacity = monthEventCapacity(rowHeight, density);
        final visible = _visibleRange(strip.kind, firstOfMonth);
        final shown = [
          for (final event in index.forWeek(strip.weekIndex))
            if (event.id != hiddenEventId) event,
        ];
        final layout =
            index.memo.putIfAbsent(
                  (
                    'week',
                    strip.weekIndex,
                    strip.kind,
                    capacity,
                    hiddenEventId,
                  ),
                  () => layoutWeek(
                    events: shown,
                    days: days,
                    visibleStart: visible.$1,
                    visibleEnd: visible.$2,
                    capacity: capacity,
                  ),
                )
                as MonthWeekLayout;
        final byId = {for (final event in shown) event.id: event};
        final columnWidth = constraints.maxWidth / 7;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _column(
                      days: days,
                      column: column,
                      firstOfMonth: firstOfMonth,
                      layout: layout.columns[column],
                      density: density,
                      byId: byId,
                    ),
                  ),
              ],
            ),
            for (final span in layout.spans)
              if (layout.showsSpan(span) && byId[span.eventId] != null)
                _span(
                  span: span,
                  event: byId[span.eventId]!,
                  density: density,
                  columnWidth: columnWidth,
                ),
          ],
        );
      },
    );
  }

  (int, int) _visibleRange(MonthStripKind kind, int firstOfMonth) {
    var start = 7;
    var end = -1;
    for (var column = 0; column < 7; column++) {
      if (!columnVisible(
        kind: kind,
        firstOfMonth: firstOfMonth,
        column: column,
      )) {
        continue;
      }
      if (column < start) start = column;
      if (column > end) end = column;
    }
    return (start, end);
  }

  Widget _column({
    required List<DateTime> days,
    required int column,
    required int firstOfMonth,
    required ColumnLayout layout,
    required EventDensity density,
    required Map<String, CalendarEvent> byId,
  }) {
    final showDay = columnVisible(
      kind: strip.kind,
      firstOfMonth: firstOfMonth,
      column: column,
    );
    if (!showDay) return const SizedBox.expand();
    final day = days[column];
    final content = Column(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onDayTap(day),
          onLongPressStart: (details) =>
              onHoldStart?.call(null, details.globalPosition),
          child: SizedBox(
            height: monthEventHeader,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: _DayNumber(day: day, today: sameDay(day, today)),
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: monthEventBottomPad),
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDayTap(day),
                    onLongPressStart: (details) =>
                        onHoldStart?.call(null, details.globalPosition),
                  ),
                ),
                for (final chip in layout.chips)
                  if (byId[chip.eventId] != null)
                    Positioned(
                      top: chip.lane * density.slot,
                      left: 2,
                      right: 2,
                      height: density.itemHeight,
                      child: _MonthEventBlock(
                        event: byId[chip.eventId]!,
                        dimmed: chip.eventId == dimmedEventId,
                        density: density,
                        onTap: onEventTap,
                        onHoldStart: onHoldStart,
                      ),
                    ),
                if (layout.overflow > 0)
                  Positioned(
                    top: (layout.overflowLane ?? 0) * density.slot,
                    left: 4,
                    right: 2,
                    height: density.itemHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDayTap(day),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '+${layout.overflow}',
                          style: const TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
    final hover = hoverDay;
    if (hover == null) {
      return KeyedSubtree(key: ValueKey('$rowKey-$column'), child: content);
    }
    return ValueListenableBuilder<DropRange?>(
      key: ValueKey('$rowKey-$column'),
      valueListenable: hover,
      child: content,
      builder: (context, range, child) => ColoredBox(
        color: range == null || !range.covers(day)
            ? Colors.transparent
            : range.moving
            ? calendarEventColor.withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.12),
        child: child,
      ),
    );
  }

  Widget _span({
    required SpanPlacement span,
    required CalendarEvent event,
    required EventDensity density,
    required double columnWidth,
  }) {
    final leftInset = span.continuesBefore ? 0.0 : 2.0;
    final rightInset = span.continuesAfter ? 0.0 : 2.0;
    final left = span.startColumn * columnWidth + leftInset;
    final right = (span.endColumn + 1) * columnWidth - rightInset;
    return Positioned(
      left: left,
      top: monthEventHeader + span.lane * density.slot,
      width: right - left,
      height: density.itemHeight,
      child: _MonthEventBlock(
        event: event,
        dimmed: event.id == dimmedEventId,
        density: density,
        continuesBefore: span.continuesBefore,
        continuesAfter: span.continuesAfter,
        onTap: onEventTap,
        onHoldStart: onHoldStart,
      ),
    );
  }
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day, required this.today});

  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final weekend = day.weekday >= DateTime.saturday;
    final color = today
        ? Colors.white
        : weekend
        ? const Color(0xFFD1D1D6)
        : Colors.white;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: today
          ? const BoxDecoration(
              color: Color(0xFFFF3B30),
              shape: BoxShape.circle,
            )
          : null,
      child: Text(
        '${day.day}',
        key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: today ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _MonthEventBlock extends StatelessWidget {
  const _MonthEventBlock({
    required this.event,
    required this.density,
    this.dimmed = false,
    this.continuesBefore = false,
    this.continuesAfter = false,
    this.onTap,
    this.onHoldStart,
  });

  final CalendarEvent event;
  final EventDensity density;
  final bool dimmed;
  final bool continuesBefore;
  final bool continuesAfter;
  final void Function(CalendarEvent event, Rect rect)? onTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    final corner = Radius.circular(monthChipRadius(density));
    final radius = BorderRadius.horizontal(
      left: continuesBefore ? Radius.zero : corner,
      right: continuesAfter ? Radius.zero : corner,
    );
    return AnimatedOpacity(
      opacity: dimmed ? 0.35 : 1,
      duration: const Duration(milliseconds: 160),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                onTap!(event, box.localToGlobal(Offset.zero) & box.size);
              },
        onLongPressStart: onHoldStart == null
            ? null
            : (details) => onHoldStart!(event, details.globalPosition),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: calendarEventColor,
            borderRadius: radius,
          ),
          child: density.showTitle
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: density.showTime && !event.allDay
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              eventDisplayTitle(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              clockLabel(event.start),
                              maxLines: 1,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            eventDisplayTitle(event),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
