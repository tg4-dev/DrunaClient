import 'dart:convert';
import 'dart:math' as math;

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/repositories/druna_repository.dart';

/// Whether an email already has an account.
enum EmailStatus {
  /// Sign in with the password.
  registered,

  /// A code went out; registration follows.
  fresh,
}

/// The server could not do it: the text is for the user, in Russian.
class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the server already has: the registration goes back to that step.
enum TakenField { email, username }

/// Registration refused: the email or the username belongs to someone.
class AuthTakenException extends AuthFlowException {
  const AuthTakenException(this.field, super.message);

  final TakenField field;
}

/// The server's sign-up answers a taken email or username with the
/// database's own text (`duplicate key … "unique_email"`); this turns it
/// into [AuthTakenException]. Anything else passes through.
Object takenOr(Object error) {
  if (error is! ApiException) return error;
  final text = error.message.toLowerCase();
  if (!text.contains('unique') && !text.contains('duplicate')) return error;
  if (text.contains('email')) {
    return const AuthTakenException(
      TakenField.email,
      'эта почта уже зарегистрирована',
    );
  }
  if (text.contains('username')) {
    return const AuthTakenException(TakenField.username, 'ник занят');
  }
  return error;
}

/// The text to show for any failure of the onboarding.
String authErrorText(Object error) => switch (error) {
  ApiException(isUnauthorized: true) => wrongPassword.message,
  AuthFlowException(:final message) => message,
  ApiException(:final message) => message,
  _ => 'Не получилось, попробуй ещё раз',
};

/// A wrong password at sign-in: the server answers 401.
const wrongPassword = AuthFlowException('неверный пароль');

/// No server endpoint resets a password yet (docs/backend-changes.md).
const resetUnsupported = AuthFlowException(
  'восстановление пароля пока не поддерживается',
);

/// What the onboarding asks of the server (design-system §9.9). The server
/// has only `sign-up` and `sign-in` by username; the rest is proposed in
/// docs/backend-changes.md. Sign-in and registration save the tokens; the
/// session is let in later, by [SessionController.adopt].
abstract interface class AuthFlowSource {
  /// Is there an account? For a new email this also sends the code.
  Future<EmailStatus> startEmail(String email);

  Future<void> resendCode(String email);

  /// False for a wrong code.
  Future<bool> verifyCode(String email, String code);

  /// True when nobody has the username yet.
  Future<bool> usernameAvailable(String username);

  Future<void> signIn({required String email, required String password});

  /// «забыл пароль?». Nowhere supported yet: throws [resetUnsupported].
  Future<void> resetPassword(String email);

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  });
}

/// The real server: only registration exists there. Everything else
/// answers honestly that it is not supported.
class ServerAuthFlowSource implements AuthFlowSource {
  ServerAuthFlowSource(this.repository);

  final DrunaRepository repository;

  static const _unsupported = AuthFlowException(
    'Вход по почте пока не поддерживается сервером',
  );

  @override
  Future<EmailStatus> startEmail(String email) async => throw _unsupported;

  @override
  Future<void> resendCode(String email) async => throw _unsupported;

  @override
  Future<bool> verifyCode(String email, String code) async =>
      throw _unsupported;

  @override
  Future<bool> usernameAvailable(String username) async => throw _unsupported;

  @override
  Future<void> signIn({required String email, required String password}) =>
      throw _unsupported;

  @override
  Future<void> resetPassword(String email) async => throw resetUnsupported;

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    try {
      await repository.signUp(
        name: name,
        username: username,
        email: email,
        password: password,
      );
    } catch (error) {
      throw takenOr(error);
    }
  }
}

/// Demo answers for what the server lacks; registration and sign-in are
/// real. The code is always [code]. An email counts as registered when an
/// account was made with it on this device: the server signs in by
/// username, and this is where the username is remembered.
class DemoAuthFlowSource implements AuthFlowSource {
  DemoAuthFlowSource({
    required this.repository,
    required this.storage,
    this.latency = const Duration(milliseconds: 700),
  });

  final DrunaRepository repository;
  final SettingsStorage storage;

  /// How long each demo answer takes; zero in tests.
  final Duration latency;

  static const code = '123456';
  static const takenUsernames = {'admin', 'druna', 'test'};
  static const _accountsKey = 'demo_auth.accounts';

  /// The username of an email the server has, made elsewhere: not known.
  static const _unknown = '';

  final _random = math.Random();

