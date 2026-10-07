import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/calendar/day_title_layout.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const width = 390.0;
  final week = Rect.fromLTWH(0, 220, width, 96);

  ExpandLayout layout(double t) =>
      expandLayout(t: t, week: week, screenHeight: 844);

  test('the day opens as one sheet from the tapped week', () {
    final start = layout(0);

    expect(dayMidnightInset, 40);
    expect(start.top, week.top);
    expect(start.bottom, week.bottom);
    expect(start.veil, 0);

    final fading = layout(0.1);

    expect(fading.top, closeTo(week.top * 0.9, 0.01));
    expect(fading.veil, greaterThan(0));
    expect(fading.veil, lessThan(1));

    final mid = layout(0.5);

    expect(mid.top, week.top / 2);
    expect(mid.bottom, closeTo((week.bottom + 844) / 2, 0.01));
    expect(mid.veil, 1);

    final end = layout(1);

    expect(end.top, 0);
    expect(end.bottom, 844);
    expect(end.veil, 1);
    expect(dayTitleSlot, dayMidnightInset + dayTitleRide);
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
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 16));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -40));
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
