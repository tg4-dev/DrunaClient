import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_detail.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_column.dart';
import 'package:druna_app/features/friends/friend_schedule.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('busySpansOnDay', () {
    final day = DateTime(2026, 6, 25);
    CalendarEvent at(String id, int from, int to) => CalendarEvent(
      id: id,
      title: '',
      start: DateTime(2026, 6, 25, from),
      end: DateTime(2026, 6, 25, to),
    );

    test('joins overlapping and touching events', () {
      expect(
        busySpansOnDay([at('a', 9, 11), at('b', 10, 12), at('c', 12, 13)], day),
        [const BusySpan(9, 13)],
      );
    });

    test('keeps gaps between events', () {
      expect(busySpansOnDay([at('a', 14, 17), at('b', 9, 11)], day), [
        const BusySpan(9, 11),
        const BusySpan(14, 17),
      ]);
    });

    test('marks a span that goes on into the next day', () {
      final late = CalendarEvent(
        id: 'n',
        title: '',
        start: DateTime(2026, 6, 25, 22),
        end: DateTime(2026, 6, 26, 2),
      );
      expect(busySpansOnDay([late], day), [
        const BusySpan(22, 24, continuesAfter: true),
      ]);
    });
  });

  test('myBandRuns: first title and how many more', () {
    CalendarEvent at(String id, int from, int to) => CalendarEvent(
      id: id,
      title: id,
      start: DateTime(2026, 6, 25, from),
      end: DateTime(2026, 6, 25, to),
    );
    final runs = myBandRuns([at('b', 10, 12), at('a', 9, 11), at('c', 14, 15)]);
    expect(
      [for (final run in runs) (run.first.title, run.more)],
      [('a', 1), ('c', 0)],
    );
  });

  group('folding into the stack', () {
    const geometry = DayFriendsGeometry(
      height: 800,
      bottomInset: 40,
      rows: 8,
      stackSlots: 3,
    );
    double top(int row, double fold, {double offset = 0}) => geometry.avatarTop(
      row: row.toDouble(),
      stack: row,
      offset: offset,
      fold: fold,
    );

    test('starts on the rows and ends in the stack', () {
      for (var row = 0; row < 3; row++) {
        expect(
          top(row, 0),
          geometry.rowTop(row) + DayFriendsGeometry.avatarInset,
        );
        expect(top(row, 1), geometry.stackTop(row));
      }
    });

    test('slides down with the finger, never back up', () {
      for (var row = 0; row < 3; row++) {
        var last = top(row, 0);
        for (var i = 1; i <= 100; i++) {
          final now = top(row, i / 100);
          expect(now, greaterThanOrEqualTo(last - 1e-9));
          last = now;
        }
      }
      final step = top(0, 0.2) - top(0, 0.1);
      expect(top(2, 0.2) - top(2, 0.1), closeTo(step, 0.5));
      expect(step, greaterThan(0));
    });

    test('gaps close towards the end, the lowest settling first', () {
      double gap(double fold) => top(1, fold) - top(0, fold);
      expect(gap(0.3), closeTo(DayFriendsGeometry.rowStep, 0.5));
      expect(gap(0.9), lessThan(gap(0.5)));
      expect(gap(1), DayFriendsGeometry.stackStep);
      expect(top(2, 0.9), closeTo(geometry.stackTop(2), 1));
      expect(top(0, 0.9), lessThan(geometry.stackTop(0) - 5));
    });
  });

  group('open day with friends', () {
    Future<DateTime> busiestDayThisWeek(WidgetTester tester) async {
      final friends = [
        for (var i = 0; i < 3; i++)
          tester.widget<RingedAvatar>(find.byType(RingedAvatar).at(i)).friend,
      ];
      final schedule = DemoFriendSchedule();
      final events = <CalendarEvent>[
        for (final friend in friends)
          ...await tester.runAsync(() => schedule.eventsOf(friend)) ??
              const <CalendarEvent>[],
      ];
      final monday = mondayOfWeek(weekIndexOf(DateTime.now()));
      var best = dateOnly(DateTime.now());
      var most = 0;
      for (var i = 0; i < 7; i++) {
        final day = addCalendarDays(monday, i);
        final count = busySpansOnDay(events, day).length;
        if (count > most) {
          most = count;
          best = day;
        }
      }
      return best;
    }

    Future<void> openDay(
      WidgetTester tester, {
      double height = 2622,
      bool busy = false,
    }) async {
      tester.view.physicalSize = Size(1206, height);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final store = MemoryTokenStore();
      final repository = DrunaRepository(
        ApiClient(
          baseUrl: 'https://example.test',
          tokenStore: store,
          dio: Dio(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: HomePager(
            session: SessionController(repository),
            settings: AppSettings(
              storage: MemorySettingsStorage(),
              demoByDefault: true,
            ),
            config: const AppConfig(apiBaseUrl: 'https://example.test'),
            demoDelay: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(RingedAvatar).at(i));
        await tester.pumpAndSettle();
      }
      final day = busy ? await busiestDayThisWeek(tester) : DateTime.now();
      await tester.tap(
        find.byKey(ValueKey('day-${day.year}-${day.month}-${day.day}')),
      );
      await tester.pumpAndSettle();
    }

    Finder columnAvatars() => find.descendant(
      of: find.byType(FriendColumn),
      matching: find.byType(RingedAvatar),
    );
    final folded = find.byKey(const ValueKey('friend-column-stack'));

    Future<void> pull(WidgetTester tester, double dy) async {
      await tester.timedDragFrom(
        const Offset(250, 500),
        Offset(0, dy),
        const Duration(milliseconds: 400),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('friends stand level with their rows', (tester) async {
      await openDay(tester);

      expect(find.byType(DayDetail), findsOneWidget);
      expect(folded, findsNothing);
      final timeline = tester.getRect(find.byType(DayDetail));
      final tops = [
        for (final element in columnAvatars().evaluate())
          tester.getRect(find.byWidget(element.widget)).top - timeline.top,
      ]..sort();
      for (var i = 0; i < tops.length; i++) {
        expect(
          tops[i],
          closeTo(
            DayFriendsGeometry.friendsTop +
                DayFriendsGeometry.avatarInset +
                i * DayFriendsGeometry.rowStep,
            0.5,
          ),
        );
      }
    });

    testWidgets('rows and the column scroll together, then a pull past the '
        'top switches to my calendar', (tester) async {
      await openDay(tester, height: 2000);
      final before = tester.getRect(columnAvatars().last).top;

      await pull(tester, -120);
      final after = tester.getRect(columnAvatars().last).top;
      expect(after, lessThan(before));
      expect(folded, findsNothing);

      await pull(tester, before - after + 200);
      expect(folded, findsOneWidget);
    });

    testWidgets('a drag up in my calendar brings friends back', (tester) async {
      await openDay(tester);
      await pull(tester, 200);
      expect(folded, findsOneWidget);

      await pull(tester, -200);
      expect(folded, findsNothing);
    });

    testWidgets('mid-switch, each friend\'s bar keeps level with them', (
      tester,
    ) async {
      await openDay(tester, busy: true);
      final bars = find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            RegExp(r'^friend-\d+-').hasMatch(key.value);
      });
      expect(bars, findsWidgets);
      Finder barOf(Element element) => find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(DecoratedBox),
      );
      final rest = [
        for (final element in bars.evaluate())
          tester.getRect(barOf(element)).top,
      ];

      final gesture = await tester.startGesture(const Offset(250, 500));
      for (var i = 0; i < 7; i++) {
        await gesture.moveBy(const Offset(0, 10));
        await tester.pump();
      }
      for (final element in bars.evaluate()) {
        final key = (element.widget.key! as ValueKey<String>).value;
        final owner = int.parse(key.split('-')[1]);
        final avatar = find.descendant(
          of: find.byType(FriendColumn),
          matching: find.byWidgetPredicate(
            (widget) => widget is RingedAvatar && widget.friend.id == owner,
          ),
        );
        final bar = barOf(element);
        expect(
          tester.getRect(bar).top,
          closeTo(
            tester.getRect(avatar).top - DayFriendsGeometry.avatarInset,
            0.5,
          ),
        );
      }
      final moved = [
        for (final element in bars.evaluate())
          tester.getRect(barOf(element)).top,
      ];
      for (var i = 0; i < rest.length; i++) {
        expect(moved[i] - rest[i], greaterThan(20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      for (final element in bars.evaluate()) {
        expect(
          tester.getRect(barOf(element)).height,
          DayFriendsGeometry.avatar,
        );
      }
    });

    testWidgets('a tap on my band shows my events, on the stack friends', (
      tester,
    ) async {
      await openDay(tester);
      await tester.tap(find.byKey(const ValueKey('day-my-band')));
      await tester.pumpAndSettle();
      expect(folded, findsOneWidget);

      await tester.tap(folded);
      await tester.pumpAndSettle();
      expect(folded, findsNothing);
    });

    testWidgets('in my calendar a chevron over the stack points up to '
        'friends, and takes a tap', (tester) async {
      await openDay(tester);
      final hint = find.byKey(const ValueKey('day-swipe-hint'));
      await tester.tap(find.byKey(const ValueKey('day-my-band')));
      await tester.pumpAndSettle();
      final stack = tester.getRect(folded);
      final chevron = tester.getRect(hint);
      expect(chevron.bottom, lessThanOrEqualTo(stack.top + 8));
      expect(chevron.top, greaterThan(0));

      await tester.tap(hint);
      await tester.pumpAndSettle();
      expect(folded, findsNothing);
    });
  });

  testWidgets('titles stick to the edge of the friends column', (tester) async {
    final event = CalendarEvent(
      id: 'long',
      title: 'Тренировка',
      start: DateTime(2026, 10, 31, 8),
      end: DateTime(2026, 10, 31, 20),
    );
    const pixelsPerHour = 40.0;
    const inset = DayFriendsGeometry.columnWidth;
    final offset = timelineX(DateTime(2026, 10, 31, 10), pixelsPerHour);
    await tester.pumpWidget(
      MaterialApp(
        home: Stack(
          children: [
            Positioned.fill(
              child: DayTitleOverlay(
                events: [event],
                lanes: const {'long': 0},
                scrollOffset: offset,
                pixelsPerHour: pixelsPerHour,
                viewportWidth: 400,
                leftInset: inset,
              ),
            ),
          ],
        ),
      ),
    );
    expect(
      tester.getRect(find.textContaining('Тренировка')).left,
      greaterThanOrEqualTo(inset),
    );
  });
}