  Future<void> _wait() async {
    if (latency == Duration.zero) return;
    final jitter = _random.nextInt(200);
    await Future<void>.delayed(latency + Duration(milliseconds: jitter));
  }

  Future<Map<String, String>> _accounts() async {
    final raw = await storage.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }

  @override
  Future<EmailStatus> startEmail(String email) async {
    await _wait();
    final accounts = await _accounts();
    return accounts.containsKey(email)
        ? EmailStatus.registered
        : EmailStatus.fresh;
  }

  @override
  Future<void> resendCode(String email) => _wait();

  @override
  Future<bool> verifyCode(String email, String code) async {
    await _wait();
    return code == DemoAuthFlowSource.code;
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    await _wait();
    return !takenUsernames.contains(username);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    final username = (await _accounts())[email];
    if (username == null || username == _unknown) {
      // The server signs in by username only, and this device does not
      // know it for this email.
      throw const AuthFlowException(
        'Вход по почте сервер пока не умеет: в демо войти можно только в '
        'аккаунт, созданный на этом устройстве',
      );
    }
    await repository.signIn(username, password);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _wait();
    throw resetUnsupported;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    try {
      await repository.createAccount(
        name: name,
        username: username,
        email: email,
        password: password,
      );
    } catch (error) {
      final taken = takenOr(error);
      // The server has this email from elsewhere: next time it takes the
      // sign-in path instead of a new registration.
      if (taken is AuthTakenException && taken.field == TakenField.email) {
        await _remember(email, _unknown);
      }
      throw taken;
    }
    // Remembered before signing in: if that fails, the account exists all
    // the same and the email must lead to the password next time.
    await _remember(email, username);
    await repository.signIn(username, password);
  }

  Future<void> _remember(String email, String username) async {
    final accounts = await _accounts()
      ..[email] = username;
    await storage.setString(_accountsKey, jsonEncode(accounts));
  }
}

/// The onboarding played from the settings (design-system §9.9): demo
/// answers, and nothing reaches the server — no account is made, the
/// session stays as it is. [registeredEmail] takes the sign-in path, and
/// with [signInOnly] every email does; [wrongPassword] fails the sign-in.
class RehearsalAuthFlowSource implements AuthFlowSource {
  RehearsalAuthFlowSource({
    this.signInOnly = false,
    this.latency = const Duration(milliseconds: 700),
  });

  /// «Пройти вход» in the settings: any email has an account.
  final bool signInOnly;
  final Duration latency;

  static const registeredEmail = 'demo@druna.app';
  static const badPassword = 'wrongpass';

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future<void>.delayed(latency);

  @override
  Future<EmailStatus> startEmail(String email) async {
    await _wait();
    return signInOnly || email == registeredEmail
        ? EmailStatus.registered
        : EmailStatus.fresh;
  }

  @override
  Future<void> resendCode(String email) => _wait();

  @override
  Future<bool> verifyCode(String email, String code) async {
    await _wait();
    return code == DemoAuthFlowSource.code;
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    await _wait();
    return !DemoAuthFlowSource.takenUsernames.contains(username);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _wait();
    if (password == badPassword) throw wrongPassword;
  }

  @override
  Future<void> resetPassword(String email) async {
    await _wait();
    throw resetUnsupported;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) => _wait();
}

/// The mode without a server (`config/offline.json`): the whole flow runs
/// on the device. The code is [DemoAuthFlowSource.code]; an email with an
/// account on this device signs in with any password — there is nothing to
/// check it against. The session goes to [OfflineAccounts].
class OfflineAuthFlowSource implements AuthFlowSource {
  OfflineAuthFlowSource(
    this.accounts, {
    this.latency = const Duration(milliseconds: 500),
  });

  final OfflineAccounts accounts;
  final Duration latency;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future<void>.delayed(latency);

  @override
  Future<EmailStatus> startEmail(String email) async {
    await _wait();
    return (await accounts.accounts()).containsKey(email)
        ? EmailStatus.registered
        : EmailStatus.fresh;
  }

  @override
  Future<void> resendCode(String email) => _wait();

  @override
  Future<bool> verifyCode(String email, String code) async {
    await _wait();
    return code == DemoAuthFlowSource.code;
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    await _wait();
    final mine = (await accounts.accounts()).values.map((a) => a.username);
    return !DemoAuthFlowSource.takenUsernames.contains(username) &&
        !mine.contains(username);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _wait();
    await accounts.signIn(email);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _wait();
    throw resetUnsupported;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    await _wait();
    await accounts.create(email: email, username: username, name: name);
  }
}
