import 'package:dio/dio.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ru_RU'));

  DrunaRepository repository() => DrunaRepository(
    ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: MemoryTokenStore(),
      dio: Dio(),
    ),
  );

  test(
    'registration, restart, rename, sign-out and sign-in by email',
    () async {
      final storage = MemorySettingsStorage();
      final accounts = OfflineAccounts(storage);
      final source = OfflineAuthFlowSource(accounts, latency: Duration.zero);

      expect(await source.startEmail('a@b.ru'), EmailStatus.fresh);
      expect(await source.usernameAvailable('alice'), isTrue);
      await source.register(
        email: 'a@b.ru',
        password: 'secret12',
        username: 'alice',
        name: 'Аня',
      );
      expect(await source.usernameAvailable('alice'), isFalse);

      final session = SessionController(repository(), offline: accounts);
      await session.adopt();
      expect(session.state, SessionState.signedIn);
      expect(session.profile?.username, 'alice');

      // A new launch finds the session on the device.
      final again = SessionController(repository(), offline: accounts);
      await again.restore();
      expect(again.state, SessionState.signedIn);

      await again.rename('Анна');
      expect(again.profile?.name, 'Анна');
      expect((await accounts.current())?.name, 'Анна');

      await again.logout();
      expect(again.state, SessionState.signedOut);
      final later = SessionController(repository(), offline: accounts);
      await later.restore();
      expect(later.state, SessionState.signedOut);

      expect(await source.startEmail('a@b.ru'), EmailStatus.registered);
      await source.signIn(email: 'a@b.ru', password: 'anything');
      await later.adopt();
      expect(later.profile?.name, 'Анна');
    },
  );

  test('production never runs without the server', () {
    const config = AppConfig(
      apiBaseUrl: 'https://druna.app',
      environment: 'production',
      offline: true,
    );
    expect(config.offline, isFalse);
  });

  testWidgets('offline, the app opens on the onboarding, then on the saved '
      'session', (tester) async {
    final storage = MemorySettingsStorage();
    const config = AppConfig(
      apiBaseUrl: 'https://example.test',
      environment: 'test',
      offline: true,
    );
    DrunaApp app() => DrunaApp(
      repository: repository(),
      tokenStore: MemoryTokenStore(),
      config: config,
      settingsStorage: storage,
    );

    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(OnboardingFlow), findsOneWidget);

    await OfflineAccounts(
      storage,
    ).create(email: 'a@b.ru', username: 'alice', name: 'Аня');
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomePager), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
