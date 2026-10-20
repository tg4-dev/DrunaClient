import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/features/friends/friends_page.dart';
import 'package:druna_app/features/settings/settings_page.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
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
    final settings = AppSettings(
      storage: MemorySettingsStorage(),
      demoByDefault: true,
    );
    addTearDown(() => settings.slowMotion = false);
    await tester.pumpWidget(
      MaterialApp(
        home: HomePager(
          session: SessionController(repository),
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

  Future<void> swipe(WidgetTester tester, double dx) async {
    await tester.flingFrom(const Offset(200, 500), Offset(dx, 0), 1500);
    await tester.pumpAndSettle();
  }

  Finder alinaFinder() => find.bySemanticsLabel('Алина Смирнова');
  const hint = 'Выбери друзей, чтобы увидеть их занятость';

  testWidgets('opens on friends’ calendar with the friend bar', (tester) async {
    await pumpPager(tester);

    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);
    expect(find.text(hint), findsOneWidget);
    expect(tester.getRect(alinaFinder()).left, lessThan(200));
  });

  testWidgets('left to right: my calendar, then the friends page', (
    tester,
  ) async {
    await pumpPager(tester);

    await swipe(tester, 300);
    // Same calendar in place; the bar folded away to the right.
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);
    expect(tester.getRect(alinaFinder()).left, greaterThan(400));

    await swipe(tester, 300);
    expect(onScreen(tester, find.byType(FriendsPage)), isTrue);

    await swipe(tester, -300);
    await swipe(tester, -300);
    expect(tester.getRect(alinaFinder()).left, lessThan(200));
  });

  testWidgets('right to left from home, and the gear, open settings', (
    tester,
  ) async {
    await pumpPager(tester);

    await swipe(tester, -300);
    expect(onScreen(tester, find.byType(SettingsPage)), isTrue);

    await swipe(tester, 300);
    await swipe(tester, 300);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byType(SettingsPage)), isTrue);
  });

  testWidgets('a picked friend folds into the stack, which taps back', (
    tester,
  ) async {
    await pumpPager(tester);

    await tester.tap(alinaFinder());
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('friend-ring')), findsOneWidget);
    expect(find.text(hint), findsNothing);

    await swipe(tester, 300);
    final folded = tester.getRect(alinaFinder());
    expect(folded.left, greaterThan(250));
    expect(folded.right, lessThanOrEqualTo(403));

    await tester.tap(find.bySemanticsLabel('Показать занятость друзей'));
    await tester.pumpAndSettle();
    expect(tester.getRect(alinaFinder()).left, lessThan(200));
  });

  testWidgets('"Нет сети" makes a refresh of friends fail', (tester) async {
    final settings = await pumpPager(tester);

    settings.demoOffline = true;
    await tester.pumpAndSettle();
    await swipe(tester, 300);
    await swipe(tester, 300);
    expect(onScreen(tester, find.byType(FriendsPage)), isTrue);

    await tester.fling(find.text('Друзья'), const Offset(0, 400), 1500);
    await tester.pumpAndSettle();
    // The page already had friends, so it keeps them and says why.
    expect(find.text('Демо: нет соединения с сервером.'), findsOneWidget);
    expect(find.text('Марк Ли'), findsWidgets);
  });

  testWidgets('zooming the month never slides the plane', (tester) async {
    await pumpPager(tester);

    final first = await tester.startGesture(const Offset(120, 400));
    final second = await tester.startGesture(const Offset(280, 600));
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await first.moveBy(const Offset(30, -10));
      await second.moveBy(const Offset(30, 10));
      await tester.pump();
    }
    await first.up();
    await second.up();
    await tester.pumpAndSettle();

    // Still friends' calendar: neither my calendar nor the friends page.
    expect(tester.getRect(alinaFinder()).left, lessThan(200));
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);
  });

  testWidgets('picking my colour in settings repaints my events', (
    tester,
  ) async {
    final settings = await pumpPager(tester);
    await tester.tap(find.byKey(const ValueKey('settings-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('own-color-10')));
    await tester.pumpAndSettle();
    expect(settings.ownColorSlot, 10);

    final calendar = tester.element(find.byType(CalendarScreen));
    expect(OwnEventColor.of(calendar), avatarPalette[10]);
  });

  testWidgets('an open day keeps horizontal swipes for itself', (tester) async {
    await pumpPager(tester);
    final today = DateTime.now();
    await tester.tap(
      find.byKey(ValueKey('day-${today.year}-${today.month}-${today.day}')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);

    await swipe(tester, 300);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(onScreen(tester, find.byType(CalendarScreen)), isTrue);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    await swipe(tester, 300);
    await swipe(tester, 300);
    expect(onScreen(tester, find.byType(FriendsPage)), isTrue);
  });
}
