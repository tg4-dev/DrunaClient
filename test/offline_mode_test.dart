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

void main() {
  DrunaRepository repository() => DrunaRepository(
    ApiClient(
      baseUrl: 'https://example.test',
      tokenStore: MemoryTokenStore(),
      dio: Dio(),
    ),
  );

  test(
    'demo: registration, restart, rename, sign-out, sign-in by username',
    () async {
      final storage = MemorySettingsStorage();
      final accounts = OfflineAccounts(storage);
      final source = OfflineAuthFlowSource(accounts, latency: Duration.zero);

      expect(await source.startUsername('alice'), AccountStatus.fresh);
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

      expect(await source.startUsername('alice'), AccountStatus.registered);
      await expectLater(
        source.signIn(username: 'bob', password: 'anything'),
        throwsA(wrongLogin),
      );
      await source.signIn(username: 'alice', password: 'anything');
      await later.adopt();
      expect(later.profile?.name, 'Анна');
    },
  );

  test('switching the version signs out and swaps the accounts', () async {
    final accounts = OfflineAccounts(MemorySettingsStorage());
    await accounts.create(email: 'a@b.ru', username: 'alice', name: 'Аня');
    final session = SessionController(repository(), offline: accounts);
    await session.restore();
    expect(session.state, SessionState.signedIn);

    await session.switchTo(null);
    expect(session.state, SessionState.signedOut);
    expect(session.offline, isNull);
    expect(await accounts.current(), isNull);
  });

  testWidgets('in the demo version the app opens on the onboarding, then on '
      'the saved session', (tester) async {
    final storage = MemorySettingsStorage();
    const config = AppConfig(
      apiBaseUrl: 'https://example.test',
      demoData: true,
    );
    DrunaApp app() => DrunaApp(
      repository: repository(),
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
