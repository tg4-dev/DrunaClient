import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

export 'package:druna_app/features/calendar/day_events.dart'
    show dayTimelineOrigin;

const dayTimelineDayCount = calendarDayCount;

const timelineMorningHour = 8;

const timelineEdgeZone = 56.0;
const timelineEdgeSpeed = 900.0;

const drawnEventDefault = Duration(hours: 1);

double quantizePixels(double pixelsPerHour) =>
    (pixelsPerHour * 32).round() / 32;

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
    this.events = const [],
    this.sharedEvents = const [],
    this.hiddenEventId,
    this.onEventTap,
    this.onCreateRange,
    this.onMoveEvent,
    this.mode = myEventsMode,
    this.friends,
    this.inviteColors,
    this.invitePeople,
    super.key,
  });

  final DateTime day;
  final ValueChanged<DateTime> onVisibleDay;

  final DayScrollMetrics? metrics;
  final List<CalendarEvent> events;

  final List<CalendarEvent> sharedEvents;
  final String? hiddenEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  final void Function(DateTime start, DateTime end)? onCreateRange;

  final void Function(CalendarEvent event, DateTime start)? onMoveEvent;

  final ValueListenable<double> mode;

  final DayFriendsView? friends;

  final List<Color>? inviteColors;

  final List<FriendInfo>? invitePeople;

  @override
  State<DayTimeline> createState() => DayTimelineState();
}

typedef _Ghost = ({DateTime start, DateTime end, int lane, String? title});

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

  final Duration grab;

  final DateTime anchor;

  late DateTime current;

  double x = 0;
  int lane = 0;

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
  late CalendarEventIndex _sharedIndex;
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

  late final AnimationController _ghostFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    _index = CalendarEventIndex(widget.events);
    _sharedIndex = CalendarEventIndex(widget.sharedEvents);
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
    _snap = AnimationController(vsync: this, duration: Motion.medium)
      ..addListener(_onSnapTick);
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
    if (!identical(oldWidget.sharedEvents, widget.sharedEvents)) {
      _sharedIndex = CalendarEventIndex(widget.sharedEvents);
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
        event.external != null ||
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

  void _follow(_Hold hold) {
    final raw = _timeAtX(hold.x);
    final next = _snapTime(
      hold.event == null ? raw : raw.subtract(hold.grab),
      hold.current,
    );
    if (next != hold.current) {
      hold.current = next;
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
      motion: _laneMotion(),
      leftInset: widget.friends == null ? 0 : DayFriendsGeometry.columnWidth,
    );
    final shared = _sharedIndex.between(
      addCalendarDays(dayTimelineOrigin, first),
      addCalendarDays(dayTimelineOrigin, last),
    );
    final faces = DaySharedFaces(
      events: shared,
      scrollOffset: offset,
      pixelsPerHour: _pixels,
      viewportWidth: width,
      leftInset: widget.friends == null ? 0 : DayFriendsGeometry.columnWidth,
    );
    if (widget.friends == null) {
      if (shared.isEmpty) return titles;
      return Stack(
        children: [
          Positioned.fill(child: titles),
          Positioned.fill(child: faces),
        ],
      );
    }
    return Stack(
      children: [
        if (shared.isNotEmpty) Positioned.fill(child: faces),
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

  LaneMotion? _laneMotion() {
    if (widget.friends == null) return null;
    return (lane, child) => ChipMotion(
      mode: widget.mode,
      awayAt: myFoldAt,
      homeTop: timelineLaneTop(lane),
      line: DayFriendsGeometry.myRowTop,
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
      motion: _laneMotion(),
    );
    final shared = _sharedIndex.onDay(day);
    Widget sharedLayer({required bool front}) => Positioned.fill(
      child: IgnorePointer(
        ignoring: front,
        child: DaySharedLayer(
          day: day,
          pixelsPerHour: _pixels,
          events: shared,
          front: front,
          onTap: widget.onEventTap,
        ),
      ),
    );
    final friends = widget.friends;
    if (friends == null) {
      if (shared.isEmpty) return mine;
      return Stack(
        children: [
          sharedLayer(front: false),
          Positioned.fill(child: mine),
          sharedLayer(front: true),
        ],
      );
    }
    return Stack(
      children: [
        if (shared.isNotEmpty) sharedLayer(front: false),
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
        if (shared.isNotEmpty) sharedLayer(front: true),
      ],
    );
  }

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
          final people = widget.invitePeople;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                key: const ValueKey('timeline-ghost'),
                left: left,
                width: (right - left).clamp(2.0, double.infinity),
                top: top,
                height: height,
                child: colors != null && people != null && people.isNotEmpty
                    ? _InviteGhost(people: people)
                    : DecoratedBox(
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
                      painter: _HourGridPainter(pixelsPerHour: _pixels),
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
  const _HourGridPainter({required this.pixelsPerHour});

  final double pixelsPerHour;

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
        _label(canvas, hour, x, opacity);
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
    final step = (opacity * 20).round();
    if (step == 0) return;
    final painter = _labels.putIfAbsent(
      hour * 32 + step,
      () => TextPainter(
        text: TextSpan(
          text: hour.toString().padLeft(2, '0'),
          style: TextStyle(
            fontFamily: 'Onest',
            fontVariations: [FontVariation('wght', 500)],
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
      oldDelegate.pixelsPerHour != pixelsPerHour;
}

class _TimeBubble extends StatelessWidget {
  const _TimeBubble({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Color(0xF0222225),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Onest',
            fontVariations: [FontVariation('wght', 600)],
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

class _InviteGhost extends StatelessWidget {
  const _InviteGhost({required this.people});

  final List<FriendInfo> people;

  @override
  Widget build(BuildContext context) => CustomPaint(
    foregroundPainter: const DashedRimPainter(
      color: Color(0xCCFFFFFF),
      radius: 16,
      dash: 8,
      gap: 5,
      width: sharedRimWidth,
    ),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: const BorderRadius.all(timelineEventRadius),
      ),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: FaceStack(people: people, size: 30),
          ),
        ),
      ),
    ),
  );
}
