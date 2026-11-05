import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/date_grid.dart';
import 'package:druna_app/features/event_page/event_labels.dart';
import 'package:druna_app/features/event_page/event_span.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/features/event_page/picker_scope.dart';
import 'package:druna_app/features/event_page/time_wheel.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

enum WhenField { startDate, startTime, endDate, endTime }

enum _Layout { severalDays, oneDay, allDay, allDaySeveral }

abstract final class WhenStyle {
  static final time = onest(36, weight: FontWeight.w700, height: 1.1);
  static final date = onest(
    20,
    weight: FontWeight.w600,
    color: const Color(0xBFFFFFFF),
  );
  static final fullDate = onest(
    17,
    weight: FontWeight.w600,
    color: const Color(0xBFFFFFFF),
  );
  static final allDayDate = onest(28, weight: FontWeight.w700, height: 1.1);
  static final pill = onest(17, weight: FontWeight.w600);
  static const pillFill = Color(0x33FFFFFF);
  static const pillPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);

  static const capsule = EdgeInsets.symmetric(horizontal: 10, vertical: 3);

  static const pillMin = 104.0;
}

class WhenBlock extends StatefulWidget {
  const WhenBlock({
    required this.span,
    required this.editing,
    required this.onChanged,
    this.pickers,
    super.key,
  });

  final EventSpan span;
  final bool editing;
  final ValueChanged<EventSpan> onChanged;

  final PickerScope? pickers;

  @override
  State<WhenBlock> createState() => _WhenBlockState();
}

class _WhenBlockState extends State<WhenBlock> {
  static const _capsuleGap = 6.0;

  WhenField? _open;

  @override
  void initState() {
    super.initState();
    widget.pickers?.addListener(_closePicker);
  }

