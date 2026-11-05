import 'package:druna_app/shared/ui/motion.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';

class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    required this.onDayTap,
    this.focus,
    this.events = const [],
    this.hiddenEventId,
    this.onEventTap,
    this.onCreate,
    this.onMove,
    this.leading,
    this.trailing,
    this.onTitleTap,
    this.bottomInset = 0,
    this.bottomBlur = 0,
    this.friendEvents = const [],
    this.sharedEvents = const [],
    this.mode = myEventsMode,
    this.onShowMine,
    this.onPinchChanged,
    this.inviteColors,
    this.invitePeople,
    super.key,
  });

  final void Function(DateTime day, Rect weekRect) onDayTap;
  final DateTime? focus;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(DateTime day, Rect chipRect)? onCreate;

  final Widget? leading;
  final Widget? trailing;

  final VoidCallback? onTitleTap;

  final double bottomInset;

  final double bottomBlur;

  final List<CalendarEvent> friendEvents;

  final List<CalendarEvent> sharedEvents;

  final ValueListenable<double> mode;

  final VoidCallback? onShowMine;

  final ValueChanged<bool>? onPinchChanged;

  final List<Color>? inviteColors;

  final List<FriendInfo>? invitePeople;

  final void Function(CalendarEvent event, DateTime day)? onMove;

  @override
  State<MonthCalendar> createState() => MonthCalendarState();
}

