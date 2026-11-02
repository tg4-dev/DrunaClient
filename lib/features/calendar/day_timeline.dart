import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

export 'package:druna_app/features/calendar/day_events.dart'
    show dayTimelineOrigin;

const dayTimelineDayCount = 365 * 130;

/// Hour the timeline opens on when the day has no events and is not today.
const timelineMorningHour = 8;

/// Near an edge while drawing or moving, the timeline scrolls on its own.
const timelineEdgeZone = 56.0;
const timelineEdgeSpeed = 900.0;

/// A drawn event shorter than one step becomes this long, or one step when
/// that is longer.
const drawnEventDefault = Duration(hours: 1);

/// Zoom steps are binary fractions, so `itemCount × 24 × pixels` stays exact
/// and the list's extent is always a whole number of days.
double quantizePixels(double pixelsPerHour) =>
    (pixelsPerHour * 32).round() / 32;

/// [time] rounded to the nearest [step] minutes, rolling into the next day at
/// midnight.
DateTime snapToStep(DateTime time, {int step = calendarMinuteStep}) {
  final minutes = time.hour * 60 + time.minute + time.second / 60;
  final steps = (minutes / step).round() * step;
  final day = addCalendarDays(dateOnly(time), steps ~/ (24 * 60));
  final rest = steps % (24 * 60);
  return atClock(day, rest ~/ 60, rest % 60);
}

class DayScrollMetrics extends ChangeNotifier {
  double offset = 0;
  double pixelsPerHour = defaultPixelsPerHour;

  var _disposed = false;

  void update(double offset, double pixelsPerHour) {
    if (_disposed) return;
    if (this.offset == offset && this.pixelsPerHour == pixelsPerHour) return;
    this.offset = offset;
    this.pixelsPerHour = pixelsPerHour;
    notifyListeners();
  }

