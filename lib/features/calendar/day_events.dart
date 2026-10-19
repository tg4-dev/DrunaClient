import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

const timelineEventTop = 36.0;
const timelineEventHeight = 58.0;
const timelineEventGap = 8.0;
const timelineTitlePadding = 12.0;

const timelineTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

class DayEventLayer extends StatelessWidget {
  const DayEventLayer({
    required this.day,
    required this.dayIndex,
    required this.pixelsPerHour,
    required this.viewportLeft,
    required this.events,
    this.hiddenEventId,
    this.onEventTap,
    super.key,
  });

  final DateTime day;
  final int dayIndex;
  final double pixelsPerHour;
  final double viewportLeft;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  @override
  Widget build(BuildContext context) {
    final dayWidth = 24 * pixelsPerHour;
    final slices = <_PlacedSlice>[];
    final spans = <TimedSpan>[];
    for (final event in events) {
      if (event.id == hiddenEventId) continue;
      final slice = sliceOnDay(event, day);
      if (slice == null) continue;
      slices.add(_PlacedSlice(event, slice));
      spans.add(
        TimedSpan(
          id: event.id,
          start: _atHour(day, slice.startHour),
          end: _atHour(day, slice.endHour),
        ),
      );
    }
    final lanes = assignLanes(spans);
    final laneOf = {for (final lane in lanes) lane.id: lane.lane};
    return Stack(
      children: [
        for (final placed in slices)
          _bar(
            placed: placed,
            lane: laneOf[placed.event.id] ?? 0,
            pixels: pixelsPerHour,
            dayWidth: dayWidth,
          ),
      ],
    );
  }

  Widget _bar({
    required _PlacedSlice placed,
    required int lane,
    required double pixels,
    required double dayWidth,
  }) {
    final event = placed.event;
    final slice = placed.slice;
    final sliceLeft = dayIndex * dayWidth + slice.startHour * pixels;
    final sliceRight = dayIndex * dayWidth + slice.endHour * pixels;
    final bounds = _eventBounds(event, dayWidth);
    final title = eventDisplayTitle(event);
    final titleWidth = _titleWidth(title);
    final titleOffset = stickyTitleOffset(
      eventLeft: bounds.$1,
      eventRight: bounds.$2,
      viewportLeft: viewportLeft,
      sliceLeft: sliceLeft,
      sliceRight: sliceRight,
      titleWidth: titleWidth,
      padding: timelineTitlePadding,
    );
    return Positioned(
      left: slice.startHour * pixels,
      width: (slice.endHour - slice.startHour) * pixels,
      top: timelineEventTop + lane * (timelineEventHeight + timelineEventGap),
      height: timelineEventHeight,
      child: _TimelineBar(
        event: event,
        title: title,
        titleOffset: titleOffset,
        onTap: onEventTap,
      ),
    );
  }

  (double, double) _eventBounds(CalendarEvent event, double dayWidth) {
    final firstIndex =
        dayIndex + calendarDaysBetween(day, eventFirstDay(event));
    final lastIndex = dayIndex + calendarDaysBetween(day, eventLastDay(event));
    if (event.allDay) {
      return (firstIndex * dayWidth, (lastIndex + 1) * dayWidth);
    }
    final firstSlice = sliceOnDay(event, eventFirstDay(event));
    final lastSlice = sliceOnDay(event, eventLastDay(event));
    final startHour = firstSlice?.startHour ?? 0;
    final endHour = lastSlice?.endHour ?? 24;
    return (
      firstIndex * dayWidth + startHour * (dayWidth / 24),
      lastIndex * dayWidth + endHour * (dayWidth / 24),
    );
  }
}

class _PlacedSlice {
  const _PlacedSlice(this.event, this.slice);

  final CalendarEvent event;
  final EventDaySlice slice;
}

class _TimelineBar extends StatelessWidget {
  const _TimelineBar({
    required this.event,
    required this.title,
    required this.titleOffset,
    this.onTap,
  });

  final CalendarEvent event;
  final String title;
  final double? titleOffset;
  final void Function(CalendarEvent event, Rect rect)? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null
          ? null
          : () {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null || !box.hasSize) return;
              onTap!(event, box.localToGlobal(Offset.zero) & box.size);
            },
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: calendarEventColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: titleOffset == null
              ? const SizedBox.expand()
              : Stack(
                  children: [
                    Positioned(
                      left: titleOffset,
                      top: 0,
                      bottom: 0,
                      right: 0,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: timelineTitleStyle,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

double _titleWidth(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: timelineTitleStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

DateTime _atHour(DateTime day, double hour) {
  final minutes = (hour * 60).round();
  return DateTime(day.year, day.month, day.day, 0, minutes);
}
