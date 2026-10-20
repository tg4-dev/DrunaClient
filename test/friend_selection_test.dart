import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _alina = FriendInfo(id: 1, name: 'Алина', username: 'alina');
const _boris = FriendInfo(id: 2, name: 'Борис', username: 'boris');
const _vera = FriendInfo(id: 3, name: 'Вера', username: 'vera');
const _all = [_vera, _boris, _alina];

List<String> _names(List<FriendInfo> friends) => [
  for (final friend in friends) friend.name,
];

void main() {
  test('nobody picked: alphabetical', () {
    final selection = FriendSelection(MemorySettingsStorage());
    expect(_names(selection.ordered(_all)), ['Алина', 'Борис', 'Вера']);
  });

  test('picked first, in the order they were picked', () {
    final selection = FriendSelection(MemorySettingsStorage())
      ..toggle(3)
      ..toggle(2);
    expect(_names(selection.ordered(_all)), ['Вера', 'Борис', 'Алина']);
  });

  test('let go: back among the rest, ahead of the less used', () {
    final selection = FriendSelection(MemorySettingsStorage())
      ..toggle(3)
      ..toggle(3);
    expect(selection.selected, isEmpty);
    expect(_names(selection.ordered(_all)), ['Вера', 'Алина', 'Борис']);
  });

  test('is kept between launches', () async {
    final storage = MemorySettingsStorage();
    FriendSelection(storage)
      ..toggle(2)
      ..toggle(1)
      ..toggle(1);
    final restored = FriendSelection(storage);
    await restored.load();
    expect(restored.selected, [2]);
    expect(restored.usageOf(1), 1);
  });

  test('forgets removed friends and can be cleared', () {
    final selection = FriendSelection(MemorySettingsStorage())
      ..toggle(1)
      ..toggle(2)
      ..keepOnly([2, 3]);
    expect(selection.selected, [2]);
    selection.clear();
    expect(selection.selected, isEmpty);
    expect(selection.usageOf(2), 0);
  });
}
