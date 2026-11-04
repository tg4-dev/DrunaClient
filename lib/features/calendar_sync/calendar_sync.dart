import 'dart:async';
import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:flutter/widgets.dart';

enum ExternalTap { device, druna }

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

  final Duration exportDelay;

  static const _enabledKey = 'calendar_sync.enabled';
  static const _offKey = 'calendar_sync.off';
  static const _knownKey = 'calendar_sync.known';
  static const _tapKey = 'calendar_sync.tap';
  static const _drunaKey = 'calendar_sync.druna_calendar';
  static const _exportedKey = 'calendar_sync.exported';

  static const drunaCalendarName = 'Druna';

  var _access = CalendarAccess.unknown;
  CalendarAccess get access => _access;

  bool get supported => _access != CalendarAccess.unsupported;

  var _enabled = false;

  bool get enabled => _enabled;
  bool get connected => _enabled && _access == CalendarAccess.granted;

  var _calendars = <DeviceCalendarInfo>[];

  List<DeviceCalendarInfo> get calendars => _calendars;

  var _off = <String>{};
  var _known = <String>{};
  bool isOn(String calendarId) => !_off.contains(calendarId);

  var _drunaColor = Brand.accent;

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

  String? get error => _error;

  final events = ValueNotifier<List<CalendarEvent>>(const []);

  String? _drunaCalendar;

  var _exported = <String, _Exported>{};
  List<CalendarEvent> _pendingExport = const [];

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_enabled) {
      refresh();
    } else if (_backFromSettings) {
      _backFromSettings = false;
      _recheckAccess();
    }
  }

  var _backFromSettings = false;

  Future<void> _recheckAccess() async {
    try {
      _access = await device.access();
    } catch (_) {
      return;
    }
    if (_disposed) return;
    if (_access == CalendarAccess.granted) {
      _enabled = true;
      _storage.setBool(_enabledKey, true);
      _notify();
      await refresh();
      return;
    }
    _notify();
  }

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

  Future<void> openSettings() {
    if (!_enabled) _backFromSettings = true;
    return device.openSettings();
  }

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
      if (!_enabled || _disposed) return;
      final byId = {for (final calendar in on) calendar.id: calendar};
      events.value = [
        for (final event in read)
          if (byId[event.calendarId] case final calendar?)
            importedEvent(event, calendar),
      ];
      _lastSync = _now();
      _error = null;
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

  Future<void> show(CalendarEvent event) async {
    final external = event.external;
    if (external == null) return;
    try {
      await device.show(external.instanceId);
    } finally {
      await refresh();
    }
  }

  var exportEnabled = true;

  void mirror(List<CalendarEvent> own) {
    if (!exportEnabled) return;
    _pendingExport = own;
    _mirrored = true;
    _scheduleExport();
  }

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
    } finally {
      _saveExported();
    }
  }

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
      } catch (_) {}
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
    } catch (_) {}
  }

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

bool isDrunaCalendar(DeviceCalendarInfo calendar) =>
    calendar.name == CalendarSync.drunaCalendarName && !calendar.readOnly;

String _eventId(DeviceEvent event) => event.instanceId.split('@').first;

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

bool exportable(CalendarEvent event) =>
    event.external == null &&
    event.invite == null &&
    event.ownerId == null &&
    event.seriesId == null &&
    !event.id.startsWith('demo-');

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
