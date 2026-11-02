import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_detail.dart';
import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/features/calendar/day_timeline.dart';
import 'package:druna_app/features/calendar/day_title_layout.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:druna_app/features/calendar/month_events.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/features/event_page/event_subject.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/features/friends/friends_store.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// What the calendar needs to show friends: the bar at the bottom and their
/// busy time in the month.
class CalendarFriends {
  const CalendarFriends({
    required this.store,
    required this.selection,
    required this.events,
    required this.onShowFriends,
    required this.onShowMine,
    required this.onAddFriends,
    required this.onModeDrag,
    required this.onModeSettle,
    this.me,
    this.schedulesAvailable = true,
    this.invites,
    this.onOpenInvite,
    this.onSendInvite,
  });

  final FriendsStore store;
  final FriendSelection selection;

  /// Busy time of the selected friends, already in their colours.
  final ValueListenable<List<CalendarEvent>> events;
  final VoidCallback onShowFriends;
  final VoidCallback onShowMine;
  final VoidCallback onAddFriends;

  /// Pulling the open day sets the mode under the finger…
  final ValueChanged<double> onModeDrag;

  /// …and letting go settles it, with the speed in modes per second.
  final ValueChanged<double> onModeSettle;

  /// The user, for their avatar on top of the open day's column.
  final UserProfile? me;
  final bool schedulesAvailable;

  /// The user's invites as events, in everyone's colours; shown in both
  /// modes (design-system §9.8).
  final ValueListenable<List<CalendarEvent>>? invites;

  /// A tap on an invite opens its page.
  final ValueChanged<String>? onOpenInvite;

  /// Sends a new invite; throws if it failed. Without it a hold in friends'
  /// calendar makes the user's own event, as before.
  final Future<void> Function(InviteDraft draft)? onSendInvite;
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({
    this.onBusyChanged,
    this.onOpenSettings,
    this.onOpenFriends,
    this.friends,
    this.mode = myEventsMode,
    super.key,
  });

  /// Without it the calendar shows only the user's events and no bar.
  final CalendarFriends? friends;

  /// 0 shows the user's events in full, 1 friends'; see [MonthWeekGrid].
  final ValueListenable<double> mode;

  /// `true` while a day is open, an event sheet is on screen or the month is
  /// being zoomed: horizontal swipes then belong to the calendar, not to the
  /// pages around it.
  final ValueChanged<bool>? onBusyChanged;

  /// Shows the gear at the top right of the month.
  final VoidCallback? onOpenSettings;

  /// Shows the friends button at the top left of the month.
  final VoidCallback? onOpenFriends;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final _monthKey = GlobalKey<MonthCalendarState>();
  final _dayMetrics = DayScrollMetrics();
  late final AnimationController _expand;
  late final CurvedAnimation _veil;
  late List<CalendarEvent> _events;

  /// The day that was opened; the timeline starts there.
  DateTime? _day;

  /// The day the timeline shows now. Kept out of state: only closing reads it.
  DateTime? _visibleDay;
  Rect? _from;
  double? _monthOffset;
  int? _openedStrip;
  var _pulling = false;

  /// Set while the day closes after a pull: the month already takes touches.
  var _closingDay = false;
  _Editor? _editor;

  /// Sheets that were swiped away: already saved, only playing their exit.
  final _leaving = <_Editor>[];

  var _reportedBusy = false;

  /// [_events] or friends' busy time with the invites added, rebuilt only
  /// when either list changes: the month indexes whatever list it gets.
  final _mine = _Joined();
  final _theirs = _Joined();

  /// Two fingers zoom the month: the plane must not slide meanwhile.
  var _pinching = false;

