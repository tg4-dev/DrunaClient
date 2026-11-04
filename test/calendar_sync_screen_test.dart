import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync_sheet.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/features/event_page/event_page.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_device_calendar.dart';

const _work = DeviceCalendarInfo(
  id: 'work',
  name: 'Работа',
  color: Color(0xFF0A84FF),
);

void main() {
  final today = DateTime.now();

  Future<(FakeDeviceCalendar, CalendarSync)> pumpPager(
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final device = FakeDeviceCalendar(
      status: CalendarAccess.granted,
      calendars: [_work],
      events: [
        DeviceEvent(
          instanceId: 'call@1',
          calendarId: 'work',
          title: 'Созвон',
          start: DateTime(today.year, today.month, today.day, 19),
          end: DateTime(today.year, today.month, today.day, 20),
        ),
      ],
    );
    final storage = MemorySettingsStorage();
    await storage.setBool('calendar_sync.enabled', true);
    final sync = CalendarSync(
      device: device,
      storage: storage,
      exportDelay: Duration.zero,
    );
    await tester.runAsync(sync.load);
    addTearDown(sync.dispose);
    final repository = DrunaRepository(
      ApiClient(
        baseUrl: 'https://example.test',
        tokenStore: MemoryTokenStore(),
        dio: Dio(),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: SessionController(repository),
          settings: AppSettings(storage: storage, demoByDefault: true),
          config: const AppConfig(
            apiBaseUrl: 'https://example.test',
            environment: 'test',
          ),
          sync: sync,
          demoDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    // My calendar: a swipe to the right.
    await tester.flingFrom(const Offset(200, 500), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    return (device, sync);
  }

  testWidgets('a device event shows in its calendar’s colour and opens there', (
    tester,
  ) async {
    final (device, _) = await pumpPager(tester);
    expect(find.text('Созвон'), findsWidgets);
    await tester.tap(find.text('Созвон').first);
    await tester.pumpAndSettle();
    expect(device.shown, ['call@1']);
    expect(find.byType(EventPage), findsNothing);
  });

  testWidgets('set to open in Druna, it opens read-only', (tester) async {
    final (device, sync) = await pumpPager(tester);
    sync.tap = ExternalTap.druna;
    await tester.tap(find.text('Созвон').first);
    await tester.pumpAndSettle();
    expect(find.byType(EventPage), findsOneWidget);
    expect(find.byKey(const ValueKey('event-edit')), findsNothing);
    expect(find.text('Работа'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event-open-external')));
    await tester.pumpAndSettle();
    expect(device.shown, ['call@1']);
  });

  testWidgets('"Мои события" opens the calendar menu; the scrim closes it', (
    tester,
  ) async {
    await pumpPager(tester);
    await tester.tap(find.byKey(const ValueKey('mine-button')));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarSyncSheet), findsOneWidget);
    expect(find.text('Работа'), findsOneWidget);
    await tester.tapAt(const Offset(200, 120));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarSyncSheet), findsNothing);
  });

  testWidgets('a device event is not moved by holding it', (tester) async {
    CalendarEvent? moved;
    final event = CalendarEvent(
      id: 'device:x',
      title: 'Созвон',
      start: DateTime(2026, 10, 14, 10),
      end: DateTime(2026, 10, 14, 12),
      color: _work.color,
      external: const ExternalEvent(
        instanceId: 'x',
        calendarId: 'work',
        calendarName: 'Работа',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MonthCalendar(
          focus: DateTime(2026, 10, 14),
          events: [event],
          onDayTap: (_, _) async {},
          onMove: (event, day) => moved = event,
        ),
      ),
    );
    await tester.pump();
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Созвон')),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(moved, isNull);
  });
}