  /// Sets the values without notifying, for use while widgets are building.
  void seed(double offset, double pixelsPerHour) {
    this.offset = offset;
    this.pixelsPerHour = pixelsPerHour;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Where the timeline opens: an hour before the day's first event, else the
/// current hour today, else [timelineMorningHour].
int openingHour(CalendarEventIndex index, DateTime day, DateTime now) {
  final date = dateOnly(day);
  double? first;
  for (final event in index.onDay(date)) {
    if (event.allDay) continue;
    final start = event.start.isBefore(date)
        ? 0.0
        : event.start.hour + event.start.minute / 60;
    if (first == null || start < first) first = start;
  }
  if (first != null) return (first - 1).floor().clamp(0, 23);
  if (sameDay(date, now)) return (now.hour - 1).clamp(0, 23);
  return timelineMorningHour;
}

class DayTimeline extends StatefulWidget {
  const DayTimeline({
    required this.day,
    required this.onVisibleDay,
    this.metrics,
    this.hourLabelOpacity = 1,
    this.events = const [],
    this.hiddenEventId,
    this.onEventTap,
    this.onCreateRange,
    this.onMoveEvent,
    this.mode = myEventsMode,
    this.friends,
    this.inviteColors,
    super.key,
  });

  final DateTime day;
  final ValueChanged<DateTime> onVisibleDay;

  /// Carries the zoom between openings and drives the day titles.
  final DayScrollMetrics? metrics;
  final double hourLabelOpacity;
  final List<CalendarEvent> events;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  /// A long press on empty time draws an event from the press to the release.
  final void Function(DateTime start, DateTime end)? onCreateRange;

  /// A long press on a timed event picks it up; this reports its new start.
  final void Function(CalendarEvent event, DateTime start)? onMoveEvent;

  /// 0 shows the user's events in lanes, 1 friends' rows; see
  /// [DayFriendsGeometry]. Only matters with [friends].
  final ValueListenable<double> mode;

  /// Without it the timeline shows only the user's events.
  final DayFriendsView? friends;

  /// In friends' rows with friends picked, drawing makes an invite: the
  /// event being drawn takes their colours.
  final List<Color>? inviteColors;

  @override
  State<DayTimeline> createState() => DayTimelineState();
}

typedef _Ghost = ({DateTime start, DateTime end, int lane, String? title});

/// A press being turned into a new event, or an event being moved.
class _Hold {
  _Hold.create(DateTime at) : event = null, grab = Duration.zero, anchor = at {
    current = at;
  }

  _Hold.move(CalendarEvent moved, this.grab)
    : event = moved,
      anchor = moved.start {
    current = moved.start;
  }

  final CalendarEvent? event;

  /// Moving: how far into the event the finger took hold.
  final Duration grab;

  /// Drawing: the time where the press began.
  final DateTime anchor;

  /// Drawing: the time under the finger. Moving: the event's new start.
  late DateTime current;

  /// Finger x in the timeline's viewport.
  double x = 0;
  int lane = 0;

  /// The snapping step at the zoom the hold started in (see
  /// [timelineStepFor]); the sheet's wheels still offer 15 minutes.
  Duration step = const Duration(minutes: 30);

  ({DateTime start, DateTime end}) get span {
    final event = this.event;
    if (event != null) {
      return (
        start: current,
        end: current.add(event.end.difference(event.start)),
      );
    }
    if (current == anchor) {
      return (start: anchor, end: anchor.add(step));
    }
    return current.isBefore(anchor)
        ? (start: current, end: anchor)
        : (start: anchor, end: current);
  }
}

class DayTimelineState extends State<DayTimeline>
    with TickerProviderStateMixin {
  static const _dayCount = dayTimelineDayCount;

  final _listKey = GlobalKey();
  late final ScrollController _scroll;
  late final AnimationController _snap;
  late CalendarEventIndex _index;
  late double _pixels;
  double _pinchStartPixels = defaultPixelsPerHour;
  double _pinchStartOffset = 0;
  double _pinchStartFocal = 0;
  double _lastFocal = 0;
  double _snapFrom = defaultPixelsPerHour;
  double _snapTo = defaultPixelsPerHour;
  double _snapOffset = 0;
  double _snapFocal = 0;
  final _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  DateTime? _reportedDay;
  var _snapping = false;
  _Hold? _hold;
  late final Ticker _edge = createTicker(_onEdgeTick);
  Duration? _lastEdgeTick;
  final _ghost = ValueNotifier<_Ghost?>(null);

  /// The drawn or moved event fades in on hold and out on release.
  late final AnimationController _ghostFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    _index = CalendarEventIndex(widget.events);
    _pixels = quantizePixels(
      widget.metrics?.pixelsPerHour ?? defaultPixelsPerHour,
    );
    final day = dateOnly(widget.day);
    final dayIndex = calendarDaysBetween(dayTimelineOrigin, day);
    final hour = openingHour(_index, day, DateTime.now());
    final origin = (dayIndex * 24 + hour) * _pixels - dayMidnightInset;
    final initial = origin < 0 ? 0.0 : origin;
    _scroll = ScrollController(initialScrollOffset: initial)
      ..addListener(_publish);
    widget.metrics?.seed(initial, _pixels);
    _reportedDay = day;
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSnapTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publish();
    });
  }

  @override
  void didUpdateWidget(covariant DayTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.events, widget.events)) {
      _index = CalendarEventIndex(widget.events);
    }
  }

  @override
  void dispose() {
    _edge.dispose();
    _ghostFade.dispose();
    _ghost.dispose();
    _scroll.dispose();
    _snap.dispose();
    super.dispose();
  }

  double? _viewportX(Offset global) {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(global).dx;
  }

  double get _viewportWidth {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    return box != null && box.hasSize ? box.size.width : 0;
  }

  /// [raw] snapped for drawing or moving at the current zoom: on the step,
  /// pulled to labelled lines, holding [current] near a boundary
  /// ([snapWithMagnet]).
  DateTime _snapTime(DateTime raw, DateTime? current) {
    final day = dateOnly(raw);
    double minutesOf(DateTime time) => time.difference(day).inSeconds / 60.0;
    final minutes = snapWithMagnet(
      raw: minutesOf(raw),
      current: current == null ? null : minutesOf(current).round(),
      step: timelineStepFor(_pixels),
      division: timelineDivisionFor(_pixels),
    );
    final days = (minutes / (24 * 60)).floor();
    final rest = minutes - days * 24 * 60;
    return atClock(addCalendarDays(day, days), rest ~/ 60, rest % 60);
  }

  /// The unsnapped time under viewport x.
  DateTime _timeAtX(double x) {
    final minutes = ((_scroll.offset + x) / _pixels * 60).floor();
    final day = minutes ~/ (24 * 60);
    final rest = minutes % (24 * 60);
    return atClock(
      addCalendarDays(dayTimelineOrigin, day),
      rest ~/ 60,
      rest % 60,
    );
  }

  /// First row free of events across [start]…[end] on [start]'s day.
  int _freeLane(DateTime start, DateTime end) {
    final day = dateOnly(start);
    final lanes = _index.lanesAround(day);
    final used = <int>{
      for (final event in _index.onDay(day))
        if (timelineSpan(event).start.isBefore(end) &&
            timelineSpan(event).end.isAfter(start))
          lanes[event.id] ?? 0,
    };
    var lane = 0;
    while (used.contains(lane)) {
      lane++;
    }
    return lane;
  }

  /// Friends' rows are in view: the user's events are folded into their
  /// band, and a new one is drawn on the user's row.
  bool get _friendsShown =>
      widget.friends != null && widget.mode.value > calendarModeHalfway;

  void _beginCreate(Offset global) {
    if (widget.onCreateRange == null || _hold != null || _pointers.length > 1) {
      return;
    }
    final x = _viewportX(global);
    if (x == null) return;
    final at = _snapTime(_timeAtX(x), null);
    final hold = _Hold.create(at)
      ..x = x
      ..step = Duration(minutes: timelineStepFor(_pixels));
    hold.lane = _friendsShown ? 0 : _freeLane(at, at.add(hold.step));
    _startHold(hold);
  }

  void _beginMove(CalendarEvent event, Offset global) {
    if (widget.onMoveEvent == null ||
        _friendsShown ||
        event.invite != null ||
        event.allDay ||
        _hold != null ||
        _pointers.length > 1) {
      return;
    }
    final x = _viewportX(global);
    if (x == null) return;
    final hold = _Hold.move(event, _timeAtX(x).difference(event.start))
      ..x = x
      ..step = Duration(minutes: timelineStepFor(_pixels));
    hold.lane = _index.lanesAround(dateOnly(event.start))[event.id] ?? 0;
    _startHold(hold);
  }

  void _startHold(_Hold hold) {
    HapticFeedback.mediumImpact();
    setState(() => _hold = hold);
    _ghost.value = _ghostOf(hold);
    _ghostFade.forward();
    _lastEdgeTick = null;
    if (!_edge.isActive) _edge.start();
  }

  void _updateHold(Offset global) {
    final hold = _hold;
    if (hold == null) return;
    hold.x = _viewportX(global) ?? hold.x;
    _follow(hold);
  }

  /// Re-reads the time under the finger, after it moved or the list scrolled.
  void _follow(_Hold hold) {
    final raw = _timeAtX(hold.x);
    final next = _snapTime(
      hold.event == null ? raw : raw.subtract(hold.grab),
      hold.current,
    );
    if (next != hold.current) {
      hold.current = next;
      // A firmer tick on a labelled line: the hour the user aims for.
      final division = timelineDivisionFor(_pixels);
      if ((next.hour * 60 + next.minute) % division == 0) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }
    _ghost.value = _ghostOf(hold);
  }

  _Ghost _ghostOf(_Hold hold) {
    final span = hold.span;
    final event = hold.event;
    return (
      start: span.start,
      end: span.end,
      lane: hold.lane,
      title: event == null ? null : eventDisplayTitle(event),
    );
  }

  void _endHold() {
    final hold = _hold;
    if (hold == null) return;
    _releaseHold();
    final event = hold.event;
    if (event != null) {
      if (hold.current != event.start) {
        widget.onMoveEvent?.call(event, hold.current);
      }
      return;
    }
    final drawn = hold.current.difference(hold.anchor).abs();
    if (drawn < hold.step) {
      final length = hold.step > drawnEventDefault
          ? hold.step
          : drawnEventDefault;
      widget.onCreateRange?.call(hold.anchor, hold.anchor.add(length));
    } else {
      final span = hold.span;
      widget.onCreateRange?.call(span.start, span.end);
    }
  }

  void _cancelHold() {
    if (_hold == null) return;
    _releaseHold();
  }

  void _releaseHold() {
    _edge.stop();
    _lastEdgeTick = null;
    setState(() => _hold = null);
    _ghostFade.reverse().then((_) {
      if (mounted && _hold == null) _ghost.value = null;
    });
  }

  void _onEdgeTick(Duration elapsed) {
    final hold = _hold;
    final last = _lastEdgeTick;
    _lastEdgeTick = elapsed;
    if (hold == null || last == null || !_scroll.hasClients) return;
    final width = _viewportWidth;
    if (width <= 0) return;
    double depth = 0;
    if (hold.x < timelineEdgeZone) {
      depth = -(1 - hold.x / timelineEdgeZone);
    } else if (hold.x > width - timelineEdgeZone) {
      depth = (hold.x - (width - timelineEdgeZone)) / timelineEdgeZone;
    }
    if (depth == 0) return;
    final seconds = (elapsed - last).inMicroseconds / 1e6;
    final position = _scroll.position;
    final target =
        (_scroll.offset + depth.clamp(-1.0, 1.0) * timelineEdgeSpeed * seconds)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if (target == _scroll.offset) return;
    _scroll.jumpTo(target);
    _follow(hold);
  }

  int _visibleIndex() {
    final hours = (_scroll.offset + dayMidnightInset) / _pixels;
    return (hours / 24).floor().clamp(0, _dayCount - 1);
  }

  void _publish() {
    if (!_scroll.hasClients) return;
    widget.metrics?.update(_scroll.offset, _pixels);
    final day = addCalendarDays(dayTimelineOrigin, _visibleIndex());
    if (_reportedDay == day) return;
    _reportedDay = day;
    widget.onVisibleDay(day);
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
    return box.globalToLocal(mid).dx;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2) return;
    _cancelHold();
    _snap.stop();
    _snapping = false;
    _pinchStartDistance = _pointerDistance();
    _pinchStartPixels = _pixels;
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
    final next = quantizePixels(
      (_pinchStartPixels * scale)
          .clamp(timelineMinPixelsPerHour, timelineMaxPixelsPerHour)
          .toDouble(),
    );
    final focal = _focalInList() ?? _pinchStartFocal;
    _lastFocal = focal;
    final anchored = zoomedOffset(
      offset: _pinchStartOffset,
      focal: _pinchStartFocal,
      oldExtent: _pinchStartPixels,
      newExtent: next,
    );
    setState(() => _pixels = next);
    _jump(anchored + _pinchStartFocal - focal);
    _publish();
  }

  void _onPointerUp(PointerEvent event) {
    final wasPinch = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (!wasPinch || _pointers.length >= 2) return;
    _pinchStartDistance = null;
    _snapFrom = _pixels;
    _snapTo = nearestTimelinePixels(_pixels);
    _snapOffset = _scroll.hasClients ? _scroll.offset : 0;
    _snapFocal = _lastFocal;
    _snapping = true;
    _snap.forward(from: 0);
    setState(() {});
  }

  void _onSnapTick() {
    if (!_snapping) return;
    final t = Curves.easeOutCubic.transform(_snap.value);
    final next = quantizePixels(_snapFrom + (_snapTo - _snapFrom) * t);
    final offset = zoomedOffset(
      offset: _snapOffset,
      focal: _snapFocal,
      oldExtent: _snapFrom,
      newExtent: next,
    );
    setState(() => _pixels = next);
    _jump(offset);
    _publish();
    if (_snap.isCompleted) _snapping = false;
  }

  double _pointerDistance() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  Widget _titles(double width) {
    final offset = _scroll.hasClients
        ? _scroll.offset
        : _scroll.initialScrollOffset;
    final dayWidth = 24 * _pixels;
    final first = (offset / dayWidth).floor().clamp(0, _dayCount - 1);
    final last = ((offset + width) / dayWidth).floor().clamp(0, _dayCount - 1);
    final lanes = <String, int>{};
    for (var index = first; index <= last; index++) {
      lanes.addAll(
        _index.lanesAround(addCalendarDays(dayTimelineOrigin, index)),
      );
    }
    final events = _index.between(
      addCalendarDays(dayTimelineOrigin, first),
      addCalendarDays(dayTimelineOrigin, last),
    );
    final titles = DayTitleOverlay(
      events: events,
      lanes: lanes,
      scrollOffset: offset,
      pixelsPerHour: _pixels,
      viewportWidth: width,
      hiddenEventId: widget.hiddenEventId,
      dimmedEventId: _hold?.event?.id,
      motion: _laneMotion(lanes),
      leftInset: widget.friends == null ? 0 : DayFriendsGeometry.columnWidth,
    );
    if (widget.friends == null) return titles;
    return Stack(
      children: [
        Positioned.fill(child: titles),
        Positioned.fill(
          child: MyBandTitles(
            events: events,
            scrollOffset: offset,
            pixelsPerHour: _pixels,
            viewportWidth: width,
            leftInset: DayFriendsGeometry.columnWidth,
            mode: widget.mode,
          ),
        ),
      ],
    );
  }

  /// With friends, the user's bars fold up into their row as friends'
  /// rows come in, lane by lane, like the month's chips.
  LaneMotion? _laneMotion(Map<String, int> lanes) {
    if (widget.friends == null) return null;
    var count = 0;
    for (final lane in lanes.values) {
      if (lane + 1 > count) count = lane + 1;
    }
    return (lane, child) => ChipMotion(
      mode: widget.mode,
      awayAt: myFoldAt,
      lane: lane,
      lanes: count,
      homeTop: timelineLaneTop(lane),
      foldTop: DayFriendsGeometry.myRowTop,
      child: child,
    );
  }

  Widget _day(DateTime day) {
    final lanes = _index.lanesAround(day);
    final mine = DayEventLayer(
      day: day,
      pixelsPerHour: _pixels,
      events: _index.onDay(day),
      lanes: lanes,
      hiddenEventId: widget.hiddenEventId,
      dimmedEventId: _hold?.event?.id,
      onEventTap: widget.onEventTap,
      onHoldStart: _beginMove,
      onHoldMove: _updateHold,
      onHoldEnd: _endHold,
      motion: _laneMotion(lanes),
    );
    final friends = widget.friends;
    if (friends == null) return mine;
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: DayBands(
              day: day,
              pixelsPerHour: _pixels,
              mine: _index.onDay(day),
              view: friends,
              mode: widget.mode,
            ),
          ),
        ),
        // Folded away, the user's bars take no taps.
        Positioned.fill(
          child: ValueListenableBuilder<double>(
            valueListenable: widget.mode,
            child: mine,
            builder: (context, t, child) =>
                IgnorePointer(ignoring: t > calendarModeHalfway, child: child),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DayFriendLayer(
              day: day,
              pixelsPerHour: _pixels,
              view: friends,
              mode: widget.mode,
            ),
          ),
        ),
      ],
    );
  }

  /// The event being drawn or moved, following the finger in view.
  Widget _ghostLayer() {
    return FadeTransition(
      opacity: _ghostFade,
      child: ListenableBuilder(
        listenable: Listenable.merge([_ghost, _scroll]),
        builder: (context, _) {
          final ghost = _ghost.value;
          if (ghost == null || !_scroll.hasClients) {
            return const SizedBox.shrink();
          }
          final left = timelineX(ghost.start, _pixels) - _scroll.offset;
          final right = timelineX(ghost.end, _pixels) - _scroll.offset;
          final top = timelineLaneTop(ghost.lane);
          // Drawn on the user's row among friends' rows: as tall as it.
          final height = _friendsShown
              ? DayFriendsGeometry.rowHeight
              : timelineEventHeight;
          final title = ghost.title;
          final colors =
              _friendsShown &&
                  _hold?.event == null &&
                  (widget.inviteColors?.length ?? 0) > 1
              ? widget.inviteColors
              : null;
          final base = colors == null
              ? OwnEventColor.of(context)
              : mixedColor(colors);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                key: const ValueKey('timeline-ghost'),
                left: left,
                width: (right - left).clamp(2.0, double.infinity),
                top: top,
                height: height,
                child: DecoratedBox(
                  decoration: liftedEventDecoration(
                    const BorderRadius.all(timelineEventRadius),
                    color: base,
                    colors: colors,
                  ),
                  child: title == null
                      ? const SizedBox.expand()
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: timelineTitlePadding,
                          ),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              title,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: timelineTitleStyle.copyWith(
                                color: eventInk(base),
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              Positioned(
                key: const ValueKey('timeline-ghost-time'),
                left: left,
                top: top + height + 8,
                child: _TimeBubble(
                  label: clockRangeLabel(ghost.start, ghost.end),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              ListView.builder(
                key: _listKey,
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                physics: _pointers.length >= 2 || _hold != null
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: _dayCount,
                itemExtent: 24 * _pixels,
                itemBuilder: (context, index) {
                  final day = addCalendarDays(dayTimelineOrigin, index);
                  return RepaintBoundary(
                    child: CustomPaint(
                      painter: _HourGridPainter(
                        pixelsPerHour: _pixels,
                        hourLabelOpacity: widget.hourLabelOpacity,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPressStart: (details) =>
                            _beginCreate(details.globalPosition),
                        onLongPressMoveUpdate: (details) =>
                            _updateHold(details.globalPosition),
                        onLongPressEnd: (_) => _endHold(),
                        child: _day(day),
                      ),
                    ),
                  );
                },
              ),
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _scroll,
                  builder: (context, _) => _titles(constraints.maxWidth),
                ),
              ),
              Positioned.fill(child: IgnorePointer(child: _ghostLayer())),
            ],
          ),
        ),
      ),
    );
  }
}

