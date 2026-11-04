import 'dart:async';
import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:flutter/widgets.dart';

/// What a tap on an event of the device's calendar opens.
enum ExternalTap {
  /// The system's own event screen, as in Apple Calendar.
  device,

  /// Druna's event page, read-only.
  druna,
}

/// The device's calendar next to Druna's (design-system §9.12): its events
/// come in to be shown, Druna's own go out to a calendar «Druna» there.
/// That calendar is the app's, not the user's: it is never offered to be
/// switched off, and every write first makes sure it is there, single, in
/// the user's colour and holding exactly what Druna wrote.
class CalendarSync extends ChangeNotifier with WidgetsBindingObserver {
  CalendarSync({
    required this.device,
    required SettingsStorage storage,
    DateTime Function()? now,
    this.exportDelay = const Duration(milliseconds: 600),
  }) : _storage = storage,
       _now = now ?? DateTime.now;

  final DeviceCalendar device;
  final SettingsStorage _storage;
  final DateTime Function() _now;

  /// Edits come in bursts (a drag, a save): the mirror waits for a pause.
  final Duration exportDelay;

  static const _enabledKey = 'calendar_sync.enabled';
  static const _offKey = 'calendar_sync.off';
  static const _knownKey = 'calendar_sync.known';
  static const _tapKey = 'calendar_sync.tap';
  static const _drunaKey = 'calendar_sync.druna_calendar';
  static const _exportedKey = 'calendar_sync.exported';

  /// The calendar Druna writes its own events to.
  static const drunaCalendarName = 'Druna';

  var _access = CalendarAccess.unknown;
  CalendarAccess get access => _access;

  /// False on a platform without calendars: nothing about them is shown.
  bool get supported => _access != CalendarAccess.unsupported;

  var _enabled = false;

  /// The user turned the import on; it works once [access] is granted.
  bool get enabled => _enabled;
  bool get connected => _enabled && _access == CalendarAccess.granted;

  var _calendars = <DeviceCalendarInfo>[];

  /// The device's calendars but Druna's own.
  List<DeviceCalendarInfo> get calendars => _calendars;

  /// Calendars the user switched off; read-only ones (holidays, birthdays)
  /// start off.
  var _off = <String>{};
  var _known = <String>{};
  bool isOn(String calendarId) => !_off.contains(calendarId);

  var _drunaColor = Brand.accent;

  /// The user's colour: the calendar «Druna» on the device takes it.
  Color get drunaColor => _drunaColor;

  set drunaColor(Color value) {
    if (colorHex(value) == colorHex(_drunaColor)) return;
    _drunaColor = value;
    _scheduleExport();
  }

  var _tap = ExternalTap.device;
  ExternalTap get tap => _tap;

  DateTime? _lastSync;
  DateTime? get lastSync => _lastSync;

  var _syncing = false;
  bool get syncing => _syncing;

  String? _error;

  /// The last read failed; the events shown are the ones before it.
  String? get error => _error;

  /// The device's events, in their calendars' colours.
  final events = ValueNotifier<List<CalendarEvent>>(const []);

  String? _drunaCalendar;

  /// Druna's event id → what was written for it on the device.
  var _exported = <String, _Exported>{};
  List<CalendarEvent> _pendingExport = const [];

  /// Nothing is written before the calendar has said what the user's
  /// events are: an empty list would otherwise wipe the calendar «Druna».
  var _mirrored = false;
  Timer? _exportTimer;
  Future<void> _exportQueue = Future.value();
  var _observing = false;
  var _disposed = false;

  Future<void> load() async {
    _enabled = await _storage.getBool(_enabledKey) ?? false;
    _tap = (await _storage.getString(_tapKey)) == ExternalTap.druna.name
        ? ExternalTap.druna
        : ExternalTap.device;
    _off = _readSet(await _storage.getString(_offKey));
    _known = _readSet(await _storage.getString(_knownKey));
    final druna = await _storage.getString(_drunaKey);
    _drunaCalendar = druna == null || druna.isEmpty ? null : druna;
    _exported = _readExported(await _storage.getString(_exportedKey));
    try {
      _access = await device.access();
    } catch (_) {
      _access = CalendarAccess.unsupported;
    }
    if (_disposed) return;
    if (supported && !_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    notifyListeners();
    if (connected) await refresh();
  }

  /// Back from the background: the calendar may have changed there, and so
  /// may the access in the system settings.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _enabled) refresh();
  }

  /// Asks for access and, once given, turns the import on.
  Future<CalendarAccess> connect() async {
    _access = await device.requestAccess();
    if (_access == CalendarAccess.granted) {
      _enabled = true;
      _storage.setBool(_enabledKey, true);
      await refresh();
    }
    _notify();
    return _access;
  }

