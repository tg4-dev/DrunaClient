import 'dart:ui';

import 'package:druna_app/features/calendar_sync/device_calendar.dart';

class FakeDeviceCalendar implements DeviceCalendar {
  FakeDeviceCalendar({
    this.status = CalendarAccess.unknown,
    this.grant = true,
    List<DeviceCalendarInfo>? calendars,
    List<DeviceEvent>? events,
  }) : _calendars = calendars ?? [],
       deviceEvents = events ?? [];

  CalendarAccess status;

  bool grant;
  final List<DeviceCalendarInfo> _calendars;
  List<DeviceCalendarInfo> get calendarList => _calendars;
  final List<DeviceEvent> deviceEvents;

  final written = <String, (String, DeviceEventDraft)>{};
  final deleted = <String>[];
  final shown = <String>[];
  var _ids = 0;

  @override
  Future<CalendarAccess> access() async => status;

  @override
  Future<CalendarAccess> requestAccess() async {
    if (status == CalendarAccess.unknown) {
      status = grant ? CalendarAccess.granted : CalendarAccess.denied;
    }
    return status;
  }

  @override
  Future<void> openSettings() async {}

  @override
  Future<List<DeviceCalendarInfo>> calendars() async => [..._calendars];

  @override
  Future<List<DeviceEvent>> events(
    DateTime from,
    DateTime to,
    List<String> calendarIds,
  ) async => [
    for (final event in [
      ...deviceEvents,
      for (final entry in written.entries)
        DeviceEvent(
          instanceId: entry.key,
          calendarId: entry.value.$1,
          title: entry.value.$2.title,
          start: entry.value.$2.start,
          end: entry.value.$2.end,
          recurring: entry.value.$2.rrule != null,
        ),
    ])
      if (calendarIds.contains(event.calendarId) &&
          event.start.isBefore(to) &&
          event.end.isAfter(from))
        event,
  ];

  @override
  Future<void> show(String instanceId) async => shown.add(instanceId);

  @override
  Future<String> createCalendar(String name, Color color) async {
    final id = 'cal-${++_ids}';
    _calendars.add(DeviceCalendarInfo(id: id, name: name, color: color));
    return id;
  }

  @override
  Future<void> updateCalendar(
    String id, {
    required String name,
    required Color color,
  }) async {
    final i = _calendars.indexWhere((calendar) => calendar.id == id);
    _calendars[i] = DeviceCalendarInfo(id: id, name: name, color: color);
  }

  @override
  Future<void> deleteCalendar(String id) async {
    _calendars.removeWhere((calendar) => calendar.id == id);
    written.removeWhere((_, value) => value.$1 == id);
  }

  @override
  Future<String> createEvent(String calendarId, DeviceEventDraft draft) async {
    final id = 'ev-${++_ids}';
    written[id] = (calendarId, draft);
    return id;
  }

  @override
  Future<void> deleteEvent(String id, {required bool series}) async {
    written.remove(id);
    deleted.add(id);
  }
}
