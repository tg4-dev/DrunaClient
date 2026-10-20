import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

export 'package:druna_app/features/calendar/sheet_style.dart';

enum _Clock { start, end }

/// A clock column never takes more than this, so the duration keeps its line;
/// the time scales down instead with large text or narrow screens.
const _clockMaxWidth = 104.0;

/// "Весь день" and the start/end times. Tapping a time opens its wheels inside
/// the block; one set of wheels is open at a time, as in iOS Calendar.
class EventTimeBlock extends StatefulWidget {
  const EventTimeBlock({
    required this.start,
    required this.end,
    required this.allDay,
    required this.onAllDay,
    required this.onStart,
    required this.onEnd,
    super.key,
  });

  final DateTime start;
  final DateTime end;
  final bool allDay;
  final ValueChanged<bool> onAllDay;

  /// Called with the picked clock time as hour and minute.
  final void Function(int hour, int minute) onStart;
  final void Function(int hour, int minute) onEnd;

  @override
  State<EventTimeBlock> createState() => _EventTimeBlockState();
}

class _EventTimeBlockState extends State<EventTimeBlock> {
  _Clock? _open;

  void _toggle(_Clock clock) {
    FocusScope.of(context).unfocus();
    setState(() => _open = _open == clock ? null : clock);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: SheetStyle.blockDecoration,
      child: Padding(
        padding: SheetStyle.blockPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Весь день', style: SheetStyle.title),
                const Spacer(),
                AdaptiveSwitch(
                  value: widget.allDay,
                  onChanged: (value) {
                    setState(() => _open = null);
                    widget.onAllDay(value);
                  },
                ),
              ],
            ),
            Reveal(open: !widget.allDay, child: _times()),
          ],
        ),
      ),
    );
  }

  Widget _times() {
    final open = _open;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ClockColumn(
              key: const ValueKey('event-start'),
              label: 'Начало',
              time: widget.start,
              active: open == _Clock.start,
              alignment: CrossAxisAlignment.start,
              onTap: () => _toggle(_Clock.start),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        durationLabel(widget.start, widget.end),
                        maxLines: 1,
                        style: SheetStyle.duration,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.all(Radius.circular(1.5)),
                      ),
                      child: SizedBox(height: 3, width: double.infinity),
                    ),
                  ],
                ),
              ),
            ),
            _ClockColumn(
              key: const ValueKey('event-end'),
              label: 'Конец',
              time: widget.end,
              active: open == _Clock.end,
              alignment: CrossAxisAlignment.end,
              onTap: () => _toggle(_Clock.end),
            ),
          ],
        ),
        Reveal(
          open: open != null,
          contentKey: open,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: SizedBox(
              height: SheetStyle.pickerHeight,
              child: CupertinoTheme(
                data: SheetStyle.pickerTheme,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  minuteInterval: calendarMinuteStep,
                  initialDateTime: nearestQuarter(
                    open == _Clock.end ? widget.end : widget.start,
                  ),
                  onDateTimeChanged: (value) => open == _Clock.end
                      ? widget.onEnd(value.hour, value.minute)
                      : widget.onStart(value.hour, value.minute),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClockColumn extends StatelessWidget {
  const _ClockColumn({
    required this.label,
    required this.time,
    required this.active,
    required this.alignment,
    required this.onTap,
    super.key,
  });

  final String label;
  final DateTime time;
  final bool active;
  final CrossAxisAlignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label ${clockLabel(time)}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _clockMaxWidth),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment == CrossAxisAlignment.start
                ? Alignment.bottomLeft
                : Alignment.bottomRight,
            child: Column(
              crossAxisAlignment: alignment,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(label, style: SheetStyle.caption),
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: SheetStyle.motion,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? SheetStyle.accent.withValues(alpha: 0.18)
                        : Colors.transparent,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: AnimatedDefaultTextStyle(
                    duration: SheetStyle.fade,
                    style: SheetStyle.clock.copyWith(
                      color: active ? SheetStyle.accent : Colors.white,
                    ),
                    child: Text(clockLabel(time)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
