import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('duration label stays on one line', () {
    expect(
      durationLabel(const ClockTime(10, 0), const ClockTime(10, 15)),
      '15 мин.',
    );
    expect(
      durationLabel(const ClockTime(10, 0), const ClockTime(11, 0)),
      '1ч.',
    );
    expect(
      durationLabel(const ClockTime(10, 0), const ClockTime(11, 15)),
      '1ч. 15 мин.',
    );
    expect(
      durationLabel(const ClockTime(12, 0), const ClockTime(16, 0)),
      '4ч.',
    );
    expect(
      durationLabel(const ClockTime(0, 0), const ClockTime(4, 45)),
      '4ч. 45 мин.',
    );
  });

  test('an earlier end pulls the start back by one hour', () {
    final resolved = resolveClock(
      const ClockTime(18, 0),
      const ClockTime(16, 30),
    );

    expect(resolved.start, const ClockTime(15, 30));
    expect(resolved.end, const ClockTime(16, 30));
  });

  test('an end before 01:00 stays on the same day', () {
    for (final minute in [0, 15, 30, 45]) {
      final resolved = resolveClock(
        const ClockTime(12, 0),
        ClockTime(0, minute),
      );
      expect(resolved.start, const ClockTime(0, 0));
      expect(resolved.end, const ClockTime(1, 0));
    }
  });

  test('a later end keeps both clocks', () {
    final resolved = resolveClock(
      const ClockTime(16, 0),
      const ClockTime(20, 0),
    );

    expect(resolved.start, const ClockTime(16, 0));
    expect(resolved.end, const ClockTime(20, 0));
  });

  test('a new event is one hour on the quarter hour', () {
    final morning = defaultEventClock(DateTime(2026, 10, 14, 10, 7));
    expect(morning.start, const ClockTime(10, 0));
    expect(morning.end, const ClockTime(11, 0));

    final eight = defaultEventClock(DateTime(2026, 10, 14, 10, 8));
    expect(eight.start, const ClockTime(10, 15));
    expect(eight.end, const ClockTime(11, 15));

    final late = defaultEventClock(DateTime(2026, 10, 14, 23, 50));
    expect(late.start, const ClockTime(22, 0));
    expect(late.end, const ClockTime(23, 0));
  });

  test('moving an event keeps the time of day and the span', () {
    final event = CalendarEvent(
      id: 'trip',
      title: 'Поездка',
      allDay: true,
      start: DateTime(2026, 10, 14, 10, 15),
      end: DateTime(2026, 10, 18),
    );

    final moved = moveEventToDay(event, DateTime(2026, 10, 16));

    expect(moved.start, DateTime(2026, 10, 16, 10, 15));
    expect(moved.end, DateTime(2026, 10, 20));
    expect(moveEventToDay(event, DateTime(2026, 10, 14)).start, event.start);
  });

  test(
    'saving all-day keeps a multi-day span and a timed draft collapses it',
    () {
      final trip = CalendarEvent(
        id: 'trip',
        title: 'Поездка',
        allDay: true,
        start: DateTime(2026, 10, 14),
        end: DateTime(2026, 10, 18),
      );
      final renamed = applyEventDraft(
        event: trip,
        title: 'Дом',
        allDay: true,
        start: const ClockTime(9, 0),
        end: const ClockTime(10, 0),
      );
      expect(renamed.title, 'Дом');
      expect(renamed.end, trip.end);

      final timed = CalendarEvent(
        id: 'meet',
        title: 'Встреча',
        start: DateTime(2026, 10, 14, 16, 0),
        end: DateTime(2026, 10, 14, 18, 0),
      );
      final allDay = applyEventDraft(
        event: timed,
        title: 'Выходной',
        allDay: true,
        start: const ClockTime(16, 0),
        end: const ClockTime(18, 0),
      );
      expect(allDay.allDay, isTrue);
      expect(allDay.start, DateTime(2026, 10, 14));
      expect(allDay.end, DateTime(2026, 10, 14));

      final back = applyEventDraft(
        event: trip,
        title: 'Поездка',
        allDay: false,
        start: const ClockTime(18, 0),
        end: const ClockTime(16, 0),
      );
      expect(back.allDay, isFalse);
      expect(back.start, DateTime(2026, 10, 14, 15, 0));
      expect(back.end, DateTime(2026, 10, 14, 16, 0));
    },
  );

  test('month densities follow the row heights', () {
    expect(densityForRowHeight(monthRowMin).bars, isTrue);
    expect(densityForRowHeight(monthBarSnapThreshold).bars, isTrue);
    expect(densityForRowHeight(monthRowLevels[1]).showTitle, isTrue);
    expect(densityForRowHeight(monthRowLevels[1]).showTime, isFalse);
    expect(densityForRowHeight(monthRowLevels[2]).showTime, isTrue);
    expect(
      monthEventCapacity(monthRowMin, barDensity),
      greaterThanOrEqualTo(4),
    );
    expect(
      monthEventCapacity(monthRowLevels[2], detailDensity),
      greaterThan(2),
    );
  });

  test('events that do not fit become +N', () {
    final day = DateTime(2026, 10, 14);
    final days = daysOfWeek(weekIndexOf(day));
    final column = days.indexWhere((item) => sameDay(item, day));
    final events = [
      for (var index = 0; index < 6; index++)
        CalendarEvent(
          id: 'e$index',
          title: 'Дело $index',
          start: DateTime(day.year, day.month, day.day, 8 + index),
          end: DateTime(day.year, day.month, day.day, 9 + index),
        ),
    ];

    final layout = layoutWeek(
      events: events,
      days: days,
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 3,
    );

    expect(layout.columns[column].chips, hasLength(2));
    expect(layout.columns[column].overflow, 4);
    expect(layout.columns[column].chips.map((chip) => chip.eventId), [
      'e0',
      'e1',
    ]);
  });

  test('a multi-day bar is clipped to each week', () {
    final firstMonday = DateTime(2026, 10, 12);
    expect(firstMonday.weekday, DateTime.monday);
    final trip = CalendarEvent(
      id: 'trip',
      title: 'Поездка',
      allDay: true,
      start: DateTime(2026, 10, 14),
      end: DateTime(2026, 10, 20),
    );
    final firstDays = daysOfWeek(weekIndexOf(firstMonday));
    final first = layoutWeek(
      events: [trip],
      days: firstDays,
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 3,
    );
    expect(first.spans, hasLength(1));
    expect(first.spans.single.startColumn, 2);
    expect(first.spans.single.endColumn, 6);
    expect(first.spans.single.continuesBefore, isFalse);
    expect(first.spans.single.continuesAfter, isTrue);
    expect(first.spans.single.lane, 0);

    final nextMonday = DateTime(2026, 10, 19);
    final second = layoutWeek(
      events: [trip],
      days: daysOfWeek(weekIndexOf(nextMonday)),
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 3,
    );
    expect(second.spans.single.startColumn, 0);
    expect(second.spans.single.endColumn, 1);
    expect(second.spans.single.continuesBefore, isTrue);
    expect(second.spans.single.continuesAfter, isFalse);
  });

  test(
    'overlapping intervals take different lanes and a touching one reuses',
    () {
      final day = DateTime(2026, 10, 14);
      TimedSpan span(String id, int startHour, int endHour) => TimedSpan(
        id: id,
        start: DateTime(day.year, day.month, day.day, startHour),
        end: DateTime(day.year, day.month, day.day, endHour),
      );

      final lanes = assignLanes([
        span('a', 10, 12),
        span('b', 11, 13),
        span('c', 12, 14),
      ]);

      expect(lanes.map((lane) => lane.lane), [0, 1, 0]);
    },
  );

  test('the sticky title stays inside the visible slice', () {
    const padding = 8.0;
    const titleWidth = 40.0;

    expect(
      stickyTitleOffset(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 200,
        sliceLeft: 100,
        sliceRight: 250,
        titleWidth: titleWidth,
        padding: padding,
      ),
      108,
    );
    expect(
      stickyTitleOffset(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 200,
        sliceLeft: 250,
        sliceRight: 400,
        titleWidth: titleWidth,
        padding: padding,
      ),
      isNull,
    );
    expect(
      stickyTitleOffset(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 300,
        sliceLeft: 250,
        sliceRight: 400,
        titleWidth: titleWidth,
        padding: padding,
      ),
      58,
    );
    expect(
      stickyTitleOffset(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 0,
        sliceLeft: 100,
        sliceRight: 400,
        titleWidth: titleWidth,
        padding: padding,
      ),
      padding,
    );
  });

  test('fresh and tail strips hide the other month', () {
    expect(
      columnVisible(kind: MonthStripKind.fresh, firstOfMonth: 6, column: 5),
      isFalse,
    );
    expect(
      columnVisible(kind: MonthStripKind.fresh, firstOfMonth: 6, column: 6),
      isTrue,
    );
    expect(
      columnVisible(kind: MonthStripKind.tail, firstOfMonth: 6, column: 5),
      isTrue,
    );
  });
}
