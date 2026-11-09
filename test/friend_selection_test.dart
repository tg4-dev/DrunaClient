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

  group('groups', () {
    test('opening a group picks its people once, closing lets them go', () {
      final selection = FriendSelection(MemorySettingsStorage())
        ..toggle(1)
        ..openGroup('g', [1, 2]);
      expect(selection.isOpen('g'), isTrue);
      expect(selection.selected, [1, 2]);
      selection.closeGroup('g', [1, 2]);
      expect(selection.isOpen('g'), isFalse);
      expect(selection.selected, isEmpty);
    });

    test('closing keeps people another open group still needs', () {
      final selection = FriendSelection(MemorySettingsStorage())
        ..openGroup('a', [1, 2])
        ..openGroup('b', [2, 3])
        ..closeGroup('a', [1, 2], keep: [2, 3]);
      expect(selection.selected, [2, 3]);
      expect(selection.openGroups, ['b']);
    });

    test('open groups survive a restart, gone groups close', () async {
      final storage = MemorySettingsStorage();
      FriendSelection(storage).openGroup('g', [1]);
      await Future<void>.delayed(Duration.zero);
      final again = FriendSelection(storage);
      await again.load();
      expect(again.openGroups, ['g']);
      expect(again.selected, [1]);
      again.keepOnlyGroups(['other']);
      expect(again.openGroups, isEmpty);
    });
  });

  group('bar order', () {
    const groups = [(id: 'g', name: 'Ужин')];
    List<String> labels(List<BarItem> items) => [
      for (final item in items)
        switch (item) {
          BarFriend(:final friend) => friend.name,
          BarGroup(:final id) => id,
        },
    ];

    test('a group has no priority: it sorts by use with the friends', () {
      final selection = FriendSelection(MemorySettingsStorage())
        ..toggle(2)
        ..toggle(2);
      expect(labels(selection.barOrder(_all, groups)), [
        'Борис',
        'Алина',
        'Вера',
        'g',
      ]);
      selection
        ..openGroup('g', const [])
        ..closeGroup('g', const [])
        ..openGroup('g', const [])
        ..closeGroup('g', const []);
      expect(labels(selection.barOrder(_all, groups)).first, 'g');
    });

    test('picked friends go first, then open groups, then the rest', () {
      final selection = FriendSelection(MemorySettingsStorage())
        ..openGroup('g', const [])
        ..toggle(3);
      expect(labels(selection.barOrder(_all, groups)), [
        'Вера',
        'g',
        'Алина',
        'Борис',
      ]);
    });

    test('only the top 30% by use go first, the rest by name', () {
      final selection = FriendSelection(MemorySettingsStorage());
      for (final id in [3, 3, 2]) {
        selection
          ..toggle(id)
          ..toggle(id);
      }
      expect(labels(selection.barOrder(_all, groups)), [
        'Вера',
        'Борис',
        'Алина',
        'g',
      ]);
      expect(labels(selection.barOrder(_all, const [])), [
        'Вера',
        'Алина',
        'Борис',
      ]);
    });

    test('opening a group counts for the group, not for its people', () {
      final selection = FriendSelection(MemorySettingsStorage())
        ..openGroup('g', [1, 2])
        ..closeGroup('g', [1, 2]);
      expect(selection.groupUsageOf('g'), 1);
      expect(selection.usageOf(1), 0);
      expect(selection.usageOf(2), 0);
    });

    test('group use is kept between launches', () async {
      final storage = MemorySettingsStorage();
      FriendSelection(storage).openGroup('g', const []);
      final again = FriendSelection(storage);
      await again.load();
      expect(again.groupUsageOf('g'), 1);
    });
  });
}
