import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync_sheet.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_calendar.dart';

const _work = DeviceCalendarInfo(
  id: 'work',
  name: 'Работа',
  color: Color(0xFF0A84FF),
  account: 'iCloud',
);
const _holidays = DeviceCalendarInfo(
  id: 'holidays',
  name: 'Праздники',
  color: Color(0xFF34C759),
  readOnly: true,
);

final _today = DateTime(2026, 11, 3);

CalendarSync _sync(FakeDeviceCalendar device, [SettingsStorage? storage]) =>
    CalendarSync(
      device: device,
      storage: storage ?? MemorySettingsStorage(),
      now: () => _today,
      exportDelay: Duration.zero,
    );

void main() {
  group('importedEvent', () {
    test('a timed event keeps its times and its calendar colour', () {
      final event = importedEvent(
        DeviceEvent(
          instanceId: 'a@1',
          calendarId: 'work',
          title: 'Созвон',
          start: DateTime(2026, 11, 3, 10),
          end: DateTime(2026, 11, 3, 11),
        ),
        _work,
      );
      expect(event.id, 'device:a@1');
      expect(event.color, _work.color);
      expect(event.allDay, isFalse);
      expect(event.end, DateTime(2026, 11, 3, 11));
      expect(event.external?.calendarName, 'Работа');
    });

    test('an all-day event ends on its last day, not the next midnight', () {
      DeviceEvent allDay(DateTime start, DateTime end) => DeviceEvent(
        instanceId: 'b',
        calendarId: 'work',
        title: 'Отпуск',
        start: start,
        end: end,
        allDay: true,
      );
      final one = importedEvent(
        allDay(DateTime(2026, 11, 3), DateTime(2026, 11, 4)),
        _work,
      );
      expect(one.start, DateTime(2026, 11, 3));
      expect(one.end, DateTime(2026, 11, 3));
      final three = importedEvent(
        allDay(DateTime(2026, 11, 3), DateTime(2026, 11, 6)),
        _work,
      );
      expect(three.end, DateTime(2026, 11, 5));
    });
  });

  group('rruleOf', () {
    final timed = CalendarEvent(
      id: 'x',
      title: '',
      start: DateTime(2026, 11, 3, 9),
      end: DateTime(2026, 11, 3, 10),
    );

    test('weekly with days and an interval', () {
      const rule = RepeatRule(
        preset: RepeatPreset.custom,
        unit: RepeatUnit.week,
        interval: 2,
        weekdays: {5, 1},
      );
      expect(rruleOf(rule, timed), 'FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,FR');
    });

    test('a weekly rule without days takes the first day', () {
      final rule = RepeatRule.fromPreset(RepeatPreset.weekly, _today);
      expect(
        rruleOf(rule.copyWith(weekdays: {}), timed),
        'FREQ=WEEKLY;BYDAY=TU',
      );
    });

    test('until: a date for all-day events, the end of that day otherwise', () {
      final rule = RepeatRule.fromPreset(
        RepeatPreset.daily,
        _today,
      ).copyWith(until: DateTime(2026, 12, 1));
      final allDay = timed.copyWith(allDay: true);
      expect(rruleOf(rule, allDay), 'FREQ=DAILY;UNTIL=20261201');
      final utc = DateTime(2026, 12, 1, 23, 59, 59).toUtc();
      expect(
        rruleOf(rule, timed),
        startsWith(
          'FREQ=DAILY;UNTIL=${utc.year}${utc.month.toString().padLeft(2, '0')}',
        ),
      );
      expect(rruleOf(rule, timed), endsWith('Z'));
    });
  });

  group('CalendarSync', () {
    test('connecting reads the calendars; read-only ones start off', () async {
      final device = FakeDeviceCalendar(
        calendars: [_work, _holidays],
        events: [
          DeviceEvent(
            instanceId: 'w1',
            calendarId: 'work',
            title: 'Созвон',
            start: DateTime(2026, 11, 4, 10),
            end: DateTime(2026, 11, 4, 11),
          ),
          DeviceEvent(
            instanceId: 'h1',
            calendarId: 'holidays',
            title: 'День народного единства',
            start: DateTime(2026, 11, 4),
            end: DateTime(2026, 11, 5),
            allDay: true,
          ),
        ],
      );
      final sync = _sync(device);
      await sync.load();
      expect(sync.connected, isFalse);
      expect(await sync.connect(), CalendarAccess.granted);
      expect(sync.connected, isTrue);
      expect(sync.isOn('work'), isTrue);
      expect(sync.isOn('holidays'), isFalse);
      expect([for (final e in sync.events.value) e.title], ['Созвон']);

      sync.setCalendar('holidays', true);
      await pumpEventQueue();
      expect(sync.events.value, hasLength(2));
      sync.dispose();
    });

    test('access granted in the system settings connects on return', () async {
      final device = FakeDeviceCalendar(calendars: [_work], grant: false);
      final sync = _sync(device);
      await sync.load();
      expect(await sync.connect(), CalendarAccess.denied);
      expect(sync.connected, isFalse);

      await sync.openSettings();
      device.status = CalendarAccess.granted;
      sync.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(sync.access, CalendarAccess.granted);
      expect(sync.connected, isTrue);
      sync.dispose();
    });

    test(
      'an event deleted on the system screen is gone once it closes',
      () async {
        final device = FakeDeviceCalendar(
          calendars: [_work],
          events: [
            DeviceEvent(
              instanceId: 'w1',
              calendarId: 'work',
              title: 'Созвон',
              start: DateTime(2026, 11, 4, 10),
              end: DateTime(2026, 11, 4, 11),
            ),
          ],
        );
        final sync = _sync(device);
        await sync.load();
        await sync.connect();
        final event = sync.events.value.single;
        final reading = sync.refresh();
        device.deviceEvents.clear();
        await Future.wait([reading, sync.show(event)]);
        expect(device.shown, ['w1']);
        expect(sync.events.value, isEmpty);
        sync.dispose();
      },
    );

    test('a refused prompt leaves it off', () async {
      final sync = _sync(FakeDeviceCalendar(grant: false));
      await sync.load();
      expect(await sync.connect(), CalendarAccess.denied);
      expect(sync.enabled, isFalse);
      sync.dispose();
    });

    test('settings survive a restart', () async {
      final storage = MemorySettingsStorage();
      final device = FakeDeviceCalendar(calendars: [_work, _holidays]);
      final first = _sync(device, storage);
      await first.load();
      await first.connect();
      first.setCalendar('work', false);
      first.tap = ExternalTap.druna;
      first.dispose();

      final second = _sync(device, storage);
      await second.load();
      expect(second.connected, isTrue);
      expect(second.isOn('work'), isFalse);
      expect(second.tap, ExternalTap.druna);
      second.dispose();
    });

    test('in the demo version nothing goes to the device', () async {
      final device = FakeDeviceCalendar(calendars: [_work]);
      final sync = _sync(device)..exportEnabled = false;
      await sync.load();
      await sync.connect();
      sync.mirror([
        CalendarEvent(
          id: 'local-1',
          title: 'Бег',
          start: DateTime(2026, 11, 3, 8),
          end: DateTime(2026, 11, 3, 9),
        ),
      ]);
      await sync.flushExport();
      expect(device.written, isEmpty);
      sync.dispose();
    });

    test('the calendar «Druna» mirrors only what the user made', () async {
      final device = FakeDeviceCalendar(calendars: [_work]);
      final sync = _sync(device);
      await sync.load();
      await sync.connect();
      final mine = CalendarEvent(
        id: 'local-1',
        title: 'Бег',
        start: DateTime(2026, 11, 3, 8),
        end: DateTime(2026, 11, 3, 9),
        repeat: RepeatRule.fromPreset(RepeatPreset.weekly, _today),
      );
      final demo = CalendarEvent(
        id: 'demo-lunch',
        title: 'Обед',
        start: DateTime(2026, 11, 5, 13),
        end: DateTime(2026, 11, 5, 14),
      );
      sync.mirror([mine, demo, ...sync.events.value]);
      await sync.flushExport();
      expect(device.written.values.map((w) => w.$2.title), ['Бег']);
      expect(device.written.values.single.$2.rrule, 'FREQ=WEEKLY;BYDAY=TU');
      await sync.refresh();
      expect(sync.calendars.map((c) => c.id), ['work']);

      sync.mirror([mine.copyWith(title: 'Бег в парке'), demo]);
      await sync.flushExport();
      expect(device.written.values.single.$2.title, 'Бег в парке');
      sync.mirror([demo]);
      await sync.flushExport();
      expect(device.written, isEmpty);
      sync.dispose();
    });

    group('the calendar «Druna» keeps itself', () {
      final run = CalendarEvent(
        id: 'local-1',
        title: 'Бег',
        start: DateTime(2026, 11, 5, 8),
        end: DateTime(2026, 11, 5, 9),
      );

      Future<(FakeDeviceCalendar, CalendarSync)> start({
        List<DeviceCalendarInfo> extra = const [],
      }) async {
        final device = FakeDeviceCalendar(calendars: [_work, ...extra]);
        final sync = _sync(device)..drunaColor = const Color(0xFFFF2D78);
        await sync.load();
        await sync.connect();
        sync.mirror([run]);
        await sync.flushExport();
        return (device, sync);
      }

      DeviceCalendarInfo druna(FakeDeviceCalendar device) => device.calendarList
          .singleWhere((calendar) => calendar.name == 'Druna');

      test(
        'nothing is written before the calendar says what is mine',
        () async {
          final device = FakeDeviceCalendar(calendars: [_work]);
          final sync = _sync(device);
          await sync.load();
          await sync.connect();
          await sync.flushExport();
          expect(device.calendarList, [_work]);
          sync.dispose();
        },
      );

      test('it is never offered in the list, and wears my colour', () async {
        final (device, sync) = await start();
        await sync.refresh();
        expect(sync.calendars.map((c) => c.id), ['work']);
        expect(druna(device).color, const Color(0xFFFF2D78));

        sync.drunaColor = const Color(0xFF34C759);
        await sync.flushExport();
        expect(druna(device).color, const Color(0xFF34C759));
        sync.dispose();
      });

      test('deleted by the user, it comes back with everything', () async {
        final (device, sync) = await start();
        await device.deleteCalendar(druna(device).id);
        sync.mirror([run]);
        await sync.flushExport();
        expect(druna(device), isNotNull);
        expect(device.written.values.single.$2.title, 'Бег');
        sync.dispose();
      });

      test('renamed or recoloured, it is put back', () async {
        final (device, sync) = await start();
        await device.updateCalendar(
          druna(device).id,
          name: 'Мой',
          color: const Color(0xFF000000),
        );
        await sync.refresh();
        await sync.flushExport();
        expect(druna(device).color, const Color(0xFFFF2D78));
        expect(sync.calendars.map((c) => c.id), ['work']);
        sync.dispose();
      });

      test('a leftover «Druna» of an earlier install goes', () async {
        const old = DeviceCalendarInfo(
          id: 'old',
          name: 'Druna',
          color: Color(0xFF970AB6),
        );
        final (device, sync) = await start(extra: [old]);
        expect(
          device.calendarList.where((c) => c.name == 'Druna'),
          hasLength(1),
        );
        expect(device.calendarList.any((c) => c.id == 'old'), isFalse);
        sync.dispose();
      });

      test(
        'an event deleted there is written again; a stray one goes',
        () async {
          final (device, sync) = await start();
          final calendar = druna(device).id;
          device.written.clear();
          device.written['stray'] = (
            calendar,
            DeviceEventDraft(
              title: 'Чужое',
              start: DateTime(2026, 11, 6, 8),
              end: DateTime(2026, 11, 6, 9),
            ),
          );
          sync.mirror([run]);
          await sync.flushExport();
          expect(device.deleted, contains('stray'));
          expect(device.written.values.map((w) => w.$2.title), ['Бег']);
          sync.dispose();
        },
      );

      test('disconnecting removes it', () async {
        final (device, sync) = await start();
        await sync.disconnect(removeDrunaCalendar: true);
        expect(device.calendarList, [_work]);
        expect(device.written, isEmpty);
        sync.dispose();
      });
    });
  });

  group('CalendarSyncOptions', () {
    Future<CalendarSync> pump(
      WidgetTester tester,
      FakeDeviceCalendar device,
    ) async {
      final sync = _sync(device);
      await tester.runAsync(sync.load);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListenableBuilder(
              listenable: sync,
              builder: (context, _) => CalendarSyncOptions(sync: sync),
            ),
          ),
        ),
      );
      return sync;
    }

    testWidgets('«Подключить» asks, then lists the calendars', (tester) async {
      final sync = await pump(
        tester,
        FakeDeviceCalendar(calendars: [_work, _holidays]),
      );
      await tester.tap(find.byKey(const ValueKey('sync-connect')));
      await tester.pumpAndSettle();
      expect(find.text('Работа'), findsOneWidget);
      expect(find.text('Праздники'), findsOneWidget);
      expect(find.text('Открывать события'), findsOneWidget);
      sync.dispose();
    });

    testWidgets('without access it leads to the settings', (tester) async {
      final sync = await pump(
        tester,
        FakeDeviceCalendar(status: CalendarAccess.denied),
      );
      expect(find.byKey(const ValueKey('sync-open-settings')), findsOneWidget);
      expect(find.byKey(const ValueKey('sync-connect')), findsNothing);
      sync.dispose();
    });
  });
}
