import 'package:druna_app/features/calendar/repeat_rule.dart';

/// Months as the event page writes them: three letters and a dot, May in
/// full since it is three letters already.
const _months = [
  'янв.',
  'фев.',
  'мар.',
  'апр.',
  'мая',
  'июн.',
  'июл.',
  'авг.',
  'сен.',
  'окт.',
  'ноя.',
  'дек.',
];

/// "31 окт.", "2 ноя.", "5 мая".
String shortDateLabel(DateTime day) => '${day.day} ${_months[day.month - 1]}';

const _monthsOf = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

/// "31 октября": one day, written out above its times.
String fullDateLabel(DateTime day) => '${day.day} ${_monthsOf[day.month - 1]}';

/// How long, in the pill between the times: the first unit in full, the
/// second short — "45 минут", "2 часа", "2 часа 30 м", "1 день",
/// "1 день 2 ч". Minutes are dropped next to days.
String durationPillLabel(DateTime start, DateTime end) {
  var minutes = end.difference(start).inMinutes;
  if (minutes < 0) minutes = 0;
  final days = minutes ~/ (24 * 60);
  final hours = minutes % (24 * 60) ~/ 60;
  final rest = minutes % 60;
  if (days > 0) {
    final word = russianPlural(days, 'день', 'дня', 'дней');
    return hours > 0 ? '$days $word $hours ч' : '$days $word';
  }
  if (hours > 0) {
    final word = russianPlural(hours, 'час', 'часа', 'часов');
    return rest > 0 ? '$hours $word $rest м' : '$hours $word';
  }
  return '$rest ${russianPlural(rest, 'минута', 'минуты', 'минут')}';
}

/// What the repeat block says after "Повтор:".
String repeatSummaryLabel(RepeatRule rule) => switch (rule.preset) {
  RepeatPreset.daily => 'Каждый день',
  RepeatPreset.weekly => 'По неделям',
  RepeatPreset.biweekly => 'Раз в 2 недели',
  RepeatPreset.monthly => 'Каждый месяц',
  RepeatPreset.yearly => 'Каждый год',
  RepeatPreset.custom => repeatEveryLabel(rule.unit, rule.interval),
};
