import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';

/// The user's events before their profile (and so their colour) is known.
const calendarEventColor = Color(0xFF9A3040);
const calendarMinuteStep = 15;

/// The colour of the user's own events: the colour of their avatar, so they
/// look the same to themselves as to their friends.
class OwnEventColor extends InheritedWidget {
  const OwnEventColor({required this.color, required super.child, super.key});

  final Color color;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwnEventColor>()?.color ??
      calendarEventColor;

  @override
  bool updateShouldNotify(OwnEventColor oldWidget) => oldWidget.color != color;
}

/// A friend's event keeps the friend's colour; the user's take [own].
Color eventColor(CalendarEvent event, Color own) => event.color ?? own;

/// Text on an event: white on dark colours, black on light ones.
Color eventInk(Color background) => avatarInkFor(background);

/// An event picked up or being drawn: a soft glow in its own colour and an
/// edge a shade lighter, instead of a foreign outline.
BoxDecoration liftedEventDecoration(
  BorderRadius radius, {
  Color color = calendarEventColor,
}) {
  return BoxDecoration(
    color: color,
    borderRadius: radius,
    border: Border.all(
      color: Color.lerp(color, Colors.white, 0.28)!,
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: color.withValues(alpha: 0.55),
        blurRadius: 18,
        spreadRadius: 1,
      ),
    ],
  );
}

/// Shortest timed event; a shorter or inverted span grows to this.
const minimumEventLength = Duration(minutes: calendarMinuteStep);

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.repeat,
    this.seriesId,
    this.color,
    this.ownerId,
  });

  final String id;
  final String title;
  final DateTime start;

  /// Exclusive for timed events. For all-day events this is the last day,
  /// inclusive, so a one-day event has `start == end`.
  final DateTime end;
  final bool allDay;
  final RepeatRule? repeat;

  /// Set on generated occurrences: the id of the event that holds the rule.
  final String? seriesId;

  /// A friend's colour; the user's own events leave it null.
  final Color? color;

  /// The friend this event belongs to; null for the user's own events.
  final int? ownerId;

  String get sourceId => seriesId ?? id;

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    RepeatRule? repeat,
    bool clearRepeat = false,
    String? seriesId,
    bool clearSeries = false,
    Color? color,
    int? ownerId,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
      repeat: clearRepeat ? null : repeat ?? this.repeat,
      seriesId: clearSeries ? null : seriesId ?? this.seriesId,
      color: color ?? this.color,
      ownerId: ownerId ?? this.ownerId,
    );
  }
}

/// Repairs spans no screen can draw: a timed end at or before its start, and
/// an all-day end before its first day.
CalendarEvent normalizeEvent(CalendarEvent event) {
  if (event.allDay) {
    final first = dateOnly(event.start);
    final last = dateOnly(event.end);
    if (!last.isBefore(first) && event.start == first && event.end == last) {
      return event;
    }
    return event.copyWith(
      start: first,
      end: last.isBefore(first) ? first : last,
    );
  }
  if (event.end.isAfter(event.start)) return event;
  return event.copyWith(end: event.start.add(minimumEventLength));
}

DateTime eventFirstDay(CalendarEvent event) => dateOnly(event.start);

DateTime eventLastDay(CalendarEvent event) {
  if (event.allDay) return dateOnly(event.end);
  final end = event.end;
  final atMidnight =
      end.hour == 0 &&
      end.minute == 0 &&
      end.second == 0 &&
      end.millisecond == 0 &&
      end.microsecond == 0;
  if (atMidnight && !sameDay(event.start, end)) {
    return addCalendarDays(end, -1);
  }
  return dateOnly(end);
}

bool eventIsBar(CalendarEvent event) =>
    event.allDay || !sameDay(eventFirstDay(event), eventLastDay(event));

bool eventOccursOn(CalendarEvent event, DateTime day) {
  final date = dateOnly(day);
  return !date.isBefore(eventFirstDay(event)) &&
      !date.isAfter(eventLastDay(event));
}

/// The event covers more than one day.
bool eventSpansDays(CalendarEvent event) =>
    !sameDay(eventFirstDay(event), eventLastDay(event));

/// "24.10-25.10": first and last day of the event.
String eventDatesLabel(CalendarEvent event) {
  String date(DateTime day) =>
      '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
  return '${date(eventFirstDay(event))}-${date(eventLastDay(event))}';
}