  /// Stops the import; [removeDrunaCalendar] also takes the calendar
  /// «Druna» off the device.
  Future<void> disconnect({bool removeDrunaCalendar = false}) async {
    _enabled = false;
    _storage.setBool(_enabledKey, false);
    events.value = const [];
    _calendars = [];
    _lastSync = null;
    _error = null;
    _notify();
    if (removeDrunaCalendar) await _removeDrunaCalendar();
  }

  Future<void> openSettings() => device.openSettings();

  /// Reads the calendars and their events again. Asked while a read is
  /// under way, it reads once more after it: the calendar may have changed
  /// in between (an event deleted on the system's screen).
  Future<void> refresh() {
    if (!_enabled) return Future.value();
    final reading = _reading;
    if (reading != null) {
      _again = true;
      return reading;
    }
    return _reading = _readUntilSettled();
  }

  Future<void>? _reading;
  var _again = false;

  Future<void> _readUntilSettled() async {
    _syncing = true;
    _notify();
    try {
      do {
        _again = false;
        await _read();
      } while (_again && _enabled && !_disposed);
    } finally {
      _syncing = false;
      _reading = null;
      _notify();
    }
  }

  Future<void> _read() async {
    try {
      _access = await device.access();
      if (_access != CalendarAccess.granted) {
        events.value = const [];
        _calendars = [];
        return;
      }
      final all = await device.calendars();
      final druna = _drunaCalendar;
      _calendars = [
        for (final calendar in all)
          if (calendar.id != druna && !isDrunaCalendar(calendar)) calendar,
      ];
      _learn(_calendars);
      final on = [
        for (final calendar in _calendars)
          if (isOn(calendar.id)) calendar,
      ];
      final (from, to) = _window();
      final read = await device.events(from, to, [
        for (final calendar in on) calendar.id,
      ]);
      // Disconnected meanwhile: what was read is no longer wanted.
      if (!_enabled || _disposed) return;
      final byId = {for (final calendar in on) calendar.id: calendar};
      events.value = [
        for (final event in read)
          if (byId[event.calendarId] case final calendar?)
            importedEvent(event, calendar),
      ];
      _lastSync = _now();
      _error = null;
      // The calendar «Druna» may have been changed meanwhile, too.
      _scheduleExport();
    } catch (error) {
      _error = 'Не получилось прочитать календарь';
    }
  }

  void setCalendar(String calendarId, bool on) {
    if (isOn(calendarId) == on) return;
    on ? _off.remove(calendarId) : _off.add(calendarId);
    _storage.setString(_offKey, jsonEncode(_off.toList()));
    _notify();
    refresh();
  }

  set tap(ExternalTap value) {
    if (_tap == value) return;
    _tap = value;
    _storage.setString(_tapKey, value.name);
    _notify();
  }

  /// The system's screen for an event of the device's calendar. The event
  /// may be edited or deleted there: once it closes, the calendar is read
  /// again.
  Future<void> show(CalendarEvent event) async {
    final external = event.external;
    if (external == null) return;
    try {
      await device.show(external.instanceId);
    } finally {
      await refresh();
    }
  }

  /// The user's own events as they are now: the calendar «Druna» on the
  /// device is brought to match them, after a pause.
  void mirror(List<CalendarEvent> own) {
    _pendingExport = own;
    _mirrored = true;
    _scheduleExport();
  }

  /// Waits for the queued writes; tests use it.
  @visibleForTesting
  Future<void> flushExport() async {
    if (_exportTimer?.isActive ?? false) {
      _exportTimer!.cancel();
      _exportQueue = _exportQueue.then((_) => _writeExport());
    }
    await _exportQueue;
  }

  void _scheduleExport() {
    if (!_mirrored || _disposed) return;
    _exportTimer?.cancel();
    _exportTimer = Timer(exportDelay, () {
      _exportQueue = _exportQueue.then((_) => _writeExport());
    });
  }

  Future<void> _writeExport() async {
    if (_disposed || !connected || !_mirrored) return;
    final wanted = {
      for (final event in _pendingExport)
        if (exportable(event)) event.id: event,
    };
    try {
      final calendar = await _keepDrunaCalendar();
      await _checkWritten(calendar, wanted);
      for (final entry in _exported.entries.toList()) {
        final event = wanted[entry.key];
        if (event != null && _print(event) == entry.value.print) continue;
        await device.deleteEvent(
          entry.value.deviceId,
          series: entry.value.series,
        );
        _exported.remove(entry.key);
      }
      for (final event in wanted.values) {
        if (_exported.containsKey(event.id)) continue;
        final id = await device.createEvent(calendar, exportDraft(event));
        _exported[event.id] = _Exported(
          id,
          _print(event),
          series: event.repeat != null,
        );
      }
    } catch (_) {
      // Next change tries again; the calendar «Druna» is a mirror.
    } finally {
      _saveExported();
    }
  }

