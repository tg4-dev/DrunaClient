import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/friends/friends_page.dart';
import 'package:druna_app/features/settings/settings_page.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  Future<AppSettings> pumpPager(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final store = MemoryTokenStore();
    final repository = DrunaRepository(
      ApiClient(baseUrl: 'https://example.test', tokenStore: store, dio: Dio()),
    );
    final session = SessionController(repository);
    final settings = AppSettings(
      storage: MemorySettingsStorage(),
      demoByDefault: true,
    );
    addTearDown(() => settings.slowMotion = false);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: session,
          settings: settings,
          config: const AppConfig(
            apiBaseUrl: 'https://example.test',
            environment: 'test',
          ),
          demoDelay: Duration.zero,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  bool onScreen(WidgetTester tester, Finder finder) {
    final rect = tester.getRect(finder);
    return rect.left >= -1 && rect.right <= 403;
  }

  testWidgets('starts on the calendar; friends lie to its left', (
    tester,
  ) async {
    await pumpPager(tester);
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);

    await tester.fling(find.byType(CalendarScreen), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(FriendsPage)), isTrue);
    expect(find.text('Алина Смирнова'), findsOneWidget);

    await tester.fling(find.byType(FriendsPage), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);
  });

  testWidgets('the gear slides to settings on the right', (tester) async {
    await pumpPager(tester);

    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(SettingsPage)), isTrue);
    expect(find.text('Настройки'), findsOneWidget);

    await tester.fling(find.byType(SettingsPage), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);
  });

  testWidgets('"Нет сети" turns demo friends into an error', (tester) async {
    final settings = await pumpPager(tester);

    settings.demoOffline = true;
    await tester.pumpAndSettle();
    await tester.fling(find.byType(CalendarScreen), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('Не удалось загрузить друзей'), findsOneWidget);
    expect(find.text('Демо: нет соединения с сервером.'), findsOneWidget);

    settings.demoOffline = false;
    await tester.pumpAndSettle();
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Алина Смирнова'), findsOneWidget);
  });

  testWidgets('an open day keeps horizontal swipes for itself', (tester) async {
    await pumpPager(tester);
    final today = DateTime.now();
    await tester.tap(
      find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await tester.fling(find.byType(CalendarScreen), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await tester.fling(find.byType(CalendarScreen), const Offset(300, 0), 1500);
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(FriendsPage)), isTrue);
  });
}
