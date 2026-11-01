import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/foundation.dart';

enum SessionState { restoring, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this.repository);

  final DrunaRepository repository;
  SessionState state = SessionState.restoring;
  UserProfile? profile;

  Future<void> restore() async {
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
    } catch (_) {
      // The home screen owns retry/offline presentation. A failed token refresh
      // clears the secure store and the next protected request returns auth error.
    }
  }

  Future<void> signIn(String username, String password) async {
    await repository.signIn(username, password);
    profile = await repository.getProfile();
    state = SessionState.signedIn;
    notifyListeners();
  }

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await repository.signUp(
      name: name,
      username: username,
      email: email,
      password: password,
    );
    profile = await repository.getProfile();
    state = SessionState.signedIn;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await repository.getProfile();
    notifyListeners();
  }

  /// A new display name; the server ignores an empty one, so it is refused
  /// here. Throws on failure, keeping the old name.
  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'пустое');
    profile = await repository.updateProfile(name: trimmed);
    notifyListeners();
  }

  Future<void> logout() async {
    await repository.logout();
    profile = null;
    state = SessionState.signedOut;
    notifyListeners();
  }
}
