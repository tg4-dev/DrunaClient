import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_sheet.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final meeting = CalendarEvent(
    id: 'meet',
    title: 'Встреча',
    start: DateTime(2026, 10, 7, 16),
    end: DateTime(2026, 10, 7, 20),
  );

  Future<void> pumpSheet(
    WidgetTester tester, {
    ValueChanged<CalendarEvent>? onSave,
    VoidCallback? onCancel,
  }) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: EventDurationSheet(
          event: meeting,
          onSave: onSave ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Finder switchIn(String label) => find.descendant(
    of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
    matching: find.byType(AdaptiveSwitch),
  );

  testWidgets('the card and the time block match the reference', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(find.text('Мои события'), findsOneWidget);
    expect(find.text('Ср, 7 окт'), findsOneWidget);
    expect(find.text('16:00-20:00'), findsOneWidget);
    expect(find.text('4 часа'), findsOneWidget);
    expect(find.text('Начало'), findsOneWidget);
    expect(find.text('Конец'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
    expect(find.text('20:00'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
    expect(tester.takeException(), isNull);

    tester.view.viewInsets = const FakeViewPadding(bottom: 1008);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(find.text('16:00-20:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one set of wheels opens at a time', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.byKey(const ValueKey('event-start')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-end')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-end')));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });

  testWidgets('all-day hides the times', (tester) async {
    await pumpSheet(tester);

    await tester.tap(switchIn('Весь день'));
    await tester.pumpAndSettle();

    expect(find.text('Начало'), findsNothing);
    expect(find.text('16:00-20:00'), findsNothing);
  });

  Future<void> pickRepeat(WidgetTester tester, String label) async {
    final menu = find.byKey(const ValueKey('repeat-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(CupertinoActionSheet),
        matching: find.text(label),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> turnRepeatOn(WidgetTester tester) async {
    final toggle = switchIn('Повтор');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
  }

  testWidgets('the card stays put; the blocks move under it', (tester) async {
    await pumpSheet(tester);
    final card = tester.getRect(find.text('Мои события'));
    expect(card.top, lessThan(tester.getRect(find.text('Весь день')).top));

    tester.view.viewInsets = const FakeViewPadding(bottom: 1008);
    addTearDown(tester.view.resetViewInsets);
    await tester.pump();
    expect(tester.getRect(find.text('Мои события')), card);

    await turnRepeatOn(tester);
    expect(tester.getRect(find.text('Мои события')), card);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pulling the blocks down scrolls; only the card closes', (
    tester,
  ) async {
    CalendarEvent? saved;
    await pumpSheet(tester, onSave: (event) => saved = event);

    await tester.drag(find.text('Весь день'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Мои события'), findsOneWidget);

    await tester.drag(find.text('Мои события'), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
  });

  testWidgets('the repeat switch opens the frequency menu', (tester) async {
    await pumpSheet(tester);

    expect(find.byKey(const ValueKey('repeat-menu')), findsNothing);
    await turnRepeatOn(tester);

    expect(find.text('Как часто'), findsOneWidget);
    expect(find.text('Каждую неделю'), findsOneWidget);
    expect(find.byKey(const ValueKey('weekday-3')), findsOneWidget);
    expect(find.text('Окончание повтора'), findsOneWidget);

    final menu = find.byKey(const ValueKey('repeat-menu'));
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    final sheet = find.byType(CupertinoActionSheet);
    for (final label in repeatPresetLabels.values) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: sheet, matching: find.text('Никогда')),
      findsNothing,
    );
    await tester.tap(find.byType(CupertinoActionSheetAction).last);
    await tester.pumpAndSettle();

    await pickRepeat(tester, 'Дополнительно');
    expect(find.text('Интервал'), findsOneWidget);

    await pickRepeat(tester, 'Каждый месяц');
    expect(find.byKey(const ValueKey('weekday-3')), findsNothing);
    expect(find.text('Интервал'), findsNothing);

    await turnRepeatOn(tester);
    expect(find.text('Как часто'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saving returns the edited event with its rule', (tester) async {
    CalendarEvent? saved;
    await pumpSheet(tester, onSave: (event) => saved = event);

    await turnRepeatOn(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('weekday-5')));
    await tester.tap(find.byKey(const ValueKey('weekday-5')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sheet-save')));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.start, meeting.start);
    expect(saved!.end, meeting.end);
    expect(saved!.repeat?.preset, RepeatPreset.weekly);
    expect(saved!.repeat?.weekdays, {DateTime.wednesday, DateTime.friday});
  });

  testWidgets('a swipe down saves the moment the finger lifts', (tester) async {
    CalendarEvent? saved;
    var gone = false;
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: EventDurationSheet(
          event: meeting,
          onSave: (event) => saved = event,
          onCancel: () {},
          onGone: () => gone = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(CupertinoTextField), 'Ужин');
    await tester.drag(find.text('Мои события'), const Offset(0, 160));
    await tester.pump();

    expect(saved?.title, 'Ужин');
    expect(gone, isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    expect(gone, isTrue);
  });

  testWidgets('a short pull springs back', (tester) async {
    var cancelled = false;
    await pumpSheet(tester, onCancel: () => cancelled = true);
    final before = tester.getTopLeft(find.text('Мои события'));

    await tester.drag(find.text('Мои события'), const Offset(0, 40));
    await tester.pumpAndSettle();

    expect(cancelled, isFalse);
    expect(tester.getTopLeft(find.text('Мои события')), before);
  });

  testWidgets('the title is focused as soon as the sheet opens', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventDurationSheet(
          event: meeting,
          onSave: (_) {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pump();

    final field = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(field.focusNode!.hasFocus, isTrue);
  });

  testWidgets('cancel closes without saving', (tester) async {
    var cancelled = false;
    CalendarEvent? saved;
    await pumpSheet(
      tester,
      onSave: (event) => saved = event,
      onCancel: () => cancelled = true,
    );

    await tester.tap(find.byKey(const ValueKey('sheet-cancel')));
    await tester.pumpAndSettle();

    expect(cancelled, isTrue);
    expect(saved, isNull);
  });
}
