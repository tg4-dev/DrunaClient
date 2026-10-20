import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where settings live between launches.
abstract interface class SettingsStorage {
  Future<bool?> getBool(String key);
  Future<void> setBool(String key, bool value);
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);
}

class PreferencesSettingsStorage implements SettingsStorage {
  final _preferences = SharedPreferencesAsync();

  @override
  Future<bool?> getBool(String key) => _preferences.getBool(key);
  @override
  Future<void> setBool(String key, bool value) =>
      _preferences.setBool(key, value);
  @override
  Future<String?> getString(String key) => _preferences.getString(key);
  @override
  Future<void> setString(String key, String value) =>
      _preferences.setString(key, value);
}

class MemorySettingsStorage implements SettingsStorage {
  final values = <String, Object>{};

  @override
  Future<bool?> getBool(String key) async => values[key] as bool?;
  @override
  Future<void> setBool(String key, bool value) async => values[key] = value;
  @override
  Future<String?> getString(String key) async => values[key] as String?;
  @override
  Future<void> setString(String key, String value) async => values[key] = value;
}

/// Switches on the settings page that make testing easier. In production the
/// demo switches are always off.
class AppSettings extends ChangeNotifier {
  AppSettings({
    required SettingsStorage storage,
    required bool demoByDefault,
    this.allowDemo = true,
  }) : _storage = storage,
       _demoFriends = allowDemo && demoByDefault,
       _demoSchedules = allowDemo && demoByDefault;

  static const _demoFriendsKey = 'settings.demo_friends';
  static const _demoOfflineKey = 'settings.demo_offline';
  static const _demoSchedulesKey = 'settings.demo_schedules';
  static const _slowMotionKey = 'settings.slow_motion';
  static const _ownColorKey = 'settings.own_color';

  /// How much slower every animation runs with [slowMotion].
  static const slowMotionFactor = 5.0;

  final SettingsStorage _storage;
  final bool allowDemo;

  /// For other small state kept between launches, e.g. picked friends.
  SettingsStorage get storage => _storage;

  bool _demoFriends;
  bool _demoOffline = false;
  bool _demoSchedules;
  bool _slowMotion = false;
  int? _ownColorSlot;
  bool _disposed = false;

  /// Friends come from [DemoFriendsSource] instead of the server.
  bool get demoFriends => _demoFriends;

  /// Selected friends show generated busy time. The server has no endpoint
  /// for a friend's schedule, so without this the calendar shows none.
  bool get demoSchedules => _demoSchedules;

  /// Demo data answers every request with a network error.
  bool get demoOffline => _demoOffline;

  /// Every animation runs [slowMotionFactor] times slower.
  bool get slowMotion => _slowMotion;

  /// The colour the user picked for themselves, as a slot of
  /// [avatarPalette]; null — the one their id gives. Kept on this device
  /// only: the server has no field for it yet.
  int? get ownColorSlot => _ownColorSlot;

  set ownColorSlot(int? slot) {
    final valid = slot != null && slot >= 0 && slot < avatarPalette.length;
    _ownColorSlot = valid ? slot : null;
    notifyListeners();
    _storage.setString(_ownColorKey, valid ? '$slot' : '');
  }

  Future<void> load() async {
    if (allowDemo) {
      _demoFriends = await _storage.getBool(_demoFriendsKey) ?? _demoFriends;
      _demoOffline = await _storage.getBool(_demoOfflineKey) ?? false;
      _demoSchedules =
          await _storage.getBool(_demoSchedulesKey) ?? _demoSchedules;
    }
    _slowMotion = await _storage.getBool(_slowMotionKey) ?? false;
    final slot = int.tryParse(await _storage.getString(_ownColorKey) ?? '');
    _ownColorSlot = slot != null && slot >= 0 && slot < avatarPalette.length
        ? slot
        : null;
    if (_disposed) return;
    _applySlowMotion();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  set demoFriends(bool value) => _set(_demoFriendsKey, value, () {
    _demoFriends = allowDemo && value;
  });

  set demoOffline(bool value) => _set(_demoOfflineKey, value, () {
    _demoOffline = allowDemo && value;
  });

  set demoSchedules(bool value) => _set(_demoSchedulesKey, value, () {
    _demoSchedules = allowDemo && value;
  });

  set slowMotion(bool value) => _set(_slowMotionKey, value, () {
    _slowMotion = value;
    _applySlowMotion();
  });

  void _set(String key, bool value, VoidCallback apply) {
    apply();
    notifyListeners();
    _storage.setBool(key, value);
  }

  void _applySlowMotion() {
    timeDilation = _slowMotion ? slowMotionFactor : 1;
  }
}

/// The user's colour: the one they picked, else the one their id gives,
/// else the calendar's default until the profile has loaded.
Color ownColorFor(AppSettings settings, UserProfile? profile) {
  final slot = settings.ownColorSlot;
  if (slot != null) return avatarPalette[slot];
  if (profile == null) return calendarEventColor;
  return avatarColorFor(id: profile.id, username: profile.username);
}
