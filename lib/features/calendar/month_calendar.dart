import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    required this.onDayTap,
    this.focus,
    this.events = const [],
    this.hiddenEventId,
    this.onEventTap,
    this.onCreate,
    this.onMove,
    super.key,
  });

  final void Function(DateTime day, Rect weekRect) onDayTap;
  final DateTime? focus;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(DateTime day, Rect chipRect)? onCreate;
  final void Function(CalendarEvent event, DateTime day)? onMove;

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
  late final ValueNotifier<double> _rows = ValueNotifier(monthRowLevels[1]);
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
  var _holding = false;
  int? _holdPointer;
  String? _holdEventId;
  Offset? _holdLocal;
  DateTime? _hoverDay;

  double get _rowHeight => _rows.value;

  set _rowHeight(double value) {
    if (_rows.value == value) return;
    _rows.value = value;
  }

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
    _rows.dispose();
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
    if (_pointers.length >= 2) _cancelHold();
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
    if (_holding && event.pointer == _holdPointer) {
      _updateHold(event.position);
    }
    final start = _pinchStartDistance;
    if (_holding || _pointers.length < 2 || start == null || start == 0) {
      return;
    }
    final scale = _pointerDistance() / start;
    var next = (_pinchStartHeight * scale)
        .clamp(monthRowMin, monthRowMax)
        .toDouble();
    final focal = _focalInList() ?? _pinchStartFocal;
    _lastFocal = focal;
    final previous = _rowHeight;
    var didSnap = false;
    if (previous > monthBarSnapThreshold && next <= monthBarSnapThreshold) {
      next = monthRowMin;
      didSnap = true;
    }
    final anchored = zoomedOffset(
      offset: _pinchStartOffset,
      focal: _pinchStartFocal,
      oldExtent: _pinchStartHeight,
      newExtent: next,
    );
    final jumped = anchored + _pinchStartFocal - focal;
    _rowHeight = next;
    _jump(jumped);
    if (!didSnap) return;
    HapticFeedback.lightImpact();
    _pinchStartHeight = next;
    _pinchStartDistance = _pointerDistance();
    _pinchStartOffset = jumped;
    _pinchStartFocal = focal;
    _lastFocal = focal;
  }

  void _onPointerUp(PointerEvent event) {
    final finishHold = _holding && event.pointer == _holdPointer;
    final wasPinch = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (finishHold && _pointers.isEmpty) _finishHold();
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
    _rowHeight = next;
    _jump(offset);
    if (_rowSnap.isCompleted) _snapping = false;
  }

  double _pointerDistance() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  void _beginHold(CalendarEvent? event, Offset global) {
    if (_holding || _pointers.length != 1) return;
    _holdPointer = _pointers.keys.single;
    setState(() {
      _holding = true;
      _holdEventId = event?.id;
      _holdLocal = _localOf(global);
      _hoverDay = _dayAtGlobal(global);
    });
  }

  void _updateHold(Offset global) {
    setState(() {
      _holdLocal = _localOf(global);
      _hoverDay = _dayAtGlobal(global);
    });
  }

  void _finishHold() {
    final day = _hoverDay;
    final eventId = _holdEventId;
    final creating = eventId == null;
    _clearHold();
    if (day == null) return;
    if (creating) {
      widget.onCreate?.call(
        day,
        _rectForDaySlot(day) ?? const Rect.fromLTWH(24, 120, 80, 18),
      );
      return;
    }
    CalendarEvent? event;
    for (final item in widget.events) {
      if (item.id == eventId) event = item;
    }
    if (event == null || sameDay(eventFirstDay(event), day)) return;
    widget.onMove?.call(event, day);
  }

  void _cancelHold() {
    if (!_holding) return;
    _clearHold();
  }

  void _clearHold() {
    setState(() {
      _holding = false;
      _holdEventId = null;
      _holdLocal = null;
      _hoverDay = null;
      _holdPointer = null;
    });
  }

  Offset? _localOf(Offset global) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  DateTime? _dayAtGlobal(Offset global) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_scroll.hasClients) return null;
    final local = box.globalToLocal(global);
    if (local.dx < 0 ||
        local.dy < 0 ||
        local.dx >= box.size.width ||
        local.dy >= box.size.height) {
      return null;
    }
    final contentY = _scroll.offset + local.dy;
    if (_rowHeight <= 0) return null;
    var index = stripIndexForScrollUnits(contentY / _rowHeight);
    var strip = stripAt(index);
    var top = stripUnits(index) * _rowHeight;
    var extent = stripExtentUnits(strip) * _rowHeight;
    if (contentY >= top + extent && index + 1 < stripCount) {
      index += 1;
      strip = stripAt(index);
      top = stripUnits(index) * _rowHeight;
      extent = stripExtentUnits(strip) * _rowHeight;
    }
    if (contentY < top || contentY >= top + extent) return null;
    final band = stripHasBand(strip)
        ? extent * monthBandRatio / (1 + monthBandRatio)
        : 0.0;
    if (contentY < top + band) return null;
    final days = daysOfWeek(strip.weekIndex);
    final first = days.indexWhere((day) => day.day == 1);
    final column = (local.dx / (box.size.width / 7)).floor();
    if (column < 0 || column > 6) return null;
    if (!columnVisible(kind: strip.kind, firstOfMonth: first, column: column)) {
      return null;
    }
    return days[column];
  }

  Rect? _rectForDaySlot(DateTime day) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !_scroll.hasClients) return null;
    final index = stripIndexOfDay(day);
    final strip = stripAt(index);
    final origin = box.localToGlobal(Offset.zero);
    final top = origin.dy + stripUnits(index) * _rowHeight - _scroll.offset;
    final extent = stripExtentUnits(strip) * _rowHeight;
    final band = stripHasBand(strip)
        ? extent * monthBandRatio / (1 + monthBandRatio)
        : 0.0;
    final days = daysOfWeek(strip.weekIndex);
    final column = days.indexWhere((item) => sameDay(item, day));
    if (column < 0) return null;
    final columnWidth = box.size.width / 7;
    final density = densityForRowHeight(_rowHeight);
    return Rect.fromLTWH(
      origin.dx + column * columnWidth + 2,
      top + band + monthEventHeader,
      columnWidth - 4,
      density.itemHeight,
    );
  }

  Widget _dragChip() {
    final local = _holdLocal;
    if (local == null) return const SizedBox.shrink();
    var title = 'Название';
    final id = _holdEventId;
    if (id != null) {
      for (final event in widget.events) {
        if (event.id == id) title = eventDisplayTitle(event);
      }
    }
    const width = 132.0;
    const height = 28.0;
    return Positioned(
      left: local.dx - width / 2,
      top: local.dy - height - 24,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: calendarEventColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ColoredBox(
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
                    onPointerCancel: _onPointerCancel,
                    child: AnimatedBuilder(
                      animation: _rows,
                      builder: (context, _) {
                        return CustomScrollView(
                          key: _listKey,
                          controller: _scroll,
                          physics: _pointers.length >= 2 || _holding
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          slivers: [
                            _MonthStripSliver(
                              rowHeight: _rowHeight,
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final strip = stripAt(index);
                                return _WeekStrip(
                                  strip: strip,
                                  today: _today,
                                  events: widget.events,
                                  hiddenEventId:
                                      _holdEventId ?? widget.hiddenEventId,
                                  hoverDay: _hoverDay,
                                  onEventTap: widget.onEventTap,
                                  onHoldStart: _beginHold,
                                  onTap: (day) {
                                    final rect = rectForStrip(index);
                                    if (rect != null) {
                                      widget.onDayTap(day, rect);
                                    }
                                  },
                                );
                              }, childCount: stripCount),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_holding) _dragChip(),
      ],
    );
  }

  void _onPointerCancel(PointerEvent event) {
    if (_holding && event.pointer == _holdPointer) _cancelHold();
    _onPointerUp(event);
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
    required this.events,
    this.hiddenEventId,
    this.hoverDay,
    this.onEventTap,
    this.onHoldStart,
  });

  final MonthStrip strip;
  final DateTime today;
  final ValueChanged<DateTime> onTap;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final DateTime? hoverDay;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(strip.weekIndex);
    final firstOfMonth = days.indexWhere((day) => day.day == 1);
    final rowKey = stripKeyId(strip);
    final band = stripHasBand(strip);
    return RepaintBoundary(
      child: LayoutBuilder(
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
                child: MonthWeekGrid(
                  strip: strip,
                  rowKey: rowKey,
                  today: today,
                  events: events,
                  hiddenEventId: hiddenEventId,
                  hoverDay: hoverDay,
                  onDayTap: onTap,
                  onEventTap: onEventTap,
                  onHoldStart: onHoldStart,
                ),
              ),
            ],
          );
        },
      ),
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
