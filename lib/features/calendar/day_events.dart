import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

const timelineEventTop = 36.0;

/// As tall as an avatar of the friends' column (48): the user's bars and
/// friends' rows read as one scale.
const timelineEventHeight = 48.0;
const timelineEventGap = 8.0;
const timelineTitlePadding = 12.0;
const timelineEventRadius = Radius.circular(16);

/// `bodyStrong` (design-system §3): smaller than the 20 pt of the taller
/// bars.
const timelineTitleStyle = TextStyle(
  color: Colors.white,
  fontSize: 17,
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
    this.motion,
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

  /// Moves a bar in [lane] with the calendar's mode (see [ChipMotion]).
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
              child: _rimmed(
                event,
                OwnEventColor.of(context),
                DecoratedBox(
                  // Apple Calendar's dark look, as in the month: a deep
                  // fill, the title in the light tone ([DayTitleOverlay]).
                  decoration: event.invite == null
                      ? BoxDecoration(
                          color: gridTone(
                            eventColor(event, OwnEventColor.of(context)),
                          ).fill,
                          borderRadius: radius,
                        )
                      : eventFill(
                          event,
                          OwnEventColor.of(context),
                          radius: radius,
                        ),
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

  /// An invite the user has not answered gets a dashed edge.
  Widget _rimmed(CalendarEvent event, Color own, Widget child) {
    final invite = event.invite;
    if (invite == null || !invite.pending) return child;
    return PendingInviteRim(
      color: eventColor(event, own),
      radius: timelineEventRadius.x,
      child: child,
    );
  }
}

/// Wraps a bar or a title in [lane] in its motion.
typedef LaneMotion = Widget Function(int lane, Widget child);

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

  /// Moves a title together with its bar ([DayEventLayer.motion]).
  final LaneMotion? motion;

  /// The friends column covers this much of the left edge: titles stick
  /// to its edge instead of going under it.
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
                tone: event.invite == null
                    ? gridTone(eventColor(event, own))
                    : GridTone(
                        fill: eventColor(event, own),
                        ink: eventInkFor(event, own),
                      ),
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

/// A bar's title in the light tone of its colour, the dates after it a
/// little dimmer; cut and faded into the bar's fill at its end, as in the
/// month, instead of an ellipsis.
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

/// X of [time] on the timeline, in list coordinates.
double timelineX(DateTime time, double pixelsPerHour) {
  final dayIndex = calendarDaysBetween(dayTimelineOrigin, time);
  final hours = time.hour + time.minute / 60.0 + time.second / 3600.0;
  return (dayIndex * 24 + hours) * pixelsPerHour;
}

/// Day zero of the timeline list.
final dayTimelineOrigin = DateTime(1970, 1, 1);

/// Dates after a multi-day event's title; [_FadingTitle] colours them.
const timelineDatesStyle = TextStyle(
  color: Color(0x99000000),
  fontSize: 13,
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