String eventDisplayTitle(CalendarEvent event) {
  final title = event.title.trim();
  return title.isEmpty ? 'Название' : title;
}

String eventDateLabel(DateTime day) {
  final date = dateOnly(day);
  return '${weekdayShort(date)}, ${date.day} ${monthShort(date).toLowerCase()}';
}

String clockLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String clockRangeLabel(DateTime start, DateTime end) =>
    '${clockLabel(start)}-${clockLabel(end)}';

/// "4 часа", "30 минут", "1 ч 30 мин".
String durationLabel(DateTime start, DateTime end) {
  var minutes = end.difference(start).inMinutes;
  if (minutes < 0) minutes = 0;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) {
    return '$rest ${russianPlural(rest, 'минута', 'минуты', 'минут')}';
  }
  if (rest == 0) {
    return '$hours ${russianPlural(hours, 'час', 'часа', 'часов')}';
  }
  return '$hours ч $rest мин';
}

/// [time] rounded to the nearest quarter hour, kept on its own day.
DateTime nearestQuarter(DateTime time) {
  final total = time.hour * 60 + time.minute;
  final remainder = total % calendarMinuteStep;
  var rounded = total - remainder;
  if (remainder >= 8) rounded += calendarMinuteStep;
  if (rounded >= 24 * 60) rounded = 23 * 60 + 45;
  return atClock(time, rounded ~/ 60, rounded % 60);
}

