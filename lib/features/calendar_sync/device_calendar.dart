import 'dart:io' show Platform;

import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

enum CalendarAccess { unknown, granted, denied, unsupported }

@immutable
class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.color,
    this.account = '',
    this.readOnly = false,
  });

  final String id;
  final String name;
  final Color color;

  final String account;

  final bool readOnly;
}

@immutable
class DeviceEvent {
  const DeviceEvent({
    required this.instanceId,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.recurring = false,
  });

  final String instanceId;
  final String calendarId;
  final String title;
  final DateTime start;

  final DateTime end;
  final bool allDay;

  final bool recurring;
}

@immutable
class DeviceEventDraft {
  const DeviceEventDraft({
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.rrule,
  });

  final String title;
  final DateTime start;

  final DateTime end;
  final bool allDay;

  final String? rrule;
}

abstract interface class DeviceCalendar {
  Future<CalendarAccess> access();

  Future<CalendarAccess> requestAccess();

  Future<void> openSettings();

  Future<List<DeviceCalendarInfo>> calendars();

  Future<List<DeviceEvent>> events(
    DateTime from,
    DateTime to,
    List<String> calendarIds,
  );

  Future<void> show(String instanceId);

  Future<String> createCalendar(String name, Color color);

  Future<void> updateCalendar(
    String id, {
    required String name,
    required Color color,
  });
  Future<void> deleteCalendar(String id);

  Future<String> createEvent(String calendarId, DeviceEventDraft draft);

  Future<void> deleteEvent(String id, {required bool series});
}

DeviceCalendar platformDeviceCalendar() {
  if (kIsWeb) return const NoDeviceCalendar();
  if (Platform.isIOS || Platform.isAndroid) return PluginDeviceCalendar();
  return const NoDeviceCalendar();
}

String deviceCalendarName() =>
    !kIsWeb && Platform.isIOS ? 'Apple Календарь' : 'Календарь устройства';

class NoDeviceCalendar implements DeviceCalendar {
  const NoDeviceCalendar();

  @override
  Future<CalendarAccess> access() async => CalendarAccess.unsupported;
  @override
  Future<CalendarAccess> requestAccess() async => CalendarAccess.unsupported;
  @override
  Future<void> openSettings() async {}
  @override
  Future<List<DeviceCalendarInfo>> calendars() async => const [];
  @override
  Future<List<DeviceEvent>> events(
    DateTime from,
    DateTime to,
    List<String> calendarIds,
  ) async => const [];
  @override
  Future<void> show(String instanceId) async {}
  @override
  Future<String> createCalendar(String name, Color color) =>
      throw UnsupportedError('Нет календаря устройства');
  @override
  Future<void> updateCalendar(
    String id, {
    required String name,
    required Color color,
  }) async {}
  @override
  Future<void> deleteCalendar(String id) async {}
  @override
  Future<String> createEvent(String calendarId, DeviceEventDraft draft) =>
      throw UnsupportedError('Нет календаря устройства');
  @override
  Future<void> deleteEvent(String id, {required bool series}) async {}
}

class PluginDeviceCalendar implements DeviceCalendar {
  final _calendar = plugin.DeviceCalendar.instance;

  static CalendarAccess _access(plugin.CalendarPermissionStatus status) =>
      switch (status) {
        plugin.CalendarPermissionStatus.granted => CalendarAccess.granted,
        plugin.CalendarPermissionStatus.notDetermined => CalendarAccess.unknown,
        _ => CalendarAccess.denied,
      };

  @override
  Future<CalendarAccess> access() async =>
      _access(await _calendar.hasPermissions());

  @override
  Future<CalendarAccess> requestAccess() async =>
      _access(await _calendar.requestPermissions());

  @override
  Future<void> openSettings() => _calendar.openAppSettings();

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => [
    for (final calendar in await _calendar.listCalendars())
      if (!calendar.hidden)
        DeviceCalendarInfo(
          id: calendar.id,
          name: calendar.name,
          color: calendar.color ?? const Color(0xFF8E8E93),
          account: calendar.accountName ?? '',
          readOnly: calendar.readOnly,
        ),
  ];

  @override
  Future<List<DeviceEvent>> events(
    DateTime from,
    DateTime to,
    List<String> calendarIds,
  ) async {
    if (calendarIds.isEmpty) return const [];
    return [
      for (final event in await _calendar.listEvents(
        from,
        to,
        calendarIds: calendarIds,
      ))
        if (event.status != plugin.EventStatus.canceled)
          DeviceEvent(
            instanceId: event.instanceId,
            calendarId: event.calendarId,
            title: event.title,
            start: event.startDate,
            end: event.endDate,
            allDay: event.isAllDay,
            recurring: event.isRecurring,
          ),
    ];
  }

  @override
  Future<void> show(String instanceId) => _calendar.showEventModal(instanceId);

  @override
  Future<String> createCalendar(String name, Color color) =>
      _calendar.createCalendar(name: name, colorHex: colorHex(color));

  @override
  Future<void> updateCalendar(
    String id, {
    required String name,
    required Color color,
  }) => _calendar.updateCalendar(id, name: name, colorHex: colorHex(color));

  @override
  Future<void> deleteCalendar(String id) => _calendar.deleteCalendar(id);

  @override
  Future<String> createEvent(String calendarId, DeviceEventDraft draft) {
    final rrule = draft.rrule;
    return _calendar.createEvent(
      calendarId: calendarId,
      title: draft.title,
      startDate: draft.start,
      endDate: draft.end,
      isAllDay: draft.allDay,
      recurrenceRule: rrule == null
          ? null
          : plugin.RecurrenceRule.fromRruleString(rrule),
    );
  }

  @override
  Future<void> deleteEvent(String id, {required bool series}) async {
    try {
      if (series) {
        await _calendar.deleteRecurring(id, plugin.EventSpan.allEvents);
      } else {
        await _calendar.deleteEvent(instanceId: id);
      }
    } on plugin.DeviceCalendarException catch (error) {
      if (error.errorCode != plugin.DeviceCalendarError.notFound) rethrow;
    }
  }
}

String colorHex(Color color) {
  String part(double channel) =>
      (channel * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${part(color.r)}${part(color.g)}${part(color.b)}';
}
