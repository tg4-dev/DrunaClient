import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A month to pick a day from, in the page's type over a see-through dark
/// panel: the picked day in a white circle, today in red (design-system
/// §9.1). Arrows move between months.
class DateGrid extends StatefulWidget {
  const DateGrid({
    required this.selected,
    required this.onPicked,
    this.today,
    this.firstDay,
    super.key,
  });

  final DateTime selected;
  final ValueChanged<DateTime> onPicked;

  /// Days before it are faint and cannot be picked.
  final DateTime? firstDay;

  /// For tests; the clock otherwise.
  final DateTime? today;

  @override
  State<DateGrid> createState() => _DateGridState();
}

class _DateGridState extends State<DateGrid> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  static const _cell = 42.0;
  static const _weekdays = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  void _shift(int months) {
    HapticFeedback.selectionClick();
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final today = dateOnly(widget.today ?? DateTime.now());
    final lead = _month.weekday - 1;
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    // Taps on empty cells stay in the grid instead of closing it.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: DecoratedBox(
        decoration: EventPageStyle.block,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 10, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${monthNames[_month.month - 1]} ${_month.year} г.',
                      style: onest(18, weight: FontWeight.w600),
                    ),
                  ),
                  _Arrow(
                    key: const ValueKey('grid-previous'),
                    icon: CupertinoIcons.chevron_left,
                    label: 'Предыдущий месяц',
                    onTap: () => _shift(-1),
                  ),
                  _Arrow(
                    key: const ValueKey('grid-next'),
                    icon: CupertinoIcons.chevron_right,
                    label: 'Следующий месяц',
                    onTap: () => _shift(1),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in _weekdays)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: onest(
                            13,
                            weight: FontWeight.w600,
                            color: const Color(0x80FFFFFF),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              for (var row = 0; row < rows; row++)
                Row(
                  children: [
                    for (var column = 0; column < 7; column++)
                      Expanded(child: _day(row * 7 + column - lead + 1, today)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _day(int number, DateTime today) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    if (number < 1 || number > days) {
      return const SizedBox(height: _cell);
    }
    final day = DateTime(_month.year, _month.month, number);
    final picked = sameDay(day, widget.selected);
    final isToday = sameDay(day, today);
    final first = widget.firstDay;
    final allowed = first == null || !day.isBefore(dateOnly(first));
    return Semantics(
      button: true,
      selected: picked,
      label: '$number ${monthNames[_month.month - 1]}',
      excludeSemantics: true,
      child: GestureDetector(
        key: ValueKey('grid-day-$number'),
        behavior: HitTestBehavior.opaque,
        onTap: allowed
            ? () {
                HapticFeedback.selectionClick();
                widget.onPicked(day);
              }
            : null,
        child: SizedBox(
          height: _cell,
          child: Center(
            child: AnimatedContainer(
              duration: EventPageStyle.fade,
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: picked ? Colors.white : const Color(0x00FFFFFF),
              ),
              child: Text(
                '$number',
                style: onest(
                  20,
                  weight: picked ? FontWeight.w600 : FontWeight.w400,
                  color: picked
                      ? Colors.black
                      : !allowed
                      ? const Color(0x4DFFFFFF)
                      : isToday
                      ? SheetStyle.today
                      : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 22, color: const Color(0xCCFFFFFF)),
      ),
    ),
  );
}
