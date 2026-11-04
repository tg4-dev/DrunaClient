import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/day_timeline.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';

void main() {
  final day = DateTime(2026, 10, 14);
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  double xOf(DateTime time, int openHour) {
    final offset =
        timelineX(at(openHour), defaultPixelsPerHour) - dayMidnightInset;
    return timelineX(time, defaultPixelsPerHour) - offset;
  }

  Future<void> pumpTimeline(
    WidgetTester tester, {
    List<CalendarEvent> events = const [],
    void Function(DateTime start, DateTime end)? onCreate,
    void Function(CalendarEvent event, DateTime start)? onMove,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DayTimeline(
          day: day,
          events: events,
          onVisibleDay: (_) {},
          onCreateRange: onCreate,
          onMoveEvent: onMove,
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> holdAndDrag(
    WidgetTester tester,
    Offset from,
    double dx, {
    Duration hold = Duration.zero,
  }) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    const steps = 6;
    for (var step = 0; step < steps; step++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var waited = Duration.zero; waited < hold;) {
      await tester.pump(const Duration(milliseconds: 16));
      waited += const Duration(milliseconds: 16);
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  const y = 120.0;

  testWidgets('holding empty time draws an event to where it is released', (
    tester,
  ) async {
    DateTime? start;
    DateTime? end;
    await pumpTimeline(
      tester,
      onCreate: (s, e) {
        start = s;
        end = e;
      },
    );

    await holdAndDrag(
      tester,
      Offset(xOf(at(9), timelineMorningHour), y),
      2 * defaultPixelsPerHour,
    );

    expect(start, at(9));
    expect(end, at(11));
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawing to the left moves the start earlier', (tester) async {
    DateTime? start;
    DateTime? end;
    await pumpTimeline(
      tester,
      onCreate: (s, e) {
        start = s;
        end = e;
      },
    );

    await holdAndDrag(
      tester,
      Offset(xOf(at(11), timelineMorningHour), y),
      -1.5 * defaultPixelsPerHour,
    );

    expect(start, at(9, 30));
    expect(end, at(11));
  });

  testWidgets('a hold without a drag makes a one-hour event', (tester) async {
    DateTime? start;
    DateTime? end;
    await pumpTimeline(
      tester,
      onCreate: (s, e) {
        start = s;
        end = e;
      },
    );

    await holdAndDrag(tester, Offset(xOf(at(10), timelineMorningHour), y), 0);

    expect(start, at(10));
    expect(end, at(11));
  });

  testWidgets('holding an event moves it and keeps its length', (tester) async {
    final meet = CalendarEvent(
      id: 'meet',
      title: 'Встреча',
      start: at(10),
      end: at(12),
    );
    CalendarEvent? moved;
    DateTime? movedTo;
    await pumpTimeline(
      tester,
      events: [meet],
      onMove: (event, start) {
        moved = event;
        movedTo = start;
      },
    );

    final grab = Offset(
      xOf(at(10, 30), 9),
      timelineLaneTop(0) + timelineEventHeight / 2,
    );
    await holdAndDrag(tester, grab, defaultPixelsPerHour);

    expect(moved?.id, 'meet');
    expect(movedTo, at(11));
  });

  testWidgets('holding at the right edge scrolls the timeline on', (
    tester,
  ) async {
    DateTime? end;
    await pumpTimeline(tester, onCreate: (_, e) => end = e);
    final from = Offset(xOf(at(9), timelineMorningHour), y);
    final width = tester.getSize(find.byType(DayTimeline)).width;

    await holdAndDrag(
      tester,
      from,
      width - 8 - from.dx,
      hold: const Duration(milliseconds: 600),
    );

    final edgeTime = at(timelineMorningHour).add(
      Duration(
        minutes: ((width - dayMidnightInset) / defaultPixelsPerHour * 60)
            .round(),
      ),
    );
    expect(end, isNotNull);
    expect(end!.isAfter(edgeTime.add(const Duration(hours: 2))), isTrue);
  });

  test('zoom steps are binary fractions', () {
    for (final value in [18.3, 27.77, 46.0, 91.999]) {
      final quantized = quantizePixels(value);
      expect(quantized * 32, (quantized * 32).roundToDouble());
      expect((quantized - value).abs(), lessThanOrEqualTo(1 / 64));
      expect(
        (dayTimelineDayCount * 24 * quantized) / (24 * quantized),
        dayTimelineDayCount,
      );
    }
  });

  testWidgets('drawing snaps to half hours and shows the time under it', (
    tester,
  ) async {
    DateTime? end;
    await pumpTimeline(tester, onCreate: (_, e) => end = e);

    final gesture = await tester.startGesture(
      Offset(xOf(at(9), timelineMorningHour), y),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(Offset(defaultPixelsPerHour * 55 / 60, 0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('09:00-10:00'), findsOneWidget);
    expect(
      tester.getRect(find.text('09:00-10:00')).top,
      greaterThan(
        tester.getRect(find.byKey(const ValueKey('timeline-ghost'))).bottom,
      ),
    );
    await gesture.up();
    await tester.pumpAndSettle();

    expect(end, at(10));
  });

  testWidgets('zoomed out to 4 h, drawing snaps to whole hours', (
    tester,
  ) async {
    DateTime? start;
    DateTime? end;
    final metrics = DayScrollMetrics()..pixelsPerHour = 18;
    addTearDown(metrics.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: DayTimeline(
          day: day,
          events: const [],
          metrics: metrics,
          onVisibleDay: (_) {},
          onCreateRange: (s, e) {
            start = s;
            end = e;
          },
        ),
      ),
    );
    await tester.pump();
    final offset = timelineX(at(timelineMorningHour), 18) - dayMidnightInset;
    double x(DateTime time) => timelineX(time, 18) - offset;

    await holdAndDrag(tester, Offset(x(at(9, 20)), y), 18 * 130 / 60);

    expect(start!.minute, 0);
    expect(end!.minute, 0);
    expect(end!.difference(start!).inHours, greaterThanOrEqualTo(2));
  });

  testWidgets('a multi-day event shows its dates after the title', (
    tester,
  ) async {
    await pumpTimeline(
      tester,
      events: [
        CalendarEvent(
          id: 'trip',
          title: 'Поездка',
          start: at(9),
          end: DateTime(2026, 10, 16, 12),
        ),
      ],
    );

    expect(find.textContaining('14.10-16.10'), findsOneWidget);
  });

  testWidgets('in the day, bars take the grid tones and the title the '
      'light one', (tester) async {
    await pumpTimeline(
      tester,
      events: [
        CalendarEvent(
          id: 'mine',
          title: 'Обед',
          start: at(timelineMorningHour + 1),
          end: at(timelineMorningHour + 3),
        ),
      ],
    );
    final tone = gridTone(defaultOwnColor);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            widget.decoration is BoxDecoration &&
            (widget.decoration as BoxDecoration).color == tone.fill,
      ),
      findsWidgets,
    );
    final title = tester.widget<Text>(find.text('Обед'));
    expect(title.style?.color, tone.ink);
  });

  testWidgets('a shared event in the day is a cell with the faces, behind '
      'the rows, and opens on a tap', (tester) async {
    CalendarEvent? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: DayTimeline(
          day: day,
          onVisibleDay: (_) {},
          onEventTap: (event, _) => opened = event,
          sharedEvents: [
            CalendarEvent(
              id: 'dinner',
              title: 'Ужин',
              start: at(timelineMorningHour + 1),
              end: at(timelineMorningHour + 3),
              invite: const EventInvite(
                id: 'dinner',
                colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
                people: [
                  FriendInfo(id: 1, name: 'Катя', username: 'katya'),
                  FriendInfo(id: 2, name: 'Маша', username: 'masha'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SharedCellBack), findsOneWidget);
    expect(find.byType(FaceStack), findsOneWidget);
    await tester.tap(find.byType(SharedCellBack), warnIfMissed: false);
    expect(opened?.id, 'dinner');
  });

  testWidgets('a shared event\'s faces stick to the left edge while it runs '
      'on past it', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DayTimeline(
          day: day,
          onVisibleDay: (_) {},
          sharedEvents: [
            CalendarEvent(
              id: 'trip',
              title: 'Поездка',
              start: at(0),
              end: at(23),
              invite: const EventInvite(
                id: 'trip',
                colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
                people: [FriendInfo(id: 1, name: 'Катя', username: 'katya')],
              ),
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    final faces = tester.getRect(find.byType(FaceStack));
    expect(faces.left, closeTo(10, 0.5));
    expect(faces.width, sharedDayFaceSize);
  });
}
