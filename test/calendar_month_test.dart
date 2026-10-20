import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_timeline.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('June 2025 day 1 sits on Sunday of the week of May 26', () {
    final monday = mondayOfWeek(weekIndexOf(DateTime(2025, 6, 1)));
    final days = daysOfWeek(weekIndexOf(DateTime(2025, 6, 1)));

    expect(monday, DateTime(2025, 5, 26));
    expect(days[6], DateTime(2025, 6, 1));
    expect(monthOfWeek(weekIndexOf(DateTime(2025, 6, 1))), DateTime(2025, 6));
  });

  test('a month that starts midweek adds a lower strip', () {
    final june = DateTime(2025, 6, 1);
    final week = weekIndexOf(june);

    expect(weekIsCut(week), isTrue);
    expect(monthShort(june), 'Июн');
    expect(stripAt(stripIndexOfDay(june)).kind, MonthStripKind.fresh);
    expect(
      stripAt(stripIndexOfDay(DateTime(2025, 5, 30))).kind,
      MonthStripKind.tail,
    );
    expect(stripIndexOfWeek(week + 1) - stripIndexOfWeek(week), 2);

    final september = DateTime(2025, 9, 1);
    expect(september.weekday, DateTime.monday);
    final septemberWeek = weekIndexOf(september);
    expect(weekIsCut(septemberWeek), isFalse);
    expect(stripAt(stripIndexOfDay(september)).kind, MonthStripKind.full);
    expect(
      stripIndexOfWeek(septemberWeek + 1) - stripIndexOfWeek(septemberWeek),
      1,
    );
  });

  test('strip units match the summed row extents', () {
    final index = stripIndexOfDay(DateTime(2025, 6, 1));
    var sum = 0.0;
    for (var i = 0; i < index; i++) {
      sum += stripExtentUnits(stripAt(i));
    }
    expect(stripUnits(index), closeTo(sum, 0.001));

    final may = DateTime(1981, 5, 1);
    expect(may.weekday, DateTime.friday);
    expect(weekIsCut(weekIndexOf(may)), isTrue);
    expect(stripHasBand(stripAt(stripIndexOfDay(may))), isTrue);
  });

  test('a month start row is taller and the name sits in that row', () {
    final june = DateTime(2025, 6, 1);
    final fresh = stripAt(stripIndexOfDay(june));
    final tail = stripAt(stripIndexOfDay(DateTime(2025, 5, 30)));

    expect(stripHasBand(fresh), isTrue);
    expect(stripHasBand(tail), isFalse);
    expect(stripExtentUnits(fresh), 1 + monthBandRatio);
    expect(stripExtentUnits(tail), 1);
    expect(stripUnits(stripIndexOfDay(june)), unitsOfWeek(fresh.weekIndex) + 1);

    expect(
      stripIndexForScrollUnits(stripUnits(stripIndexOfDay(june))),
      stripIndexOfDay(june) - 1,
    );
    expect(
      stripIndexForScrollUnits(stripUnits(stripIndexOfDay(june)) + 0.01),
      stripIndexOfDay(june),
    );

    final september = stripAt(stripIndexOfDay(DateTime(2025, 9, 1)));
    expect(september.kind, MonthStripKind.full);
    expect(stripHasBand(september), isTrue);
    expect(stripExtentUnits(september), greaterThan(stripExtentUnits(tail)));
  });

  test('zoom keeps the content point under the focal pixel', () {
    final next = zoomedOffset(
      offset: 200,
      focal: 40,
      oldExtent: 10,
      newExtent: 20,
    );

    expect(next, 440);
    expect((200 + 40) / 10, (next + 40) / 20);
  });

  testWidgets('weekday header has no dates and June 1 is on Sunday', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(focus: DateTime(2025, 6, 1), onDayTap: _ignoreTap),
      ),
    );
    await tester.pump();

    final header = find.byKey(const ValueKey('weekday-header'));
    expect(header, findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('1')), findsNothing);
    expect(
      find.descendant(of: header, matching: find.text('Вс')),
      findsOneWidget,
    );

    final band = find.byKey(const ValueKey('week-2025-5-26-fresh-band'));
    expect(band, findsOneWidget);
    expect(
      find.descendant(of: band, matching: find.text('Июн')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('week-2025-5-26-fresh-5')), findsNothing);
    final sunday = find.byKey(const ValueKey('week-2025-5-26-fresh-6'));
    expect(sunday, findsOneWidget);
    expect(
      find.descendant(of: sunday, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sunday, matching: find.text('Июн')),
      findsNothing,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('week-2025-5-26-fresh'))).height,
      greaterThan(96),
    );
  });

  testWidgets('a Monday the 1st keeps its column and still has a band', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(focus: DateTime(2025, 9, 1), onDayTap: _ignoreTap),
      ),
    );
    await tester.pump();

    final band = find.byKey(const ValueKey('week-2025-9-1-full-band'));
    expect(band, findsOneWidget);
    expect(
      find.descendant(of: band, matching: find.text('Сен')),
      findsOneWidget,
    );
    final monday = find.byKey(const ValueKey('week-2025-9-1-full-0'));
    expect(monday, findsOneWidget);
    expect(
      find.descendant(of: monday, matching: find.text('1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: monday, matching: find.text('Сен')),
      findsNothing,
    );
  });

  testWidgets('week separators stay visible', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(focus: DateTime(2025, 9, 8), onDayTap: _ignoreTap),
      ),
    );
    await tester.pump();

    final rules = find.byKey(const ValueKey('week-rule'));
    expect(rules, findsWidgets);
    final size = tester.getSize(rules.first);
    expect(size.height, greaterThan(0));
    expect(size.width, greaterThan(20));
  });

  testWidgets('holding an event drops it on another day', (tester) async {
    CalendarEvent? moved;
    DateTime? movedDay;
    final event = CalendarEvent(
      id: 'druna',
      title: 'Друна',
      start: DateTime(2026, 10, 14, 10),
      end: DateTime(2026, 10, 14, 12),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(
          focus: DateTime(2026, 10, 14),
          events: [event],
          onDayTap: _ignoreTap,
          onMove: (event, day) {
            moved = event;
            movedDay = day;
          },
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Друна')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(moved?.id, 'druna');
    expect(movedDay, DateTime(2026, 10, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a multi-day event moves by the days it was dragged', (
    tester,
  ) async {
    DateTime? movedDay;
    final trip = CalendarEvent(
      id: 'trip',
      title: 'Поездка',
      allDay: true,
      start: DateTime(2026, 10, 14),
      end: DateTime(2026, 10, 17),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(
          focus: DateTime(2026, 10, 14),
          events: [trip],
          onDayTap: _ignoreTap,
          onMove: (event, day) => movedDay = day,
        ),
      ),
    );
    await tester.pump();

    // Grab the bar over Friday, its third day, and drop it on Saturday.
    final friday = tester.getCenter(
      find.byKey(const ValueKey('day-2026-10-16')),
    );
    final barY = tester.getCenter(find.text('Поездка')).dy;
    final saturday = tester.getCenter(
      find.byKey(const ValueKey('day-2026-10-17')),
    );
    final gesture = await tester.startGesture(Offset(friday.dx, barY));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(Offset(saturday.dx - friday.dx, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(movedDay, DateTime(2026, 10, 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding an empty day creates an event there', (tester) async {
    DateTime? created;
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(
          focus: DateTime(2026, 10, 14),
          onDayTap: _ignoreTap,
          onCreate: (day, rect) => created = day,
        ),
      ),
    );
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('day-2026-10-16'))),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.up();
    await tester.pump();

    expect(created, DateTime(2026, 10, 16));
  });

  testWidgets('demo events fit in the month and on the timeline', (
    tester,
  ) async {
    final day = DateTime(2026, 10, 14);
    final events = demoCalendarEvents(day);
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(focus: day, events: events, onDayTap: _ignoreTap),
      ),
    );
    await tester.pump();

    expect(find.text('Друна'), findsOneWidget);
    expect(find.text('Поездка'), findsWidgets);
    expect(tester.takeException(), isNull);

    final metrics = DayScrollMetrics();
    await tester.pumpWidget(
      MaterialApp(
        home: DayTimeline(
          day: day,
          metrics: metrics,
          events: events,
          onVisibleDay: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Друна'), findsWidgets);
    expect(tester.takeException(), isNull);
    metrics.dispose();
  });

  group('friends’ mode', () {
    final today = DateTime.now();
    final mine = CalendarEvent(
      id: 'mine',
      title: 'Моё',
      start: DateTime(today.year, today.month, today.day, 10),
      end: DateTime(today.year, today.month, today.day, 11),
    );
    const friendColour = Color(0xFF34C759);
    final busy = CalendarEvent(
      id: 'busy',
      title: '',
      start: DateTime(today.year, today.month, today.day, 12),
      end: DateTime(today.year, today.month, today.day, 13),
      color: friendColour,
      ownerId: 7,
    );

    Future<List<CalendarEvent>> pumpMonth(
      WidgetTester tester,
      double mode, {
      VoidCallback? onShowMine,
    }) async {
      final tapped = <CalendarEvent>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthCalendar(
              focus: today,
              events: [mine],
              friendEvents: [busy],
              mode: AlwaysStoppedAnimation(mode),
              onShowMine: onShowMine,
              onDayTap: (_, _) {},
              onEventTap: (event, _) => tapped.add(event),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tapped;
    }

    /// Painted: no fully transparent [Opacity] above it. Hidden layers stay
    /// mounted (so their state survives a swipe) but are not drawn.
    bool painted(WidgetTester tester, Element element) {
      var shown = true;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is Opacity && widget.opacity == 0) shown = false;
        return shown;
      });
      return shown;
    }

    Iterable<Color?> chipColours(WidgetTester tester) => find
        .byType(DecoratedBox)
        .evaluate()
        .where((element) => painted(tester, element))
        .map((element) => (element.widget as DecoratedBox).decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.color);

    bool textShown(WidgetTester tester, String text) =>
        find.text(text).evaluate().any((element) => painted(tester, element));

    testWidgets('my mode: my chips in full and tappable', (tester) async {
      final tapped = await pumpMonth(tester, 0);
      expect(textShown(tester, 'Моё'), isTrue);
      expect(chipColours(tester), isNot(contains(friendColour)));

      await tester.tap(find.text('Моё'));
      expect(tapped.single.id, 'mine');
    });

    testWidgets('friends’ chips do not replay their entrance after a swipe', (
      tester,
    ) async {
      final mode = ValueNotifier<double>(1);
      addTearDown(mode.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MonthCalendar(
              focus: today,
              events: [mine],
              friendEvents: [busy],
              mode: mode,
              onDayTap: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final value in [0.5, 0.0, 0.5, 1.0]) {
        mode.value = value;
        await tester.pump();
      }
      // The very first frame back: an entrance would start from 0.
      final chip = find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == friendColour,
      );
      final fades = tester.widgetList<Opacity>(
        find.ancestor(of: chip.first, matching: find.byType(Opacity)),
      );
      expect(fades.every((opacity) => opacity.opacity == 1), isTrue);
    });

    testWidgets('today is a white disc with a dark number', (tester) async {
      await pumpMonth(tester, 0);
      final number = tester.widget<Text>(
        find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
      );
      expect(number.style?.color, Colors.black);
      final disc = tester.widget<Container>(
        find
            .ancestor(
              of: find.byWidget(number),
              matching: find.byType(Container),
            )
            .first,
      );
      expect((disc.decoration! as BoxDecoration).color, Colors.white);
    });

    testWidgets('my events take my colour, with dark text on a light one', (
      tester,
    ) async {
      const mine = Color(0xFFFFD60A);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnEventColor(
              color: mine,
              child: MonthCalendar(
                focus: today,
                events: [
                  CalendarEvent(
                    id: 'mine',
                    title: 'Моё',
                    start: DateTime(today.year, today.month, today.day, 10),
                    end: DateTime(today.year, today.month, today.day, 11),
                  ),
                ],
                onDayTap: (_, _) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chipColours(tester), contains(mine));
      expect(tester.widget<Text>(find.text('Моё')).style?.color, Colors.black);
    });

    testWidgets('friends’ mode: their chips in their colour; mine a band', (
      tester,
    ) async {
      var shown = 0;
      final tapped = await pumpMonth(tester, 1, onShowMine: () => shown++);
      expect(textShown(tester, 'Моё'), isFalse);
      expect(chipColours(tester), contains(friendColour));

      // My chip is beyond the line and takes no taps.
      await tester.tap(find.text('Моё'), warnIfMissed: false);

      await tester.tap(find.bySemanticsLabel('Показать мои события').first);
      expect(shown, 1);
      expect(tapped, isEmpty);
    });
  });
}

void _ignoreTap(DateTime day, Rect weekRect) {}
