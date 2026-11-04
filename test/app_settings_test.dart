import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => timeDilation = 1);

  test('reads saved switches over the defaults', () async {
    final storage = MemorySettingsStorage()
      ..values['settings.demo'] = false
      ..values['settings.slow_motion'] = true;
    final settings = AppSettings(storage: storage, demoByDefault: true);
    expect(settings.demo, isTrue);

    await settings.load();
    expect(settings.demo, isFalse);
    expect(settings.slowMotion, isTrue);
    expect(timeDilation, AppSettings.slowMotionFactor);
  });

  test('saves every change', () async {
    final storage = MemorySettingsStorage();
    AppSettings(storage: storage, demoByDefault: false)
      ..demo = true
      ..demoOffline = true;
    expect(storage.values['settings.demo'], isTrue);
    expect(storage.values['settings.demo_offline'], isTrue);
  });

  test('«Нет сети» works only in the demo version', () {
    final settings = AppSettings(
      storage: MemorySettingsStorage(),
      demoByDefault: false,
    )..demoOffline = true;
    expect(settings.demoOffline, isFalse);
    settings.demo = true;
    expect(settings.demoOffline, isTrue);
  });

  test('my colour: picked, else purple', () async {
    final storage = MemorySettingsStorage();
    final settings = AppSettings(storage: storage, demoByDefault: false);
    expect(ownColorFor(settings), defaultOwnColor);
    expect(avatarPalette[defaultOwnColorSlot], defaultOwnColor);

    settings.ownColorSlot = 3;
    expect(ownColorFor(settings), avatarPalette[3]);

    final restored = AppSettings(storage: storage, demoByDefault: false);
    await restored.load();
    expect(restored.ownColorSlot, 3);

    restored.ownColorSlot = null;
    expect(ownColorFor(restored), defaultOwnColor);
    final again = AppSettings(storage: storage, demoByDefault: false);
    await again.load();
    expect(again.ownColorSlot, isNull);
  });
}
