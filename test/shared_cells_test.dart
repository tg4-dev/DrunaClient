import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/oklab.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A Monday-to-Sunday week, all of it in view.
  final monday = DateTime(2026, 11, 2);
  final week = weekIndexOf(monday);
  final days = daysOfWeek(week);

  CalendarEvent shared(
    String id,
    int fromDay,
    int toDay, {
    bool pending = false,
    List<FriendInfo> people = const [],
  }) => CalendarEvent(
    id: id,
    title: id,
    start: DateTime(2026, 11, 2 + fromDay, 18),
    end: DateTime(2026, 11, 2 + toDay, 21),
    invite: EventInvite(
      id: id,
      colors: const [Color(0xFF34C759), Color(0xFF0A84FF)],
      people: people,
      pending: pending,
    ),
  );

  List<SharedPiece> layout(List<CalendarEvent> events) => layoutSharedWeek(
    events: events,
    days: days,
    visibleStart: 0,
    visibleEnd: 6,
  );

  group('shared cells of a week', () {
    test('a lone event fills its day', () {
      final pieces = layout([shared('a', 1, 1)]);
      expect(pieces, hasLength(1));
      expect(pieces.single.startColumn, 1);
      expect(pieces.single.endColumn, 1);
      expect(pieces.single.slots, 1);
    });

    test('an event over several days is one cell across them', () {
      final pieces = layout([shared('trip', 2, 4)]);
      expect(pieces, hasLength(1));
      expect(pieces.single.startColumn, 2);
      expect(pieces.single.endColumn, 4);
    });

    test('overlapping events stack, each in its own cell', () {
      final pieces = layout([shared('a', 1, 2), shared('b', 2, 2)]);
      expect(pieces, hasLength(2));
      expect({for (final piece in pieces) piece.slot}, {0, 1});
      expect(pieces.every((piece) => piece.slots == 2), isTrue);
    });

    test('events on other days do not share a stack', () {
      final pieces = layout([shared('a', 0, 0), shared('b', 3, 3)]);
      expect(pieces.every((piece) => piece.slots == 1), isTrue);
    });

    test('more than two on a day: the first and "+N" under it', () {
      final pieces = layout([
        shared('a', 1, 1),
        shared('b', 1, 1),
        shared('c', 1, 1),
      ]);
      expect(pieces, hasLength(2));
      final more = pieces.singleWhere((piece) => piece.eventId == null);
      expect(more.more, 2);
      expect(more.slot, 1);
    });

    test('an event running on past the week is cut square there', () {
      final pieces = layout([
        CalendarEvent(
          id: 'long',
          title: 'long',
          start: DateTime(2026, 11, 6),
          end: DateTime(2026, 11, 10),
          allDay: true,
          invite: const EventInvite(id: 'long', colors: [Color(0xFF34C759)]),
        ),
      ]);
      expect(pieces.single.endColumn, 6);
      expect(pieces.single.continuesAfter, isTrue);
    });

    test('stacked cells never overlap and stay inside the week', () {
      const piece = SharedPiece(
        eventId: 'a',
        startColumn: 0,
        endColumn: 0,
        slot: 0,
        slots: 2,
      );
      const lower = SharedPiece(
        eventId: 'b',
        startColumn: 0,
        endColumn: 0,
        slot: 1,
        slots: 2,
      );
      final top = sharedPieceRect(piece, 50, 120);
      final bottom = sharedPieceRect(lower, 50, 120);
      expect(top.bottom, lessThanOrEqualTo(bottom.top));
      expect(top.top, greaterThanOrEqualTo(0));
      expect(bottom.bottom, lessThanOrEqualTo(120));
    });
  });

  group('the accordion fold', () {
    test('lanes keep their order and gaps at every step', () {
      const line = 0.0;
      const height = 15.0;
      const slot = 17.0;
      for (var away = 0.0; away <= 1.0; away += 0.05) {
        final shown = chipShownAt(away);
        double topOf(int lane) {
          final homeTop = 40 + lane * slot;
          return line + (homeTop - line) * shown;
        }

        for (var lane = 0; lane < 4; lane++) {
          final bottom = topOf(lane) + height * shown;
          expect(bottom, lessThanOrEqualTo(topOf(lane + 1) + 1e-9));
        }
      }
    });

    test('the transform squeezes towards the line', () {
      final matrix = chipFoldTransform(shown: 0.5, homeTop: 40, line: 0);
      final top = MatrixUtils.transformPoint(matrix, Offset.zero);
      expect(top.dy, closeTo(-20, 1e-9));
    });

    test('titles are gone before the chip is squeezed much', () {
      expect(chipTitleAlpha(1), 1);
      expect(chipTitleAlpha(chipTitleGone), 0);
      expect(chipTitleAlpha(0.3), 0);
    });
  });

  test('a day with less room shows fewer chips and "+N"', () {
    final events = [
      for (var i = 0; i < 5; i++)
        CalendarEvent(
          id: 'e$i',
          title: 'e$i',
          start: DateTime(2026, 11, 3, 9 + i),
          end: DateTime(2026, 11, 3, 10 + i),
        ),
    ];
    final layout = layoutWeek(
      events: events,
      days: days,
      visibleStart: 0,
      visibleEnd: 6,
      capacity: 8,
      columnCapacity: [8, 2, 8, 8, 8, 8, 8],
    );
    final column = layout.columns[1];
    expect(column.chips, hasLength(1));
    expect(column.overflowLane, 1);
    expect(column.overflow, 4);
  });

  testWidgets('chips never reach a shared cell\'s faces', (tester) async {
    final today = DateTime.now();
    DateTime at(int hour) => DateTime(today.year, today.month, today.day, hour);
    final dinner = CalendarEvent(
      id: 'dinner',
      title: 'Ужин',
      start: at(19),
      end: at(21),
      invite: const EventInvite(
        id: 'dinner',
        colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
        people: [
          FriendInfo(id: 1, name: 'Катя', username: 'katya'),
          FriendInfo(id: 2, name: 'Маша', username: 'masha'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendar(
            focus: today,
            events: [
              for (var i = 0; i < 8; i++)
                CalendarEvent(
                  id: 'mine$i',
                  title: 'Дело $i',
                  start: at(8 + i),
                  end: at(9 + i),
                ),
            ],
            sharedEvents: [dinner],
            onDayTap: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.byType(FaceStack).first);
    final chips = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          isToneOf(
            (widget.decoration as BoxDecoration).color,
            calendarEventColor,
          ),
    );
    expect(chips, findsWidgets);
    for (final chip in chips.evaluate()) {
      final rect = tester.getRect(find.byWidget(chip.widget));
      if (rect.right <= title.left || rect.left >= title.right) continue;
      expect(rect.bottom, lessThanOrEqualTo(title.top), reason: '$rect');
    }
  });

  test('one friend\'s events on one day are one chip', () {
    CalendarEvent busy(String id, int owner, int from, int to) => CalendarEvent(
      id: id,
      title: '',
      start: DateTime(2026, 11, 4, from),
      end: DateTime(2026, 11, 4, to),
      ownerId: owner,
      color: const Color(0xFF30C8D6),
    );
    final merged = mergeBusyByDay([
      busy('a', 1, 9, 10),
      busy('b', 1, 14, 16),
      busy('c', 2, 11, 12),
    ]);
    expect(merged, hasLength(2));
    final first = merged.singleWhere((event) => event.ownerId == 1);
    expect(first.start, DateTime(2026, 11, 4, 9));
    expect(first.end, DateTime(2026, 11, 4, 16));
  });

  test('a friend\'s event over days takes in the one on its day', () {
    final merged = mergeBusyByDay([
      CalendarEvent(
        id: 'trip',
        title: '',
        start: DateTime(2026, 11, 19, 10),
        end: DateTime(2026, 11, 21, 18),
        ownerId: 1,
      ),
      CalendarEvent(
        id: 'lunch',
        title: '',
        start: DateTime(2026, 11, 19, 13),
        end: DateTime(2026, 11, 19, 14),
        ownerId: 1,
      ),
      CalendarEvent(
        id: 'later',
        title: '',
        start: DateTime(2026, 11, 22, 13),
        end: DateTime(2026, 11, 22, 14),
        ownerId: 1,
      ),
    ]);
    expect(merged, hasLength(2));
    final bar = merged.singleWhere((event) => event.allDay);
    expect(eventFirstDay(bar), DateTime(2026, 11, 19));
    expect(eventLastDay(bar), DateTime(2026, 11, 21));
  });

  testWidgets('zooming through every density never overflows a chip', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 5);
    final busy = [
      for (var i = 0; i < 6; i++)
        CalendarEvent(
          id: 'm$i',
          title: 'Очень длинное дело $i',
          start: DateTime(2026, 11, 5, 9 + i),
          end: DateTime(2026, 11, 5, 10 + i),
        ),
      CalendarEvent(
        id: 'trip',
        title: 'Поездка',
        start: DateTime(2026, 11, 6),
        end: DateTime(2026, 11, 9),
        allDay: true,
      ),
    ];
    final cell = CalendarEvent(
      id: 'dinner',
      title: 'Ужин',
      start: DateTime(2026, 11, 5, 19),
      end: DateTime(2026, 11, 5, 21),
      invite: const EventInvite(
        id: 'dinner',
        colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
        pending: true,
        people: [FriendInfo(id: 1, name: 'Катя', username: 'katya')],
      ),
    );
    final height = ValueNotifier<double>(monthRowMin);
    addTearDown(height.dispose);
    final grid = MonthWeekGrid(
      strip: MonthStrip(weekIndexOf(day), MonthStripKind.full),
      rowKey: 'w',
      today: day,
      onDayTap: (_) {},
      index: CalendarEventIndex(busy),
      sharedIndex: CalendarEventIndex([cell]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: ValueListenableBuilder<double>(
            valueListenable: height,
            builder: (context, h, _) =>
                SizedBox(width: 402, height: h, child: grid),
          ),
        ),
      ),
    );
    for (final levels in [monthRowLevels, monthRowLevels.reversed]) {
      for (final h in levels) {
        height.value = h;
        // The glide starts on this frame; then mid-glide, then settled.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        expect(tester.takeException(), isNull, reason: '$h');
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.takeException(), isNull, reason: '$h');
      }
    }
  });

  testWidgets('a one-line title fades out before the chip\'s round end', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 5);
    final grid = MonthWeekGrid(
      strip: MonthStrip(weekIndexOf(day), MonthStripKind.full),
      rowKey: 'w',
      today: day,
      onDayTap: (_) {},
      index: CalendarEventIndex([
        CalendarEvent(
          id: 'long',
          title: 'Очень длинное название',
          start: DateTime(2026, 11, 5, 9),
          end: DateTime(2026, 11, 5, 10),
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 402, height: monthRowLevels[1], child: grid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    bool isFill(Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        isToneOf(
          (widget.decoration as BoxDecoration).color,
          calendarEventColor,
        );
    bool isFade(Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).gradient is LinearGradient;
    final chip = tester.getRect(find.byWidgetPredicate(isFill).first);
    final fade = tester.getRect(find.byWidgetPredicate(isFade).first);
    expect(fade.right, lessThanOrEqualTo(chip.right - chip.height / 2 * 0.5));
  });

  test('grid tones: a deep fill and light text of the colour\'s own hue', () {
    for (final color in avatarPalette) {
      final tone = gridTone(color);
      final (_, a, b) = oklab(color);
      final (fillL, fa, fb) = oklab(tone.fill);
      final (inkL, ia, ib) = oklab(tone.ink);
      expect(fillL, closeTo(gridFillLightness, 0.01));
      expect(inkL, inInclusiveRange(gridInkLightnessMin - 0.01, 0.86));
      // Same hue: the angle in the a-b plane barely moves.
      double angle(double x, double y) => math.atan2(y, x);
      double gap(double p, double q) {
        final d = (p - q).abs() % (2 * math.pi);
        return math.min(d, 2 * math.pi - d);
      }

      expect(gap(angle(fa, fb), angle(a, b)), lessThan(0.08), reason: '$color');
      expect(gap(angle(ia, ib), angle(a, b)), lessThan(0.08), reason: '$color');
    }
  });

  testWidgets('a day opened right after a pinch closes back on its week', (
    tester,
  ) async {
    final today = DateTime(2026, 11, 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendar(focus: today, onDayTap: (_, _) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final month = tester.state<MonthCalendarState>(find.byType(MonthCalendar));
    final index = stripIndexOfDay(today);
    double rowOf() => month.rectForStrip(index)!.height;

    // Pinch the rows taller, then let go: the rows settle on a level.
    final centre = tester.getCenter(find.byType(MonthCalendar));
    final a = await tester.startGesture(centre - const Offset(0, 40));
    final b = await tester.startGesture(centre + const Offset(0, 40));
    await tester.pump();
    await a.moveBy(const Offset(0, -60));
    await b.moveBy(const Offset(0, 60));
    await tester.pump();
    await b.up();
    await tester.pump(const Duration(milliseconds: 30));

    // A tap opens the day mid-settle: it ends at once and is saved in rows.
    month.finishRowSnap();
    await tester.pump();
    final settled = rowOf();
    expect(monthRowLevels, contains(settled));
    final rows = month.scrollUnits;
    await a.up();
    await tester.pumpAndSettle();
    expect(rowOf(), settled, reason: 'no settling after it was finished');

    final title = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('month-title')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    // The rows change again while the day is open (another level);
    // restored in rows, the month shows the same week where it was.
    final c = await tester.startGesture(centre - const Offset(0, 80));
    final d = await tester.startGesture(centre + const Offset(0, 80));
    await tester.pump();
    await c.moveBy(const Offset(0, 50));
    await d.moveBy(const Offset(0, -50));
    await tester.pump();
    await c.up();
    await d.up();
    await tester.pumpAndSettle();
    expect(rowOf(), isNot(settled));
    month.restoreUnits(rows);
    await tester.pump();
    expect(month.scrollUnits, closeTo(rows, 0.01));
    expect(find.text(title), findsOneWidget, reason: 'not years away');
  });

  testWidgets('a chip running on into the next week fades out there', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 5);
    final grid = MonthWeekGrid(
      strip: MonthStrip(weekIndexOf(day), MonthStripKind.full),
      rowKey: 'w',
      today: day,
      onDayTap: (_) {},
      index: CalendarEventIndex([
        CalendarEvent(
          id: 'trip',
          title: 'Поездка',
          start: DateTime(2026, 11, 7),
          end: DateTime(2026, 11, 10),
          allDay: true,
        ),
      ]),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 402, height: monthRowLevels[1], child: grid),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final faded = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<LinearGradient>()
        .where((gradient) => gradient.colors.length == 4);
    expect(faded, isNotEmpty);
    expect(faded.first.colors.first.a, 1);
    expect(faded.first.colors.last.a, 0);
  });

  testWidgets('chips grow to the next density only when it shows more', (
    tester,
  ) async {
    final day = DateTime(2026, 11, 5);
    Future<double> chipHeight(String title, {bool allDay = false}) async {
      final grid = MonthWeekGrid(
        key: UniqueKey(),
        strip: MonthStrip(weekIndexOf(day), MonthStripKind.full),
        rowKey: 'w',
        today: day,
        onDayTap: (_) {},
        index: CalendarEventIndex([
          CalendarEvent(
            id: 'e',
            title: title,
            start: allDay ? day : DateTime(2026, 11, 5, 9),
            end: allDay ? day : DateTime(2026, 11, 5, 10),
            allDay: allDay,
          ),
        ]),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 402, height: monthRowMax, child: grid),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester
          .getRect(
            find
                .byWidgetPredicate(
                  (widget) =>
                      widget is DecoratedBox &&
                      isToneOf(
                        (widget.decoration as BoxDecoration?)?.color,
                        calendarEventColor,
                      ),
                )
                .first,
          )
          .height;
    }

    // A short title fits one line: the title-and-time chip, not the tall.
    expect(await chipHeight('Сон'), detailDensity.itemHeight);
    // A long one needs the second line: the tall chip.
    expect(
      await chipHeight('Очень длинное название встречи'),
      fullDensity.itemHeight,
    );
    // All day, no time to show: the title chip.
    expect(await chipHeight('Отпуск', allDay: true), titleDensity.itemHeight);
  });

  testWidgets('a shared cell stays put while the mode changes', (tester) async {
    final mode = ValueNotifier<double>(0);
    addTearDown(mode.dispose);
    final today = DateTime.now();
    final event = CalendarEvent(
      id: 'dinner',
      title: 'Ужин',
      start: DateTime(today.year, today.month, today.day, 19),
      end: DateTime(today.year, today.month, today.day, 21),
      invite: const EventInvite(
        id: 'dinner',
        colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SharedCells(
            events: [event],
            child: MonthCalendar(
              focus: today,
              sharedEvents: [event],
              mode: mode,
              onDayTap: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final cell = find.byType(SharedCellBack).first;
    final before = tester.getRect(cell);
    for (final t in [0.25, 0.5, 0.75, 1.0]) {
      mode.value = t;
      await tester.pump();
      expect(tester.getRect(cell), before, reason: '$t');
    }
  });

  testWidgets('an unanswered cell shows "+" and the faces, no title', (
    tester,
  ) async {
    final today = DateTime.now();
    final event = CalendarEvent(
      id: 'skate',
      title: 'Каток',
      start: DateTime(today.year, today.month, today.day, 19),
      end: DateTime(today.year, today.month, today.day, 21),
      invite: const EventInvite(
        id: 'skate',
        colors: [Color(0xFF34C759), Color(0xFFFF2D78)],
        pending: true,
        people: [
          FriendInfo(id: 1, name: 'Катя', username: 'katya'),
          FriendInfo(id: 2, name: 'Маша', username: 'masha'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MonthCalendar(
            focus: today,
            sharedEvents: [event],
            onDayTap: (_, _) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Каток'), findsNothing);
    final faces = find.byType(FaceStack).first;
    expect(faces, findsOneWidget);

    // "+" stands halfway between the day number and the faces.
    final plus = tester.getRect(
      find.byKey(const ValueKey('shared-plus')).first,
    );
    final week = tester.getRect(
      find.ancestor(of: faces, matching: find.byType(MonthWeekGrid)).first,
    );
    final numberBottom = week.top + dayNumberTop + dayNumberSize;
    final facesTop = tester.getRect(faces).top;
    expect(plus.center.dy, closeTo((numberBottom + facesTop) / 2, 0.5));
  });
}

/// A chip's fill or ink is one of [base]'s grid tones ([gridTone]).
bool isToneOf(Color? color, Color base) =>
    color == gridTone(base).fill || color == gridTone(base).ink;
