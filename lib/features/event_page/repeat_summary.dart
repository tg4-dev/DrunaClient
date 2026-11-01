import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/event_page/event_labels.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/material.dart';

/// How the event repeats, read-only: "Повтор:" and the rule, then the
/// weekdays for a weekly rule, the picked ones in white.
class RepeatSummary extends StatelessWidget {
  const RepeatSummary({required this.rule, required this.day, super.key});

  final RepeatRule rule;

  /// The event's first day: a weekly rule without days repeats on it.
  final DateTime day;

  static const _dot = 32.0;

  /// As wide as the row of days, under the dates (the reference).
  static const _width = 300.0;

  @override
  Widget build(BuildContext context) {
    final picked = rule.weekdays.isEmpty ? {day.weekday} : rule.weekdays;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _width),
        child: Column(
          key: const ValueKey('repeat-summary'),
          children: [
            Row(
              children: [
                Text('Повтор:', style: EventPageStyle.label),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    repeatSummaryLabel(rule),
                    textAlign: TextAlign.end,
                    style: EventPageStyle.label,
                  ),
                ),
              ],
            ),
            if (rule.unit == RepeatUnit.week) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var weekday = 1; weekday <= 7; weekday++)
                    Container(
                      width: _dot,
                      height: _dot,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: picked.contains(weekday)
                            ? Colors.white
                            : const Color(0x33FFFFFF),
                      ),
                      child: Text(
                        weekdayLabels[weekday - 1],
                        style: onest(
                          15,
                          color: picked.contains(weekday)
                              ? Colors.black
                              : const Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
