import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/features/event_page/event_subject.dart';
import 'package:druna_app/features/friends/friend_schedule.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/features/friends/friends_page.dart';
import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/features/friends/friends_store.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invite_events.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/features/settings/settings_page.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/material.dart';

/// The signed-in app: one horizontal plane with four stops.
///
/// ```text
/// [ Friends ] [ My calendar | Friends' calendar ] [ Settings ]
///      0            1                2                 3
/// ```
///
/// Stops 1 and 2 are the same calendar, which stays in place: between them
/// the swipe only changes which events are shown ([CalendarScreen.mode]).
class HomePager extends StatefulWidget {
  const HomePager({
    required this.session,
    required this.settings,
    required this.config,
    this.demoDelay = const Duration(milliseconds: 300),
    super.key,
  });

  final SessionController session;
  final AppSettings settings;
  final AppConfig config;

  /// How long demo friends take to answer; zero in tests.
  final Duration demoDelay;

  static const friendsStop = 0;
  static const myCalendarStop = 1;
  static const friendsCalendarStop = 2;
  static const settingsStop = 3;

  /// The app opens on friends' calendar.
  static const homeStop = friendsCalendarStop;

  /// Taps that move along the plane (gear, stack, glow, back) take this long.
  static const slide = Duration(milliseconds: 280);

  @override
  State<HomePager> createState() => _HomePagerState();
}

class _HomePagerState extends State<HomePager> {
  ScrollController? _plane;
  double _width = 0;
  var _stop = HomePager.homeStop;
  var _calendarBusy = false;

  /// 0 — my calendar, 1 — friends' calendar; follows the finger.
  final _mode = ValueNotifier<double>(1);

  late var _demo = DemoFriendsSource(delay: widget.demoDelay);
  late final _server = ServerFriendsSource(widget.session.repository);
  final _demoSchedule = DemoFriendSchedule();
  late final FriendsStore _store = FriendsStore(_friendsSource)..load();
  late final FriendSelection _selection = FriendSelection(
    widget.settings.storage,
  )..load();
  late final FriendSchedules _schedules = FriendSchedules(
    selection: _selection,
    friends: _store,
    source: _scheduleSource,
  );

  /// Invites run on demo data only with demo friends: the server has none
  /// (docs/backend-changes.md, «Приглашения на события»).
  DemoInvitesSource? _demoInvites;
  late final InvitesStore _invites = InvitesStore(_newInvitesSource())
    ..addListener(_syncInvites)
    ..load();

  /// The invites as events, in everyone's colours, for the calendar.
  final _inviteEvents = ValueNotifier<List<CalendarEvent>>(const []);

  /// The invite whose page is open over the plane.
  String? _openInvite;

  FriendsSource get _friendsSource =>
      widget.settings.demoFriends ? _demo : _server;

  FriendInfo get _me => meAsPerson(widget.session.profile);

  InvitesSource _newInvitesSource() {
    if (!widget.settings.demoFriends) {
      _demoInvites = null;
      return const ServerInvitesSource();
    }
    return _demoInvites = DemoInvitesSource(
      me: () => _me,
      delay: widget.demoDelay,
      // Friends answer by themselves, but not in tests (no delay there).
      replyDelay: widget.demoDelay == Duration.zero
          ? null
          : const Duration(seconds: 4),
    )..offline = widget.settings.demoOffline;
  }

  void _syncInvites() {
    _inviteEvents.value = inviteEvents(
      _invites.invites,
      meId: _me.id,
      own: _ownColor,
    );
  }

  void _resetInvites() => _invites.source = _newInvitesSource();

  void _showInvite(String id) => setState(() => _openInvite = id);

  /// Sends a new invite to the store; throws for the sheet to say so.
  Future<void> _sendInvite(InviteDraft draft) => _invites.create(draft);

  FriendScheduleSource get _scheduleSource =>
      widget.settings.demoSchedules ? _demoSchedule : const NoFriendSchedule();

  @override
  void initState() {
    super.initState();
    _demo.offline = widget.settings.demoOffline;
    widget.settings.addListener(_onSettings);
    widget.session.addListener(_onSession);
    _store.addListener(_dropMissingFriends);
  }

