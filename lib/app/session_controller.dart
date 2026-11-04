import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/foundation.dart';

enum SessionState { restoring, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this.repository, {this.offline}) {
    repository.onSessionExpired = _expired;
  }

  final DrunaRepository repository;

  var _expiredSignOut = false;

  bool takeExpiredSignOut() {
    final expired = _expiredSignOut;
    _expiredSignOut = false;
    return expired;
  }

  void _expired() {
    if (offline != null || state != SessionState.signedIn) return;
    profile = null;
    state = SessionState.signedOut;
    _expiredSignOut = true;
    notifyListeners();
  }

  OfflineAccounts? offline;
  SessionState state = SessionState.restoring;
  UserProfile? profile;

  Future<void> restore() async {
    final offline = this.offline;
    if (offline != null) {
      profile = await offline.current();
      state = profile == null ? SessionState.signedOut : SessionState.signedIn;
      notifyListeners();
      return;
    }
    final hasTokens = await repository.restoreSession();
    if (!hasTokens) {
      state = SessionState.signedOut;
      notifyListeners();
      return;
    }
    state = SessionState.signedIn;
    notifyListeners();
    try {
      profile = await repository.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> adopt() async {
    try {
      profile = await (offline?.current() ?? repository.getProfile());
    } catch (_) {}
    state = SessionState.signedIn;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await (offline?.current() ?? repository.getProfile());
    notifyListeners();
  }

  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'пустое');
    profile =
        await (offline?.rename(trimmed) ??
            repository.updateProfile(name: trimmed));
    notifyListeners();
  }

  Future<void> switchTo(OfflineAccounts? accounts) async {
    if (identical(accounts, offline)) return;
    await logout();
    offline = accounts;
  }

  Future<void> logout() async {
    await (offline?.signOut() ?? repository.logout());
    profile = null;
    state = SessionState.signedOut;
    notifyListeners();
  }
}
