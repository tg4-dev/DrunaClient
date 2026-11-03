import 'dart:io' show Platform;

import 'package:device_calendar_plus/device_calendar_plus.dart' as plugin;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Whether the app may read the device's calendars.
enum CalendarAccess {
  /// Never asked: the system will show its prompt.
  unknown,
  granted,

  /// Refused, restricted or add-only: only the system settings change it.
  denied,

  /// No calendar on this platform (desktop, tests).
  unsupported,
}

/// A calendar on the device: «Работа», «Дом», «Праздники».
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

  /// The account that holds it: iCloud, Gmail, «На iPhone».
  final String account;

  /// Subscriptions and system calendars (holidays, birthdays).
  final bool readOnly;
}

/// One occurrence of an event on the device; a series comes as one per
/// occurrence.
@immutable
class DeviceEvent {
  const DeviceEvent({
    required this.instanceId,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
    this.allDay = false,
    this.free = false,
    this.recurring = false,
  });

  /// Opens this occurrence in the system's event screen.
  final String instanceId;
  final String calendarId;
  final String title;
  final DateTime start;

  /// Exclusive, for all-day events too: a one-day event ends at the next
  /// midnight.
  final DateTime end;
  final bool allDay;

  /// Marked «свободен»: it does not take the time.
  final bool free;

  /// One occurrence of a series: deleting it means deleting the series.
  final bool recurring;
}

/// An event Druna writes into its own calendar on the device.
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

  /// Exclusive, as in [DeviceEvent.end].
  final DateTime end;
  final bool allDay;

  /// RFC 5545 without the `RRULE:` prefix; null — no repeat.
  final String? rrule;
}

/// The device's calendars: Apple Calendar on iOS, the calendar provider on
/// Android.
abstract interface class DeviceCalendar {
  Future<CalendarAccess> access();

  /// Shows the system prompt if it was never shown.
  Future<CalendarAccess> requestAccess();

  /// The app's page in the system settings, to grant access after a
  /// refusal.
  Future<void> openSettings();

  Future<List<DeviceCalendarInfo>> calendars();

  /// Occurrences overlapping `[from, to)` in [calendarIds].
  Future<List<DeviceEvent>> events(
    DateTime from,
    DateTime to,
    List<String> calendarIds,
  );

  /// The system's own screen for the event.
  Future<void> show(String instanceId);

  /// Returns the new calendar's id.
  Future<String> createCalendar(String name, Color color);

  /// Puts the name and the colour back (the user may have changed them).
  Future<void> updateCalendar(
    String id, {
    required String name,
    required Color color,
  });
  Future<void> deleteCalendar(String id);

  /// Returns the new event's id.
  Future<String> createEvent(String calendarId, DeviceEventDraft draft);

  /// Removes the event with all its repeats; a missing one is not an error.
  Future<void> deleteEvent(String id, {required bool series});
}

/// The plugin on iOS and Android; nothing elsewhere.
DeviceCalendar platformDeviceCalendar() {
  if (kIsWeb) return const NoDeviceCalendar();
  if (Platform.isIOS || Platform.isAndroid) return PluginDeviceCalendar();
  return const NoDeviceCalendar();
}

/// What the device's calendar is called in the interface.
String deviceCalendarName() =>
    !kIsWeb && Platform.isIOS ? 'Apple Календарь' : 'Календарь устройства';

/// A platform without calendars: everything is unsupported.
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
    // An empty list means every calendar to the plugin.
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
            free: event.availability == plugin.EventAvailability.free,
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

/// `#RRGGBB`, as the system calendars take it.
String colorHex(Color color) {
  String part(double channel) =>
      (channel * 255).round().toRadixString(16).padLeft(2, '0');
  return '#${part(color.r)}${part(color.g)}${part(color.b)}';
}
