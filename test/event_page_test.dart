import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/event_page/date_grid.dart';
import 'package:druna_app/features/event_page/event_labels.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/features/event_page/event_span.dart';
import 'package:druna_app/features/event_page/event_subject.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/event_page/time_wheel.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('labels', () {
    test('dates: three lowercase letters and a dot', () {
      expect(shortDateLabel(DateTime(2026, 10, 31)), '31 окт.');
      expect(shortDateLabel(DateTime(2026, 11, 2)), '2 ноя.');
      expect(shortDateLabel(DateTime(2026, 5, 5)), '5 мая');
    });

    test('one day is written out', () {
      expect(fullDateLabel(DateTime(2026, 10, 31)), '31 октября');
      expect(fullDateLabel(DateTime(2026, 5, 1)), '1 мая');
    });

    test('durations: the first unit in full, the second short', () {
      final start = DateTime(2026, 10, 31, 18);
      String after(Duration length) =>
          durationPillLabel(start, start.add(length));
      expect(after(const Duration(minutes: 45)), '45 минут');
      expect(after(const Duration(minutes: 1)), '1 минута');
      expect(after(const Duration(hours: 2)), '2 часа');
      expect(after(const Duration(hours: 2, minutes: 30)), '2 часа 30 м');
      expect(after(const Duration(hours: 5)), '5 часов');
      expect(after(const Duration(days: 1)), '1 день');
      expect(after(const Duration(days: 1, hours: 2)), '1 день 2 ч');
      // Minutes are dropped next to days.
      expect(
        after(const Duration(days: 2, hours: 2, minutes: 30)),
        '2 дня 2 ч',
      );
    });

    test('repeat summaries', () {
      final day = DateTime(2026, 11, 4);
      expect(
        repeatSummaryLabel(RepeatRule.fromPreset(RepeatPreset.weekly, day)),
        'По неделям',
      );
      expect(
        repeatSummaryLabel(RepeatRule.fromPreset(RepeatPreset.daily, day)),
        'Каждый день',
      );
    });
  });

  group('span', () {
    final trip = EventSpan.timed(
      DateTime(2026, 10, 31, 18),
      DateTime(2026, 11, 2, 20),
    );

    test('reads the days and the clocks', () {
      expect(trip.firstDay, DateTime(2026, 10, 31));
      expect(trip.lastDay, DateTime(2026, 11, 2));
      expect(trip.oneDay, isFalse);
      expect(trip.durationLabel, '2 дня 2 ч');
    });

    test('a new first day keeps the length in days', () {
      final moved = trip.withStartDay(DateTime(2026, 11, 7));
      expect(moved.firstDay, DateTime(2026, 11, 7));
      expect(moved.lastDay, DateTime(2026, 11, 9));
      expect(moved.durationLabel, trip.durationLabel);
    });

    test('a new start time keeps the length', () {
      final moved = trip.withStartClock(10, 0);
      expect(moved.start, DateTime(2026, 10, 31, 10));
      expect(moved.end, DateTime(2026, 11, 2, 12));
    });

    test('an end before the start on one day runs past midnight', () {
      final evening = EventSpan.timed(
        DateTime(2026, 11, 1, 22),
        DateTime(2026, 11, 1, 23),
      );
      final late = evening.withEndClock(2, 0);
      expect(late.end, DateTime(2026, 11, 2, 2));
      expect(late.durationLabel, '4 часа');
    });

    test('the last day never comes before the first', () {
      final early = trip.withEndDay(DateTime(2026, 10, 1));
      expect(early.lastDay.isBefore(early.firstDay), isFalse);
      expect(early.end.isAfter(early.start), isTrue);
    });

    test('all day keeps the clocks for later and saves whole days', () {
      final allDay = trip.withAllDay(true);
      expect(allDay.durationLabel, '3 дня');
      expect(
        EventSpan.timed(
          DateTime(2026, 10, 31, 9),
          DateTime(2026, 10, 31, 10),
        ).withAllDay(true).durationLabel,
        'весь день',
      );
      expect(allDay.withAllDay(false).start, trip.start);

      final event = allDay.applyTo(
        CalendarEvent(id: 'trip', title: '', start: trip.start, end: trip.end),
        title: '  Поездка ',
      );
      expect(event.allDay, isTrue);
      expect(event.title, 'Поездка');
      expect(event.start, DateTime(2026, 10, 31));
      expect(event.end, DateTime(2026, 11, 2));
    });
  });

  group('title fit', () {
    // The test font draws every glyph one em wide: "ABCDE" at 10 is 50.
    const style = TextStyle(fontSize: 10, height: 1);

    double widthOf(TitleFit fit, String line) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: style.copyWith(
            fontSize: fit.fontSize,
            letterSpacing: fit.letterSpacing,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final width = painter.width * fit.scaleX;
      painter.dispose();
      return width;
    }

    testWidgets('gives way in order: tracking, squeeze, size, lines', (
      tester,
    ) async {
      final loose = fitTitle('ABCDE', style, 60);
      expect(loose.letterSpacing, 0);
      expect(loose.scaleX, 1);
      expect(loose.fontSize, 10);

      final tracked = fitTitle('ABCDE', style, 48);
      expect(tracked.letterSpacing, lessThan(0));
      expect(
        tracked.letterSpacing,
        greaterThanOrEqualTo(10 * titleMinTrackingEm),
      );
      expect(tracked.scaleX, 1);
      expect(tracked.fontSize, 10);
      expect(widthOf(tracked, 'ABCDE'), closeTo(48, 0.5));

      final squeezed = fitTitle('ABCDE', style, 40);
      expect(squeezed.letterSpacing, 10 * titleMinTrackingEm);
      expect(squeezed.scaleX, lessThan(1));
      expect(squeezed.scaleX, greaterThanOrEqualTo(titleMinScaleX));
      expect(squeezed.fontSize, 10);
      expect(widthOf(squeezed, 'ABCDE'), closeTo(40, 0.5));

      final smaller = fitTitle('ABCDE', style, 34);
      expect(smaller.scaleX, titleMinScaleX);
      expect(smaller.fontSize, lessThan(10));
      expect(smaller.fontSize, greaterThanOrEqualTo(10 * titleMinSizeShare));
      expect(smaller.lines, ['ABCDE']);

      final wrapped = fitTitle('ABCDE FGHIJ', style, 50);
      expect(wrapped.lines, ['ABCDE', 'FGHIJ']);
      expect(wrapped.overflows, isFalse);

      final tooLong = fitTitle('ABCDEFGHIJ', style, 30);
      expect(tooLong.lines, ['ABCDEFGHIJ']);
      expect(tooLong.overflows, isTrue);
    });
  });

  group('page', () {
    const me = FriendInfo(id: 1, name: 'Глеб', username: 'gleb');
    final meeting = CalendarEvent(
      id: 'meet',
      title: 'Встреча',
      start: DateTime(2026, 10, 7, 16),
      end: DateTime(2026, 10, 7, 20),
    );

    Future<void> pumpPage(
      WidgetTester tester,
      EventSubject subject, {
      ValueChanged<CalendarEvent>? onSave,
      VoidCallback? onDelete,
      VoidCallback? onGone,
    }) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: OwnEventColor(
              color: const Color(0xFFE5482D),
              child: EventPage(
                subject: subject,
                me: me,
                onSave: onSave,
                onDelete: onDelete,
                onGone: onGone ?? () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('an own event opens to view, with the pencil', (tester) async {
      await pumpPage(tester, OwnEvent(meeting));

      expect(find.text('Мои события'), findsOneWidget);
      expect(find.bySemanticsLabel('Встреча'), findsOneWidget);
      // One day: its date in full above the times, how long between them.
      expect(find.text('7 октября'), findsOneWidget);
      expect(find.text('7 окт.'), findsNothing);
      expect(find.text('16:00'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget);
      expect(find.text('4 часа'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-edit')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-delete')), findsNothing);
      expect(find.text('Весь день'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a repeating event says how it repeats', (tester) async {
      final weekly = meeting.copyWith(
        repeat: RepeatRule.fromPreset(RepeatPreset.weekly, meeting.start),
      );
      await pumpPage(tester, OwnEvent(weekly));
      expect(find.text('Повтор:'), findsOneWidget);
      expect(find.text('По неделям'), findsOneWidget);
    });

    testWidgets('editing: dates and times become capsules with pickers', (
      tester,
    ) async {
      CalendarEvent? saved;
      await pumpPage(tester, OwnEvent(meeting), onSave: (e) => saved = e);

      await tester.tap(find.byKey(const ValueKey('event-edit')));
      await tester.pumpAndSettle();
      expect(find.text('Весь день'), findsOneWidget);
      expect(find.byKey(const ValueKey('event-delete')), findsOneWidget);
      expect(find.byKey(const ValueKey('event-save')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('when-startTime')));
      await tester.pumpAndSettle();
      expect(find.byType(TimeWheel), findsOneWidget);
      expect(find.text('Время начала'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('when-endDate')));
      await tester.pumpAndSettle();
      expect(find.byType(TimeWheel), findsNothing);
      expect(find.byType(DateGrid), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('grid-day-9')));
      await tester.tap(find.byKey(const ValueKey('grid-day-9')));
      await tester.pumpAndSettle();
      expect(find.text('9 окт.'), findsOneWidget);
      expect(find.text('2 дня 4 ч'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('event-save')));
      await tester.pumpAndSettle();
      expect(saved?.end, DateTime(2026, 10, 9, 20));
      // Saved, the page shows the event again.
      expect(find.byKey(const ValueKey('event-edit')), findsOneWidget);
      expect(find.text('9 окт.'), findsOneWidget);
    });

    testWidgets('editing moves neither the title nor the dates', (
      tester,
    ) async {
      await pumpPage(tester, OwnEvent(meeting));
      final title = tester.getRect(find.byKey(const ValueKey('event-title')));
      final date = tester.getRect(find.byKey(const ValueKey('when-startTime')));

      await tester.tap(find.byKey(const ValueKey('event-edit')));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('event-title-field'));
      expect(tester.getRect(field).size, title.size);
      // "Весь день" opens above the dates: they move down, not sideways.
      final editing = tester.getRect(
        find.byKey(const ValueKey('when-startTime')),
      );
      expect(editing.left, date.left);
      expect(editing.width, date.width);

      // A longer event keeps the times and the pill's middle in place.
      final duration = tester.getRect(
        find.byKey(const ValueKey('when-duration')),
      );
      await tester.tap(find.byKey(const ValueKey('when-endDate')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('grid-day-20')));
      await tester.tap(find.byKey(const ValueKey('grid-day-20')));
      await tester.pumpAndSettle();
      expect(find.text('13 дней 4 ч'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('when-duration')));
      await tester.pumpAndSettle();
      final after = tester.getRect(find.byKey(const ValueKey('when-duration')));
      expect(after.center.dx, closeTo(duration.center.dx, 0.5));
      expect(
        tester.getRect(find.byKey(const ValueKey('when-startTime'))).left,
        editing.left,
      );
    });

    testWidgets('a tap on empty space closes the open month', (tester) async {
      await pumpPage(tester, OwnEvent(meeting));
      await tester.tap(find.byKey(const ValueKey('event-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('when-endDate')));
      await tester.pumpAndSettle();
      expect(find.byType(DateGrid), findsOneWidget);

      // Inside the month taps stay there: the arrows turn the page.
      await tester.tap(find.byKey(const ValueKey('grid-next')));
      await tester.pumpAndSettle();
      expect(find.byType(DateGrid), findsOneWidget);

      // The page's margin beside the dates is empty space.
      final row = tester.getRect(find.byKey(const ValueKey('when-duration')));
      await tester.tapAt(Offset(4, row.center.dy));
      await tester.pumpAndSettle();
      expect(find.byType(DateGrid), findsNothing);
    });

    testWidgets('all day hides the times', (tester) async {
      await pumpPage(tester, OwnEvent(meeting, isNew: true));
      await tester.tap(find.byKey(const ValueKey('when-all-day')));
      await tester.pumpAndSettle();
      expect(find.text('16:00'), findsNothing);
      expect(find.text('весь день'), findsOneWidget);
    });

    testWidgets('a new event opens in editing; a pull saves it', (
      tester,
    ) async {
      CalendarEvent? saved;
      var gone = false;
      await pumpPage(
        tester,
        OwnEvent(meeting.copyWith(title: ''), isNew: true),
        onSave: (e) => saved = e,
        onGone: () => gone = true,
      );
      final field = find.byKey(const ValueKey('sheet-title'));
      expect(field, findsOneWidget);
      expect(tester.widget<TextField>(field).focusNode?.hasFocus, isTrue);

      await tester.enterText(field, 'Каток');
      await tester.fling(
        find.byKey(const ValueKey('event-grabber')),
        const Offset(0, 400),
        1500,
      );
      await tester.pumpAndSettle();
      expect(saved?.title, 'Каток');
      expect(gone, isTrue);
    });

    testWidgets('the bin lets the keyboard go', (tester) async {
      var deleted = false;
      await pumpPage(
        tester,
        OwnEvent(meeting, isNew: true),
        onDelete: () => deleted = true,
      );
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.tap(find.byKey(const ValueKey('event-delete')));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('the bin asks, then deletes', (tester) async {
      var deleted = false;
      await pumpPage(tester, OwnEvent(meeting), onDelete: () => deleted = true);
      await tester.tap(find.byKey(const ValueKey('event-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('event-delete')));
      await tester.pumpAndSettle();
      expect(find.text('Удалить событие?'), findsOneWidget);
      await tester.tap(find.text('Удалить').last);
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
    });
  });
}