/// [day]'s date at [hour]:[minute] local time.
DateTime atClock(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

/// One hour from the nearest quarter of [now], or 22:00–23:00 when that runs
/// past the day.
({DateTime start, DateTime end}) defaultEventSpan(DateTime day, DateTime now) {
  final quarter = nearestQuarter(now);
  final minutes = quarter.hour * 60 + quarter.minute;
  if (minutes + 60 <= 23 * 60 + 45) {
    final start = atClock(day, quarter.hour, quarter.minute);
    return (start: start, end: start.add(const Duration(hours: 1)));
  }
  return (start: atClock(day, 22, 0), end: atClock(day, 23, 0));
}

CalendarEvent createEventOnDay({
  required String id,
  required DateTime day,
  required DateTime now,
}) {
  final span = defaultEventSpan(dateOnly(day), now);
  return CalendarEvent(id: id, title: '', start: span.start, end: span.end);
}

/// Moves the event so it starts on [day], keeping times and its length in days.
CalendarEvent moveEventToDay(CalendarEvent event, DateTime day) =>
    shiftEventDays(event, calendarDaysBetween(eventFirstDay(event), day));

/// Shifts the event by whole days. A repeat's end date is a date the user
/// picked, so it stays where it is.
CalendarEvent shiftEventDays(CalendarEvent event, int days) {
  if (days == 0) return event;
  return event.copyWith(
    start: _shift(event.start, days),
    end: _shift(event.end, days),
  );
}

/// Moves a timed event by [shift], keeping its length. All-day events move by
/// whole days, the days [shift] crosses.
CalendarEvent shiftEventBy(CalendarEvent event, Duration shift) {
  if (shift == Duration.zero) return event;
  if (event.allDay) {
    return shiftEventDays(
      event,
      calendarDaysBetween(event.start, event.start.add(shift)),
    );
  }
  return event.copyWith(
    start: event.start.add(shift),
    end: event.end.add(shift),
  );
}

/// A new start time keeps the event's length.
({DateTime start, DateTime end}) withStartClock(
  DateTime start,
  DateTime end,
  int hour,
  int minute,
) {
  final next = atClock(start, hour, minute);
  final length = end.isAfter(start)
      ? end.difference(start)
      : minimumEventLength;
  return (start: next, end: next.add(length));
}

/// A new end time lands on the start's day, or the next day when it is not
/// after the start, so 22:00 → 02:00 becomes an overnight event.
({DateTime start, DateTime end}) withEndClock(
  DateTime start,
  DateTime end,
  int hour,
  int minute,
) {
  var next = atClock(start, hour, minute);
  if (!next.isAfter(start)) {
    final tomorrow = addCalendarDays(start, 1);
    next = atClock(tomorrow, hour, minute);
  }
  return (start: start, end: next);
}

/// Applies the sheet's fields to [event]. Timed drafts carry full dates, so an
/// overnight or multi-day event keeps its days.
CalendarEvent applyEventDraft({
  required CalendarEvent event,
  required String title,
  required bool allDay,
  required DateTime start,
  required DateTime end,
  RepeatRule? repeat,
}) {
  final trimmed = title.trim();
  if (allDay) {
    // An all-day event keeps its days; a timed one takes the draft's days.
    final days = event.allDay ? event : event.copyWith(start: start, end: end);
    final first = eventFirstDay(days);
    final last = eventLastDay(days);
    return normalizeEvent(
      event.copyWith(
        title: trimmed,
        allDay: true,
        start: first,
        end: last,
        repeat: repeat,
        clearRepeat: repeat == null,
      ),
    );
  }
  return normalizeEvent(
    event.copyWith(
      title: trimmed,
      allDay: false,
      start: start,
      end: end,
      repeat: repeat,
      clearRepeat: repeat == null,
    ),
  );
}

/// Events by week and day, with repeating series unrolled and every span
/// normalised. Build one per change of the event list; lookups are cached.
class CalendarEventIndex {
  CalendarEventIndex(List<CalendarEvent> events)
    : events = [for (final event in events) normalizeEvent(event)] {
    for (final event in this.events) {
      _byId[event.id] = event;
    }
  }

  static final empty = CalendarEventIndex(const []);

  final List<CalendarEvent> events;
  final _byId = <String, CalendarEvent>{};
  final _weeks = <int, List<CalendarEvent>>{};
  final _days = <DateTime, List<CalendarEvent>>{};
  final _dayLanes = <DateTime, Map<String, int>>{};
  final _lanes = <String, int>{};

  /// Per-index memo for derived layouts; dropped with the index.
  final memo = <Object, Object>{};

  /// The stored event behind [id], for an occurrence too.
  CalendarEvent? source(String id) {
    final direct = _byId[id];
    if (direct != null) return direct;
    final at = id.indexOf('@');
    return at < 0 ? null : _byId[id.substring(0, at)];
  }

  List<CalendarEvent> forWeek(int weekIndex) {
    return _weeks.putIfAbsent(weekIndex, () {
      final monday = mondayOfWeek(weekIndex);
      return between(monday, addCalendarDays(monday, 6));
    });
  }

  /// Every event or occurrence touching [first]…[last], inclusive.
  List<CalendarEvent> between(DateTime first, DateTime last) {
    final from = dateOnly(first);
    final to = dateOnly(last);
    final result = <CalendarEvent>[];
    for (final event in events) {
      final rule = event.repeat;
      final firstDay = eventFirstDay(event);
      final span = calendarDaysBetween(firstDay, eventLastDay(event));
      if (rule == null) {
        if (!eventLastDay(event).isBefore(from) && !firstDay.isAfter(to)) {
          result.add(event);
        }
        continue;
      }
      for (final day in repeatDaysBetween(
        rule: rule,
        first: firstDay,
        from: addCalendarDays(from, -span),
        to: to,
      )) {
        result.add(_occurrence(event, day));
      }
    }
    return result;
  }

  List<CalendarEvent> onDay(DateTime day) {
    final date = dateOnly(day);
    return _days.putIfAbsent(date, () => between(date, date));
  }

  /// Timeline row for each event touching [day]. Rows come from whole chains of
  /// overlapping events, so an overnight event keeps its row past midnight.
  Map<String, int> lanesAround(DateTime day) {
    final date = dateOnly(day);
    return _dayLanes.putIfAbsent(date, () => _lanesAround(date));
  }

  Map<String, int> _lanesAround(DateTime date) {
    var reach = 1;
    while (true) {
      final first = addCalendarDays(date, -reach);
      final windowEnd = addCalendarDays(date, reach + 1);
      final mine = [
        for (final cluster in _clusters(
          between(first, addCalendarDays(date, reach)),
        ))
          if (cluster.touches(date)) cluster,
      ];
      final clipped = mine.any(
        (cluster) =>
            !cluster.start.isAfter(first) || !cluster.end.isBefore(windowEnd),
      );
      if (clipped && reach < _laneReachLimit) {
        reach *= 2;
        continue;
      }
      return {
        for (final cluster in mine)
          for (final entry in cluster.lanes.entries)
            entry.key: _lanes.putIfAbsent(entry.key, () => entry.value),
      };
    }
  }

  CalendarEvent _occurrence(CalendarEvent event, DateTime day) {
    final shift = calendarDaysBetween(eventFirstDay(event), day);
    if (shift == 0) return event;
    return CalendarEvent(
      id: '${event.id}@${day.year}-${day.month}-${day.day}',
      title: event.title,
      start: _shift(event.start, shift),
      end: _shift(event.end, shift),
      allDay: event.allDay,
      repeat: event.repeat,
      seriesId: event.id,
      color: event.color,
      ownerId: event.ownerId,
    );
  }
}

/// Days searched each way for the end of an overlap chain.
const _laneReachLimit = 32;

class _Cluster {
  _Cluster(this.start, this.end, this.lanes);

  final DateTime start;
  final DateTime end;
  final Map<String, int> lanes;

  bool touches(DateTime day) {
    final dayEnd = addCalendarDays(day, 1);
    return start.isBefore(dayEnd) && end.isAfter(day);
  }
}

/// Instants the event covers on the timeline; all-day events fill their days.
({DateTime start, DateTime end}) timelineSpan(CalendarEvent event) {
  if (!event.allDay) return (start: event.start, end: event.end);
  return (
    start: eventFirstDay(event),
    end: addCalendarDays(eventLastDay(event), 1),
  );
}

List<_Cluster> _clusters(List<CalendarEvent> events) {
  final spans =
      [for (final event in events) (event: event, span: timelineSpan(event))]
        ..sort((a, b) {
          final byStart = a.span.start.compareTo(b.span.start);
          if (byStart != 0) return byStart;
          final byEnd = a.span.end.compareTo(b.span.end);
          if (byEnd != 0) return byEnd;
          return a.event.id.compareTo(b.event.id);
        });
  final clusters = <_Cluster>[];
  var index = 0;
  while (index < spans.length) {
    final start = spans[index].span.start;
    var end = spans[index].span.end;
    final laneEnds = <DateTime>[];
    final lanes = <String, int>{};
    while (index < spans.length &&
        (lanes.isEmpty || spans[index].span.start.isBefore(end))) {
      final item = spans[index];
      var lane = 0;
      while (lane < laneEnds.length &&
          laneEnds[lane].isAfter(item.span.start)) {
        lane++;
      }
      if (lane == laneEnds.length) {
        laneEnds.add(item.span.end);
      } else {
        laneEnds[lane] = item.span.end;
      }
      lanes[item.event.id] = lane;
      if (item.span.end.isAfter(end)) end = item.span.end;
      index++;
    }
    clusters.add(_Cluster(start, end, lanes));
  }
  return clusters;
}

List<CalendarEvent> demoCalendarEvents(DateTime today) {
  final day = dateOnly(today);
  DateTime at(int offset, int hour, int minute) {
    final date = addCalendarDays(day, offset);
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  return [
    CalendarEvent(
      id: 'demo-druna',
      title: 'Друна',
      start: at(0, 10, 0),
      end: at(0, 13, 0),
    ),
    CalendarEvent(
      id: 'demo-baseball',
      title: 'Бейсбол',
      start: at(0, 11, 0),
      end: at(0, 13, 30),
    ),
    CalendarEvent(
      id: 'demo-lunch',
      title: 'Обед',
      start: at(1, 13, 0),
      end: at(1, 14, 0),
    ),
    CalendarEvent(
      id: 'demo-meet',
      title: 'Встреча',
      start: at(1, 16, 0),
      end: at(1, 17, 30),
    ),
    for (var index = 0; index < 6; index++)
      CalendarEvent(
        id: 'demo-crowd-$index',
        title: 'Дело ${index + 1}',
        start: at(2, 9 + index, 0),
        end: at(2, 10 + index, 0),
      ),
    CalendarEvent(
      id: 'demo-trip',
      title: 'Поездка',
      allDay: true,
      start: addCalendarDays(day, 3),
      end: addCalendarDays(day, 6),
    ),
  ];
}

DateTime _shift(DateTime value, int days) {
  final date = addCalendarDays(value, days);
  return DateTime(
    date.year,
    date.month,
    date.day,
    value.hour,
    value.minute,
    value.second,
  );
}