class _HourGridPainter extends CustomPainter {
  const _HourGridPainter({
    required this.pixelsPerHour,
    required this.hourLabelOpacity,
  });

  final double pixelsPerHour;
  final double hourLabelOpacity;

  /// Hour labels by hour and opacity step; the labels never change text.
  static final _labels = <int, TextPainter>{};

  @override
  void paint(Canvas canvas, Size size) {
    final half = halfHourOpacity(pixelsPerHour);
    final hourPaint = Paint()..strokeWidth = 1;
    final halfPaint = Paint()
      ..strokeWidth = 0.6
      ..color = Colors.white.withValues(alpha: 0.22 * half);
    for (var hour = 0; hour < 24; hour++) {
      final opacity = hourLineOpacity(hour, pixelsPerHour);
      final x = hour * pixelsPerHour;
      if (opacity > 0.02) {
        if (hourLabelOpacity > 0.02) _label(canvas, hour, x, opacity);
        hourPaint.color = Colors.white.withValues(alpha: 0.34 * opacity);
        canvas.drawLine(
          Offset(x, hour == 0 ? 0 : 28),
          Offset(x, size.height),
          hourPaint,
        );
      }
      if (half > 0.02) {
        final mid = x + pixelsPerHour / 2;
        canvas.drawLine(Offset(mid, 36), Offset(mid, size.height), halfPaint);
      }
    }
  }

  void _label(Canvas canvas, int hour, double x, double opacity) {
    final step = (opacity * hourLabelOpacity * 20).round();
    if (step == 0) return;
    final painter = _labels.putIfAbsent(
      hour * 32 + step,
      () => TextPainter(
        text: TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: TextStyle(
            color: const Color(0xFF8E8E93).withValues(alpha: step / 20),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
    painter.paint(canvas, Offset(x + 4, 6));
  }

  @override
  bool shouldRepaint(covariant _HourGridPainter oldDelegate) =>
      oldDelegate.pixelsPerHour != pixelsPerHour ||
      oldDelegate.hourLabelOpacity != hourLabelOpacity;
}

/// The time of the event being drawn or moved, floating under it.
class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF0222225),
        borderRadius: BorderRadius.all(Radius.circular(10)),
        boxShadow: [BoxShadow(color: Color(0x80000000), blurRadius: 10)],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
