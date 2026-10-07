const monthRowLevels = [52.0, 96.0, 140.0];
const monthRowMin = 52.0;
const monthRowMax = 140.0;
const monthTitleHeight = 58.0;
const weekdayHeaderHeight = 28.0;

/// Extra height of a month-start row, as a fraction of the regular row.
const monthBandRatio = 0.34;
const plainDayPad = 16.0;
const bandDayPad = 8.0;

const monthNames = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

const monthShortNames = [
  'Янв',
  'Фев',
  'Мар',
  'Апр',
  'Май',
  'Июн',
  'Июл',
  'Авг',
  'Сен',
  'Окт',
  'Ноя',
  'Дек',
];

const weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Monday of the first addressable week.
final weekEpoch = DateTime(1970, 1, 5);
const weekCount = 52 * 120;

String monthTitle(DateTime month) =>
    '${monthNames[month.month - 1]} ${month.year}';

String monthLabel(DateTime month) => monthNames[month.month - 1];

String monthShort(DateTime month) => monthShortNames[month.month - 1];

String weekdayShort(DateTime day) => weekdayLabels[day.weekday - 1];

DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whole calendar days between two dates. UTC arithmetic keeps a week at
/// seven dates when local time shifts for daylight saving.
int calendarDaysBetween(DateTime from, DateTime to) {
  final start = DateTime.utc(from.year, from.month, from.day);
  final end = DateTime.utc(to.year, to.month, to.day);
  return end.difference(start).inDays;
}

