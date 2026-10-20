import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
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

  test('my colour: picked, else by id, else the default', () async {
    const me = UserProfile(id: 5, name: 'Я', username: 'me', email: '');
    final storage = MemorySettingsStorage();
    final settings = AppSettings(storage: storage, demoByDefault: false);
    expect(ownColorFor(settings, null), calendarEventColor);
    expect(ownColorFor(settings, me), avatarColorFor(id: 5));

    settings.ownColorSlot = 3;
    expect(ownColorFor(settings, me), avatarPalette[3]);

    final restored = AppSettings(storage: storage, demoByDefault: false);
    await restored.load();
    expect(restored.ownColorSlot, 3);

    restored.ownColorSlot = null;
    expect(ownColorFor(restored, me), avatarColorFor(id: 5));
    final again = AppSettings(storage: storage, demoByDefault: false);
    await again.load();
    expect(again.ownColorSlot, isNull);
  });
}