  /// The calendar «Druna», single, named and coloured as it should be. It
  /// is made again if it is gone (deleted by the user, an earlier install's
  /// left behind under another id): then everything goes in again. Other
  /// calendars named «Druna» are leftovers of earlier installs and go.
  Future<String> _keepDrunaCalendar() async {
    final all = await device.calendars();
    final known = _drunaCalendar;
    DeviceCalendarInfo? kept;
    for (final calendar in all) {
      if (calendar.id == known) kept = calendar;
    }
    for (final calendar in all) {
      if (calendar.id == kept?.id || !isDrunaCalendar(calendar)) continue;
      try {
        await device.deleteCalendar(calendar.id);
      } catch (_) {
        // Not ours to delete after all: it stays, out of the list.
      }
    }
    if (kept == null) {
      final id = await device.createCalendar(drunaCalendarName, _drunaColor);
      _drunaCalendar = id;
      _exported = {};
      _storage.setString(_drunaKey, id);
      return id;
    }
    if (kept.name != drunaCalendarName ||
        colorHex(kept.color) != colorHex(_drunaColor)) {
      await device.updateCalendar(
        kept.id,
        name: drunaCalendarName,
        color: _drunaColor,
      );
    }
    return kept.id;
  }

  /// What is in the calendar «Druna» against what Druna wrote: an event
  /// deleted there is written again, one Druna does not know (added by
  /// hand, or written by a run that did not get to note it) goes.
  Future<void> _checkWritten(
    String calendar,
    Map<String, CalendarEvent> wanted,
  ) async {
    final (from, to) = _window();
    final present = await device.events(from, to, [calendar]);
    final presentIds = {for (final event in present) _eventId(event)};
    final ours = {for (final written in _exported.values) written.deviceId};
    final dropped = <String>{};
    for (final event in present) {
      final id = _eventId(event);
      if (ours.contains(id) || !dropped.add(id)) continue;
      await device.deleteEvent(event.instanceId, series: event.recurring);
    }
    _exported.removeWhere((key, written) {
      final event = wanted[key];
      return event != null &&
          _inWindow(event, from, to) &&
          !presentIds.contains(written.deviceId);
    });
  }

  /// From a month back to a year ahead: what is read and checked.
  (DateTime, DateTime) _window() {
    final today = dateOnly(_now());
    return (
      DateTime(today.year, today.month - 1),
      DateTime(today.year + 1, today.month + 1),
    );
  }

  Future<void> _removeDrunaCalendar() async {
    _exportTimer?.cancel();
    final id = _drunaCalendar;
    _drunaCalendar = null;
    _exported = {};
    _storage.setString(_drunaKey, '');
    _saveExported();
    if (id == null) return;
    try {
      await device.deleteCalendar(id);
    } catch (_) {
      // Already gone, or no access any more: nothing left to remove.
    }
  }

  /// New calendars start on, but subscriptions and system ones start off.
  void _learn(List<DeviceCalendarInfo> calendars) {
    var changed = false;
    for (final calendar in calendars) {
      if (_known.add(calendar.id)) {
        changed = true;
        if (calendar.readOnly) _off.add(calendar.id);
      }
    }
    if (!changed) return;
    _storage.setString(_knownKey, jsonEncode(_known.toList()));
    _storage.setString(_offKey, jsonEncode(_off.toList()));
  }

  void _saveExported() => _storage.setString(
    _exportedKey,
    jsonEncode({
      for (final entry in _exported.entries) entry.key: entry.value.toJson(),
    }),
  );

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _exportTimer?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    events.dispose();
    super.dispose();
  }
}

/// A calendar named «Druna» that can be written: Druna's own, or one an
/// earlier install left.
bool isDrunaCalendar(DeviceCalendarInfo calendar) =>
    calendar.name == CalendarSync.drunaCalendarName && !calendar.readOnly;

/// The series an occurrence belongs to: its id up to the occurrence's
/// timestamp.
String _eventId(DeviceEvent event) => event.instanceId.split('@').first;

