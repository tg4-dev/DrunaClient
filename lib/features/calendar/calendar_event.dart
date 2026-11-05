import 'dart:math' as math;

import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/oklab.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';

const calendarMinuteStep = 15;

class OwnEventColor extends InheritedWidget {
  const OwnEventColor({required this.color, required super.child, super.key});

  final Color color;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwnEventColor>()?.color ??
      defaultOwnColor;

  @override
  bool updateShouldNotify(OwnEventColor oldWidget) => oldWidget.color != color;
}

Color eventColor(CalendarEvent event, Color own) => event.color ?? own;

Color eventInk(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

@immutable
class GridTone {
  const GridTone({required this.fill, required this.ink});

  final Color fill;

  final Color ink;
}

const gridFillLightness = 0.30;
const gridFillChroma = 0.5;
const gridInkLightnessMin = 0.72;
const gridInkLightnessMax = 0.85;

final _gridTones = <Color, GridTone>{};

GridTone gridTone(Color color) => _gridTones.putIfAbsent(color, () {
  final (l, a, b) = oklab(color);
  final chroma = math.sqrt(a * a + b * b);
  final hue = math.atan2(b, a);
  Color at(double lightness, double c) {
    var fit = c;
    for (var i = 0; i < 24; i++) {
      final lab = (lightness, fit * math.cos(hue), fit * math.sin(hue));
      if (inSrgbGamut(lab)) return fromOklab(lab);
      fit *= 0.9;
    }
    return fromOklab((lightness, 0, 0));
  }

  return GridTone(
    fill: at(gridFillLightness, chroma * gridFillChroma),
    ink: at(l.clamp(gridInkLightnessMin, gridInkLightnessMax), chroma),
  );
});

Color mixedColor(List<Color> colors) {
  if (colors.isEmpty) return defaultOwnColor;
  var r = 0.0, g = 0.0, b = 0.0;
  for (final color in colors) {
    r += color.r;
    g += color.g;
    b += color.b;
  }
  final n = colors.length;
  return Color.from(alpha: 1, red: r / n, green: g / n, blue: b / n);
}

BoxDecoration liftedEventDecoration(
  BorderRadius radius, {
  Color color = defaultOwnColor,
  List<Color>? colors,
}) {
  final gradient = colors != null && colors.length > 1 ? colors : null;
  final base = gradient == null ? color : mixedColor(gradient);
  return BoxDecoration(
    color: gradient == null ? base : null,
    gradient: gradient == null ? null : LinearGradient(colors: gradient),
    borderRadius: radius,
    border: Border.all(
      color: Color.lerp(base, Colors.white, 0.28)!,
      width: 1.5,
    ),
  );
}

@immutable
class EventInvite {
  const EventInvite({
    required this.id,
    required this.colors,
    this.people = const [],
    this.pending = false,
    this.mine = false,
  });

  final String id;

  final List<Color> colors;

  final List<FriendInfo> people;

  final bool pending;

  final bool mine;
}

class DashedRimPainter extends CustomPainter {
  const DashedRimPainter({
    required this.color,
    required this.radius,
    this.dash = 4,
    this.gap = 3,
    this.width = 1.5,
    this.inset,
  });

  final Color color;
  final double radius;
  final double dash;
  final double gap;
  final double width;

  final EdgeInsets? inset;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || color.a <= 0) return;
    final rect = (inset ?? EdgeInsets.all(width / 2)).deflateRect(
      Offset.zero & size,
    );
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(radius.clamp(0, rect.shortestSide / 2).toDouble()),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width;
    for (final metric in path.computeMetrics()) {
      final count = (metric.length / (dash + gap)).floor().clamp(1, 1 << 20);
      final step = metric.length / count;
      for (var i = 0; i < count; i++) {
        final from = i * step;
        canvas.drawPath(metric.extractPath(from, from + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedRimPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.dash != dash ||
      old.gap != gap ||
      old.width != width ||
      old.inset != inset;
}

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
    this.invite,
    this.external,
  });

  final String id;
  final String title;
  final DateTime start;

  final DateTime end;
  final bool allDay;
  final RepeatRule? repeat;

  final String? seriesId;

  final Color? color;

  final int? ownerId;

  final EventInvite? invite;

  final ExternalEvent? external;

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
    EventInvite? invite,
    ExternalEvent? external,
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
      invite: invite ?? this.invite,
      external: external ?? this.external,
    );
  }
}

@immutable
class ExternalEvent {
  const ExternalEvent({
    required this.instanceId,
    required this.calendarId,
    required this.calendarName,
  });

  final String instanceId;
  final String calendarId;

  final String calendarName;
}

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

List<CalendarEvent> mergeBusyByDay(List<CalendarEvent> events) {
  final byOwner = <int?, List<CalendarEvent>>{};
  for (final event in events) {
    byOwner.putIfAbsent(event.ownerId, () => []).add(event);
  }
  final merged = <CalendarEvent>[];
  for (final own in byOwner.values) {
    own.sort((a, b) => eventFirstDay(a).compareTo(eventFirstDay(b)));
    var group = <CalendarEvent>[];
    var last = DateTime(0);
    void flush() {
      if (group.isNotEmpty) merged.add(_sumOf(group));
      group = [];
    }

    for (final event in own) {
      if (group.isNotEmpty && eventFirstDay(event).isAfter(last)) flush();
      group.add(event);
      final end = eventLastDay(event);
      if (group.length == 1 || end.isAfter(last)) last = end;
    }
    flush();
  }
  return merged;
}

CalendarEvent _sumOf(List<CalendarEvent> group) {
  if (group.length == 1) return group.single;
  final first = group
      .map(eventFirstDay)
      .reduce((a, b) => a.isBefore(b) ? a : b);
  final last = group.map(eventLastDay).reduce((a, b) => a.isAfter(b) ? a : b);
  final id =
      'busy-${group.first.ownerId}-${first.year}-${first.month}-${first.day}';
  if (sameDay(first, last) && group.every((event) => !event.allDay)) {
    return group.first.copyWith(
      id: id,
      start: group
          .map((event) => event.start)
          .reduce((a, b) => a.isBefore(b) ? a : b),
      end: group
          .map((event) => event.end)
          .reduce((a, b) => a.isAfter(b) ? a : b),
    );
  }
  return group.first.copyWith(id: id, start: first, end: last, allDay: true);
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

bool eventSpansDays(CalendarEvent event) =>
    !sameDay(eventFirstDay(event), eventLastDay(event));

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

DateTime nearestQuarter(DateTime time) {
  final total = time.hour * 60 + time.minute;
  final remainder = total % calendarMinuteStep;
  var rounded = total - remainder;
  if (remainder >= 8) rounded += calendarMinuteStep;
  if (rounded >= 24 * 60) rounded = 23 * 60 + 45;
  return atClock(time, rounded ~/ 60, rounded % 60);
}

DateTime atClock(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

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

CalendarEvent shiftEventDays(CalendarEvent event, int days) {
  if (days == 0) return event;
  return event.copyWith(
    start: _shift(event.start, days),
    end: _shift(event.end, days),
  );
}

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

  final memo = <Object, Object>{};

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
      invite: event.invite,
      external: event.external,
    );
  }
}

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
