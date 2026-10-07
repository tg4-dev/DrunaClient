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
}

void _ignoreTap(DateTime day, Rect weekRect) {}
