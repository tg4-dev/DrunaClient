import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/friends/friend_schedule.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/features/friends/friends_store.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

const _alina = FriendInfo(id: 101, name: 'Алина', username: 'alina');

void main() {
  final today = DateTime(2026, 10, 20);

  test('demo busy time is the same on every run, near today', () async {
    final first = await DemoFriendSchedule(today: today).eventsOf(_alina);
    final again = await DemoFriendSchedule(today: today).eventsOf(_alina);
    expect(first, isNotEmpty);
    expect([for (final e in first) e.start], [for (final e in again) e.start]);
    for (final event in first) {
      expect(event.title, isEmpty);
      expect(event.start.difference(today).inDays.abs(), lessThan(8 * 7 + 7));
    }
  });

  test('without a source there is no busy time', () async {
    expect(await const NoFriendSchedule().eventsOf(_alina), isEmpty);
  });

  test('picked friends show in their colour; letting go hides them', () async {
    final store = FriendsStore(DemoFriendsSource(delay: Duration.zero));
    await store.load();
    final selection = FriendSelection(MemorySettingsStorage());
    final schedules = FriendSchedules(
      selection: selection,
      friends: store,
      source: DemoFriendSchedule(today: today),
    );
    addTearDown(schedules.dispose);

    selection.toggle(101);
    await pumpEventQueue();
    expect(schedules.value, isNotEmpty);
    final colour = avatarColorFor(id: 101, username: 'alina');
    expect(schedules.value.every((e) => e.color == colour), isTrue);
    expect(schedules.value.every((e) => e.ownerId == 101), isTrue);

    selection.toggle(101);
    await pumpEventQueue();
    expect(schedules.value, isEmpty);

    selection.toggle(101);
    schedules.source = const NoFriendSchedule();
    await pumpEventQueue();
    expect(schedules.value, isEmpty);
  });
}
