import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/foundation.dart';

enum SessionState { restoring, signedOut, signedIn }

class SessionController extends ChangeNotifier {
  SessionController(this.repository, {this.offline});

  final DrunaRepository repository;

  /// The mode without a server: the session and the profile come from the
  /// device, not from tokens and `/users/me`.
  final OfflineAccounts? offline;
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
    } catch (_) {
      // The home screen owns retry/offline presentation. A failed token refresh
      // clears the secure store and the next protected request returns auth error.
    }
  }

  /// Takes over the tokens the onboarding has just saved (sign-in or
  /// sign-up): loads the profile and lets the app in. The onboarding calls
  /// it when its last screen has played, not when the tokens arrive.
  Future<void> adopt() async {
    try {
      profile = await (offline?.current() ?? repository.getProfile());
    } catch (_) {
      // As in [restore]: the home screen copes without a profile.
    }
    state = SessionState.signedIn;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    profile = await (offline?.current() ?? repository.getProfile());
    notifyListeners();
  }

  /// A new display name; the server ignores an empty one, so it is refused
  /// here. Throws on failure, keeping the old name.
  Future<void> rename(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw ArgumentError.value(name, 'name', 'пустое');
    profile =
        await (offline?.rename(trimmed) ??
            repository.updateProfile(name: trimmed));
    notifyListeners();
  }

  Future<void> logout() async {
    await (offline?.signOut() ?? repository.logout());
    profile = null;
    state = SessionState.signedOut;
    notifyListeners();
  }
}
