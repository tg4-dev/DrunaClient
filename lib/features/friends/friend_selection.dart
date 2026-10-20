import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';

/// Which friends the calendar shows, and how often each was picked. Kept
/// between launches.
class FriendSelection extends ChangeNotifier {
  FriendSelection(this._storage);

  static const _key = 'friends.selection';

  final SettingsStorage _storage;
  final _selected = <int>[];
  final _usage = <int, int>{};
  bool _disposed = false;

  /// Selected friend ids in the order they were picked.
  List<int> get selected => List.unmodifiable(_selected);

  bool isSelected(int id) => _selected.contains(id);

  int usageOf(int id) => _usage[id] ?? 0;

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
    } on Object {
      // A broken entry starts the selection over.
      return;
    }
    notifyListeners();
  }

  /// Picking a friend counts as a use; letting go does not.
  void toggle(int id) {
    if (!_selected.remove(id)) {
      _selected.add(id);
      _usage[id] = usageOf(id) + 1;
    }
    _changed();
  }

  /// Forgets friends that are gone, e.g. removed on the friends page.
  void keepOnly(Iterable<int> ids) {
    final keep = ids.toSet();
    final before = _selected.length;
    _selected.removeWhere((id) => !keep.contains(id));
    if (_selected.length != before) _changed();
  }

  void clear() {
    _selected.clear();
    _usage.clear();
    _changed();
  }

  /// Selected first, in the order they were picked; the rest by how often
  /// they were picked, then by name.
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
      }),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Name to show, falling back to the username.
String friendName(FriendInfo friend) =>
    friend.name.trim().isEmpty ? friend.username : friend.name.trim();
