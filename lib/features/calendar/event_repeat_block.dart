import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/date_grid.dart';
import 'package:druna_app/features/event_page/picker_scope.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum _Open { interval, until }

const _never = 'never';
const _onDate = 'date';

/// "Повтор" with an iOS pull-down menu. Weekly rules add the weekday row,
/// "Дополнительно" adds "Каждые N …", and a set rule can end on a date.
class EventRepeatBlock extends StatefulWidget {
  const EventRepeatBlock({
    required this.rule,
    required this.day,
    required this.onChanged,
    this.decoration,
    this.picked = SheetStyle.today,
    this.pickedInk = Colors.white,
    this.pickers,
    super.key,
  });

  /// Closes the open wheel or month when the page is tapped elsewhere.
  final PickerScope? pickers;

  /// The block's background; the event sheet's grey by default. On the
  /// event page's gradient it is see-through.
  final BoxDecoration? decoration;

  /// The picked weekdays and the text on them.
  final Color picked;
  final Color pickedInk;

  final RepeatRule? rule;

  /// First day of the event; seeds the weekday and bounds the end date.
  final DateTime day;
  final ValueChanged<RepeatRule?> onChanged;

  @override
  State<EventRepeatBlock> createState() => _EventRepeatBlockState();
}

class _EventRepeatBlockState extends State<EventRepeatBlock> {
  _Open? _open;
  FixedExtentScrollController? _count;
  FixedExtentScrollController? _unit;

  @override
  void initState() {
    super.initState();
    widget.pickers?.addListener(_closePicker);
  }

