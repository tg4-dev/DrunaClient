import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class AppSettings extends ChangeNotifier {
  AppSettings({required SettingsStorage storage, required bool demoByDefault})
    : _storage = storage,
      _demo = demoByDefault;

  static const _demoKey = 'settings.demo';
  static const _demoOfflineKey = 'settings.demo_offline';
  static const _slowMotionKey = 'settings.slow_motion';
  static const _ownColorKey = 'settings.own_color';
  static const _ownFontKey = 'settings.own_font';

  static const slowMotionFactor = 5.0;

  final SettingsStorage _storage;

  SettingsStorage get storage => _storage;

  bool _demo;
  bool _demoOffline = false;
  bool _slowMotion = false;
  int? _ownColorSlot;
  String? _ownFontId;
  bool _disposed = false;

  bool get demo => _demo;

  bool get demoOffline => _demo && _demoOffline;

  bool get slowMotion => _slowMotion;

  int? get ownColorSlot => _ownColorSlot;

  set ownColorSlot(int? slot) {
    final valid = slot != null && slot >= 0 && slot < avatarPalette.length;
    _ownColorSlot = valid ? slot : null;
    notifyListeners();
    _storage.setString(_ownColorKey, valid ? '$slot' : '');
  }

  String? get ownFontId => _ownFontId;

  set ownFontId(String? id) {
    _ownFontId = id;
    notifyListeners();
    _storage.setString(_ownFontKey, id ?? '');
  }

  Future<void> load() async {
    _demo = await _storage.getBool(_demoKey) ?? _demo;
    _demoOffline = await _storage.getBool(_demoOfflineKey) ?? false;
    _slowMotion = await _storage.getBool(_slowMotionKey) ?? false;
    final slot = int.tryParse(await _storage.getString(_ownColorKey) ?? '');
    _ownColorSlot = slot != null && slot >= 0 && slot < avatarPalette.length
        ? slot
        : null;
    final font = await _storage.getString(_ownFontKey);
    _ownFontId = font == null || font.isEmpty ? null : font;
    if (_disposed) return;
    _applySlowMotion();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  set demo(bool value) => _set(_demoKey, value, () {
    _demo = value;
  });

  set demoOffline(bool value) => _set(_demoOfflineKey, value, () {
    _demoOffline = value;
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

Color ownColorFor(AppSettings settings) =>
    avatarPalette[settings.ownColorSlot ?? defaultOwnColorSlot];

AvatarFont ownFontFor(AppSettings settings) =>
    avatarFontById(settings.ownFontId);
