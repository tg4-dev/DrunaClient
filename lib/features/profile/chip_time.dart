import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/event_page/event_labels.dart';

typedef ChipTime = ({
  String? caption,
  String left,
  String middle,
  String right,
  bool span,
});

DateTime chipLastDay(DateTime start, DateTime end) {
  final midnight =
      end.hour == 0 &&
      end.minute == 0 &&
      end.second == 0 &&
      end.millisecond == 0 &&
      end.microsecond == 0;
  if (midnight && end.isAfter(start)) {
    return dateOnly(end.subtract(const Duration(microseconds: 1)));
  }
  return dateOnly(end);
}

ChipTime chipTime(DateTime start, DateTime end, {required bool allDay}) {
  final first = dateOnly(start);
  final last = chipLastDay(start, end);
  if (!last.isAfter(first)) {
    return (
      caption: null,
      left: '${first.day} ${weekdayShort(first)}'.toUpperCase(),
      middle: allDay ? 'весь день' : clockLabel(start),
      right: monthShort(first).toUpperCase(),
      span: false,
    );
  }
  final caption = first.month == last.month && first.year == last.year
      ? monthNames[first.month - 1].toUpperCase()
      : '${monthShort(first)} – ${monthShort(last)}'.toUpperCase();
  final String middle;
  if (allDay) {
    final days = calendarDaysBetween(first, last) + 1;
    middle = '$days ${russianPlural(days, 'день', 'дня', 'дней')}';
  } else {
    middle = durationPillLabel(start, end);
  }
  return (
    caption: caption,
    left: _dayMonth(first),
    middle: middle,
    right: _dayMonth(last),
    span: true,
  );
}

String _dayMonth(DateTime day) =>
    '${day.day.toString().padLeft(2, '0')}.${day.month.toString().padLeft(2, '0')}';
