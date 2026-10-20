import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/friends/friends_page.dart';
import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/features/settings/settings_page.dart';
import 'package:flutter/material.dart';

/// The signed-in app: pages side by side on one plane, the calendar in the
/// middle. Friends lie to its left, settings to its right.
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

  static const friendsPage = 0;
  static const calendarPage = 1;
  static const settingsPage = 2;

  /// Taps on the gear and system back slide this long.
  static const slide = Duration(milliseconds: 280);

  @override
  State<HomePager> createState() => _HomePagerState();
}

class _HomePagerState extends State<HomePager> {
  final _controller = PageController(initialPage: HomePager.calendarPage);
  var _page = HomePager.calendarPage;
  var _calendarBusy = false;
  late var _demo = DemoFriendsSource(delay: widget.demoDelay);
  late final _server = ServerFriendsSource(widget.session.repository);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _page = page);
  }

  void _goTo(int page) {
    _controller.animateToPage(
      page,
      duration: HomePager.slide,
      curve: Curves.easeOutCubic,
    );
  }

  void _resetDemo() {
    setState(() => _demo = DemoFriendsSource(delay: widget.demoDelay));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _page == HomePager.calendarPage,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goTo(HomePager.calendarPage);
      },
      child: ColoredBox(
        color: Colors.black,
        child: ListenableBuilder(
          listenable: widget.settings,
          builder: (context, _) {
            final demo = widget.settings.demoFriends;
            _demo.offline = widget.settings.demoOffline;
            return PageView(
              controller: _controller,
              onPageChanged: _onPageChanged,
              physics: _calendarBusy
                  ? const NeverScrollableScrollPhysics()
                  : const _SnappyPagePhysics(),
              children: [
                _KeepAlive(
                  child: FriendsPage(
                    // A new source is a new page: it loads from scratch.
                    key: ObjectKey(demo ? _demo : _server),
                    source: demo ? _demo : _server,
                  ),
                ),
                _KeepAlive(
                  child: CalendarScreen(
                    onBusyChanged: (busy) =>
                        setState(() => _calendarBusy = busy),
                    onOpenSettings: () => _goTo(HomePager.settingsPage),
                  ),
                ),
                _KeepAlive(
                  child: SettingsPage(
                    session: widget.session,
                    settings: widget.settings,
                    config: widget.config,
                    onResetDemo: _resetDemo,
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

/// Page snapping with a stiffer spring than the default, so a released swipe
/// settles in about half the time.
class _SnappyPagePhysics extends PageScrollPhysics {
  const _SnappyPagePhysics({super.parent});

  @override
  _SnappyPagePhysics applyTo(ScrollPhysics? ancestor) =>
      _SnappyPagePhysics(parent: buildParent(ancestor));

  @override
  SpringDescription get spring =>
      SpringDescription.withDampingRatio(mass: 0.5, stiffness: 400, ratio: 1);
}

/// Keeps a page alive off screen, so the month keeps its scroll position and
/// friends are not reloaded on every swipe.
class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
