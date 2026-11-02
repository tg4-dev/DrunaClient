import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/models/models.dart';

/// The accounts and the session of the mode without a server (`OFFLINE`,
/// [AppConfig.offline]): made in the onboarding, kept on this device only,
/// no tokens. The rest of the app runs on its demo data.
class OfflineAccounts {
  OfflineAccounts(this.storage);

  final SettingsStorage storage;

  static const _accountsKey = 'offline.accounts';
  static const _currentKey = 'offline.current';

  /// Ids far from the demo friends', so colours do not repeat theirs.
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

  /// Makes an account and signs into it.
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

  Future<void> signIn(String email) => storage.setString(_currentKey, email);

  Future<void> signOut() => storage.setString(_currentKey, '');

  /// The signed-in account, or null.
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
