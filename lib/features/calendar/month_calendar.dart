import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({required this.onDayTap, this.focus, super.key});

  final void Function(DateTime day, Rect weekRect) onDayTap;
  final DateTime? focus;

  @override
  State<MonthCalendar> createState() => MonthCalendarState();
}

class MonthCalendarState extends State<MonthCalendar>
    with SingleTickerProviderStateMixin {
  final _listKey = GlobalKey();
  late final ScrollController _scroll;
  late final AnimationController _rowSnap;
  late DateTime _visibleMonth;
  late DateTime _today;
  double _rowHeight = monthRowLevels[1];
  double _pinchStartHeight = monthRowLevels[1];
  double _pinchStartOffset = 0;
  double _pinchStartFocal = 0;
  double _lastFocal = 0;
  double _snapFrom = monthRowLevels[1];
  double _snapTo = monthRowLevels[1];
  double _snapOffset = 0;
  double _snapFocal = 0;
  final _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  var _snapping = false;

  @override
  void initState() {
    super.initState();
    _today = dateOnly(DateTime.now());
    final focus = dateOnly(widget.focus ?? _today);
    final index = stripIndexOfDay(focus);
    _visibleMonth = monthOfStrip(stripAt(index));
    _scroll = ScrollController(
      initialScrollOffset: stripUnits(index) * _rowHeight,
    )..addListener(_onScroll);
    _rowSnap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSnapTick);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _rowSnap.dispose();
    super.dispose();
  }

  double get scrollOffset => _scroll.hasClients ? _scroll.offset : 0;

  void restoreOffset(double offset) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(offset.clamp(0, max).toDouble());
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final units = _scroll.offset / _rowHeight;
    final week = weekAtUnits(units);
    final local = units - unitsOfWeek(week);
    final strip = weekIsCut(week) && local >= 1
        ? MonthStrip(week, MonthStripKind.fresh)
        : weekIsCut(week)
        ? MonthStrip(week, MonthStripKind.tail)
        : MonthStrip(week, MonthStripKind.full);
    final month = monthOfStrip(strip);
    if (month == _visibleMonth) return;
    setState(() => _visibleMonth = month);
  }

  Rect? rectForStrip(int index) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_scroll.hasClients) return null;
    final strip = stripAt(index);
    final origin = box.localToGlobal(Offset.zero);
    final top = origin.dy + stripUnits(index) * _rowHeight - _scroll.offset;
    final height = stripExtentUnits(strip) * _rowHeight;
    return Rect.fromLTWH(origin.dx, top, box.size.width, height);
  }

  Rect? revealDay(DateTime day) {
    final index = stripIndexOfDay(day);
    if (_scroll.hasClients) {
      final top = stripUnits(index) * _rowHeight;
      final height = stripExtentUnits(stripAt(index)) * _rowHeight;
      final viewport = _scroll.position.viewportDimension;
      final offset = _scroll.offset;
      final visible =
          top >= offset - 1 && top + height <= offset + viewport + 1;
      if (!visible) {
        final centered = top - (viewport - height) / 2;
        final max = _scroll.position.maxScrollExtent;
        _scroll.jumpTo(centered.clamp(0, max).toDouble());
      }
    }
    return rectForStrip(index);
  }

  void _jump(double offset) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (offset <= max) {
      _scroll.jumpTo(offset.clamp(0, max).toDouble());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final grown = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(offset.clamp(0, grown).toDouble());
    });
  }

  double? _focalInList() {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _pointers.length < 2) return null;
    final points = _pointers.values.toList();
    final mid = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    return box.globalToLocal(mid).dy;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2) return;
    _rowSnap.stop();
    _snapping = false;
    _pinchStartDistance = _pointerDistance();
    _pinchStartHeight = _rowHeight;
    _pinchStartOffset = _scroll.hasClients ? _scroll.offset : 0;
    _pinchStartFocal = _focalInList() ?? 0;
    _lastFocal = _pinchStartFocal;
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (_pointers.length < 2 || start == null || start == 0) return;
    final scale = _pointerDistance() / start;
    final next = (_pinchStartHeight * scale)
        .clamp(monthRowMin, monthRowMax)
        .toDouble();
    final focal = _focalInList() ?? _pinchStartFocal;
    _lastFocal = focal;
    final anchored = zoomedOffset(
      offset: _pinchStartOffset,
      focal: _pinchStartFocal,
      oldExtent: _pinchStartHeight,
      newExtent: next,
    );
    setState(() => _rowHeight = next);
    _jump(anchored + _pinchStartFocal - focal);
  }

  void _onPointerUp(PointerEvent event) {
    final wasPinch = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (!wasPinch || _pointers.length >= 2) return;
    _pinchStartDistance = null;
    _snapFrom = _rowHeight;
    _snapTo = nearestLevel(_rowHeight, monthRowLevels);
    _snapOffset = _scroll.hasClients ? _scroll.offset : 0;
    _snapFocal = _lastFocal;
    _snapping = true;
    _rowSnap.forward(from: 0);
    setState(() {});
  }

  void _onSnapTick() {
    if (!_snapping) return;
    final t = Curves.easeOutCubic.transform(_rowSnap.value);
    final next = _snapFrom + (_snapTo - _snapFrom) * t;
    final offset = zoomedOffset(
      offset: _snapOffset,
      focal: _snapFocal,
      oldExtent: _snapFrom,
      newExtent: next,
    );
    setState(() => _rowHeight = next);
    _jump(offset);
    if (_rowSnap.isCompleted) _snapping = false;
  }

  double _pointerDistance() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: monthTitleHeight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    monthTitle(_visibleMonth),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),
              ),
            ),
            const _WeekdayHeader(),
            Expanded(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                onPointerCancel: _onPointerUp,
                child: CustomScrollView(
                  key: _listKey,
                  controller: _scroll,
                  physics: _pointers.length >= 2
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  slivers: [
                    _MonthStripSliver(
                      rowHeight: _rowHeight,
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final strip = stripAt(index);
                        return _WeekStrip(
                          strip: strip,
                          today: _today,
                          onTap: (day) {
                            final rect = rectForStrip(index);
                            if (rect != null) widget.onDayTap(day, rect);
                          },
                        );
                      }, childCount: stripCount),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: ValueKey('weekday-header'),
      height: weekdayHeaderHeight,
      child: Row(
        children: [
          for (final label in weekdayLabels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({
    required this.strip,
    required this.today,
    required this.onTap,
  });

  final MonthStrip strip;
  final DateTime today;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(strip.weekIndex);
    final firstOfMonth = days.indexWhere((day) => day.day == 1);
    final rowKey = stripKeyId(strip);
    final band = stripHasBand(strip);
    return LayoutBuilder(
      key: ValueKey(rowKey),
      builder: (context, constraints) {
        final bandHeight = band
            ? constraints.maxHeight * monthBandRatio / (1 + monthBandRatio)
            : 0.0;
        return Column(
          children: [
            if (band)
              _MonthBand(
                key: ValueKey('$rowKey-band'),
                label: monthShort(days[firstOfMonth]),
                slot: firstOfMonth < 0 ? 0 : firstOfMonth,
                height: bandHeight,
              )
            else
              _StripRule(
                widthFactor: strip.kind == MonthStripKind.tail
                    ? (firstOfMonth > 0 ? firstOfMonth / 7 : 1)
                    : 1,
              ),
            Expanded(
              child: Row(
                children: [
                  for (var slot = 0; slot < 7; slot++)
                    Expanded(child: _slot(days, slot, firstOfMonth, rowKey)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _slot(List<DateTime> days, int slot, int firstOfMonth, String rowKey) {
    final showDay = switch (strip.kind) {
      MonthStripKind.tail => firstOfMonth > 0 && slot < firstOfMonth,
      MonthStripKind.fresh => firstOfMonth >= 0 && slot >= firstOfMonth,
      MonthStripKind.full => true,
    };
    if (!showDay) return const SizedBox.expand();
    final day = days[slot];
    return _DayCell(
      key: ValueKey('$rowKey-$slot'),
      day: day,
      today: sameDay(day, today),
      band: stripHasBand(strip),
      onTap: () => onTap(day),
    );
  }
}

class _StripRule extends StatelessWidget {
  const _StripRule({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('week-rule'),
      height: 0.6,
      width: double.infinity,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widthFactor.clamp(0, 1),
        heightFactor: 1,
        child: const ColoredBox(color: Color(0xFF3A3A3C)),
      ),
    );
  }
}

class _MonthBand extends StatelessWidget {
  const _MonthBand({
    required this.label,
    required this.slot,
    required this.height,
    super.key,
  });

  final String label;
  final int slot;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final column = constraints.maxWidth / 7;
          return Stack(
            children: [
              Positioned(
                left: column * slot,
                right: 0,
                bottom: 0,
                height: 0.6,
                child: const ColoredBox(color: Color(0xFF3A3A3C)),
              ),
              Positioned(
                left: column * slot + 6,
                bottom: 3,
                child: Text(
                  label,
                  softWrap: false,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    height: 1,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.onTap,
    required this.band,
    super.key,
  });

  final DateTime day;
  final bool today;
  final VoidCallback onTap;
  final bool band;

  @override
  Widget build(BuildContext context) {
    final weekend = day.weekday >= DateTime.saturday;
    final color = today
        ? Colors.white
        : weekend
        ? const Color(0xFFD1D1D6)
        : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.only(top: band ? bandDayPad : plainDayPad),
          child: Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: today
                ? const BoxDecoration(
                    color: Color(0xFFFF3B30),
                    shape: BoxShape.circle,
                  )
                : null,
            child: Text(
              '${day.day}',
              key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: today ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthStripSliver extends SliverMultiBoxAdaptorWidget {
  const _MonthStripSliver({required super.delegate, required this.rowHeight});

  final double rowHeight;

  @override
  RenderSliverVariedExtentList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return _RenderMonthStrips(childManager: element, rowHeight: rowHeight);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverVariedExtentList renderObject,
  ) {
    (renderObject as _RenderMonthStrips).rowHeight = rowHeight;
  }
}

class _RenderMonthStrips extends RenderSliverVariedExtentList {
  _RenderMonthStrips({required super.childManager, required double rowHeight})
    : _rowHeight = rowHeight,
      super(itemExtentBuilder: _extents(rowHeight));

  double _rowHeight;

  static ItemExtentBuilder _extents(double rowHeight) {
    return (int index, SliverLayoutDimensions _) {
      return rowHeight * stripExtentUnits(stripAt(index));
    };
  }

  set rowHeight(double value) {
    if (_rowHeight == value) return;
    _rowHeight = value;
    itemExtentBuilder = _extents(value);
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) {
    if (index <= 0) return 0;
    if (index >= stripCount) return unitsOfWeek(weekCount) * _rowHeight;
    return stripUnits(index) * _rowHeight;
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return _indexForOffset(scrollOffset);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return _indexForOffset(scrollOffset);
  }

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) {
    return unitsOfWeek(weekCount) * _rowHeight;
  }

  int _indexForOffset(double scrollOffset) {
    if (scrollOffset <= 0 || _rowHeight <= 0) return 0;
    return stripIndexForScrollUnits(scrollOffset / _rowHeight);
  }
}
