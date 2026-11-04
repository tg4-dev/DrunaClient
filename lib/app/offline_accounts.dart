import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/models/models.dart';

class OfflineAccounts {
  OfflineAccounts(this.storage);

  final SettingsStorage storage;

  static const _accountsKey = 'offline.accounts';
  static const _currentKey = 'offline.current';

  static const _firstId = 900;

  Future<Map<String, UserProfile>> accounts() async {
    final raw = await storage.getString(_accountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return {
        for (final MapEntry(:key, :value) in map.entries)
          key: UserProfile.fromJson(Map<String, dynamic>.from(value as Map)),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> _write(Map<String, UserProfile> accounts) => storage.setString(
    _accountsKey,
    jsonEncode({
      for (final MapEntry(:key, :value) in accounts.entries)
        key: {
          'id': value.id,
          'name': value.name,
          'username': value.username,
          'email': value.email,
        },
    }),
  );

  Future<UserProfile> create({
    required String email,
    required String username,
    required String name,
  }) async {
    final all = await accounts();
    final profile = UserProfile(
      id: _firstId + all.length,
      name: name,
      username: username,
      email: email,
    );
    all[email] = profile;
    await _write(all);
    await storage.setString(_currentKey, email);
    return profile;
  }

  Future<UserProfile?> byUsername(String username) async {
    for (final account in (await accounts()).values) {
      if (account.username == username) return account;
    }
    return null;
  }

  Future<void> signIn(String email) => storage.setString(_currentKey, email);

  Future<void> signOut() => storage.setString(_currentKey, '');

  Future<UserProfile?> current() async {
    final email = await storage.getString(_currentKey);
    if (email == null || email.isEmpty) return null;
    return (await accounts())[email];
  }

  Future<UserProfile> rename(String name) async {
    final me = await current();
    if (me == null) throw StateError('no offline session');
    final renamed = UserProfile(
      id: me.id,
      name: name,
      username: me.username,
      email: me.email,
    );
    final all = await accounts()
      ..[me.email] = renamed;
    await _write(all);
    return renamed;
  }
}
