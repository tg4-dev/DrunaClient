import 'dart:async';
import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
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
    this.mode = myEventsMode,
    this.onShowMine,
    this.onPinchChanged,
    this.inviteColors,
    super.key,
  });

  final void Function(DateTime day, Rect weekRect) onDayTap;
  final DateTime? focus;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(DateTime day, Rect chipRect)? onCreate;

  /// Glass buttons left and right of the month title pill.
  final Widget? leading;
  final Widget? trailing;

  /// A tap on the title pill; by default it goes back to today.
  final VoidCallback? onTitleTap;

  /// Room taken at the bottom by what stands over the month (the friend
  /// bar): the weeks scroll on under it.
  final double bottomInset;

  /// How far up from the bottom edge the weeks are blurred, under the bar.
  final double bottomBlur;

  /// Busy time of the selected friends, in their colours.
  final List<CalendarEvent> friendEvents;

  /// 0 shows the user's events, 1 friends'; see [MonthWeekGrid].
  final ValueListenable<double> mode;

  /// A tap on the band of the user's events while friends are shown.
  final VoidCallback? onShowMine;

  /// `true` when a second finger lands and the month starts to zoom,
  /// `false` when the zoom ends: sideways swipes must wait meanwhile.
  final ValueChanged<bool>? onPinchChanged;

  /// In friends' calendar with friends picked, a hold invites them: the
  /// chip being placed takes their colours and says so.
  final List<Color>? inviteColors;

  /// [day] is the event's new first day: the drop day shifted back by how far
  /// into the event it was grabbed.
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

  /// The drag chip fades in on hold and out on release instead of popping.
  late final AnimationController _chipFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );
  DateTime? _hoverDay;

  /// The days the held event would land on, tinted in every row they cross.
  final _dropRange = ValueNotifier<DropRange?>(null);
  late CalendarEventIndex _index;
  late CalendarEventIndex _friendIndex;
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
    _friendIndex = CalendarEventIndex(widget.friendEvents);
    _lifecycle = AppLifecycleListener(onResume: _refreshToday);
    _scheduleMidnight();
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
  void didUpdateWidget(covariant MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.events, widget.events)) {
      _index = CalendarEventIndex(widget.events);
    }
    if (!identical(oldWidget.friendEvents, widget.friendEvents)) {
      _friendIndex = CalendarEventIndex(widget.friendEvents);
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

  /// Back to the week of today, as a tap on the title of Apple's Calendar.
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

  /// The colours of an invite a hold would make now; null for an own event.
  List<Color>? get _invitingColors {
    final colors = widget.inviteColors;
    if (colors == null || colors.length < 2) return null;
    return widget.mode.value > calendarModeHalfway ? colors : null;
  }

  void _beginHold(CalendarEvent? event, Offset global) {
    // An invite is not the user's to move: its page changes it.
    if (event?.invite != null) return;
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

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final chrome = top + monthChrome;
    // Exactly as far as the weeks show under the top and the bar: every
    // week laid out is rebuilt on each frame of a pinch.
    final above = chrome + chromeFade;
    final below = widget.bottomInset;
    final cache = math.max(above, below);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The weeks run on under the top and the friend bar: the list is
        // unclipped and lays out that far past its edges. The month blurs
        // itself there (`progressive_blur` blurs its child), strongest at
        // the screen edges.
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) => EdgeBlur(
              sigma: chromeBlurSigma,
              gradient: _edgeBlur(
                height: constraints.maxHeight,
                top: above,
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
                                    mode: widget.mode,
                                    onShowMine: widget.onShowMine,
                                    hiddenEventId: widget.hiddenEventId,
                                    dimmedEventId: _holdEvent?.id,
                                    hoverDay: _dropRange,
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

/// The top of the month darkens towards the screen edge under the glass
/// row and the weekdays, fading out below them; the blur is the month's own.
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

/// Blur at the screen edges of the month, under the pinned top and the
/// bottom. Sigma is in physical pixels, as the shader takes it.
const chromeBlurSigma = 24.0;

/// Full blur at the top edge fading out [top] below it, and at the bottom
/// edge fading out [bottom] above it; none between.
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

  /// How far past the top and the bottom of the list weeks still show,
  /// under the blurred top and the friend bar.
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

  /// The list paints only the weeks inside it; these run on under the top
  /// and the bar, so a week stays until it has left the screen, not the
  /// list. Laid out by the cache extent, they only need painting.
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
