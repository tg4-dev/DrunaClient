import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/features/calendar/day_timeline.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_column.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A vertical pull of this many points takes the mode all the way across.
const dayModePullRange = 280.0;

/// What a vertical drag on the open day does, decided as it starts.
enum _Drag { rows, mode, ignored }

/// The open day with friends: the timeline under a friends column on the
/// left (design-system §9.6).
///
/// In friends' calendar a vertical drag scrolls the rows and the column
/// together; pulled down past the top it switches to the user's calendar,
/// like pull-to-refresh. In the user's calendar a drag up switches back.
/// A drag that starts on the user's band switches at once, and a tap on
/// either band switches too.
class DayDetail extends StatefulWidget {
  const DayDetail({
    required this.day,
    required this.events,
    required this.onVisibleDay,
    required this.friends,
    required this.selection,
    required this.friendEvents,
    required this.mode,
    required this.me,
    required this.onShowMine,
    required this.onShowFriends,
    required this.onModeDrag,
    required this.onModeSettle,
    this.metrics,
    this.onEventTap,
    this.onCreateRange,
    this.onMoveEvent,
    super.key,
  });

  final DateTime day;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onVisibleDay;
  final DayScrollMetrics? metrics;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(DateTime start, DateTime end)? onCreateRange;
  final void Function(CalendarEvent event, DateTime start)? onMoveEvent;

  /// Everyone in the column; null while loading.
  final List<FriendInfo>? friends;
  final FriendSelection selection;

  /// Busy time of the selected friends, each event with its owner.
  final List<CalendarEvent> friendEvents;

  /// Shared with the month: 0 the user's calendar, 1 friends'.
  final ValueListenable<double> mode;

  /// The user's avatar for the top of the column.
  final Widget me;
  final VoidCallback onShowMine;
  final VoidCallback onShowFriends;

  /// The mode under the finger, while it pulls.
  final ValueChanged<double> onModeDrag;

  /// The pull let go, with its speed in modes per second.
  final ValueChanged<double> onModeSettle;

  @override
  State<DayDetail> createState() => _DayDetailState();
}