  /// Tells the parent after the frame, since it rebuilds in response.
  void _reportBusy() {
    final busy =
        _pinching || _day != null || _editor != null || _leaving.isNotEmpty;
    if (busy == _reportedBusy) return;
    _reportedBusy = busy;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onBusyChanged?.call(busy);
    });
  }

  @override
  void initState() {
    super.initState();
    _events = demoCalendarEvents(DateTime.now());
    _expand = AnimationController(vsync: this, duration: expandOpenDuration);
    _veil = CurvedAnimation(parent: _expand, curve: expandVeilCurve);
  }

  @override
  void dispose() {
    _veil.dispose();
    _expand.dispose();
    _dayMetrics.dispose();
    super.dispose();
  }

  Future<void> _open(DateTime day, Rect weekRect) async {
    final date = DateTime(day.year, day.month, day.day);
    _visibleDay = date;
    setState(() {
      _day = date;
      _from = weekRect;
      _monthOffset = _monthKey.currentState?.scrollOffset;
      _openedStrip = stripIndexOfDay(date);
    });
    await _expand.animateTo(1, curve: Curves.easeOutCubic);
  }

  double _pullRange() {
    final travel = _from?.top ?? 280;
    return travel.clamp(1.0, 1200.0);
  }

  void _onPullStart(DragStartDetails details) {
    if (_day == null || _expand.value < 0.98) return;
    _expand.stop();
    setState(() => _pulling = true);
  }

  void _onPullUpdate(DragUpdateDetails details) {
    if (!_pulling) return;
    final delta = details.primaryDelta ?? 0;
    _expand.value = (_expand.value - delta / _pullRange()).clamp(0.0, 1.0);
  }

  void _onPullEnd(DragEndDetails details) {
    _finishPull(details.primaryVelocity ?? 0);
  }

  void _onPullCancel() {
    _finishPull(0);
  }

  void _finishPull(double velocity) {
    if (!_pulling) return;
    setState(() => _pulling = false);
    if (velocity > 500 || _expand.value < 0.7) {
      _close(byGesture: true);
      return;
    }
    final remaining = 1 - _expand.value;
    _expand.animateTo(
      1,
      duration: _scrubDuration(remaining),
      curve: Curves.easeOutCubic,
    );
  }

  Duration _scrubDuration(double span, {int limit = 360}) {
    final milliseconds = (expandOpenDuration.inMilliseconds * span).round();
    return Duration(milliseconds: milliseconds.clamp(1, limit));
  }

  void _createEvent(DateTime day, Rect rect) {
    final event = createEventOnDay(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      day: day,
      now: DateTime.now(),
    );
    if (_inviting) {
      _openInviteEditor(event);
      return;
    }
    setState(() => _events = [..._events, event]);
    _openEditor(event, isNew: true);
  }

  /// An event drawn on the timeline, from where the press began to where it
  /// ended.
  void _createRange(DateTime start, DateTime end) {
    final event = CalendarEvent(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      title: '',
      start: start,
      end: end,
    );
    if (_inviting) {
      _openInviteEditor(event);
      return;
    }
    setState(() => _events = [..._events, event]);
    _openEditor(event, isNew: true);
  }

  /// The picked friends, in the order they were picked.
  List<FriendInfo> _invitees() {
    final friends = widget.friends;
    final all = friends?.store.friends;
    if (friends == null || all == null) return const [];
    final byId = {for (final friend in all) friend.id: friend};
    return [for (final id in friends.selection.selected) ?byId[id]];
  }

  /// In friends' calendar with friends picked, a hold invites them instead
  /// of making the user's own event.
  bool get _inviting =>
      widget.friends?.onSendInvite != null &&
      widget.mode.value > calendarModeHalfway &&
      _invitees().isNotEmpty;

  /// The user's colour, then each picked friend's: an invite's gradient.
  List<Color>? _inviteColors(BuildContext context) {
    if (widget.friends?.onSendInvite == null) return null;
    final invitees = _invitees();
    if (invitees.isEmpty) return null;
    return [
      OwnEventColor.of(context),
      for (final person in invitees)
        avatarColorFor(id: person.id, username: person.username),
    ];
  }

  void _openInviteEditor(CalendarEvent event) {
    if (widget.friends?.onSendInvite == null) return;
    setState(() => _editor = _Editor(NewInvite(event, _invitees())));
  }

  /// An invite opens its page over the plane; the user's own events open
  /// here, to view.
  void _onEventTap(CalendarEvent event, Rect rect) {
    final invite = event.invite;
    if (invite != null) {
      widget.friends?.onOpenInvite?.call(invite.id);
      return;
    }
    _openEditor(event, isNew: false);
  }

  /// Moving an occurrence on the timeline moves its series by the same time.
  void _moveEventTo(CalendarEvent event, DateTime start) {
    final shift = start.difference(event.start);
    if (shift == Duration.zero) return;
    setState(() {
      _events = [
        for (final item in _events)
          if (item.id == event.sourceId) shiftEventBy(item, shift) else item,
      ];
    });
  }

  /// Moving one occurrence moves its whole series by the same days.
  void _moveEvent(CalendarEvent event, DateTime day) {
    final shift = calendarDaysBetween(eventFirstDay(event), day);
    if (shift == 0) return;
    setState(() {
      _events = [
        for (final item in _events)
          if (item.id == event.sourceId) shiftEventDays(item, shift) else item,
      ];
    });
  }

  void _openEditor(CalendarEvent event, {required bool isNew}) {
    setState(() => _editor = _Editor(OwnEvent(event, isNew: isNew)));
  }

  void _dropEditor(_Editor editor) {
    if (identical(_editor, editor)) _editor = null;
    _leaving.remove(editor);
  }

  /// The page is leaving: it keeps playing its exit, but no longer holds
  /// the screen.
  void _dismissEditor(_Editor editor) {
    if (!identical(_editor, editor)) return;
    _editor = null;
    _leaving.add(editor);
  }

  /// An edited occurrence is stored as its series, moved back to the series'
  /// first day by as many days as the occurrence was from it.
  void _saveEditor(_Editor editor, CalendarEvent updated) {
    final subject = editor.subject;
    if (subject is! OwnEvent) return;
    final opened = subject.event;
    var stored = updated;
    if (updated.seriesId != null) {
      CalendarEvent? source;
      for (final item in _events) {
        if (item.id == updated.seriesId) source = item;
      }
      if (source != null) {
        final back = calendarDaysBetween(
          eventFirstDay(opened),
          eventFirstDay(source),
        );
        stored = shiftEventDays(
          updated,
          back,
        ).copyWith(id: source.id, clearSeries: true);
      }
    }
    setState(() {
      _events = [
        for (final item in _events)
          if (item.id == stored.id) stored else item,
      ];
    });
  }

  /// Removes the event, with its whole series.
  void _deleteEditor(_Editor editor) {
    final subject = editor.subject;
    if (subject is! OwnEvent) return;
    final id = subject.event.sourceId;
    setState(() {
      _events = [
        for (final item in _events)
          if (item.id != id) item,
      ];
    });
  }

  /// [byGesture]: the user already let go, so the month takes touches at once
  /// and the rest of the motion is short.
  Future<void> _close({bool byGesture = false}) async {
    if (!mounted) return;
    if (byGesture) setState(() => _closingDay = true);
    final day = _visibleDay ?? _day;
    if (day != null) {
      final same = _openedStrip != null && stripIndexOfDay(day) == _openedStrip;
      final Rect? rect;
      if (same && _monthOffset != null) {
        _monthKey.currentState?.restoreOffset(_monthOffset!);
        rect = _monthKey.currentState?.rectForStrip(stripIndexOfDay(day));
      } else {
        rect = _monthKey.currentState?.revealDay(day);
      }
      if (rect != null) setState(() => _from = rect);
    }
    await _expand.animateTo(
      0,
      duration: _scrubDuration(_expand.value, limit: byGesture ? 160 : 360),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    _visibleDay = null;
    setState(() {
      _closingDay = false;
      _day = null;
      _from = null;
      _monthOffset = null;
      _openedStrip = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    _reportBusy();
    final day = _day;
    final from = _from;
    // Each layer is built once per state change and handed to the animation
    // as a child, so open/close frames only move and fade it.
    final friends = widget.friends;
    final invites = friends?.invites;
    final mine = _mine.of(_events, invites?.value);
    MonthCalendar monthWith(List<CalendarEvent> friendEvents) => MonthCalendar(
      key: _monthKey,
      focus: DateTime.now(),
      events: mine,
      friendEvents: _theirs.of(friendEvents, invites?.value),
      inviteColors: _inviteColors(context),
      mode: widget.mode,
      onShowMine: friends?.onShowMine,
      onPinchChanged: (pinching) {
        if (pinching != _pinching) setState(() => _pinching = pinching);
      },
      onDayTap: _open,
      onEventTap: _onEventTap,
      onCreate: _createEvent,
      onMove: _moveEvent,
      leading: widget.onOpenFriends == null
          ? null
          : PillButton(
              key: const ValueKey('friends-button'),
              icon: CupertinoIcons.person_2,
              label: 'Друзья',
              onPressed: widget.onOpenFriends,
            ),
      trailing: widget.onOpenSettings == null
          ? null
          : PillButton(
              key: const ValueKey('settings-button'),
              icon: CupertinoIcons.gear_alt,
              label: 'Настройки',
              onPressed: widget.onOpenSettings,
            ),
      bottomBlur: friends == null ? 0 : _bottomShadeHeight(context),
      bottomInset: friends == null
          ? 0
          : MediaQuery.paddingOf(context).bottom + friendBarExtent,
    );
    final Widget month = friends == null
        ? monthWith(const [])
        : ListenableBuilder(
            // The picked friends set an invite's colours; invites come and
            // go by themselves.
            listenable: Listenable.merge([
              friends.events,
              friends.selection,
              friends.store,
              ?invites,
            ]),
            builder: (context, _) => monthWith(friends.events.value),
          );
    return Scaffold(
      backgroundColor: Colors.black,
      // The calendar has no fields; the event page over it handles the
      // keyboard itself and keeps its gradient running under it.
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _expand,
            child: month,
            builder: (context, child) {
              final t = _expand.value;
              return Offstage(
                offstage: t >= 1,
                child: TickerMode(
                  enabled: t < 1,
                  child: IgnorePointer(
                    ignoring: t > 0.04 && !_closingDay,
                    child: child,
                  ),
                ),
              );
            },
          ),
          // The bottom of the month darkens under the friend bar (the month
          // blurs itself there, [MonthCalendar.bottomBlur]); the shade
          // leaves with the bar as a day opens.
          if (friends != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: _bottomShadeHeight(context),
              child: AnimatedBuilder(
                animation: _expand,
                builder: (context, child) => Opacity(
                  opacity: (1 - _expand.value * 2).clamp(0.0, 1.0),
                  child: child,
                ),
                child: const IgnorePointer(child: _ShadedBottom()),
              ),
            ),
          if (friends != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 4,
              child: AnimatedBuilder(
                animation: _expand,
                // The bar belongs to the month: it leaves as a day opens.
                builder: (context, child) => IgnorePointer(
                  ignoring: _expand.value > 0.04 && !_closingDay,
                  child: Opacity(
                    opacity: (1 - _expand.value * 2).clamp(0.0, 1.0),
                    child: child,
                  ),
                ),
                child: ListenableBuilder(
                  listenable: friends.store,
                  builder: (context, _) => FriendBar(
                    friends: friends.store.friends,
                    selection: friends.selection,
                    mode: widget.mode,
                    schedulesAvailable: friends.schedulesAvailable,
                    onShowFriends: friends.onShowFriends,
                    onAddFriends: friends.onAddFriends,
                  ),
                ),
              ),
            ),
          if (day != null && from != null)
            _ExpandedDay(
              animation: _expand,
              veil: _veil,
              week: from,
              day: day,
              events: mine,
              inviteColors: _inviteColors(context),
              metrics: _dayMetrics,
              friends: friends,
              mode: widget.mode,
              onVisibleDay: (next) => _visibleDay = next,
              onEventTap: _onEventTap,
              onCreateRange: _createRange,
              onMoveEvent: _moveEventTo,
              onClose: _close,
              pulling: _pulling,
              closing: _closingDay,
              onPullStart: _onPullStart,
              onPullUpdate: _onPullUpdate,
              onPullEnd: _onPullEnd,
              onPullCancel: _onPullCancel,
            ),
          for (final editor in [..._leaving, ?_editor])
            Positioned.fill(
              key: editor.key,
              child: EventPage(
                subject: editor.subject,
                me: meAsPerson(widget.friends?.me),
                onSave: (updated) => _saveEditor(editor, updated),
                onDelete: () => _deleteEditor(editor),
                onSendInvite: widget.friends?.onSendInvite,
                onClosing: () => setState(() => _dismissEditor(editor)),
                onGone: () => setState(() => _dropEditor(editor)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ExpandedDay extends StatelessWidget {
  const _ExpandedDay({
    required this.animation,
    required this.veil,
    required this.week,
    required this.day,
    required this.events,
    required this.metrics,
    required this.friends,
    this.inviteColors,
    required this.mode,
    required this.onVisibleDay,
    required this.onEventTap,
    required this.onCreateRange,
    required this.onMoveEvent,
    required this.onClose,
    required this.pulling,
    required this.closing,
    required this.onPullStart,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
  });

  final Animation<double> animation;
  final Animation<double> veil;
  final Rect week;
  final DateTime day;
  final List<CalendarEvent> events;
  final DayScrollMetrics metrics;

  /// Colours of an invite being drawn in friends' calendar.
  final List<Color>? inviteColors;

  /// With friends the day shows their rows and switches modes with the
  /// month (see [DayDetail]); without, only the user's events.
  final CalendarFriends? friends;
  final ValueListenable<double> mode;
  final ValueChanged<DateTime> onVisibleDay;
  final void Function(CalendarEvent event, Rect rect) onEventTap;
  final void Function(DateTime start, DateTime end) onCreateRange;
  final void Function(CalendarEvent event, DateTime start) onMoveEvent;
  final VoidCallback onClose;
  final bool pulling;

  /// Closing after a pull: the sheet lets touches through to the month.
  final bool closing;
  final GestureDragStartCallback onPullStart;
  final GestureDragUpdateCallback onPullUpdate;
  final GestureDragEndCallback onPullEnd;
  final VoidCallback onPullCancel;

  @override
  Widget build(BuildContext context) {
    final headerHeight = MediaQuery.paddingOf(context).top + monthTitleHeight;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final friends = this.friends;
    final Widget timeline = friends == null
        ? DayTimeline(
            day: day,
            metrics: metrics,
            events: events,
            onVisibleDay: onVisibleDay,
            onEventTap: onEventTap,
            onCreateRange: onCreateRange,
            onMoveEvent: onMoveEvent,
          )
        : ListenableBuilder(
            listenable: Listenable.merge([
              friends.store,
              friends.selection,
              friends.events,
            ]),
            builder: (context, _) => DayDetail(
              day: day,
              metrics: metrics,
              events: events,
              onVisibleDay: onVisibleDay,
              onEventTap: onEventTap,
              onCreateRange: onCreateRange,
              onMoveEvent: onMoveEvent,
              friends: friends.store.friends,
              selection: friends.selection,
              friendEvents: friends.events.value,
              mode: mode,
              me: _MyAvatar(profile: friends.me),
              onShowMine: friends.onShowMine,
              onShowFriends: friends.onShowFriends,
              onModeDrag: friends.onModeDrag,
              onModeSettle: friends.onModeSettle,
              inviteColors: inviteColors,
            ),
          );
    final sheet = FadeTransition(
      opacity: veil,
      child: ColoredBox(
        color: Colors.black,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                top: headerHeight,
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedBuilder(
                  animation: animation,
                  child: timeline,
                  builder: (context, child) => IgnorePointer(
                    ignoring: pulling || animation.value < 0.98,
                    child: child,
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: headerHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: onPullStart,
                  onVerticalDragUpdate: onPullUpdate,
                  onVerticalDragEnd: onPullEnd,
                  onVerticalDragCancel: onPullCancel,
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: monthTitleHeight,
                      child: Stack(
                        clipBehavior: Clip.hardEdge,
                        children: [
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: metrics,
                              builder: (context, _) =>
                                  _DayTitleTrack(metrics: metrics),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: IconButton(
                              onPressed: onClose,
                              tooltip: 'Назад к месяцу',
                              padding: EdgeInsets.zero,
                              alignment: Alignment.bottomLeft,
                              constraints: const BoxConstraints(
                                minWidth: 44,
                                minHeight: 36,
                              ),
                              icon: const Icon(
                                Icons.chevron_left,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return AnimatedBuilder(
      animation: animation,
      child: sheet,
      builder: (context, child) {
        final layout = expandLayout(
          t: animation.value,
          week: week,
          screenHeight: screenHeight,
        );
        return Stack(
          children: [
            Positioned(
              top: layout.top,
              left: 0,
              right: 0,
              height: (layout.bottom - layout.top).clamp(0.0, double.infinity),
              child: IgnorePointer(
                ignoring: closing || !pulling && layout.motion < 0.02,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

const _dayTitleMinX = 40.0;

String _dayTitle(DateTime day) => '${day.day} ${weekdayShort(day)}';

TextStyle _dayTitleStyle(
  double size,
  double opacity, [
  FontWeight weight = FontWeight.w700,
  double letterSpacing = -0.6,
]) => TextStyle(
  color: Colors.white.withValues(alpha: opacity.clamp(0, 1)),
  fontSize: size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  height: 1,
);

double _titleWidth(
  String text,
  double size,
  FontWeight weight, [
  double letterSpacing = -0.6,
]) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: _dayTitleStyle(size, 1, weight, letterSpacing),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _fitOpacity(double x, double width) {
  if (width <= 0 || x >= _dayTitleMinX) return 1;
  return ((x + width - _dayTitleMinX) / width).clamp(0.0, 1.0);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _MidnightLine {
  const _MidnightLine(this.x, this.span);

  final double x;
  final double span;
}

class _MidnightRulesPainter extends CustomPainter {
  const _MidnightRulesPainter(this.lines);

  final List<_MidnightLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 1;
    for (final line in lines) {
      final top = size.height - line.span;
      canvas.drawLine(Offset(line.x, top), Offset(line.x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MidnightRulesPainter oldDelegate) {
    if (oldDelegate.lines.length != lines.length) return true;
    for (var index = 0; index < lines.length; index++) {
      final a = oldDelegate.lines[index];
      final b = lines[index];
      if (a.x != b.x || a.span != b.span) return true;
    }
    return false;
  }
}

class _DayTitleTrack extends StatelessWidget {
  const _DayTitleTrack({required this.metrics});

  final DayScrollMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final probe = dayTitleLayout(
      offset: metrics.offset,
      pixelsPerHour: metrics.pixelsPerHour,
      bigWidth: 1,
    );
    final titles = dayTitleLayout(
      offset: metrics.offset,
      pixelsPerHour: metrics.pixelsPerHour,
      bigWidth: _titleWidth(
        _dayTitle(_dayAt(probe.index)),
        dayTitleBig,
        FontWeight.w700,
      ),
    );
    final currentWeight =
        FontWeight.lerp(FontWeight.w700, FontWeight.w400, titles.travel) ??
        FontWeight.w700;
    final currentWidth = _titleWidth(
      _dayTitle(_dayAt(titles.index)),
      titles.currentSize,
      currentWeight,
    );
    final currentX = titles.currentX(currentWidth);
    final nextWeight =
        FontWeight.lerp(FontWeight.w400, FontWeight.w700, titles.travel) ??
        FontWeight.w400;
    final nextX = titles.nextX();
    final lines = <_MidnightLine>[
      _MidnightLine(titles.currentMidnight, titles.currentSize),
      if (titles.nextMidnight != null)
        _MidnightLine(titles.nextMidnight!, titles.nextSize),
    ];
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MidnightRulesPainter(lines)),
        ),
        if (titles.index > 0) _previous(titles),
        _placed(
          titles.index,
          currentX,
          titles.currentSize,
          currentWeight,
          _fitOpacity(currentX, currentWidth),
        ),
        if (nextX != null)
          _placed(
            titles.index + 1,
            nextX,
            titles.nextSize,
            nextWeight,
            _lerp(0.8, 1, titles.travel),
          ),
      ],
    );
  }

  Widget _previous(DayTitleLayout titles) {
    final width = _titleWidth(
      _dayTitle(_dayAt(titles.index - 1)),
      dayTitleSmall,
      FontWeight.w400,
    );
    final x = titles.previousX(width);
    return _placed(
      titles.index - 1,
      x,
      dayTitleSmall,
      FontWeight.w400,
      _fitOpacity(x, width),
    );
  }

  DateTime _dayAt(int dayIndex) => addCalendarDays(dayTimelineOrigin, dayIndex);

  Widget _placed(
    int dayIndex,
    double x,
    double size,
    FontWeight weight,
    double opacity,
  ) {
    if (opacity < 0.02) return const SizedBox.shrink();
    return Positioned(
      left: x,
      bottom: 0,
      child: Text(
        _dayTitle(_dayAt(dayIndex)),
        style: _dayTitleStyle(size, opacity, weight),
      ),
    );
  }
}

/// The user on top of the open day's column, in the colour of their events.
class _MyAvatar extends StatelessWidget {
  const _MyAvatar({required this.profile});

  final UserProfile? profile;

  @override
  Widget build(BuildContext context) {
    final profile = this.profile;
    return Semantics(
      label: 'Мои события',
      excludeSemantics: true,
      child: PersonAvatar(
        id: profile?.id ?? 0,
        name: profile?.name ?? '',
        username: profile?.username ?? 'Я',
        color: OwnEventColor.of(context),
        size: DayFriendsGeometry.avatar,
      ),
    );
  }
}

/// One open event page; the key keeps its state while it leaves.
class _Editor {
  _Editor(this.subject);

  final EventSubject subject;
  final key = UniqueKey();
}

/// Two lists as one, the same list object while neither changes.
class _Joined {
  List<CalendarEvent>? _a;
  List<CalendarEvent>? _b;
  List<CalendarEvent> _joined = const [];

  List<CalendarEvent> of(List<CalendarEvent> a, List<CalendarEvent>? b) {
    if (b == null || b.isEmpty) return a;
    if (!identical(a, _a) || !identical(b, _b)) {
      _a = a;
      _b = b;
      _joined = [...a, ...b];
    }
    return _joined;
  }
}

/// The bottom blur and shade reach this share of the way from the screen
/// edge to just above the friend bar.
const bottomBlurShare = 0.75;

double _bottomShadeHeight(BuildContext context) =>
    (MediaQuery.paddingOf(context).bottom + friendBarExtent + chromeFade) *
    bottomBlurShare;

/// The bottom of the month under the friend bar: darker towards the screen
/// edge, fading out upwards.
class _ShadedBottom extends StatelessWidget {
  const _ShadedBottom();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0xD9000000), Color(0x99000000), Color(0x00000000)],
        stops: [0, 0.55, 1],
      ),
    ),
    child: SizedBox.expand(),
  );
}
