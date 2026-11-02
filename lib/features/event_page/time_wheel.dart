import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hours and minutes on two looping wheels, in the page's type: the picked
/// value large in the middle, the rest smaller and fainter (design-system
/// §9.1). Minutes go in steps of [minuteStep].
class TimeWheel extends StatefulWidget {
  const TimeWheel({
    required this.hour,
    required this.minute,
    required this.onChanged,
    super.key,
  });

  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  /// The calendar's quarter hours.
  static const minuteStep = calendarMinuteStep;
  static const height = 196.0;
  static const itemExtent = 52.0;

  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late int _hour = widget.hour;
  late int _minute = _snap(widget.minute);
  late final _hours = FixedExtentScrollController(initialItem: _hour);
  late final _minutes = FixedExtentScrollController(
    initialItem: _minute ~/ TimeWheel.minuteStep,
  );

  static int _snap(int minute) {
    final step = TimeWheel.minuteStep;
    return ((minute / step).round() * step).clamp(0, 60 - step);
  }

  @override
  void dispose() {
    _hours.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _report() {
    HapticFeedback.selectionClick();
    widget.onChanged(_hour, _minute);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: TimeWheel.height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _wheel(
            key: const ValueKey('wheel-hours'),
            controller: _hours,
            count: 24,
            label: (i) => i,
            onSelected: (i) {
              _hour = i % 24;
              _report();
            },
          ),
          const SizedBox(width: 24),
          _wheel(
            key: const ValueKey('wheel-minutes'),
            controller: _minutes,
            count: 60 ~/ TimeWheel.minuteStep,
            label: (i) => i * TimeWheel.minuteStep,
            onSelected: (i) {
              _minute =
                  (i % (60 ~/ TimeWheel.minuteStep)) * TimeWheel.minuteStep;
              _report();
            },
          ),
        ],
      ),
    );
  }

  Widget _wheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int count,
    required int Function(int index) label,
    required ValueChanged<int> onSelected,
  }) {
    final style = onest(40, height: 1);
    return SizedBox(
      width: 86,
      child: ListWheelScrollView.useDelegate(
        key: key,
        controller: controller,
        itemExtent: TimeWheel.itemExtent,
        diameterRatio: 1.4,
        perspective: 0.004,
        overAndUnderCenterOpacity: 0.45,
        useMagnifier: true,
        magnification: 1.12,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildLoopingListDelegate(
          children: [
            for (var i = 0; i < count; i++)
              Center(
                child: Text(label(i).toString().padLeft(2, '0'), style: style),
              ),
          ],
        ),
      ),
    );
  }
}