  @override
  void didUpdateWidget(covariant WhenBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickers != widget.pickers) {
      oldWidget.pickers?.removeListener(_closePicker);
      widget.pickers?.addListener(_closePicker);
    }
    if (!widget.editing) _open = null;
    if (widget.span.allDay &&
        (_open == WhenField.startTime || _open == WhenField.endTime)) {
      _open = null;
    }
  }

  @override
  void dispose() {
    widget.pickers?.removeListener(_closePicker);
    super.dispose();
  }

  void _closePicker() {
    if (_open != null) setState(() => _open = null);
  }

  void _toggle(WhenField field) {
    FocusScope.of(context).unfocus();
    setState(() => _open = _open == field ? null : field);
  }

  _Layout get _layout {
    final span = widget.span;
    final oneDay = span.oneDay && !widget.editing;
    if (span.allDay) return oneDay ? _Layout.allDay : _Layout.allDaySeveral;
    return oneDay ? _Layout.oneDay : _Layout.severalDays;
  }

  @override
  Widget build(BuildContext context) {
    final span = widget.span;
    final layout = _layout;
    return Column(
      children: [
        Reveal(
          open: widget.editing,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(
              children: [
                Expanded(child: Text('Весь день', style: EventPageStyle.label)),
                AdaptiveSwitch(
                  key: const ValueKey('when-all-day'),
                  value: span.allDay,
                  onChanged: (value) =>
                      widget.onChanged(span.withAllDay(value)),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: EventPageStyle.motion,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: EventPageStyle.motion,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(
              key: ValueKey((layout, widget.editing)),
              child: _row(layout),
            ),
          ),
        ),
        Reveal(
          open: widget.editing && _open != null,
          contentKey: _open,
          child: _open == null ? const SizedBox.shrink() : _editor(_open!),
        ),
      ],
    );
  }

  Widget _row(_Layout layout) {
    final span = widget.span;
    final scaler = MediaQuery.textScalerOf(context);
    final pill = _Pill(text: span.durationLabel);
    switch (layout) {
      case _Layout.severalDays:
        final side = _sideWidth(scaler, [
          ('00:00', WhenStyle.time),
          ('28 сен.', WhenStyle.date),
        ]);
        return _sides(
          side,
          left: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _value(
                WhenField.startTime,
                clockLabel(span.start),
                WhenStyle.time,
              ),
              SizedBox(height: widget.editing ? _capsuleGap : 0),
              _value(
                WhenField.startDate,
                shortDateLabel(span.firstDay),
                WhenStyle.date,
              ),
            ],
          ),
          pill: pill,
          right: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _value(WhenField.endTime, clockLabel(span.end), WhenStyle.time),
              SizedBox(height: widget.editing ? _capsuleGap : 0),
              _value(
                WhenField.endDate,
                shortDateLabel(span.lastDay),
                WhenStyle.date,
              ),
            ],
          ),
        );
      case _Layout.oneDay:
        final side = _sideWidth(scaler, [('00:00', WhenStyle.time)]);
        return Column(
          children: [
            _value(
              WhenField.startDate,
              fullDateLabel(span.firstDay),
              WhenStyle.fullDate,
            ),
            const SizedBox(height: 6),
            _sides(
              side,
              left: _value(
                WhenField.startTime,
                clockLabel(span.start),
                WhenStyle.time,
              ),
              pill: pill,
              right: _value(
                WhenField.endTime,
                clockLabel(span.end),
                WhenStyle.time,
              ),
            ),
          ],
        );
      case _Layout.allDay:
        return Row(
          children: [
            _value(
              WhenField.startDate,
              shortDateLabel(span.firstDay),
              WhenStyle.allDayDate,
            ),
            const Spacer(),
            pill,
          ],
        );
      case _Layout.allDaySeveral:
        final side = _sideWidth(scaler, [('28 сен.', WhenStyle.allDayDate)]);
        return _sides(
          side,
          left: _value(
            WhenField.startDate,
            shortDateLabel(span.firstDay),
            WhenStyle.allDayDate,
          ),
          pill: pill,
          right: _value(
            WhenField.endDate,
            shortDateLabel(span.lastDay),
            WhenStyle.allDayDate,
          ),
        );
    }
  }

  Widget _sides(
    double side, {
    required Widget left,
    required Widget pill,
    required Widget right,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed = side * 2 + WhenStyle.pillMin;
        final fits = constraints.maxWidth >= needed;
        final row = SizedBox(
          width: fits ? constraints.maxWidth : needed,
          child: Row(
            children: [
              SizedBox(
                width: side,
                child: Align(alignment: Alignment.centerLeft, child: left),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(fit: BoxFit.scaleDown, child: pill),
                ),
              ),
              SizedBox(
                width: side,
                child: Align(alignment: Alignment.centerRight, child: right),
              ),
            ],
          ),
        );
        return fits ? row : FittedBox(fit: BoxFit.scaleDown, child: row);
      },
    );
  }

  double _sideWidth(TextScaler scaler, List<(String, TextStyle)> samples) {
    var widest = 0.0;
    for (final (text, style) in samples) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest.ceilToDouble() + WhenStyle.capsule.horizontal + 2;
  }

  Widget _value(WhenField field, String text, TextStyle style) {
    final editing = widget.editing;
    final open = editing && _open == field;
    final label = Padding(
      padding: WhenStyle.capsule,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        style: style.copyWith(color: open ? Colors.black : style.color),
      ),
    );
    return Semantics(
      key: ValueKey('when-${field.name}'),
      button: editing,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: editing ? () => _toggle(field) : null,
        child: editing
            ? PillSurface(
                fill: open ? Colors.white : PillStyle.fill,
                child: label,
              )
            : label,
      ),
    );
  }

  Widget _editor(WhenField field) {
    final span = widget.span;
    final (caption, editor) = switch (field) {
      WhenField.startDate => (
        'Дата начала',
        DateGrid(
          key: const ValueKey('grid-start'),
          selected: span.firstDay,
          onPicked: (day) => widget.onChanged(span.withStartDay(day)),
        ),
      ),
      WhenField.endDate => (
        'Дата окончания',
        DateGrid(
          key: const ValueKey('grid-end'),
          selected: span.lastDay,
          firstDay: span.firstDay,
          onPicked: (day) => widget.onChanged(span.withEndDay(day)),
        ),
      ),
      WhenField.startTime => (
        'Время начала',
        TimeWheel(
          key: const ValueKey('wheel-start'),
          hour: span.start.hour,
          minute: span.start.minute,
          onChanged: (hour, minute) =>
              widget.onChanged(widget.span.withStartClock(hour, minute)),
        ),
      ),
      WhenField.endTime => (
        'Время окончания',
        TimeWheel(
          key: const ValueKey('wheel-end'),
          hour: span.end.hour,
          minute: span.end.minute,
          onChanged: (hour, minute) =>
              widget.onChanged(widget.span.withEndClock(hour, minute)),
        ),
      ),
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            Text(caption, style: EventPageStyle.caption),
            const SizedBox(height: 8),
            editor,
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      shape: StadiumBorder(),
      color: WhenStyle.pillFill,
    ),
    child: Padding(
      padding: WhenStyle.pillPadding,
      child: Text(
        text,
        key: const ValueKey('when-duration'),
        maxLines: 1,
        softWrap: false,
        style: WhenStyle.pill,
      ),
    ),
  );
}
