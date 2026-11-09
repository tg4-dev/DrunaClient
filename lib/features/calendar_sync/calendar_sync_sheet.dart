import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/floating_sheet.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/setting_rows.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:druna_app/shared/ui/value_menu.dart';
import 'package:flutter/cupertino.dart';

abstract final class SyncSheetStyle {
  static const dot = 12.0;
}

class CalendarSyncSheet extends StatefulWidget {
  const CalendarSyncSheet({
    required this.sync,
    required this.onClosing,
    required this.onGone,
    super.key,
  });

  final CalendarSync sync;

  final VoidCallback onClosing;

  final VoidCallback onGone;

  @override
  State<CalendarSyncSheet> createState() => _CalendarSyncSheetState();
}

class _CalendarSyncSheetState extends State<CalendarSyncSheet> {
  @override
  void initState() {
    super.initState();
    if (widget.sync.enabled) widget.sync.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingSheet(
      scrimKey: const ValueKey('sync-scrim'),
      icon: CupertinoIcons.calendar,
      title: deviceCalendarName(),
      onClosing: widget.onClosing,
      onGone: widget.onGone,
      child: ListenableBuilder(
        listenable: widget.sync,
        builder: (context, _) => CalendarSyncOptions(sync: widget.sync),
      ),
    );
  }
}

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
