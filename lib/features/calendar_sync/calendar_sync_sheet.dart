import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/setting_rows.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:druna_app/shared/ui/value_menu.dart';
import 'package:flutter/cupertino.dart';

/// Measurements of the calendar's menu (design-system §9.12). The motion,
/// the scrim and the grabber are the event sheet's.
abstract final class SyncSheetStyle {
  /// The sheet floats this far from the screen's sides and bottom.
  static const inset = 8.0;
  static const radius = EventPageStyle.radius;

  /// At most this share of the screen; the rest scrolls.
  static const maxHeight = 0.75;
  static const dot = 12.0;
}

/// The menu of the user's calendar, risen from the bottom over the month:
/// the device's calendar — whether it is connected, which of its calendars
/// show, whether Druna's events go there, what a tap on its event opens.
class CalendarSyncSheet extends StatefulWidget {
  const CalendarSyncSheet({
    required this.sync,
    required this.onClosing,
    required this.onGone,
    super.key,
  });

  final CalendarSync sync;

  /// The sheet starts leaving: the month may take touches again.
  final VoidCallback onClosing;

  /// The sheet has left and can be removed.
  final VoidCallback onGone;

  @override
  State<CalendarSyncSheet> createState() => _CalendarSyncSheetState();
}

class _CalendarSyncSheetState extends State<CalendarSyncSheet>
    with TickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: EventPageStyle.enter,
    reverseDuration: EventPageStyle.leave,
  );
  late final _rise = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutQuart,
    reverseCurve: Curves.easeInCubic,
  );
  late final _settle = AnimationController(
    vsync: this,
    duration: EventPageStyle.settle,
  )..addListener(_onSettle);
  final _drag = ValueNotifier<double>(0);
  double _settleFrom = 0;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _motion.forward();
    if (widget.sync.enabled) widget.sync.refresh();
  }

  @override
  void dispose() {
    _rise.dispose();
    _motion.dispose();
    _settle.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onSettle() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    _drag.value = _settleFrom * (1 - t);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    widget.onClosing();
    await _motion.reverse();
    if (mounted) widget.onGone();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    final next = _drag.value + (details.primaryDelta ?? 0);
    // Upward pulls resist; the sheet only leaves downward.
    _drag.value = next < 0 ? next * 0.25 : next;
  }

  /// Let go far or fast enough, the sheet leaves at once and the month
  /// takes touches; otherwise it settles back.
  void _onDragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value > EventPageStyle.dismissDistance ||
        velocity > EventPageStyle.dismissVelocity) {
      _swipeAway();
      return;
    }
    _settleFrom = _drag.value;
    _settle.forward(from: 0);
  }

  void _swipeAway() {
    _closing = true;
    widget.onClosing();
    final height = MediaQuery.sizeOf(context).height;
    final from = _drag.value;
    final exit = AnimationController(
      vsync: this,
      duration: EventPageStyle.fling,
    );
    exit.addListener(() {
      _drag.value =
          from + (height - from) * Curves.easeIn.transform(exit.value);
    });
    exit.forward().whenComplete(() {
      exit.dispose();
      if (mounted) widget.onGone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    return IgnorePointer(
      ignoring: _closing,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _drag]),
        builder: (context, sheet) {
          final drag = _drag.value;
          final release = (1 - drag.clamp(0, 400) / 400).toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('sync-scrim'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Opacity(
                    opacity: (_rise.value * release).clamp(0.0, 1.0),
                    child: const ColoredBox(color: EventPageStyle.scrim),
                  ),
                ),
              ),
              Positioned(
                left: SyncSheetStyle.inset,
                right: SyncSheetStyle.inset,
                bottom: SyncSheetStyle.inset,
                child: Transform.translate(
                  offset: Offset(0, height * (1 - _rise.value) + drag),
                  child: sheet,
                ),
              ),
            ],
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height * SyncSheetStyle.maxHeight,
          ),
          // Rows scrolled to the edge go under the corners, not past them.
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(SyncSheetStyle.radius),
            ),
            child: ColoredBox(
              color: SheetStyle.block,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: EventPageStyle.grabber.width,
                              height: EventPageStyle.grabber.height,
                              decoration: BoxDecoration(
                                color: EventPageStyle.grabberColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.calendar,
                                color: SheetStyle.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  deviceCalendarName(),
                                  style: SheetStyle.title,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      // The last row clears the home indicator.
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        12,
                        12 + media.padding.bottom,
                      ),
                      child: ListenableBuilder(
                        listenable: widget.sync,
                        builder: (context, _) =>
                            CalendarSyncOptions(sync: widget.sync),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the menu holds, by the state of the device's calendar.
class CalendarSyncOptions extends StatelessWidget {
  const CalendarSyncOptions({required this.sync, super.key});

  final CalendarSync sync;

  Future<void> _connect(BuildContext context) async {
    final access = await sync.connect();
    if (!context.mounted || access == CalendarAccess.granted) return;
    showToast(context, 'Нет доступа к календарю', error: true);
  }

  Future<void> _disconnect(BuildContext context) async {
    final ok = await confirmAction(
      context,
      title: 'Отключить календарь?',
      message:
          'Его события пропадут из Druna, а календарь «Druna» удалится с '
          'устройства.',
      confirmLabel: 'Отключить',
      destructive: true,
    );
    if (ok) await sync.disconnect(removeDrunaCalendar: true);
  }

  @override
  Widget build(BuildContext context) {
    if (sync.access == CalendarAccess.denied) {
      return _Pitch(
        text:
            'Нет доступа к календарю. Разреши его в настройках, и события '
            'календаря появятся рядом с твоими.',
        button: PillButton(
          key: const ValueKey('sync-open-settings'),
          icon: CupertinoIcons.gear_alt,
          text: 'Открыть настройки',
          onPressed: sync.openSettings,
        ),
      );
    }
    if (!sync.connected) {
      return _Pitch(
        text:
            'События календаря появятся рядом с твоими, а свои Druna '
            'добавит в календарь «Druna».',
        button: PillButton(
          key: const ValueKey('sync-connect'),
          icon: CupertinoIcons.calendar_badge_plus,
          text: 'Подключить',
          onPressed: () => _connect(context),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Caption('Календари'),
        if (sync.calendars.isEmpty)
          SettingRow(title: sync.syncing ? 'Загружаем…' : 'Календарей нет'),
        for (final calendar in sync.calendars)
          SettingSwitchRow(
            key: ValueKey('sync-calendar-${calendar.id}'),
            leading: _Dot(calendar.color),
            title: calendar.name,
            subtitle: calendar.account.isEmpty ? null : calendar.account,
            value: sync.isOn(calendar.id),
            onChanged: (on) => sync.setCalendar(calendar.id, on),
          ),
        const _Caption('Druna'),
        SettingRow(
          title: 'Открывать события',
          trailing: ValueMenu(
            label: _tapOptions[sync.tap.name]!,
            options: _tapOptions,
            selected: sync.tap.name,
            onSelected: (value) => sync.tap = ExternalTap.values.byName(value),
          ),
        ),
        SettingRow(
          key: const ValueKey('sync-refresh'),
          title: 'Обновить',
          subtitle: _syncLine(),
          status: sync.syncing
              ? const SettingCheck.running()
              : sync.error == null
              ? null
              : SettingCheck.failed(sync.error!),
          onTap: sync.syncing ? null : sync.refresh,
        ),
        SettingRow(
          key: const ValueKey('sync-disconnect'),
          title: 'Отключить',
          color: SheetStyle.today,
          onTap: () => _disconnect(context),
        ),
      ],
    );
  }

  String? _syncLine() {
    final last = sync.lastSync;
    if (last == null) return null;
    String two(int value) => value.toString().padLeft(2, '0');
    return 'Обновлено в ${two(last.hour)}:${two(last.minute)}';
  }
}

const _tapOptions = {'device': 'В календаре', 'druna': 'В Druna'};

class _Pitch extends StatelessWidget {
  const _Pitch({required this.text, required this.button});

  final String text;
  final Widget button;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SheetStyle.row),
        const SizedBox(height: 14),
        button,
      ],
    ),
  );
}

class _Caption extends StatelessWidget {
  const _Caption(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 2),
    child: Text(text, style: SheetStyle.caption),
  );
}

/// The colour of a calendar, as in its own app.
class _Dot extends StatelessWidget {
  const _Dot(this.color);

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: SyncSheetStyle.dot,
    height: SyncSheetStyle.dot,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
