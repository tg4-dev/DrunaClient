import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/calendar/day_title_layout.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 390.0;
  final week = Rect.fromLTWH(0, 220, width, 96);

  ExpandLayout layout(double t) => expandLayout(
    t: t,
    week: week,
    slot: 2,
    screenWidth: width,
    screenHeight: 844,
    headerBottom: 120,
    pixelsPerHour: 46,
    contentTop: 236,
  );

  test('the date row rises together and the selected date arcs into place', () {
    final start = layout(0);
    final column = width / 7;

    expect(dayMidnightInset, 40);
    expect(start.dateX(0, 0), column / 2);
    expect(start.dateX(2, 0), 2.5 * column);
    expect(start.dateX(6, 10), start.dateX(0, 10) + 6 * column);
    expect(start.dayWidth, column);
    expect(start.anchor, 2 * column);
    expect(start.selectedSize, 17);
    expect(start.otherSize, 17);
    expect(start.otherOpacity, 1);
    expect(
      start.dateTop(2, start.selectedSize) + start.selectedSize,
      start.dateTop(0, start.otherSize) + start.otherSize,
    );
    expect(start.gridSlide, width);
    expect(start.chromeOpacity, 1);
    expect(start.gridOpacity, 0);
    expect(start.hourLabelOpacity, 0);

    final rising = layout(0.3);
    final along = rising.settled;
    final cell = 2.5 * column;
    final straight = cell + (dayTitleSlot - cell) * along;

    expect(
      (rising.dateX(2, 0) - cell).abs(),
      lessThan((straight - cell).abs()),
    );
    expect(
      rising.dateTop(0, 17) + 17,
      rising.dateTop(2, rising.selectedSize) + rising.selectedSize,
    );

    final settled = layout(0.6);

    expect(settled.selectedSize, 32);
    expect(settled.weekdayOpacity, 1);
    expect(settled.otherOpacity, 0);
    expect(settled.anchor, dayMidnightInset);
    expect(settled.dateX(2, 12), dayTitleSlot);

    final end = layout(1);

    expect(end.anchor, dayMidnightInset);
    expect(end.dayWidth, column);
    expect(end.dateX(0, 0), column / 2);
    expect(end.dateX(3, 0), closeTo(3.5 * column, 0.01));
    expect(end.dateX(2, 12), dayTitleSlot);
    expect(dayTitleSlot, dayMidnightInset + dayTitleRide);
    expect(end.selectedSize, 32);
    expect(end.otherOpacity, 0);
    expect(end.dateTop(2, end.selectedSize) + end.selectedSize, end.rowBottom);
    expect(end.dateTop(0, end.otherSize) + end.otherSize, end.rowBottom);
    expect(end.rowBottom, 120);
    expect(end.gridSlide, 0);
    expect(end.chromeOpacity, 0);
    expect(end.hourLabelOpacity, 1);
    expect(end.gridOpacity, 1);
    expect(end.todayOpacity, 0);
    expect(end.topShift, closeTo(220 - 120, 0.01));
    expect(end.bottomShift, closeTo(844 - 316, 0.01));
  });

  test('a date title crosses midnight without jumping off its line', () {
    const pixels = 46.0;
    final dayWidth = dayWidthOf(pixels);
    const index = 1000;
    final boundary = index * dayWidth - dayMidnightInset;
    final before = dayTitleLayout(
      offset: boundary - 1,
      pixelsPerHour: pixels,
      bigWidth: 80,
    );
    final at = dayTitleLayout(
      offset: boundary,
      pixelsPerHour: pixels,
      bigWidth: 80,
    );

    expect(at.index, before.index + 1);
    expect(before.nextX(), closeTo(dayTitleSlot + 1, 0.01));
    expect(before.nextSize, closeTo(dayTitleBig, 0.3));
    expect(at.currentX(80), dayTitleSlot);
    expect(at.currentSize, dayTitleBig);
    expect(at.previousX(40), at.currentMidnight - dayTitleGap - 40);
    expect(at.currentMidnight, dayMidnightInset);
  });

  testWidgets('opening a day and closing returns to the month', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CalendarScreen()));
    await tester.pump();

    final today = DateTime.now();
    final day = find.byKey(
      ValueKey('day-${today.year}-${today.month}-${today.day}'),
    );
    expect(day, findsOneWidget);
    final month = tester.state<MonthCalendarState>(find.byType(MonthCalendar));
    final offset = month.scrollOffset;

    await tester.tap(day);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(find.byKey(const ValueKey('weekday-header')), findsOneWidget);
    expect(month.scrollOffset, closeTo(offset, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the header down follows the finger and can cancel', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CalendarScreen()));
    await tester.pump();

    final today = DateTime.now();
    await tester.tap(
      find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
    );
    await tester.pumpAndSettle();

    final icon = find.byIcon(Icons.chevron_left);
    final gesture = await tester.startGesture(tester.getCenter(icon));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -70));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(icon, findsOneWidget);

    final close = await tester.startGesture(tester.getCenter(icon));
    await close.moveBy(const Offset(0, 30));
    await tester.pump();
    await close.moveBy(const Offset(0, 700));
    await tester.pump();
    await close.up();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.chevron_left), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