  /// The profile arrives after sign-in; it sets the colour of my events.
  void _onSession() {
    _syncInvites();
    setState(() {});
  }

  Color get _ownColor => ownColorFor(widget.settings, widget.session.profile);

  @override
  void dispose() {
    widget.settings.removeListener(_onSettings);
    widget.session.removeListener(_onSession);
    _store.removeListener(_dropMissingFriends);
    _plane?.dispose();
    _mode.dispose();
    _invites.dispose();
    _inviteEvents.dispose();
    _schedules.dispose();
    _selection.dispose();
    _store.dispose();
    super.dispose();
  }

  void _onSettings() {
    _demo.offline = widget.settings.demoOffline;
    _store.source = _friendsSource;
    _schedules.source = _scheduleSource;
    final demoInvites = _demoInvites;
    if ((demoInvites != null) != widget.settings.demoFriends) {
      _resetInvites();
    } else {
      demoInvites?.offline = widget.settings.demoOffline;
    }
    // The user's colour may have changed: their part of every gradient.
    _syncInvites();
    setState(() {});
  }

  void _dropMissingFriends() {
    final friends = _store.friends;
    if (friends == null || _store.error != null) return;
    _selection.keepOnly(friends.map((friend) => friend.id));
  }

  void _resetDemo() {
    setState(() => _demo = DemoFriendsSource(delay: widget.demoDelay));
    _onSettings();
  }

