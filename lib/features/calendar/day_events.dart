import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

const timelineEventTop = 36.0;

const timelineEventHeight = 48.0;
const timelineEventGap = 8.0;
const timelineTitlePadding = 12.0;
const timelineEventRadius = Radius.circular(16);

const timelineTitleStyle = TextStyle(
  fontFamily: 'Onest',
  fontVariations: [FontVariation('wght', 600)],
  color: Colors.white,
  fontSize: 17,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

double timelineLaneTop(int lane) =>
    timelineEventTop + lane * (timelineEventHeight + timelineEventGap);

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
    this.motion,
    super.key,
  });

  final DateTime day;
  final double pixelsPerHour;
  final List<CalendarEvent> events;
  final Map<String, int> lanes;
  final String? hiddenEventId;

  final String? dimmedEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  final void Function(CalendarEvent event, Offset global)? onHoldStart;
  final ValueChanged<Offset>? onHoldMove;
  final VoidCallback? onHoldEnd;

  final LaneMotion? motion;

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
          child: _moving(
            lanes[event.id] ?? 0,
            AnimatedOpacity(
              opacity: event.id == dimmedEventId ? 0.35 : 1,
              duration: const Duration(milliseconds: 160),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: gridTone(
                    eventColor(event, OwnEventColor.of(context)),
                  ).fill,
                  borderRadius: radius,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _moving(int lane, Widget child) {
    final motion = this.motion;
    return motion == null ? child : motion(lane, child);
  }
}

typedef LaneMotion = Widget Function(int lane, Widget child);

class DayTitleOverlay extends StatelessWidget {
  const DayTitleOverlay({
    required this.events,
    required this.lanes,
    required this.scrollOffset,
    required this.pixelsPerHour,
    required this.viewportWidth,
    this.hiddenEventId,
    this.dimmedEventId,
    this.motion,
    this.leftInset = 0,
    super.key,
  });

  final List<CalendarEvent> events;
  final Map<String, int> lanes;
  final double scrollOffset;
  final double pixelsPerHour;
  final double viewportWidth;
  final String? hiddenEventId;
  final String? dimmedEventId;

  final LaneMotion? motion;

  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final own = OwnEventColor.of(context);
    final children = <Widget>[];
    for (final event in events) {
      if (event.id == hiddenEventId) continue;
      final span = timelineSpan(event);
      final left = timelineX(span.start, pixelsPerHour) - scrollOffset;
      final right = timelineX(span.end, pixelsPerHour) - scrollOffset;
      if (right <= leftInset || left >= viewportWidth) continue;
      final title = eventDisplayTitle(event);
      final dates = eventSpansDays(event) ? eventDatesLabel(event) : null;
      final x = stickyTitleX(
        eventLeft: left,
        eventRight: right,
        viewportLeft: leftInset,
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
          child: _moving(
            lanes[event.id] ?? 0,
            AnimatedOpacity(
              opacity: event.id == dimmedEventId ? 0.35 : 1,
              duration: const Duration(milliseconds: 160),
              child: _FadingTitle(
                title: title,
                dates: dates,
                tone: gridTone(eventColor(event, own)),
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(child: Stack(children: children));
  }

  Widget _moving(int lane, Widget child) {
    final motion = this.motion;
    return motion == null ? child : motion(lane, child);
  }
}

class _FadingTitle extends StatelessWidget {
  const _FadingTitle({
    required this.title,
    required this.dates,
    required this.tone,
  });

  final String title;
  final String? dates;
  final GridTone tone;

  static const _fade = 16.0;

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      fit: StackFit.expand,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                if (dates != null)
                  TextSpan(
                    text: '\u2002$dates',
                    style: timelineDatesStyle.copyWith(
                      color: tone.ink.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.clip,
            style: timelineTitleStyle.copyWith(color: tone.ink),
          ),
        ),
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          width: _fade,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tone.fill.withValues(alpha: 0), tone.fill],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

double timelineX(DateTime time, double pixelsPerHour) {
  final dayIndex = calendarDaysBetween(dayTimelineOrigin, time);
  final hours = time.hour + time.minute / 60.0 + time.second / 3600.0;
  return (dayIndex * 24 + hours) * pixelsPerHour;
}

final dayTimelineOrigin = DateTime(1970, 1, 1);

const timelineDatesStyle = TextStyle(
  fontFamily: 'Onest',
  fontVariations: [FontVariation('wght', 600)],
  color: Color(0x99000000),
  fontSize: 13,
  fontWeight: FontWeight.w600,
  height: 1.1,
  fontFeatures: [FontFeature.tabularFigures()],
);

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
