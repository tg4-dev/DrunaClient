import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

const calendarEventColor = Color(0xFF9A3040);
const calendarMinuteStep = 15;

class ClockTime {
  const ClockTime(this.hour, this.minute);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  @override
  bool operator ==(Object other) =>
      other is ClockTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => clockLabel(this);
}

class ResolvedClock {
  const ResolvedClock(this.start, this.end);

  final ClockTime start;
  final ClockTime end;
}

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
  });

  final String id;
  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  CalendarEvent copyWith({
    String? id,
    String? title,
    DateTime? start,
    DateTime? end,
    bool? allDay,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      start: start ?? this.start,
      end: end ?? this.end,
      allDay: allDay ?? this.allDay,
    );
  }
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

String eventDisplayTitle(CalendarEvent event) {
  final title = event.title.trim();
  return title.isEmpty ? 'Название' : title;
}

String eventDateLabel(DateTime day) {
  final date = dateOnly(day);
  return '${weekdayShort(date)}, ${date.day} ${monthShort(date).toLowerCase()}';
}

String clockLabel(ClockTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

String clockRangeLabel(ClockTime start, ClockTime end) =>
    '${clockLabel(start)}–${clockLabel(end)}';

String durationLabel(ClockTime start, ClockTime end) {
  var minutes = end.minutes - start.minutes;
  if (minutes < 0) minutes = 0;
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest мин.';
  if (rest == 0) return '$hoursч.';
  return '$hoursч. $rest мин.';
}

/// Keeps the end from landing before the start on the same day.
///
/// When the end is earlier, the start moves to exactly one hour before it.
/// If that hour would fall on the previous day, both clocks become 00:00–01:00.
ResolvedClock resolveClock(ClockTime start, ClockTime end) {
  if (end.minutes >= start.minutes) return ResolvedClock(start, end);
  final adjusted = end.minutes - 60;
  if (adjusted < 0) {
    return const ResolvedClock(ClockTime(0, 0), ClockTime(1, 0));
  }
  return ResolvedClock(ClockTime(adjusted ~/ 60, adjusted % 60), end);
}

ClockTime nearestQuarter(DateTime time) {
  final total = time.hour * 60 + time.minute;
  final remainder = total % calendarMinuteStep;
  var rounded = total - remainder;
  if (remainder >= 8) rounded += calendarMinuteStep;
  if (rounded >= 24 * 60) rounded = 23 * 60 + 45;
  return ClockTime(rounded ~/ 60, rounded % 60);
}

({ClockTime start, ClockTime end}) defaultEventClock(DateTime now) {
  final start = nearestQuarter(now);
  final endMinutes = start.minutes + 60;
  if (endMinutes <= 23 * 60 + 45) {
    return (start: start, end: ClockTime(endMinutes ~/ 60, endMinutes % 60));
  }
  return (start: const ClockTime(22, 0), end: const ClockTime(23, 0));
}

CalendarEvent createEventOnDay({
  required String id,
  required DateTime day,
  required DateTime now,
}) {
  final clock = defaultEventClock(now);
  final date = dateOnly(day);
  return CalendarEvent(
    id: id,
    title: '',
    start: DateTime(
      date.year,
      date.month,
      date.day,
      clock.start.hour,
      clock.start.minute,
    ),
    end: DateTime(
      date.year,
      date.month,
      date.day,
      clock.end.hour,
      clock.end.minute,
    ),
  );
}

CalendarEvent moveEventToDay(CalendarEvent event, DateTime day) {
  final delta = calendarDaysBetween(eventFirstDay(event), dateOnly(day));
  if (delta == 0) return event;
  return event.copyWith(
    start: _shift(event.start, delta),
    end: _shift(event.end, delta),
  );
}

CalendarEvent applyEventDraft({
  required CalendarEvent event,
  required String title,
  required bool allDay,
  required ClockTime start,
  required ClockTime end,
}) {
  final trimmed = title.trim();
  if (allDay) {
    if (event.allDay) return event.copyWith(title: trimmed);
    final day = eventFirstDay(event);
    return event.copyWith(title: trimmed, allDay: true, start: day, end: day);
  }
  final resolved = resolveClock(start, end);
  final day = eventFirstDay(event);
  return event.copyWith(
    title: trimmed,
    allDay: false,
    start: DateTime(
      day.year,
      day.month,
      day.day,
      resolved.start.hour,
      resolved.start.minute,
    ),
    end: DateTime(
      day.year,
      day.month,
      day.day,
      resolved.end.hour,
      resolved.end.minute,
    ),
  );
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
