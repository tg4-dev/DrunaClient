import 'dart:ui' show lerpDouble;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EventDurationSheet extends StatefulWidget {
  const EventDurationSheet({
    required this.event,
    required this.onSave,
    required this.onCancel,
    this.from,
    super.key,
  });

  final CalendarEvent event;
  final Rect? from;
  final ValueChanged<CalendarEvent> onSave;
  final VoidCallback onCancel;

  @override
  State<EventDurationSheet> createState() => _EventDurationSheetState();
}

class _EventDurationSheetState extends State<EventDurationSheet>
    with SingleTickerProviderStateMixin {
  final _stackKey = GlobalKey();
  final _cardKey = GlobalKey();
  late final AnimationController _motion;
  late final CurvedAnimation _curve;
  late final CurvedAnimation _blocksFade;
  late final Animation<Offset> _blocksSlide;
  late final CurvedAnimation _cardFade;
  final _titleFocus = FocusNode();
  final _clock = ValueNotifier<int>(0);
  late final TextEditingController _title;
  late final FixedExtentScrollController _startHour;
  late final FixedExtentScrollController _startMinute;
  late final FixedExtentScrollController _endHour;
  late final FixedExtentScrollController _endMinute;
  late ClockTime _start;
  late ClockTime _end;
  var _allDay = false;
  var _repeat = false;
  var _syncing = false;
  var _closing = false;
  Rect? _target;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _allDay = event.allDay;
    if (event.allDay) {
      _start = const ClockTime(16, 0);
      _end = const ClockTime(17, 0);
    } else {
      final resolved = resolveClock(
        nearestQuarter(event.start),
        nearestQuarter(event.end),
      );
      _start = resolved.start;
      _end = resolved.end;
    }
    _title = TextEditingController(text: event.title);
    _startHour = FixedExtentScrollController(initialItem: _start.hour);
    _startMinute = FixedExtentScrollController(
      initialItem: _start.minute ~/ calendarMinuteStep,
    );
    _endHour = FixedExtentScrollController(initialItem: _end.hour);
    _endMinute = FixedExtentScrollController(
      initialItem: _end.minute ~/ calendarMinuteStep,
    );
    _motion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _curve = CurvedAnimation(parent: _motion, curve: Curves.easeOutCubic);
    _blocksFade = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.22, 1, curve: Curves.easeOut),
    );
    _blocksSlide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(_curve);
    _cardFade = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0.45, 1, curve: Curves.easeOut),
    );
    if (widget.from == null) {
      _open();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _capture());
    }
  }

  Future<void> _open() async {
    await _motion.forward();
    if (mounted && !_closing) _titleFocus.requestFocus();
  }

  void _capture() {
    if (!mounted) return;
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _target = box.localToGlobal(Offset.zero) & box.size);
    _open();
  }

  @override
  void dispose() {
    _blocksFade.dispose();
    _cardFade.dispose();
    _curve.dispose();
    _motion.dispose();
    _titleFocus.dispose();
    _clock.dispose();
    _title.dispose();
    _startHour.dispose();
    _startMinute.dispose();
    _endHour.dispose();
    _endMinute.dispose();
    super.dispose();
  }

  void _onStartHour(int hour) =>
      _apply(resolveClock(ClockTime(hour, _start.minute), _end));

  void _onStartMinute(int index) => _apply(
    resolveClock(ClockTime(_start.hour, index * calendarMinuteStep), _end),
  );

  void _onEndHour(int hour) =>
      _apply(resolveClock(_start, ClockTime(hour, _end.minute)));

  void _onEndMinute(int index) => _apply(
    resolveClock(_start, ClockTime(_end.hour, index * calendarMinuteStep)),
  );

  void _apply(ResolvedClock resolved) {
    if (_syncing || _closing) return;
    _start = resolved.start;
    _end = resolved.end;
    _clock.value++;
    _jump(_startHour, resolved.start.hour);
    _jump(_startMinute, resolved.start.minute ~/ calendarMinuteStep);
    _jump(_endHour, resolved.end.hour);
    _jump(_endMinute, resolved.end.minute ~/ calendarMinuteStep);
  }

  void _jump(FixedExtentScrollController controller, int index) {
    if (!controller.hasClients || controller.selectedItem == index) return;
    _syncing = true;
    controller.jumpToItem(index);
    _syncing = false;
  }

  void _save() {
    final updated = applyEventDraft(
      event: widget.event,
      title: _title.text,
      allDay: _allDay,
      start: _start,
      end: _end,
    );
    _dismiss(() => widget.onSave(updated));
  }

  Future<void> _dismiss(VoidCallback action) async {
    if (_closing) return;
    _closing = true;
    _titleFocus.unfocus();
    await _motion.reverse();
    if (!mounted) return;
    action();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        key: _stackKey,
        children: [
          FadeTransition(
            opacity: _motion,
            child: const ColoredBox(
              color: Color(0x8C000000),
              child: SizedBox.expand(),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: keyboard,
            child: SafeArea(
              bottom: keyboard == 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wheels = (constraints.maxHeight - 280 - 72).clamp(
                      96.0,
                      168.0,
                    );
                    return Column(
                      children: [
                        FadeTransition(
                          opacity: _cardFade,
                          child: KeyedSubtree(key: _cardKey, child: _card()),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Stack(
                            children: [
                              FadeTransition(
                                opacity: _blocksFade,
                                child: SlideTransition(
                                  position: _blocksSlide,
                                  child: ListView(
                                    padding: const EdgeInsets.only(bottom: 72),
                                    children: [
                                      _durationBlock(wheels),
                                      const SizedBox(height: 10),
                                      _repeatBlock(),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 8,
                                child: FadeTransition(
                                  opacity: _blocksFade,
                                  child: _buttons(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _motion,
            builder: (context, _) => _flyer(),
          ),
        ],
      ),
    );
  }

  Widget _flyer() {
    final from = widget.from;
    final target = _target;
    if (from == null || target == null || _motion.value >= 0.995) {
      return const SizedBox.shrink();
    }
    final box = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return const SizedBox.shrink();
    final t = Curves.easeOutCubic.transform(_motion.value);
    final rect = Rect.lerp(_local(box, from), _local(box, target), t)!;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: calendarEventColor,
            borderRadius: BorderRadius.circular(lerpDouble(6, 20, t)!),
          ),
        ),
      ),
    );
  }

  Rect _local(RenderBox box, Rect global) =>
      box.globalToLocal(global.topLeft) & global.size;

  Widget _card() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: calendarEventColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Мои события',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Text(
                  eventDateLabel(eventFirstDay(widget.event)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: CupertinoTextField(
                    controller: _title,
                    focusNode: _titleFocus,
                    autofocus: false,
                    padding: EdgeInsets.zero,
                    decoration: const BoxDecoration(),
                    cursorColor: const Color(0xFF0A84FF),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                    placeholder: 'Название',
                    placeholderStyle: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!_allDay) ...[
                  const SizedBox(width: 12),
                  ListenableBuilder(
                    listenable: _clock,
                    builder: (context, _) => Text(
                      clockRangeLabel(_start, _end),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _durationBlock(double wheelHeight) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 8),
        child: Column(
          children: [
            Row(
              children: [
                const Text(
                  'Весь день',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                CupertinoSwitch(
                  value: _allDay,
                  activeTrackColor: const Color(0xFF34C759),
                  onChanged: (value) => setState(() => _allDay = value),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: _wheels(wheelHeight),
              secondChild: const SizedBox(width: double.infinity),
              crossFadeState: _allDay
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheels(double height) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _WheelColumn(
              label: 'Начало',
              hour: _startHour,
              minute: _startMinute,
              onHour: _onStartHour,
              onMinute: _onStartMinute,
            ),
          ),
          SizedBox(
            width: 108,
            child: Column(
              children: [
                const Text(
                  '',
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Expanded(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 2),
                        child: ColoredBox(
                          color: Colors.white,
                          child: SizedBox(height: 1.5, width: double.infinity),
                        ),
                      ),
                      ListenableBuilder(
                        listenable: _clock,
                        builder: (context, _) => Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Text(
                            durationLabel(_start, _end),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _WheelColumn(
              label: 'Конец',
              hour: _endHour,
              minute: _endMinute,
              onHour: _onEndHour,
              onMinute: _onEndMinute,
            ),
          ),
        ],
      ),
    );
  }

  Widget _repeatBlock() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        child: Row(
          children: [
            const Text(
              'Повтор',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            CupertinoSwitch(
              value: _repeat,
              activeTrackColor: const Color(0xFF34C759),
              onChanged: (value) => setState(() => _repeat = value),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SheetButton(
          color: const Color(0xFF8E8E93),
          icon: Icons.close,
          onTap: () => _dismiss(widget.onCancel),
        ),
        const SizedBox(width: 64),
        _SheetButton(
          color: const Color(0xFF0A84FF),
          icon: Icons.check,
          onTap: _save,
        ),
      ],
    );
  }
}

class _WheelColumn extends StatelessWidget {
  const _WheelColumn({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onHour,
    required this.onMinute,
  });

  final String label;
  final FixedExtentScrollController hour;
  final FixedExtentScrollController minute;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E8E93),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: _Drum(
                  controller: hour,
                  count: 24,
                  label: (index) => index.toString().padLeft(2, '0'),
                  onChanged: onHour,
                ),
              ),
              Expanded(
                child: _Drum(
                  controller: minute,
                  count: 4,
                  label: (index) =>
                      (index * calendarMinuteStep).toString().padLeft(2, '0'),
                  onChanged: onMinute,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Drum extends StatelessWidget {
  const _Drum({
    required this.controller,
    required this.count,
    required this.label,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int count;
  final String Function(int index) label;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 32,
      diameterRatio: 1.15,
      magnification: 1.2,
      squeeze: 1.05,
      useMagnifier: true,
      looping: true,
      selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
        background: Colors.transparent,
      ),
      onSelectedItemChanged: onChanged,
      children: [
        for (var index = 0; index < count; index++)
          Center(
            child: Text(
              label(index),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 58,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
