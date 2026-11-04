import 'dart:math' as math;

import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/repositories/druna_repository.dart';

enum AccountStatus { registered, fresh, unknown }

enum EmailStatus { registered, fresh }

class AuthFlowException implements Exception {
  const AuthFlowException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum TakenField { email, username }

class AuthTakenException extends AuthFlowException {
  const AuthTakenException(this.field, super.message);

  final TakenField field;
}

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

String authErrorText(Object error) => switch (error) {
  ApiException(isUnauthorized: true) => wrongPassword.message,
  AuthFlowException(:final message) => message,
  ApiException(:final message) => message,
  _ => 'Не получилось, попробуй ещё раз',
};

bool isWrongCredentials(Object error) =>
    identical(error, wrongPassword) ||
    identical(error, wrongLogin) ||
    (error is ApiException && error.isUnauthorized);

const wrongPassword = AuthFlowException('неверный пароль');

const wrongLogin = AuthFlowException('неверный ник или пароль');

const resetUnsupported = AuthFlowException(
  'восстановление пароля пока не поддерживается',
);

const emailUnsupported = AuthFlowException(
  'подтверждение почты пока не поддерживается',
);

abstract interface class AuthFlowSource {
  Future<AccountStatus> startUsername(String username);

  Future<String?> signIn({required String username, required String password});

  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  });

  Future<EmailStatus> startEmail(String email);

  Future<void> resendCode(String email);

  Future<bool> verifyCode(String email, String code);

  Future<bool> usernameAvailable(String username);

  Future<void> resetPassword(String email);
}

class ServerAuthFlowSource implements AuthFlowSource {
  ServerAuthFlowSource(this.repository);

  final DrunaRepository repository;

  @override
  Future<AccountStatus> startUsername(String username) async =>
      AccountStatus.unknown;

  @override
  Future<String?> signIn({
    required String username,
    required String password,
  }) async {
    await repository.signIn(username, password);
    try {
      return (await repository.getProfile()).name;
    } catch (_) {
      return null;
    }
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
      throw takenOr(error);
    }
    await repository.signIn(username, password);
  }

  @override
  Future<EmailStatus> startEmail(String email) async => throw emailUnsupported;

  @override
  Future<void> resendCode(String email) async => throw emailUnsupported;

  @override
  Future<bool> verifyCode(String email, String code) async =>
      throw emailUnsupported;

  @override
  Future<bool> usernameAvailable(String username) async => true;

  @override
  Future<void> resetPassword(String email) async => throw resetUnsupported;
}

class RehearsalAuthFlowSource implements AuthFlowSource {
  RehearsalAuthFlowSource({
    this.signInOnly = false,
    this.latency = const Duration(milliseconds: 700),
  });

  final bool signInOnly;
  final Duration latency;

  static const code = '123456';
  static const registeredUsername = 'demo';
  static const badPassword = 'wrongpass';
  static const takenUsernames = {'admin', 'druna', 'test'};

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future<void>.delayed(latency);

  @override
  Future<AccountStatus> startUsername(String username) async {
    await _wait();
    return signInOnly || username == registeredUsername
        ? AccountStatus.registered
        : AccountStatus.fresh;
  }

  @override
  Future<String?> signIn({
    required String username,
    required String password,
  }) async {
    await _wait();
    if (password == badPassword) throw wrongPassword;
    return username;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) => _wait();

  @override
  Future<EmailStatus> startEmail(String email) async {
    await _wait();
    return EmailStatus.fresh;
  }

  @override
  Future<void> resendCode(String email) => _wait();

  @override
  Future<bool> verifyCode(String email, String code) async {
    await _wait();
    return code == RehearsalAuthFlowSource.code;
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    await _wait();
    return !takenUsernames.contains(username);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _wait();
    throw resetUnsupported;
  }
}

class OfflineAuthFlowSource implements AuthFlowSource {
  OfflineAuthFlowSource(
    this.accounts, {
    this.latency = const Duration(milliseconds: 500),
  });

  final OfflineAccounts accounts;
  final Duration latency;

  final _random = math.Random();

  Future<void> _wait() async {
    if (latency == Duration.zero) return;
    final jitter = _random.nextInt(200);
    await Future<void>.delayed(latency + Duration(milliseconds: jitter));
  }

  @override
  Future<AccountStatus> startUsername(String username) async {
    await _wait();
    return await accounts.byUsername(username) == null
        ? AccountStatus.fresh
        : AccountStatus.registered;
  }

  @override
  Future<String?> signIn({
    required String username,
    required String password,
  }) async {
    await _wait();
    final account = await accounts.byUsername(username);
    if (account == null) throw wrongLogin;
    await accounts.signIn(account.email);
    return account.name;
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String username,
    required String name,
  }) async {
    await _wait();
    if (await accounts.byUsername(username) != null) {
      throw const AuthTakenException(TakenField.username, 'ник занят');
    }
    if ((await accounts.accounts()).containsKey(email)) {
      throw const AuthTakenException(
        TakenField.email,
        'эта почта уже зарегистрирована',
      );
    }
    await accounts.create(email: email, username: username, name: name);
  }

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
    return code == RehearsalAuthFlowSource.code;
  }

  @override
  Future<bool> usernameAvailable(String username) async {
    await _wait();
    return await accounts.byUsername(username) == null &&
        !RehearsalAuthFlowSource.takenUsernames.contains(username);
  }

  @override
  Future<void> resetPassword(String email) async {
    await _wait();
    throw resetUnsupported;
  }
}
