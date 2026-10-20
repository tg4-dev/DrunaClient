import 'package:druna_app/features/calendar/month_layout.dart';

enum RepeatUnit { day, week, month, year }

/// The choice shown in the repeat list. [custom] is "Дополнительно".
enum RepeatPreset { daily, weekly, biweekly, monthly, yearly, custom }

const repeatPresetLabels = {
  RepeatPreset.daily: 'Каждый день',
  RepeatPreset.weekly: 'Каждую неделю',
  RepeatPreset.biweekly: 'Каждые 2 недели',
  RepeatPreset.monthly: 'Каждый месяц',
  RepeatPreset.yearly: 'Каждый год',
  RepeatPreset.custom: 'Дополнительно',
};

const repeatIntervalMax = 99;

class RepeatRule {
  const RepeatRule({
    required this.preset,
    required this.unit,
    required this.interval,
    this.weekdays = const {},
    this.until,
  });

  /// [day] seeds the weekday for weekly rules.
  factory RepeatRule.fromPreset(RepeatPreset preset, DateTime day) {
    final weekday = {day.weekday};
    return switch (preset) {
      RepeatPreset.daily => const RepeatRule(
        preset: RepeatPreset.daily,
        unit: RepeatUnit.day,
        interval: 1,
      ),
      RepeatPreset.weekly => RepeatRule(
        preset: RepeatPreset.weekly,
        unit: RepeatUnit.week,
        interval: 1,
        weekdays: weekday,
      ),
      RepeatPreset.biweekly => RepeatRule(
        preset: RepeatPreset.biweekly,
        unit: RepeatUnit.week,
        interval: 2,
        weekdays: weekday,
      ),
      RepeatPreset.monthly => const RepeatRule(
        preset: RepeatPreset.monthly,
        unit: RepeatUnit.month,
        interval: 1,
      ),
      RepeatPreset.yearly => const RepeatRule(
        preset: RepeatPreset.yearly,
        unit: RepeatUnit.year,
        interval: 1,
      ),
      RepeatPreset.custom => RepeatRule(
        preset: RepeatPreset.custom,
        unit: RepeatUnit.week,
        interval: 1,
        weekdays: weekday,
      ),
    };
  }

  final RepeatPreset preset;
  final RepeatUnit unit;
  final int interval;

  /// ISO weekdays (1 = Monday) for weekly rules; empty means the first day's.
  final Set<int> weekdays;

  /// Last day an occurrence may start on, inclusive. Null repeats forever.
  final DateTime? until;

  bool get usesWeekdays => unit == RepeatUnit.week;

  RepeatRule copyWith({
    RepeatPreset? preset,
    RepeatUnit? unit,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
  }) {
    return RepeatRule(
      preset: preset ?? this.preset,
      unit: unit ?? this.unit,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      until: clearUntil ? null : until ?? this.until,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RepeatRule &&
      other.preset == preset &&
      other.unit == unit &&
      other.interval == interval &&
      other.until == until &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode => Object.hash(
    preset,
    unit,
    interval,
    until,
    Object.hashAllUnordered(weekdays),
  );
}

/// First days of the series that fall in [from]…[to], inclusive.
///
/// [first] is the series' own first day and is always an occurrence. Monthly
/// and yearly rules skip months without that date, so a series on the 31st
/// only lands on months that have one.
List<DateTime> repeatDaysBetween({
  required RepeatRule rule,
  required DateTime first,
  required DateTime from,
  required DateTime to,
}) {
  final start = dateOnly(first);
  final rangeStart = dateOnly(from);
  var rangeEnd = dateOnly(to);
  final until = rule.until;
  if (until != null && dateOnly(until).isBefore(rangeEnd)) {
    rangeEnd = dateOnly(until);
  }
  if (rangeEnd.isBefore(start) || rangeEnd.isBefore(rangeStart)) return [];
  final interval = rule.interval.clamp(1, repeatIntervalMax);
  final days = <DateTime>[];

  bool keep(DateTime day) =>
      !day.isBefore(start) &&
      !day.isBefore(rangeStart) &&
      !day.isAfter(rangeEnd);

  switch (rule.unit) {
    case RepeatUnit.day:
      final skipped = calendarDaysBetween(start, rangeStart);
      var step = skipped <= 0 ? 0 : skipped ~/ interval;
      while (true) {
        final day = addCalendarDays(start, step * interval);
        if (day.isAfter(rangeEnd)) break;
        if (keep(day)) days.add(day);
        step++;
      }
    case RepeatUnit.week:
      final weekdays = rule.weekdays.isEmpty
          ? {start.weekday}
          : (rule.weekdays.toList()..sort());
      final anchor = addCalendarDays(start, 1 - start.weekday);
      final skippedWeeks = calendarDaysBetween(anchor, rangeStart) ~/ 7;
      var step = skippedWeeks <= 0 ? 0 : skippedWeeks ~/ interval;
      while (true) {
        final monday = addCalendarDays(anchor, step * interval * 7);
        if (monday.isAfter(rangeEnd)) break;
        for (final weekday in weekdays) {
          final day = addCalendarDays(monday, weekday - 1);
          if (keep(day)) days.add(day);
        }
        step++;
      }
    case RepeatUnit.month:
    case RepeatUnit.year:
      final months = rule.unit == RepeatUnit.month ? interval : interval * 12;
      final skipped =
          (rangeStart.year - start.year) * 12 + rangeStart.month - start.month;
      var step = skipped <= 0 ? 0 : skipped ~/ months;
      while (true) {
        final month = DateTime(start.year, start.month + step * months);
        if (month.isAfter(rangeEnd)) break;
        final day = DateTime(month.year, month.month, start.day);
        if (day.month == month.month && keep(day)) days.add(day);
        step++;
      }
  }
  return days;
}

String repeatUnitLabel(RepeatUnit unit, int count) => switch (unit) {
  RepeatUnit.day => russianPlural(count, 'день', 'дня', 'дней'),
  RepeatUnit.week => russianPlural(count, 'неделю', 'недели', 'недель'),
  RepeatUnit.month => russianPlural(count, 'месяц', 'месяца', 'месяцев'),
  RepeatUnit.year => russianPlural(count, 'год', 'года', 'лет'),
};

/// "Каждые 3 недели" / "Каждую неделю" for the custom row.
String repeatEveryLabel(RepeatUnit unit, int interval) {
  if (interval == 1) {
    return switch (unit) {
      RepeatUnit.day => 'Каждый день',
      RepeatUnit.week => 'Каждую неделю',
      RepeatUnit.month => 'Каждый месяц',
      RepeatUnit.year => 'Каждый год',
    };
  }
  final every = interval % 10 == 1 && interval % 100 != 11
      ? switch (unit) {
          RepeatUnit.week => 'Каждую',
          _ => 'Каждый',
        }
      : 'Каждые';
  return '$every $interval ${repeatUnitLabel(unit, interval)}';
}

String russianPlural(int count, String one, String few, String many) {
  final mod100 = count.abs() % 100;
  final mod10 = mod100 % 10;
  if (mod100 >= 11 && mod100 <= 14) return many;
  if (mod10 == 1) return one;
  if (mod10 >= 2 && mod10 <= 4) return few;
  return many;
}