/// Whether some of [event] falls in `[from, to)`, where it can be checked.
bool _inWindow(CalendarEvent event, DateTime from, DateTime to) {
  if (!event.start.isBefore(to)) return false;
  final repeat = event.repeat;
  if (repeat == null) {
    final end = event.allDay
        ? addCalendarDays(dateOnly(event.end), 1)
        : event.end;
    return end.isAfter(from);
  }
  final until = repeat.until;
  return until == null || !until.isBefore(from);
}

/// Only what the user made goes out: not the demo's events, invites,
/// friends' time or what came from the device.
bool exportable(CalendarEvent event) =>
    event.external == null &&
    event.invite == null &&
    event.ownerId == null &&
    event.seriesId == null &&
    !event.id.startsWith('demo-');

/// An occurrence of the device's calendar as Druna's event. All-day events
/// end on their last day in Druna, at the next midnight on the device.
CalendarEvent importedEvent(DeviceEvent event, DeviceCalendarInfo calendar) {
  final external = ExternalEvent(
    instanceId: event.instanceId,
    calendarId: calendar.id,
    calendarName: calendar.name,
  );
  if (!event.allDay) {
    return CalendarEvent(
      id: 'device:${event.instanceId}',
      title: event.title,
      start: event.start,
      end: event.end,
      color: calendar.color,
      external: external,
    );
  }
  final first = dateOnly(event.start);
  final endDay = dateOnly(event.end);
  final last = event.end == endDay ? addCalendarDays(endDay, -1) : endDay;
  return CalendarEvent(
    id: 'device:${event.instanceId}',
    title: event.title,
    start: first,
    end: last.isBefore(first) ? first : last,
    allDay: true,
    color: calendar.color,
    external: external,
  );
}

/// Druna's event as it goes to the calendar «Druna».
DeviceEventDraft exportDraft(CalendarEvent event) {
  final title = event.title.trim();
  final repeat = event.repeat;
  return DeviceEventDraft(
    title: title.isEmpty ? 'Без названия' : title,
    start: event.allDay ? dateOnly(event.start) : event.start,
    end: event.allDay ? addCalendarDays(dateOnly(event.end), 1) : event.end,
    allDay: event.allDay,
    rrule: repeat == null ? null : rruleOf(repeat, event),
  );
}

/// [rule] in RFC 5545. A series that runs until a day ends after the last
/// occurrence that may start on it.
String rruleOf(RepeatRule rule, CalendarEvent event) {
  final parts = <String>[
    'FREQ=${switch (rule.unit) {
      RepeatUnit.day => 'DAILY',
      RepeatUnit.week => 'WEEKLY',
      RepeatUnit.month => 'MONTHLY',
      RepeatUnit.year => 'YEARLY',
    }}',
    if (rule.interval > 1) 'INTERVAL=${rule.interval}',
    if (rule.usesWeekdays)
      'BYDAY=${[
        for (final day in rule.weekdays.isEmpty ? {event.start.weekday} : (rule.weekdays.toList()..sort())) _weekdays[day - 1],
      ].join(',')}',
  ];
  final until = rule.until;
  if (until != null) {
    if (event.allDay) {
      parts.add('UNTIL=${_date(until)}');
    } else {
      final end = DateTime(until.year, until.month, until.day, 23, 59, 59);
      final utc = end.toUtc();
      parts.add(
        'UNTIL=${_date(utc)}T${_two(utc.hour)}${_two(utc.minute)}'
        '${_two(utc.second)}Z',
      );
    }
  }
  return parts.join(';');
}

const _weekdays = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String _two(int value) => value.toString().padLeft(2, '0');

String _date(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}${_two(day.month)}${_two(day.day)}';

/// What decides whether a written event is still right.
String _print(CalendarEvent event) {
  final draft = exportDraft(event);
  return [
    draft.title,
    draft.start.toIso8601String(),
    draft.end.toIso8601String(),
    draft.allDay,
    draft.rrule ?? '',
  ].join('|');
}

class _Exported {
  const _Exported(this.deviceId, this.print, {required this.series});

  factory _Exported.fromJson(Map<String, Object?> json) => _Exported(
    json['id']! as String,
    json['print']! as String,
    series: json['series'] == true,
  );

  final String deviceId;
  final String print;
  final bool series;

  Map<String, Object?> toJson() => {
    'id': deviceId,
    'print': print,
    'series': series,
  };
}

Set<String> _readSet(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    return {for (final item in jsonDecode(raw) as List) item as String};
  } catch (_) {
    return {};
  }
}

Map<String, _Exported> _readExported(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final map = jsonDecode(raw) as Map<String, Object?>;
    return {
      for (final entry in map.entries)
        entry.key: _Exported.fromJson(entry.value! as Map<String, Object?>),
    };
  } catch (_) {
    return {};
  }
}
