import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

const timelineEventTop = 36.0;
const timelineEventHeight = 58.0;
const timelineEventGap = 8.0;
const timelineTitlePadding = 12.0;
const timelineEventRadius = Radius.circular(16);

const timelineTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 20,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

double timelineLaneTop(int lane) =>
    timelineEventTop + lane * (timelineEventHeight + timelineEventGap);

/// One day's event bars. Titles are drawn by [DayTitleOverlay] above all days,
/// so a bar crossing midnight reads as one event.
class DayEventLayer extends StatelessWidget {
  const DayEventLayer({
    required this.day,
    required this.pixelsPerHour,
    required this.events,
    required this.lanes,
    this.hiddenEventId,
    this.dimmedEventId,
    this.onEventTap,
    this.onHoldStart,
    this.onHoldMove,
    this.onHoldEnd,
    super.key,
  });

  final DateTime day;
  final double pixelsPerHour;
  final List<CalendarEvent> events;
  final Map<String, int> lanes;
  final String? hiddenEventId;

  /// The event being moved stays in place, faded, until it is dropped.
  final String? dimmedEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  /// A long press on a bar picks the event up to move it.
  final void Function(CalendarEvent event, Offset global)? onHoldStart;
  final ValueChanged<Offset>? onHoldMove;
  final VoidCallback? onHoldEnd;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final event in events)
          if (event.id != hiddenEventId) ?_bar(event),
      ],
    );
  }

  Widget? _bar(CalendarEvent event) {
    final slice = sliceOnDay(event, day);
    if (slice == null) return null;
    final radius = BorderRadius.horizontal(
      left: slice.continuesBefore ? Radius.zero : timelineEventRadius,
      right: slice.continuesAfter ? Radius.zero : timelineEventRadius,
    );
    return Positioned(
      key: ValueKey(event.id),
      left: slice.startHour * pixelsPerHour,
      width: (slice.endHour - slice.startHour) * pixelsPerHour,
      top: timelineLaneTop(lanes[event.id] ?? 0),
      height: timelineEventHeight,
      child: Builder(
        builder: (context) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onEventTap == null
              ? null
              : () {
                  final box = context.findRenderObject() as RenderBox?;
                  if (box == null || !box.hasSize) return;
                  onEventTap!(event, box.localToGlobal(Offset.zero) & box.size);
                },
          onLongPressStart: onHoldStart == null
              ? null
              : (details) => onHoldStart!(event, details.globalPosition),
          onLongPressMoveUpdate: onHoldMove == null
              ? null
              : (details) => onHoldMove!(details.globalPosition),
          onLongPressEnd: onHoldEnd == null ? null : (_) => onHoldEnd!(),
          onLongPressCancel: onHoldEnd,
          child: AnimatedOpacity(
            opacity: event.id == dimmedEventId ? 0.35 : 1,
            duration: const Duration(milliseconds: 160),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: eventColor(event, OwnEventColor.of(context)),
                borderRadius: radius,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky titles for the events in view, in the list's scroll coordinates
/// shifted by [scrollOffset].
class DayTitleOverlay extends StatelessWidget {
  const DayTitleOverlay({
    required this.events,
    required this.lanes,
    required this.scrollOffset,
    required this.pixelsPerHour,
    required this.viewportWidth,
    this.hiddenEventId,
    this.dimmedEventId,
    super.key,
  });

  final List<CalendarEvent> events;
  final Map<String, int> lanes;
  final double scrollOffset;
  final double pixelsPerHour;
  final double viewportWidth;
  final String? hiddenEventId;
  final String? dimmedEventId;

  @override
  Widget build(BuildContext context) {
    final own = OwnEventColor.of(context);
    final children = <Widget>[];
    for (final event in events) {
      if (event.id == hiddenEventId) continue;
      final span = timelineSpan(event);
      final left = timelineX(span.start, pixelsPerHour) - scrollOffset;
      final right = timelineX(span.end, pixelsPerHour) - scrollOffset;
      if (right <= 0 || left >= viewportWidth) continue;
      final title = eventDisplayTitle(event);
      final dates = eventSpansDays(event) ? eventDatesLabel(event) : null;
      final x = stickyTitleX(
        eventLeft: left,
        eventRight: right,
        viewportLeft: 0,
        titleWidth:
            _titleWidth(title, timelineTitleStyle) +
            (dates == null
                ? 0
                : _datesGap + _titleWidth(dates, timelineDatesStyle)),
        padding: timelineTitlePadding,
      );
      if (x == null) continue;
      final width = right - timelineTitlePadding - x;
      if (width <= 4) continue;
      children.add(
        Positioned(
          key: ValueKey(event.id),
          left: x,
          width: width,
          top: timelineLaneTop(lanes[event.id] ?? 0),
          height: timelineEventHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedOpacity(
              opacity: event.id == dimmedEventId ? 0.35 : 1,
              duration: const Duration(milliseconds: 160),
              child: Text.rich(
                TextSpan(
                  text: title,
                  children: [
                    if (dates != null)
                      TextSpan(text: '\u2002$dates', style: timelineDatesStyle),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: timelineTitleStyle.copyWith(
                  color: eventInk(eventColor(event, own)),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(child: Stack(children: children));
  }
}

/// X of [time] on the timeline, in list coordinates.
double timelineX(DateTime time, double pixelsPerHour) {
  final dayIndex = calendarDaysBetween(dayTimelineOrigin, time);
  final hours = time.hour + time.minute / 60.0 + time.second / 3600.0;
  return (dayIndex * 24 + hours) * pixelsPerHour;
}

/// Day zero of the timeline list.
final dayTimelineOrigin = DateTime(1970, 1, 1);

/// Dates after a multi-day event's title: dark on the event colour.
const timelineDatesStyle = TextStyle(
  color: Color(0x99000000),
  fontSize: 15,
  fontWeight: FontWeight.w600,
  height: 1.1,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// An en space, as in the rich title.
const _datesGap = 10.0;

final _titleWidths = <(String, TextStyle), double>{};

double _titleWidth(String text, TextStyle style) {
  return _titleWidths.putIfAbsent((text, style), () {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  });
}