DateTime addCalendarDays(DateTime day, int days) {
  final shifted = DateTime.utc(
    day.year,
    day.month,
    day.day,
  ).add(Duration(days: days));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int weekIndexOf(DateTime day) {
  final date = dateOnly(day);
  final monday = addCalendarDays(date, 1 - date.weekday);
  return calendarDaysBetween(weekEpoch, monday) ~/ 7;
}

DateTime mondayOfWeek(int index) => addCalendarDays(weekEpoch, index * 7);

List<DateTime> daysOfWeek(int index) {
  final monday = mondayOfWeek(index);
  return [
    for (var column = 0; column < 7; column++) addCalendarDays(monday, column),
  ];
}

/// Month label for a week: the month that begins inside it, otherwise Monday.
DateTime monthOfWeek(int index) {
  for (final day in daysOfWeek(index)) {
    if (day.day == 1) return DateTime(day.year, day.month);
  }
  final monday = mondayOfWeek(index);
  return DateTime(monday.year, monday.month);
}

String weekKeyId(DateTime monday) =>
    'week-${monday.year}-${monday.month}-${monday.day}';

enum MonthStripKind { full, tail, fresh }

class MonthStrip {
  const MonthStrip(this.weekIndex, this.kind);

  final int weekIndex;
  final MonthStripKind kind;
}

/// Extra rows before each week: one per month that does not start on Monday.
final List<int> cutsBeforeWeek = _buildCutsBeforeWeek();

/// Month starts before each week, including months that begin on Monday.
final List<int> monthStartsBeforeWeek = _buildMonthStartsBeforeWeek();

double unitsOfWeek(int weekIndex) {
  final index = weekIndex.clamp(0, weekCount);
  return index +
      cutsBeforeWeek[index] +
      monthStartsBeforeWeek[index] * monthBandRatio;
}

bool weekStartsMonth(int weekIndex) {
  final index = weekIndex.clamp(0, weekCount - 1);
  return monthStartsBeforeWeek[index + 1] > monthStartsBeforeWeek[index];
}

bool stripHasBand(MonthStrip strip) {
  if (strip.kind == MonthStripKind.fresh) return true;
  return strip.kind == MonthStripKind.full && weekStartsMonth(strip.weekIndex);
}

double stripExtentUnits(MonthStrip strip) =>
    stripHasBand(strip) ? 1 + monthBandRatio : 1.0;

double stripUnits(int stripIndex) {
  final strip = stripAt(stripIndex.clamp(0, stripCount - 1));
  final base = unitsOfWeek(strip.weekIndex);
  if (strip.kind == MonthStripKind.fresh) return base + 1;
  return base;
}

int weekAtUnits(double units) {
  var low = 0;
  var high = weekCount - 1;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (unitsOfWeek(mid) <= units) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

int get stripCount => weekCount + cutsBeforeWeek[weekCount];

bool weekIsCut(int weekIndex) {
  final index = weekIndex.clamp(0, weekCount - 1);
  return cutsBeforeWeek[index + 1] > cutsBeforeWeek[index];
}

/// Largest strip whose start is strictly before [units].
///
/// Matches the varied-extent sliver, which treats an exact boundary as the end
/// of the previous row.
int stripIndexForScrollUnits(double units) {
  if (units <= 0) return 0;
  if (units >= unitsOfWeek(weekCount)) return stripCount - 1;
  var low = 0;
  var high = stripCount - 1;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (stripUnits(mid) < units) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

int stripIndexOfWeek(int weekIndex) {
  final index = weekIndex.clamp(0, weekCount);
  return index + cutsBeforeWeek[index];
}

int stripIndexOfDay(DateTime day) {
  final week = weekIndexOf(day).clamp(0, weekCount - 1);
  final base = stripIndexOfWeek(week);
  if (!weekIsCut(week)) return base;
  final first = daysOfWeek(week).indexWhere((item) => item.day == 1);
  final slot = dateOnly(day).weekday - 1;
  return slot >= first ? base + 1 : base;
}

MonthStrip stripAt(int stripIndex) {
  var low = 0;
  var high = weekCount - 1;
  while (low < high) {
    final mid = (low + high + 1) >> 1;
    if (stripIndexOfWeek(mid) <= stripIndex) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  if (!weekIsCut(low)) return MonthStrip(low, MonthStripKind.full);
  if (stripIndex > stripIndexOfWeek(low)) {
    return MonthStrip(low, MonthStripKind.fresh);
  }
  return MonthStrip(low, MonthStripKind.tail);
}

DateTime monthOfStrip(MonthStrip strip) {
  if (strip.kind == MonthStripKind.tail) {
    final monday = mondayOfWeek(strip.weekIndex);
    return DateTime(monday.year, monday.month);
  }
  return monthOfWeek(strip.weekIndex);
}

String stripKeyId(MonthStrip strip) {
  final monday = mondayOfWeek(strip.weekIndex);
  final kind = switch (strip.kind) {
    MonthStripKind.full => 'full',
    MonthStripKind.tail => 'tail',
    MonthStripKind.fresh => 'fresh',
  };
  return '${weekKeyId(monday)}-$kind';
}

List<int> _buildCutsBeforeWeek() {
  final extra = List<int>.filled(weekCount + 1, 0);
  var cursor = DateTime(weekEpoch.year, weekEpoch.month, 1);
  if (cursor.isBefore(weekEpoch)) {
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  final limit = mondayOfWeek(weekCount);
  while (cursor.isBefore(limit)) {
    if (cursor.weekday != DateTime.monday) {
      final week = weekIndexOf(cursor);
      if (week >= 0 && week < weekCount) extra[week + 1]++;
    }
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  for (var index = 1; index <= weekCount; index++) {
    extra[index] += extra[index - 1];
  }
  return extra;
}

List<int> _buildMonthStartsBeforeWeek() {
  final extra = List<int>.filled(weekCount + 1, 0);
  var cursor = DateTime(weekEpoch.year, weekEpoch.month, 1);
  if (cursor.isBefore(weekEpoch)) {
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  final limit = mondayOfWeek(weekCount);
  while (cursor.isBefore(limit)) {
    final week = weekIndexOf(cursor);
    if (week >= 0 && week < weekCount) extra[week + 1]++;
    cursor = DateTime(cursor.year, cursor.month + 1, 1);
  }
  for (var index = 1; index <= weekCount; index++) {
    extra[index] += extra[index - 1];
  }
  return extra;
}