class _DayDetailState extends State<DayDetail>
    with SingleTickerProviderStateMixin {
  /// How far friends' rows are scrolled up.
  late final AnimationController _rows = AnimationController.unbounded(
    vsync: this,
  )..addListener(_keepRowsInside);
  late CalendarEventIndex _friendIndex = CalendarEventIndex(
    widget.friendEvents,
  );
  var _maxOffset = 0.0;
  var _drag = _Drag.ignored;
  final _pointers = <int>{};

  /// Whether the drag that switches the mode began in friends' calendar.
  var _pullFromFriends = false;

  @override
  void didUpdateWidget(covariant DayDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.friendEvents, widget.friendEvents)) {
      _friendIndex = CalendarEventIndex(widget.friendEvents);
    }
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  bool get _friendsShown => widget.mode.value > calendarModeHalfway;

  /// A fling stops at either end instead of running past it.
  void _keepRowsInside() {
    final value = _rows.value;
    final inside = value.clamp(0.0, _maxOffset);
    if (inside == value) return;
    _rows.stop();
    _rows.value = inside;
  }

  void _onDragStart(DragStartDetails details) {
    _rows.stop();
    if (_pointers.length > 1) {
      _drag = _Drag.ignored;
      return;
    }
    _pullFromFriends = _friendsShown;
    final y = details.localPosition.dy;
    final onMyRow =
        y >= DayFriendsGeometry.myRowTop && y < DayFriendsGeometry.friendsTop;
    // In the user's calendar there is nothing to scroll: any drag is a
    // pull. In friends' it scrolls the rows, unless it starts on the band.
    _drag = !_pullFromFriends || onMyRow ? _Drag.mode : _Drag.rows;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_pointers.length > 1) _drag = _Drag.ignored;
    final dy = details.primaryDelta ?? 0;
    switch (_drag) {
      case _Drag.ignored:
        return;
      case _Drag.rows:
        // Past the top, the rest of a pull down turns into the switch.
        final past = dy - _rows.value;
        _rows.value = (_rows.value - dy).clamp(0.0, _maxOffset);
        if (dy > 0 && past > 0) {
          _drag = _Drag.mode;
          _pullMode(past);
        }
      case _Drag.mode:
        _pullMode(dy);
    }
  }

  void _pullMode(double dy) {
    final t = (widget.mode.value - dy / dayModePullRange).clamp(0.0, 1.0);
    widget.onModeDrag(t);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    switch (_drag) {
      case _Drag.ignored:
        break;
      case _Drag.rows:
        if (velocity != 0) {
          _rows.animateWith(
            ClampingScrollSimulation(
              position: _rows.value,
              velocity: -velocity,
            ),
          );
        }
      case _Drag.mode:
        widget.onModeSettle(-velocity / dayModePullRange);
    }
    _drag = _Drag.ignored;
  }

  void _onDragCancel() {
    if (_drag == _Drag.mode) widget.onModeSettle(0);
    _drag = _Drag.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.friends ?? const <FriendInfo>[];
    final present = {for (final friend in friends) friend.id};
    final selected = [
      for (final id in widget.selection.selected)
        if (present.contains(id)) id,
    ];
    final slots = (selected.length > DayFriendsGeometry.stackMax
        ? DayFriendsGeometry.stackMax + 1
        : selected.length);
    final bottomInset = MediaQuery.paddingOf(context).bottom + 16;
    return LayoutBuilder(
      builder: (context, constraints) {
        final geometry = DayFriendsGeometry(
          height: constraints.maxHeight,
          bottomInset: bottomInset,
          rows: friends.length,
          stackSlots: slots,
        );
        _maxOffset = geometry.maxOffset;
        if (_rows.value > _maxOffset) {
          // Fewer friends or a shorter screen: settle inside after the frame.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _keepRowsInside();
          });
        }
        final view = DayFriendsView(
          events: _friendIndex,
          rows: {for (var i = 0; i < selected.length; i++) selected[i]: i},
          geometry: geometry,
          offset: _rows,
        );
        return Listener(
          onPointerDown: (event) => _pointers.add(event.pointer),
          onPointerUp: (event) => _pointers.remove(event.pointer),
          onPointerCancel: (event) => _pointers.remove(event.pointer),
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: {
              VerticalDragGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<
                    VerticalDragGestureRecognizer
                  >(
                    VerticalDragGestureRecognizer.new,
                    (recognizer) => recognizer
                      ..onStart = _onDragStart
                      ..onUpdate = _onDragUpdate
                      ..onEnd = _onDragEnd
                      ..onCancel = _onDragCancel,
                  ),
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: DayTimeline(
                    day: widget.day,
                    metrics: widget.metrics,
                    events: widget.events,
                    onVisibleDay: widget.onVisibleDay,
                    onEventTap: widget.onEventTap,
                    onCreateRange: widget.onCreateRange,
                    onMoveEvent: widget.onMoveEvent,
                    mode: widget.mode,
                    friends: view,
                  ),
                ),
                ..._bandTaps(geometry),
                Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: FriendColumn(
                    friends: widget.friends,
                    selection: widget.selection,
                    mode: widget.mode,
                    offset: _rows,
                    geometry: geometry,
                    me: widget.me,
                    onShowFriends: widget.onShowFriends,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// A tap on the band of the folded layer brings it back. Translucent: a
  /// long press there still draws a new event on the timeline.
  List<Widget> _bandTaps(DayFriendsGeometry geometry) => [
    Positioned(
      top: DayFriendsGeometry.myRowTop,
      height: DayFriendsGeometry.rowHeight,
      left: DayFriendsGeometry.columnWidth,
      right: 0,
      child: ModeGate(
        mode: widget.mode,
        threshold: calendarModeHalfway,
        builder: (context, friendsShown) => Semantics(
          button: friendsShown,
          label: friendsShown ? 'Показать мои события' : null,
          child: GestureDetector(
            key: const ValueKey('day-my-band'),
            behavior: HitTestBehavior.translucent,
            onTap: friendsShown ? widget.onShowMine : null,
          ),
        ),
      ),
    ),
    if (geometry.bandHeight > 0)
      Positioned(
        top: geometry.bandTop,
        height: geometry.bandHeight,
        left: DayFriendsGeometry.columnWidth,
        right: 0,
        child: ModeGate(
          mode: widget.mode,
          threshold: calendarModeHalfway,
          builder: (context, friendsShown) => Semantics(
            button: !friendsShown,
            label: friendsShown ? null : 'Показать занятость друзей',
            child: GestureDetector(
              key: const ValueKey('day-friends-band'),
              behavior: HitTestBehavior.translucent,
              onTap: friendsShown ? null : widget.onShowFriends,
            ),
          ),
        ),
      ),
  ];
}
