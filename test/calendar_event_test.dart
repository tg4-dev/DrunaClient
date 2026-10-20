import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int day, int hour, [int minute = 0]) =>
      DateTime(2026, 10, day, hour, minute);

  test('the duration label declines hours and minutes', () {
    expect(durationLabel(at(14, 10), at(14, 10, 15)), '15 минут');
    expect(durationLabel(at(14, 10), at(14, 10, 1)), '1 минута');
    expect(durationLabel(at(14, 10), at(14, 11)), '1 час');
    expect(durationLabel(at(14, 12), at(14, 16)), '4 часа');
    expect(durationLabel(at(14, 10), at(14, 15)), '5 часов');
    expect(durationLabel(at(14, 0), at(14, 4, 45)), '4 ч 45 мин');
    expect(durationLabel(at(14, 22), at(15, 2)), '4 часа');
  });

  test('a new start keeps the length', () {
    final next = withStartClock(at(14, 16), at(14, 20), 18, 30);
    expect(next.start, at(14, 18, 30));
    expect(next.end, at(14, 22, 30));
  });

  test('an end before the start rolls to the next day', () {
    final next = withEndClock(at(14, 22), at(14, 23), 2, 0);
    expect(next.start, at(14, 22));
    expect(next.end, at(15, 2));

    final later = withEndClock(at(14, 16), at(14, 17), 20, 0);
    expect(later.end, at(14, 20));

    final equal = withEndClock(at(14, 16), at(14, 17), 16, 0);
    expect(equal.end, at(15, 16));
  });

  test('a new event is one hour on the quarter hour', () {
    final day = DateTime(2026, 10, 14);
    final morning = defaultEventSpan(day, at(14, 10, 7));
    expect(morning.start, at(14, 10));
    expect(morning.end, at(14, 11));

    final eight = defaultEventSpan(day, at(14, 10, 8));
    expect(eight.start, at(14, 10, 15));
    expect(eight.end, at(14, 11, 15));

    final late = defaultEventSpan(day, at(14, 23, 50));
    expect(late.start, at(14, 22));
    expect(late.end, at(14, 23));
  });

  test('an inverted or empty timed span grows to the minimum length', () {
    final inverted = normalizeEvent(
      CalendarEvent(id: 'a', title: '', start: at(14, 14), end: at(14, 13)),
    );
    expect(inverted.end, at(14, 14, 15));

    final empty = normalizeEvent(
      CalendarEvent(id: 'b', title: '', start: at(14, 14), end: at(14, 14)),
    );
    expect(empty.end, at(14, 14, 15));

    final index = CalendarEventIndex([
      CalendarEvent(id: 'a', title: '', start: at(14, 14), end: at(14, 13)),
    ]);
    expect(index.onDay(DateTime(2026, 10, 14)).map((event) => event.id), ['a']);
    expect(sliceOnDay(index.events.single, DateTime(2026, 10, 14)), isNotNull);
  });

  test('moving an event keeps the time of day and the span', () {
    final event = CalendarEvent(
      id: 'trip',
      title: 'Поездка',
      allDay: true,
      start: DateTime(2026, 10, 14),
      end: DateTime(2026, 10, 18),
    );

    final moved = moveEventToDay(event, DateTime(2026, 10, 16));

    expect(moved.start, DateTime(2026, 10, 16));
    expect(moved.end, DateTime(2026, 10, 20));
    expect(moveEventToDay(event, DateTime(2026, 10, 14)).start, event.start);
  });

  group('saving the sheet', () {
    final trip = CalendarEvent(
      id: 'trip',
      title: 'Поездка',
      allDay: true,
      start: DateTime(2026, 10, 14),
      end: DateTime(2026, 10, 18),
    );

    test('all-day keeps a multi-day span', () {
      final renamed = applyEventDraft(
        event: trip,
        title: ' Дом ',
        allDay: true,
        start: at(14, 9),
        end: at(14, 10),
      );
      expect(renamed.title, 'Дом');
      expect(renamed.start, trip.start);
      expect(renamed.end, trip.end);
    });

    test('a timed event turned all-day covers its days', () {
      final night = CalendarEvent(
        id: 'night',
        title: 'Ночь',
        start: at(14, 22),
        end: at(15, 2),
      );
      final allDay = applyEventDraft(
        event: night,
        title: 'Ночь',
        allDay: true,
        start: night.start,
        end: night.end,
      );
      expect(allDay.allDay, isTrue);
      expect(allDay.start, DateTime(2026, 10, 14));
      expect(allDay.end, DateTime(2026, 10, 15));
    });

    test('an overnight event keeps the next day', () {
      final night = CalendarEvent(
        id: 'night',
        title: 'Ночь',
        start: at(14, 22),
        end: at(15, 2),
      );
      final saved = applyEventDraft(
        event: night,
        title: 'Ночь',
        allDay: false,
        start: night.start,
        end: night.end,
      );
      expect(saved.start, at(14, 22));
      expect(saved.end, at(15, 2));
    });

    test('a timed draft of an all-day event uses the draft times', () {
      final back = applyEventDraft(
        event: trip,
        title: 'Поездка',
        allDay: false,
        start: at(14, 16),
        end: at(14, 18),
      );
      expect(back.allDay, isFalse);
      expect(back.start, at(14, 16));
      expect(back.end, at(14, 18));
    });
  });

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
          start: at(14, 8 + index),
          end: at(14, 9 + index),
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

  CalendarEvent bar(String id, int firstDay, int lastDay) => CalendarEvent(
    id: id,
    title: id,
    allDay: true,
    start: DateTime(2026, 10, firstDay),
    end: DateTime(2026, 10, lastDay),
  );

  test('+N keeps a lane of its own when bars fill a day', () {
    final days = daysOfWeek(weekIndexOf(DateTime(2026, 10, 12)));
    final layout = layoutWeek(
      events: [bar('a', 12, 14), bar('b', 12, 14), bar('c', 12, 14)],
      days: days,
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 2,
    );

    expect(layout.barCapacity, 1);
    final monday = layout.columns[0];
    expect(monday.overflow, 2);
    expect(monday.overflowLane, 1);
    expect(
      layout.spans.where(layout.showsSpan).map((span) => span.lane),
      everyElement(lessThan(monday.overflowLane!)),
    );
  });

  test('a hidden bar is counted even when its day has a free lane', () {
    final days = daysOfWeek(weekIndexOf(DateTime(2026, 10, 12)));
    // Mon–Wed, Mon–Tue and Tue–Wed: the third needs a third lane on Tuesday.
    final layout = layoutWeek(
      events: [bar('c', 12, 14), bar('a', 12, 13), bar('b', 13, 14)],
      days: days,
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 2,
    );

    final hidden = layout.spans.where((span) => !layout.showsSpan(span));
    expect(hidden, isNotEmpty);
    for (final span in hidden) {
      for (var column = span.startColumn; column <= span.endColumn; column++) {
        expect(layout.columns[column].overflow, greaterThan(0));
      }
    }
  });

  test('a multi-day bar is clipped to each week', () {
    final firstMonday = DateTime(2026, 10, 12);
    expect(firstMonday.weekday, DateTime.monday);
    final trip = bar('trip', 14, 20);
    final first = layoutWeek(
      events: [trip],
      days: daysOfWeek(weekIndexOf(firstMonday)),
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

    final second = layoutWeek(
      events: [trip],
      days: daysOfWeek(weekIndexOf(DateTime(2026, 10, 19))),
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 3,
    );
    expect(second.spans.single.startColumn, 0);
    expect(second.spans.single.endColumn, 1);
    expect(second.spans.single.continuesBefore, isTrue);
    expect(second.spans.single.continuesAfter, isFalse);
  });

  test('overlapping events take different rows and a touching one reuses', () {
    final index = CalendarEventIndex([
      CalendarEvent(id: 'a', title: '', start: at(14, 10), end: at(14, 12)),
      CalendarEvent(id: 'b', title: '', start: at(14, 11), end: at(14, 13)),
      CalendarEvent(id: 'c', title: '', start: at(14, 12), end: at(14, 14)),
    ]);

    final lanes = index.lanesAround(DateTime(2026, 10, 14));
    expect([lanes['a'], lanes['b'], lanes['c']], [0, 1, 0]);
  });

  test('an overnight event keeps its row on both days', () {
    final index = CalendarEventIndex([
      CalendarEvent(id: 'c', title: '', start: at(14, 20), end: at(14, 23)),
      CalendarEvent(id: 'a', title: '', start: at(14, 22), end: at(15, 2)),
    ]);

    final first = index.lanesAround(DateTime(2026, 10, 14));
    final second = index.lanesAround(DateTime(2026, 10, 15));
    expect(first['a'], 1);
    expect(second['a'], first['a']);
  });

  test('a slice knows whether the event goes on past midnight', () {
    final night = CalendarEvent(
      id: 'night',
      title: '',
      start: at(14, 22),
      end: at(15, 2),
    );
    final first = sliceOnDay(night, DateTime(2026, 10, 14))!;
    expect(first.continuesBefore, isFalse);
    expect(first.continuesAfter, isTrue);
    final second = sliceOnDay(night, DateTime(2026, 10, 15))!;
    expect(second.continuesBefore, isTrue);
    expect(second.continuesAfter, isFalse);
    expect(second.endHour, 2);
  });

  test('the sticky title stays inside its event', () {
    const padding = 8.0;
    const titleWidth = 40.0;

    expect(
      stickyTitleX(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 200,
        titleWidth: titleWidth,
        padding: padding,
      ),
      208,
    );
    expect(
      stickyTitleX(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 380,
        titleWidth: titleWidth,
        padding: padding,
      ),
      352,
    );
    expect(
      stickyTitleX(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 0,
        titleWidth: titleWidth,
        padding: padding,
      ),
      108,
    );
    expect(
      stickyTitleX(
        eventLeft: 100,
        eventRight: 400,
        viewportLeft: 400,
        titleWidth: titleWidth,
        padding: padding,
      ),
      isNull,
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
