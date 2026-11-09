import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter/foundation.dart';

class FriendSelection extends ChangeNotifier {
  FriendSelection(this._storage);

  static const _key = 'friends.selection';

  final SettingsStorage _storage;
  final _selected = <int>[];
  final _usage = <int, int>{};
  final _groups = <String>[];
  final _groupUsage = <String, int>{};
  bool _disposed = false;

  List<int> get selected => List.unmodifiable(_selected);

  List<String> get openGroups => List.unmodifiable(_groups);

  bool isOpen(String groupId) => _groups.contains(groupId);

  bool isSelected(int id) => _selected.contains(id);

  int usageOf(int id) => _usage[id] ?? 0;

  int groupUsageOf(String id) => _groupUsage[id] ?? 0;

  Future<void> load() async {
    final raw = await _storage.getString(_key);
    if (raw == null || _disposed) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _selected
        ..clear()
        ..addAll([for (final id in json['selected'] as List) id as int]);
      _usage
        ..clear()
        ..addAll({
          for (final entry in (json['usage'] as Map).entries)
            int.parse(entry.key as String): entry.value as int,
        });
      _groups
        ..clear()
        ..addAll([
          for (final id in json['groups'] as List? ?? const []) id as String,
        ]);
      _groupUsage
        ..clear()
        ..addAll({
          for (final entry in (json['groupUsage'] as Map? ?? const {}).entries)
            entry.key as String: entry.value as int,
        });
    } on Object {
      return;
    }
    notifyListeners();
  }

  void toggle(int id) {
    if (!_selected.remove(id)) {
      _selected.add(id);
      _usage[id] = usageOf(id) + 1;
    }
    _changed();
  }

  void openGroup(String groupId, Iterable<int> memberIds) {
    if (_groups.contains(groupId)) return;
    _groups.add(groupId);
    _groupUsage[groupId] = groupUsageOf(groupId) + 1;
    for (final id in memberIds) {
      if (!_selected.contains(id)) _selected.add(id);
    }
    _changed();
  }

  void closeGroup(
    String groupId,
    Iterable<int> memberIds, {
    Iterable<int> keep = const [],
  }) {
    if (!_groups.remove(groupId)) return;
    final stay = keep.toSet();
    for (final id in memberIds) {
      if (!stay.contains(id)) _selected.remove(id);
    }
    _changed();
  }

  void keepOnlyGroups(Iterable<String> ids) {
    final keep = ids.toSet();
    final before = _groups.length;
    _groups.removeWhere((id) => !keep.contains(id));
    if (_groups.length != before) _changed();
  }

  void keepOnly(Iterable<int> ids) {
    final keep = ids.toSet();
    final before = _selected.length;
    _selected.removeWhere((id) => !keep.contains(id));
    if (_selected.length != before) _changed();
  }

  void clear() {
    _selected.clear();
    _usage.clear();
    _groups.clear();
    _groupUsage.clear();
    _changed();
  }

  List<FriendInfo> ordered(List<FriendInfo> friends) {
    final byId = {for (final friend in friends) friend.id: friend};
    final rest = [
      for (final friend in friends)
        if (!_selected.contains(friend.id)) friend,
    ]..sort(_byUsageThenName);
    return [
      for (final id in _selected)
        if (byId[id] != null) byId[id]!,
      ...rest,
    ];
  }

  List<BarItem> barOrder(
    List<FriendInfo> friends,
    List<({String id, String name})> groups,
  ) {
    final byId = {for (final friend in friends) friend.id: friend};
    final known = {for (final group in groups) group.id};
    final rest = <(BarItem, int, String)>[
      for (final friend in friends)
        if (!_selected.contains(friend.id))
          (BarFriend(friend), usageOf(friend.id), friendName(friend)),
      for (final group in groups)
        if (!_groups.contains(group.id))
          (BarGroup(group.id), groupUsageOf(group.id), shownName(group.name)),
    ];
    int byName((BarItem, int, String) a, (BarItem, int, String) b) =>
        a.$3.toLowerCase().compareTo(b.$3.toLowerCase());
    final used =
        [
          for (final item in rest)
            if (item.$2 > 0) item,
        ]..sort((a, b) {
          final byUsage = b.$2.compareTo(a.$2);
          return byUsage != 0 ? byUsage : byName(a, b);
        });
    final top = used.take((rest.length * barTopShare).ceil()).toList();
    final others = [
      for (final item in rest)
        if (!top.contains(item)) item,
    ]..sort(byName);
    return [
      for (final id in _selected)
        if (byId[id] case final friend?) BarFriend(friend),
      for (final id in _groups)
        if (known.contains(id)) BarGroup(id),
      for (final (item, _, _) in top) item,
      for (final (item, _, _) in others) item,
    ];
  }

  int _byUsageThenName(FriendInfo a, FriendInfo b) {
    final byUsage = usageOf(b.id).compareTo(usageOf(a.id));
    if (byUsage != 0) return byUsage;
    return friendName(a).toLowerCase().compareTo(friendName(b).toLowerCase());
  }

  void _changed() {
    notifyListeners();
    _storage.setString(
      _key,
      jsonEncode({
        'selected': _selected,
        'usage': {
          for (final entry in _usage.entries) '${entry.key}': entry.value,
        },
        'groups': _groups,
        'groupUsage': _groupUsage,
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

const barTopShare = 0.3;

String friendName(FriendInfo friend) =>
    friend.name.trim().isEmpty ? friend.username : shownName(friend.name);

sealed class BarItem {
  const BarItem();
}

final class BarFriend extends BarItem {
  const BarFriend(this.friend);

  final FriendInfo friend;
}

final class BarGroup extends BarItem {
  const BarGroup(this.id);

  final String id;
}