  @override
  void didUpdateWidget(covariant EventRepeatBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pickers != widget.pickers) {
      oldWidget.pickers?.removeListener(_closePicker);
      widget.pickers?.addListener(_closePicker);
    }
  }

  void _closePicker() {
    if (_open != null) setState(() => _open = null);
  }

  @override
  void dispose() {
    widget.pickers?.removeListener(_closePicker);
    _count?.dispose();
    _unit?.dispose();
    super.dispose();
  }

  void _toggle(_Open section) {
    FocusScope.of(context).unfocus();
    final rule = widget.rule;
    if (section == _Open.interval && _open != section && rule != null) {
      // Fresh wheels start on the rule's values; the old pair is released
      // once its pickers have left the tree.
      final stale = [_count, _unit];
      _count = FixedExtentScrollController(initialItem: rule.interval - 1);
      _unit = FixedExtentScrollController(initialItem: rule.unit.index);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        for (final controller in stale) {
          controller?.dispose();
        }
      });
    }
    setState(() => _open = _open == section ? null : section);
  }

  void _pick(String value) {
    FocusScope.of(context).unfocus();
    if (value == _never) {
      setState(() => _open = null);
      widget.onChanged(null);
      return;
    }
    final preset = RepeatPreset.values.byName(value);
    var next = RepeatRule.fromPreset(preset, widget.day);
    final until = widget.rule?.until;
    if (until != null) next = next.copyWith(until: until);
    if (preset != RepeatPreset.custom && _open == _Open.interval) {
      setState(() => _open = null);
    }
    widget.onChanged(next);
  }

  void _pickEnd(RepeatRule rule, String value) {
    if (value == _never) {
      setState(() => _open = null);
      widget.onChanged(rule.copyWith(clearUntil: true));
      return;
    }
    if (rule.until == null) {
      widget.onChanged(
        rule.copyWith(until: addCalendarDays(dateOnly(widget.day), 30)),
      );
    }
    setState(() => _open = _Open.until);
  }

  void _toggleWeekday(RepeatRule rule, int weekday) {
    final days = {...rule.weekdays};
    if (days.isEmpty) days.add(widget.day.weekday);
    if (days.contains(weekday)) {
      if (days.length == 1) return;
      days.remove(weekday);
    } else {
      days.add(weekday);
    }
    widget.onChanged(rule.copyWith(weekdays: days));
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    return DecoratedBox(
      decoration: widget.decoration ?? SheetStyle.blockDecoration,
      child: Padding(
        padding: SheetStyle.blockPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Повтор', style: SheetStyle.title),
                const Spacer(),
                AdaptiveSwitch(
                  value: rule != null,
                  onChanged: (value) =>
                      _pick(value ? RepeatPreset.weekly.name : _never),
                ),
              ],
            ),
            Reveal(
              open: rule != null,
              child: rule == null ? const SizedBox.shrink() : _details(rule),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(RepeatRule rule) {
    final custom = rule.preset == RepeatPreset.custom;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const _Divider(),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Как часто',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetStyle.row,
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 190),
                child: _Menu(
                  key: const ValueKey('repeat-menu'),
                  label: repeatPresetLabels[rule.preset]!,
                  options: {
                    for (final preset in RepeatPreset.values)
                      preset.name: repeatPresetLabels[preset]!,
                  },
                  selected: rule.preset.name,
                  dividerAfter: const {'yearly'},
                  onSelected: _pick,
                ),
              ),
            ],
          ),
        ),
        Reveal(
          open: custom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Divider(),
              _ValueRow(
                key: const ValueKey('repeat-every'),
                label: 'Интервал',
                value: repeatEveryLabel(rule.unit, rule.interval),
                active: _open == _Open.interval,
                onTap: () => _toggle(_Open.interval),
              ),
              Reveal(
                open: _open == _Open.interval,
                child: _keep(_intervalPicker(rule)),
              ),
            ],
          ),
        ),
        Reveal(open: rule.usesWeekdays, child: _weekdays(rule)),
        const _Divider(),
        SizedBox(
          height: 44,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Окончание повтора',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetStyle.row,
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: _Menu(
                  key: const ValueKey('repeat-until'),
                  label: rule.until == null ? 'Никогда' : 'В дату',
                  options: const {_never: 'Никогда', _onDate: 'В дату'},
                  selected: rule.until == null ? _never : _onDate,
                  onSelected: (value) => _pickEnd(rule, value),
                ),
              ),
            ],
          ),
        ),
        Reveal(
          open: rule.until != null,
          child: rule.until == null
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ValueRow(
                      key: const ValueKey('repeat-until-date'),
                      label: 'Дата',
                      value: eventDateLabel(rule.until!),
                      active: _open == _Open.until,
                      onTap: () => _toggle(_Open.until),
                    ),
                    Reveal(
                      open: _open == _Open.until,
                      child: _keep(_untilPicker(rule)),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _weekdays(RepeatRule rule) {
    final selected = rule.weekdays.isEmpty
        ? {widget.day.weekday}
        : rule.weekdays;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var weekday = 1; weekday <= 7; weekday++)
            _WeekdayChip(
              key: ValueKey('weekday-$weekday'),
              label: weekdayLabels[weekday - 1],
              selected: selected.contains(weekday),
              picked: widget.picked,
              pickedInk: widget.pickedInk,
              onTap: () => _toggleWeekday(rule, weekday),
            ),
        ],
      ),
    );
  }

  Widget _intervalPicker(RepeatRule rule) {
    return SizedBox(
      height: SheetStyle.pickerHeight,
      child: CupertinoTheme(
        data: SheetStyle.pickerTheme,
        child: Row(
          children: [
            Expanded(
              child: CupertinoPicker(
                itemExtent: 34,
                scrollController: _count,
                onSelectedItemChanged: (index) =>
                    widget.onChanged(rule.copyWith(interval: index + 1)),
                children: [
                  for (var count = 1; count <= repeatIntervalMax; count++)
                    Center(child: Text('$count')),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: CupertinoPicker(
                itemExtent: 34,
                scrollController: _unit,
                onSelectedItemChanged: (index) {
                  final unit = RepeatUnit.values[index];
                  widget.onChanged(
                    rule.copyWith(
                      unit: unit,
                      weekdays: unit == RepeatUnit.week
                          ? {widget.day.weekday}
                          : const {},
                    ),
                  );
                },
                children: [
                  for (final unit in RepeatUnit.values)
                    Center(child: Text(repeatUnitLabel(unit, rule.interval))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Taps inside an open picker stay there instead of closing it.
  Widget _keep(Widget picker) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () {},
    child: picker,
  );

  /// The event page's month (design-system §9.1); not before the first
  /// day of the event.
  Widget _untilPicker(RepeatRule rule) {
    final first = dateOnly(widget.day);
    final until = rule.until ?? first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DateGrid(
        key: const ValueKey('repeat-until-grid'),
        selected: until.isBefore(first) ? first : until,
        firstDay: first,
        onPicked: (day) => widget.onChanged(rule.copyWith(until: day)),
      ),
    );
  }
}

/// The current value with ⌃⌄, opening a native pull-down menu on iOS 26 and
/// an action sheet or popup menu elsewhere.
class _Menu extends StatelessWidget {
  const _Menu({
    required this.label,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.dividerAfter = const {},
    super.key,
  });

  final String label;
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onSelected;
  final Set<String> dividerAfter;

  @override
  Widget build(BuildContext context) {
    final items = <AdaptivePopupMenuEntry>[
      for (final entry in options.entries) ...[
        AdaptivePopupMenuItem<String>(
          label: entry.value,
          value: entry.key,
          selected: entry.key == selected,
        ),
        if (dividerAfter.contains(entry.key)) const AdaptivePopupMenuDivider(),
      ],
    ];
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: AdaptivePopupMenuButton.widget<String>(
        items: items,
        onSelected: (_, entry) => onSelected(entry.value!),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AnimatedSwitcher(
                  duration: SheetStyle.fade,
                  child: Text(
                    label,
                    key: ValueKey(label),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SheetStyle.value,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                CupertinoIcons.chevron_up_chevron_down,
                size: 14,
                color: SheetStyle.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(color: SheetStyle.divider, child: SizedBox(height: 0.5));
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
    super.key,
  });

  final String label;
  final String value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(
            children: [
              Flexible(
                flex: 3,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetStyle.row,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: AnimatedDefaultTextStyle(
                  duration: SheetStyle.fade,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: SheetStyle.value.copyWith(
                    color: active ? SheetStyle.accent : SheetStyle.muted,
                  ),
                  child: Text(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekdayChip extends StatelessWidget {
  const _WeekdayChip({
    required this.label,
    required this.selected,
    required this.picked,
    required this.pickedInk,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final Color picked;
  final Color pickedInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: SheetStyle.fade,
          curve: Curves.easeOut,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? picked : SheetStyle.chip,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? pickedInk : Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
