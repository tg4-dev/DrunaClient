import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/event_page/event_labels.dart';
import 'package:flutter/foundation.dart';

/// When an event runs, as the event page edits it: a first and a last day
/// (both included) and, for timed events, the minutes of day it starts and
/// ends at. The clocks are kept while "Весь день" is on, so turning it off
/// brings the times back.
@immutable
class EventSpan {
  const EventSpan({
    required this.firstDay,
    required this.lastDay,
    required this.startMinute,
    required this.endMinute,
    required this.allDay,
  });

  /// An all-day event gets [defaultEventSpan]'s clocks for when it turns
  /// timed.
  factory EventSpan.of(CalendarEvent event, {DateTime? now}) {
    if (event.allDay) {
      final first = eventFirstDay(event);
      final clocks = defaultEventSpan(first, now ?? DateTime.now());
      return EventSpan(
        firstDay: first,
        lastDay: eventLastDay(event),
        startMinute: _minuteOf(clocks.start),
        endMinute: _minuteOf(clocks.end),
        allDay: true,
      );
    }
    return EventSpan.timed(event.start, event.end);
  }

  factory EventSpan.timed(DateTime start, DateTime end, {bool allDay = false}) {
    return EventSpan(
      firstDay: dateOnly(start),
      lastDay: dateOnly(end),
      startMinute: _minuteOf(start),
      endMinute: _minuteOf(end),
      allDay: allDay,
    )._normal();
  }

  final DateTime firstDay;
  final DateTime lastDay;
  final int startMinute;
  final int endMinute;
  final bool allDay;

  DateTime get start => allDay ? firstDay : _at(firstDay, startMinute);

  /// Exclusive for timed events; the last day itself for all-day ones.
  DateTime get end => allDay ? lastDay : _at(lastDay, endMinute);

  bool get oneDay => sameDay(firstDay, lastDay);

  /// "1 день 2 ч", "2 часа 30 м"; all day: "весь день" for one day, the
  /// number of days ("3 дня") for several.
  String get durationLabel {
    if (!allDay) return durationPillLabel(start, end);
    if (oneDay) return 'весь день';
    final days = calendarDaysBetween(firstDay, lastDay) + 1;
    return '$days ${russianPlural(days, 'день', 'дня', 'дней')}';
  }

  EventSpan withAllDay(bool value) => _copy(allDay: value)._normal();

  /// The event moves to [day] and keeps its length in days.
  EventSpan withStartDay(DateTime day) {
    final shift = calendarDaysBetween(firstDay, day);
    return _copy(
      firstDay: dateOnly(day),
      lastDay: addCalendarDays(lastDay, shift),
    )._normal();
  }

  EventSpan withEndDay(DateTime day) => _copy(lastDay: dateOnly(day))._normal();

  /// A new start keeps the event's length.
  EventSpan withStartClock(int hour, int minute) {
    final length = end.difference(start);
    final next = _at(firstDay, hour * 60 + minute);
    return EventSpan.timed(next, next.add(length), allDay: allDay);
  }

  /// An end at or before the start on the same day runs past midnight.
  EventSpan withEndClock(int hour, int minute) =>
      _copy(endMinute: hour * 60 + minute)._normal();

  /// [event] with this span, [title] and [repeat].
  CalendarEvent applyTo(
    CalendarEvent event, {
    required String title,
    RepeatRule? repeat,
  }) => normalizeEvent(
    event.copyWith(
      title: title.trim(),
      allDay: allDay,
      start: start,
      end: end,
      repeat: repeat,
      clearRepeat: repeat == null,
    ),
  );

  EventSpan _copy({
    DateTime? firstDay,
    DateTime? lastDay,
    int? endMinute,
    bool? allDay,
  }) => EventSpan(
    firstDay: firstDay ?? this.firstDay,
    lastDay: lastDay ?? this.lastDay,
    startMinute: startMinute,
    endMinute: endMinute ?? this.endMinute,
    allDay: allDay ?? this.allDay,
  );

  /// The last day is never before the first; a timed end never at or
  /// before the start.
  EventSpan _normal() {
    var span = this;
    if (span.lastDay.isBefore(span.firstDay)) {
      span = span._copy(lastDay: span.firstDay);
    }
    if (span.allDay) return span;
    final timedEnd = _at(span.lastDay, span.endMinute);
    final timedStart = _at(span.firstDay, span.startMinute);
    if (!timedEnd.isAfter(timedStart)) {
      span = span._copy(lastDay: addCalendarDays(span.firstDay, 1));
    }
    return span;
  }

  @override
  bool operator ==(Object other) =>
      other is EventSpan &&
      other.firstDay == firstDay &&
      other.lastDay == lastDay &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.allDay == allDay;

  @override
  int get hashCode =>
      Object.hash(firstDay, lastDay, startMinute, endMinute, allDay);
}

int _minuteOf(DateTime time) => time.hour * 60 + time.minute;

DateTime _at(DateTime day, int minute) =>
    atClock(day, minute ~/ 60, minute % 60);
