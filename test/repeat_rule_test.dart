import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Wednesday.
  final first = DateTime(2026, 10, 7);

  List<DateTime> days(RepeatRule rule, DateTime from, DateTime to) =>
      repeatDaysBetween(rule: rule, first: first, from: from, to: to);

  test('weekly repeats on the chosen weekdays from the first day', () {
    final rule = RepeatRule.fromPreset(
      RepeatPreset.weekly,
      first,
    ).copyWith(weekdays: {DateTime.monday, DateTime.wednesday});

    expect(days(rule, DateTime(2026, 10, 1), DateTime(2026, 10, 19)), [
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 12),
      DateTime(2026, 10, 14),
      DateTime(2026, 10, 19),
    ]);
  });

  test('every two weeks skips the weeks between', () {
    final rule = RepeatRule.fromPreset(RepeatPreset.biweekly, first);

    expect(days(rule, DateTime(2026, 10, 1), DateTime(2026, 11, 5)), [
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 21),
      DateTime(2026, 11, 4),
    ]);
  });

  test('a far window starts on the right step', () {
    final rule = RepeatRule.fromPreset(RepeatPreset.biweekly, first);

    expect(days(rule, DateTime(2027, 1, 1), DateTime(2027, 1, 14)), [
      DateTime(2027, 1, 13),
    ]);
  });

  test('monthly on the 31st skips shorter months', () {
    final rule = RepeatRule.fromPreset(RepeatPreset.monthly, first);
    final result = repeatDaysBetween(
      rule: rule,
      first: DateTime(2026, 1, 31),
      from: DateTime(2026, 1, 1),
      to: DateTime(2026, 5, 31),
    );

    expect(result, [
      DateTime(2026, 1, 31),
      DateTime(2026, 3, 31),
      DateTime(2026, 5, 31),
    ]);
  });

  test('yearly on 29 February waits for leap years', () {
    final rule = RepeatRule.fromPreset(RepeatPreset.yearly, first);
    final result = repeatDaysBetween(
      rule: rule,
      first: DateTime(2024, 2, 29),
      from: DateTime(2024, 1, 1),
      to: DateTime(2029, 1, 1),
    );

    expect(result, [DateTime(2024, 2, 29), DateTime(2028, 2, 29)]);
  });

  test('the end date is inclusive', () {
    final rule = RepeatRule.fromPreset(
      RepeatPreset.daily,
      first,
    ).copyWith(until: DateTime(2026, 10, 9));

    expect(days(rule, DateTime(2026, 10, 1), DateTime(2026, 10, 31)), [
      DateTime(2026, 10, 7),
      DateTime(2026, 10, 8),
      DateTime(2026, 10, 9),
    ]);
  });

  test('custom every three days', () {
    const rule = RepeatRule(
      preset: RepeatPreset.custom,
      unit: RepeatUnit.day,
      interval: 3,
    );

    expect(days(rule, DateTime(2026, 10, 8), DateTime(2026, 10, 16)), [
      DateTime(2026, 10, 10),
      DateTime(2026, 10, 13),
      DateTime(2026, 10, 16),
    ]);
  });

  test('the index unrolls a series with its own ids', () {
    final series = CalendarEvent(
      id: 'gym',
      title: 'Зал',
      start: DateTime(2026, 10, 7, 19),
      end: DateTime(2026, 10, 7, 20),
      repeat: RepeatRule.fromPreset(RepeatPreset.weekly, first),
    );
    final index = CalendarEventIndex([series]);

    final first14 = index.onDay(DateTime(2026, 10, 14)).single;
    expect(first14.id, 'gym@2026-10-14');
    expect(first14.sourceId, 'gym');
    expect(first14.start, DateTime(2026, 10, 14, 19));
    expect(index.source(first14.id), same(index.events.single));
    expect(index.onDay(DateTime(2026, 10, 7)).single.id, 'gym');
    expect(index.onDay(DateTime(2026, 10, 15)), isEmpty);
  });

  test('labels decline the interval', () {
    expect(repeatEveryLabel(RepeatUnit.week, 1), 'Каждую неделю');
    expect(repeatEveryLabel(RepeatUnit.week, 2), 'Каждые 2 недели');
    expect(repeatEveryLabel(RepeatUnit.day, 5), 'Каждые 5 дней');
    expect(repeatEveryLabel(RepeatUnit.year, 21), 'Каждый 21 год');
    expect(repeatEveryLabel(RepeatUnit.week, 21), 'Каждую 21 неделю');
    expect(repeatEveryLabel(RepeatUnit.month, 11), 'Каждые 11 месяцев');
  });
}