class MonthCalendarState extends State<MonthCalendar>
    with TickerProviderStateMixin {
  final _listKey = GlobalKey();
  late final ScrollController _scroll;
  late final AnimationController _rowSnap;
  late DateTime _visibleMonth;

  var _awayFromToday = false;
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
  CalendarEvent? _holdEvent;
  DateTime? _holdGrabDay;
  final _holdLocal = ValueNotifier<Offset?>(null);
  String _chipTitle = 'Название';

  late final AnimationController _chipFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  DateTime? _hoverDay;

  final _dropRange = ValueNotifier<DropRange?>(null);
  late CalendarEventIndex _index;
  late CalendarEventIndex _friendIndex;
  late CalendarEventIndex _sharedIndex;
  late final AppLifecycleListener _lifecycle;
  Timer? _midnight;

  double get _rowHeight => _rows.value;

  set _rowHeight(double value) {
    if (_rows.value == value) return;
    _rows.value = value;
  }

  @override
  void initState() {
    super.initState();
    _today = dateOnly(DateTime.now());
    _index = CalendarEventIndex(widget.events);
    _friendIndex = CalendarEventIndex(mergeBusyByDay(widget.friendEvents));
    _sharedIndex = CalendarEventIndex(widget.sharedEvents);
    _lifecycle = AppLifecycleListener(onResume: _refreshToday);
    _scheduleMidnight();
    final focus = dateOnly(widget.focus ?? _today);
    final index = stripIndexOfDay(focus);
    _visibleMonth = monthOfStrip(stripAt(index));
    _scroll = ScrollController(
      initialScrollOffset: stripUnits(index) * _rowHeight,
    )..addListener(_onScroll);
    _rows.addListener(_updateAway);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateAway());
    _rowSnap = AnimationController(vsync: this, duration: Motion.medium)
      ..addListener(_onSnapTick);
  }

  @override
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.events, widget.events)) {
      _index = CalendarEventIndex(widget.events);
    }
    if (!identical(oldWidget.friendEvents, widget.friendEvents)) {
      _friendIndex = CalendarEventIndex(mergeBusyByDay(widget.friendEvents));
    }
    if (!identical(oldWidget.sharedEvents, widget.sharedEvents)) {
      _sharedIndex = CalendarEventIndex(widget.sharedEvents);
    }
  }

  @override
  void dispose() {
    _midnight?.cancel();
    _lifecycle.dispose();
    _scroll.dispose();
    _rowSnap.dispose();
    _rows.dispose();
    _chipFade.dispose();
    _holdLocal.dispose();
    _dropRange.dispose();
    super.dispose();
  }

  void _scheduleMidnight() {
    _midnight?.cancel();
    final now = DateTime.now();
    final next = addCalendarDays(now, 1);
    _midnight = Timer(
      next.difference(now) + const Duration(seconds: 1),
      _refreshToday,
    );
  }

  void _refreshToday() {
    _scheduleMidnight();
    final today = dateOnly(DateTime.now());
    if (!mounted || today == _today) return;
    setState(() => _today = today);
    _updateAway();
  }

  double get scrollOffset => _scroll.hasClients ? _scroll.offset : 0;

  double get scrollUnits => scrollOffset / _rowHeight;

  void restoreUnits(double units) => restoreOffset(units * _rowHeight);

  void finishRowSnap() {
    if (!_snapping) return;
    _rowSnap.stop();
    _snapping = false;
    final offset = zoomedOffset(
      offset: _snapOffset,
      focal: _snapFocal,
      oldExtent: _snapFrom,
      newExtent: _snapTo,
    );
    _rowHeight = _snapTo;
    _jump(offset);
  }

  void restoreOffset(double offset) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    _scroll.jumpTo(offset.clamp(0, max).toDouble());
  }

  bool _todayShown() {
    if (!_scroll.hasClients || !_scroll.position.hasViewportDimension) {
      return true;
    }
    final index = stripIndexOfDay(_today);
    final top = stripUnits(index) * _rowHeight;
    final bottom = top + stripExtentUnits(stripAt(index)) * _rowHeight;
    final offset = _scroll.offset;
    return bottom > offset && top < offset + _scroll.position.viewportDimension;
  }

  void _updateAway() {
    final away = !_todayShown();
    if (away == _awayFromToday || !mounted) return;
    setState(() => _awayFromToday = away);
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    _updateAway();
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

  void scrollToToday() {
    if (!_scroll.hasClients) return;
    final offset = stripUnits(stripIndexOfDay(_today)) * _rowHeight;
    final max = _scroll.position.maxScrollExtent;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _scroll.animateTo(
      offset.clamp(0, max).toDouble(),
      duration: reduce
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
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
    widget.onPinchChanged?.call(true);
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
    widget.onPinchChanged?.call(false);
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

  List<Color>? get _invitingColors {
    final colors = widget.inviteColors;
    if (colors == null || colors.length < 2) return null;
    return widget.mode.value > calendarModeHalfway ? colors : null;
  }

  void _beginHold(CalendarEvent? event, Offset global) {
    if (event?.invite != null || event?.external != null) return;
    if (_holding || _pointers.length != 1) return;
    _holdPointer = _pointers.keys.single;
    final day = _dayAtGlobal(global);
    _holdLocal.value = _localOf(global);
    _chipTitle = event != null
        ? eventDisplayTitle(event)
        : _invitingColors != null
        ? 'Приглашение'
        : 'Название';
    _chipFade.forward();
    setState(() {
      _holding = true;
      _holdEvent = event;
      _holdGrabDay = day;
    });
    _hover(day);
  }

  void _updateHold(Offset global) {
    _holdLocal.value = _localOf(global);
    _hover(_dayAtGlobal(global));
  }

  void _hover(DateTime? day) {
    _hoverDay = day;
    final event = _holdEvent;
    final grab = _holdGrabDay;
    if (day == null) {
      _dropRange.value = null;
    } else if (event == null || grab == null) {
      _dropRange.value = DropRange(day, day, moving: false);
    } else {
      final shift = calendarDaysBetween(grab, day);
      _dropRange.value = DropRange(
        addCalendarDays(eventFirstDay(event), shift),
        addCalendarDays(eventLastDay(event), shift),
        moving: true,
      );
    }
  }

  void _finishHold() {
    final day = _hoverDay;
    final event = _holdEvent;
    final grab = _holdGrabDay;
    _clearHold();
    if (day == null) return;
    if (event == null) {
      widget.onCreate?.call(
        day,
        _rectForDaySlot(day) ?? const Rect.fromLTWH(24, 120, 80, 18),
      );
      return;
    }
    final shift = grab == null ? 0 : calendarDaysBetween(grab, day);
    if (shift == 0) return;
    widget.onMove?.call(event, addCalendarDays(eventFirstDay(event), shift));
  }

  void _cancelHold() {
    if (!_holding) return;
    _clearHold();
  }

  void _clearHold() {
    _hoverDay = null;
    _dropRange.value = null;
    _chipFade.reverse().then((_) {
      if (mounted && !_holding) _holdLocal.value = null;
    });
    setState(() {
      _holding = false;
      _holdEvent = null;
      _holdGrabDay = null;
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

  Widget _dragChip(Offset? local) {
    if (local == null) return const SizedBox.shrink();
    final title = _chipTitle;
    const width = 132.0;
    const height = 24.0;
    final colors = _holdEvent == null ? _invitingColors : null;
    final people = widget.invitePeople;
    if (colors != null && people != null && people.isNotEmpty) {
      return _inviteChip(local, people);
    }
    final base = colors == null
        ? OwnEventColor.of(context)
        : mixedColor(colors);
    return Positioned(
      left: local.dx - width / 2,
      top: local.dy - height - 24,
      width: width,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: liftedEventDecoration(
            BorderRadius.circular(height / 2),
            color: base,
            colors: colors,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Onest',
                  fontVariations: [FontVariation('wght', 600)],
                  color: eventInk(base),
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

  Widget _inviteChip(Offset local, List<FriendInfo> people) {
    const face = 26.0;
    const padding = 8.0;
    final count = math.min(people.length, 3);
    const height = face + padding * 2;
    final width = face + face * 0.6 * (count - 1) + padding * 2;
    return Positioned(
      left: local.dx - width / 2,
      top: local.dy - height - 20,
      width: width,
      height: height,
      child: IgnorePointer(
        child: CustomPaint(
          foregroundPainter: const DashedRimPainter(
            color: Color(0xCCFFFFFF),
            radius: 14,
            dash: 8,
            gap: 5,
            width: 2,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: FaceStack(people: people, size: face),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final chrome = top + monthChrome;
    final above = chrome + chromeFade;
    final below = widget.bottomInset;
    final cache = math.max(above, below);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => EdgeBlur(
              sigma: chromeBlurSigma,
              gradient: _edgeBlur(
                height: constraints.maxHeight,
                top: above * topBlurReach,
                bottom: widget.bottomBlur,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Positioned.fill(child: ColoredBox(color: Colors.black)),
                  Positioned(
                    top: chrome,
                    left: 0,
                    right: 0,
                    bottom: widget.bottomInset,
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
                            clipBehavior: Clip.none,
                            scrollCacheExtent: ScrollCacheExtent.pixels(cache),
                            physics: _pointers.length >= 2 || _holding
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                            slivers: [
                              _MonthStripSliver(
                                rowHeight: _rowHeight,
                                paintAbove: above,
                                paintBelow: below,
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final strip = stripAt(index);
                                  return _WeekStrip(
                                    strip: strip,
                                    today: _today,
                                    index: _index,
                                    friendIndex: _friendIndex,
                                    sharedIndex: _sharedIndex,
                                    mode: widget.mode,
                                    onShowMine: widget.onShowMine,
                                    hiddenEventId: widget.hiddenEventId,
                                    dimmedEventId: _holdEvent?.id,
                                    hoverDay: _dropRange,
                                    onEventTap: widget.onEventTap,
                                    onHoldStart: _beginHold,
                                    onTap: (day) {
                                      finishRowSnap();
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
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: chrome + chromeFade,
          child: const IgnorePointer(child: _ShadedTop()),
        ),
        Positioned(
          top: top,
          left: 16,
          right: 16,
          height: monthHeaderBar,
          child: Row(
            children: [
              SizedBox(width: PillStyle.size, child: widget.leading),
              Expanded(
                child: Center(
                  child: PillButton(
                    key: const ValueKey('month-title'),
                    label: '${monthTitle(_visibleMonth)}, к сегодня',
                    onPressed: widget.onTitleTap ?? scrollToToday,
                    fill: _awayFromToday ? Colors.white : PillStyle.fill,
                    color: _awayFromToday ? Colors.black : Colors.white,
                    child: Text(monthTitle(_visibleMonth)),
                  ),
                ),
              ),
              SizedBox(width: PillStyle.size, child: widget.trailing),
            ],
          ),
        ),
        Positioned(
          top: top + monthHeaderBar + monthHeaderGap,
          left: 0,
          right: 0,
          child: const _WeekdayHeader(),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: FadeTransition(
              opacity: _chipFade,
              child: ValueListenableBuilder<Offset?>(
                valueListenable: _holdLocal,
                builder: (context, local, _) => Stack(
                  clipBehavior: Clip.none,
                  children: [_dragChip(local)],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _onPointerCancel(PointerEvent event) {
    if (_holding && event.pointer == _holdPointer) _cancelHold();
    _onPointerUp(event);
  }
}

class _ShadedTop extends StatelessWidget {
  const _ShadedTop();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xD9000000), Color(0xB3000000), Color(0x00000000)],
        stops: [0, 0.7, 1],
      ),
    ),
    child: SizedBox.expand(),
  );
}

const chromeBlurSigma = 24.0;

const topBlurReach = 1.15;

LinearGradientBlur _edgeBlur({
  required double height,
  required double top,
  required double bottom,
}) {
  if (height <= 0) {
    return const LinearGradientBlur(
      values: [0, 0],
      stops: [0, 1],
      start: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );
  }
  final topStop = (top / height).clamp(0.0, 1.0);
  final bottomStop = (1 - bottom / height).clamp(topStop, 1.0);
  return LinearGradientBlur(
    values: bottom > 0 ? const [1, 0, 0, 1] : const [1, 0, 0],
    stops: bottom > 0 ? [0, topStop, bottomStop, 1] : [0, topStop, 1],
    start: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('weekday-header'),
      height: weekdayHeaderHeight,
      child: Row(
        children: [
          for (final label in weekdayLabels)
            Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Onest',
                    fontVariations: [FontVariation('wght', 500)],
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
    required this.index,
    required this.friendIndex,
    required this.sharedIndex,
    required this.mode,
    this.onShowMine,
    this.hiddenEventId,
    this.dimmedEventId,
    this.hoverDay,
    this.onEventTap,
    this.onHoldStart,
  });

  final MonthStrip strip;
  final DateTime today;
  final ValueChanged<DateTime> onTap;
  final CalendarEventIndex index;
  final CalendarEventIndex friendIndex;
  final CalendarEventIndex sharedIndex;
  final ValueListenable<double> mode;
  final VoidCallback? onShowMine;
  final String? hiddenEventId;
  final String? dimmedEventId;
  final ValueListenable<DropRange?>? hoverDay;
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
                  index: index,
                  friendIndex: friendIndex,
                  sharedIndex: sharedIndex,
                  mode: mode,
                  onShowMine: onShowMine,
                  hiddenEventId: hiddenEventId,
                  dimmedEventId: dimmedEventId,
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
                    fontFamily: 'Onest',
                    fontVariations: [FontVariation('wght', 600)],
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
  const _MonthStripSliver({
    required super.delegate,
    required this.rowHeight,
    required this.paintAbove,
    required this.paintBelow,
  });

  final double rowHeight;

  final double paintAbove;
  final double paintBelow;

  @override
  RenderSliverVariedExtentList createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return _RenderMonthStrips(
      childManager: element,
      rowHeight: rowHeight,
      paintAbove: paintAbove,
      paintBelow: paintBelow,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderSliverVariedExtentList renderObject,
  ) {
    (renderObject as _RenderMonthStrips)
      ..rowHeight = rowHeight
      ..paintAbove = paintAbove
      ..paintBelow = paintBelow;
  }
}

class _RenderMonthStrips extends RenderSliverVariedExtentList {
  _RenderMonthStrips({
    required super.childManager,
    required double rowHeight,
    required double paintAbove,
    required double paintBelow,
  }) : _rowHeight = rowHeight,
       _paintAbove = paintAbove,
       _paintBelow = paintBelow,
       super(itemExtentBuilder: _extents(rowHeight));

  double _rowHeight;

  double _paintAbove;
  set paintAbove(double value) {
    if (_paintAbove == value) return;
    _paintAbove = value;
    markNeedsPaint();
  }

  double _paintBelow;
  set paintBelow(double value) {
    if (_paintBelow == value) return;
    _paintBelow = value;
    markNeedsPaint();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    assert(constraints.axisDirection == AxisDirection.down);
    var child = firstChild;
    while (child != null) {
      final top = childMainAxisPosition(child);
      if (top < constraints.remainingPaintExtent + _paintBelow &&
          top + paintExtentOf(child) > -_paintAbove) {
        context.paintChild(
          child,
          offset + Offset(childCrossAxisPosition(child), top),
        );
      }
      child = childAfter(child);
    }
  }

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