  ScrollController _planeFor(double width) {
    final existing = _plane;
    if (existing == null) {
      _width = width;
      return _plane = ScrollController(initialScrollOffset: _stop * width)
        ..addListener(_onPlaneScroll);
    }
    if (width != _width) {
      _width = width;
      // A new width (rotation, split view): stay on the same stop.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (existing.hasClients) existing.jumpTo(_stop * width);
      });
    }
    return existing;
  }

  void _onPlaneScroll() {
    final plane = _plane;
    if (plane == null || !plane.hasClients || _width == 0) return;
    final offset = plane.offset;
    _mode.value = ((offset - _width) / _width).clamp(0.0, 1.0);
    final stop = (offset / _width).round().clamp(0, 3);
    if (stop != _stop && (offset - stop * _width).abs() < 1) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _stop = stop);
    }
  }

  void _goTo(int stop) {
    final plane = _plane;
    if (plane == null || !plane.hasClients || _width == 0) return;
    final reduce = MediaQuery.of(context).disableAnimations;
    final from = plane.offset / _width;
    final modeOnly =
        from >= HomePager.myCalendarStop - 0.01 &&
        from <= HomePager.friendsCalendarStop + 0.01 &&
        (stop == HomePager.myCalendarStop ||
            stop == HomePager.friendsCalendarStop);
    final position = plane.position;
    if (modeOnly && !reduce && position is ScrollPositionWithSingleContext) {
      // `animateTo` would make the calendar ignore taps until the chips
      // have unfolded; this slide lets them through.
      position.beginActivity(
        _TapThroughSlide(
          position,
          from: position.pixels,
          to: stop * _width,
          duration: HomePager.slide,
          curve: Curves.easeInOutCubic,
          vsync: position.context.vsync,
        ),
      );
      return;
    }
    plane.animateTo(
      stop * _width,
      duration: reduce ? const Duration(milliseconds: 1) : HomePager.slide,
      curve: Curves.easeOutCubic,
    );
  }

  /// The open day pulls the mode: the plane follows between the two
  /// calendar stops, where the calendar stands still.
  void _dragMode(double t) {
    final plane = _plane;
    if (plane == null || !plane.hasClients) return;
    plane.jumpTo((HomePager.myCalendarStop + t.clamp(0.0, 1.0)) * _width);
  }

  /// A quick flick picks its direction; a slow release, the nearer mode.
  void _settleMode(double velocity) {
    final int stop;
    if (velocity.abs() > _modeFlick) {
      stop = velocity > 0
          ? HomePager.friendsCalendarStop
          : HomePager.myCalendarStop;
    } else {
      stop = _mode.value >= 0.5
          ? HomePager.friendsCalendarStop
          : HomePager.myCalendarStop;
    }
    _goTo(stop);
  }

  /// Modes per second.
  static const _modeFlick = 1.5;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _stop == HomePager.homeStop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(HomePager.homeStop);
      },
      child: ColoredBox(
        color: Colors.black,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final height = constraints.maxHeight;
            final plane = _planeFor(width);
            final calendar = CalendarScreen(
              mode: _mode,
              onBusyChanged: (busy) => setState(() => _calendarBusy = busy),
              onOpenSettings: () => _goTo(HomePager.settingsStop),
              onOpenFriends: () => _goTo(HomePager.friendsStop),
              friends: CalendarFriends(
                store: _store,
                selection: _selection,
                events: _schedules,
                schedulesAvailable: widget.settings.demoSchedules,
                onShowFriends: () => _goTo(HomePager.friendsCalendarStop),
                onShowMine: () => _goTo(HomePager.myCalendarStop),
                onAddFriends: () => _goTo(HomePager.friendsStop),
                onModeDrag: _dragMode,
                onModeSettle: _settleMode,
                me: widget.session.profile,
                invites: _inviteEvents,
                onOpenInvite: _showInvite,
                onSendInvite: _sendInvite,
              ),
            );
            final pages = SingleChildScrollView(
              controller: plane,
              scrollDirection: Axis.horizontal,
              physics: _calendarBusy || _openInvite != null
                  ? const NeverScrollableScrollPhysics()
                  : const _SnappyPagePhysics(),
              child: SizedBox(
                width: width * 4,
                height: height,
                child: Row(
                  children: [
                    SizedBox(
                      width: width,
                      child: FriendsPage(
                        // A new source is a new page: it loads from scratch.
                        key: ObjectKey(_friendsSource),
                        source: _friendsSource,
                        onChanged: _store.load,
                      ),
                    ),
                    SizedBox(
                      width: width * 2,
                      child: _StillCalendar(
                        plane: plane,
                        width: width,
                        child: OwnEventColor(color: _ownColor, child: calendar),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: SettingsPage(
                        session: widget.session,
                        settings: widget.settings,
                        config: widget.config,
                        onResetDemo: _resetDemo,
                        onResetFriends: _selection.clear,
                        invites: _invites,
                        onOpenInvite: _showInvite,
                        onResetInvites: _resetInvites,
                      ),
                    ),
                  ],
                ),
              ),
            );
            return Stack(
              children: [
                pages,
                // An invite opens over every page, from the calendar or
                // from the profile.
                if (_openInvite case final id?)
                  Positioned.fill(
                    child: OwnEventColor(
                      color: _ownColor,
                      child: EventPage(
                        key: ValueKey('invite-page-$id'),
                        subject: SharedInvite(id),
                        invites: _invites,
                        me: _me,
                        onGone: () => setState(() => _openInvite = null),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Holds the calendar still on screen while the plane moves between the
/// two calendar stops; outside them it moves with the plane.
class _StillCalendar extends StatelessWidget {
  const _StillCalendar({
    required this.plane,
    required this.width,
    required this.child,
  });

  final ScrollController plane;
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: plane,
      child: SizedBox(width: width, child: child),
      builder: (context, child) {
        final offset = plane.hasClients ? plane.offset : width * 2;
        final shift = (offset - width).clamp(0.0, width);
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: Transform.translate(offset: Offset(shift, 0), child: child),
          ),
        );
      },
    );
  }
}

/// Snapping from stop to stop with a stiffer spring than the default, so a
/// released swipe settles in about half the time. Stops are a viewport
/// width apart, which is exactly what page physics snaps to.
class _SnappyPagePhysics extends PageScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 400, ratio: 1);
}

/// A scroll animation that, unlike [DrivenScrollActivity], keeps taps on
/// the content: settling the mode must not freeze the calendar. A drag
/// still takes over, as with any scroll activity.
class _TapThroughSlide extends DrivenScrollActivity {
  _TapThroughSlide(
    super.delegate, {
    required super.from,
    required super.to,
    required super.duration,
    required super.curve,
    required super.vsync,
  });

  @override
  bool get shouldIgnorePointer => false;
}
