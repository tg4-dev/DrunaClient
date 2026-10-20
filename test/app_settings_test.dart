import 'package:druna_app/app/app_settings.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => timeDilation = 1);

  test('reads saved switches over the defaults', () async {
    final storage = MemorySettingsStorage()
      ..values['settings.demo_friends'] = false
      ..values['settings.slow_motion'] = true;
    final settings = AppSettings(storage: storage, demoByDefault: true);
    expect(settings.demoFriends, isTrue);

    await settings.load();
    expect(settings.demoFriends, isFalse);
    expect(settings.slowMotion, isTrue);
    expect(timeDilation, AppSettings.slowMotionFactor);
  });

  test('saves every change', () async {
    final storage = MemorySettingsStorage();
    AppSettings(storage: storage, demoByDefault: false)
      ..demoFriends = true
      ..demoOffline = true;
    expect(storage.values['settings.demo_friends'], isTrue);
    expect(storage.values['settings.demo_offline'], isTrue);
  });

  test('production never turns demo data on', () async {
    final storage = MemorySettingsStorage()
      ..values['settings.demo_friends'] = true;
    final settings = AppSettings(
      storage: storage,
      demoByDefault: true,
      allowDemo: false,
    );
    await settings.load();
    settings.demoFriends = true;
    expect(settings.demoFriends, isFalse);
  });
}
