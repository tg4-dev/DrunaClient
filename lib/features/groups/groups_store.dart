import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/features/groups/groups_source.dart';
import 'package:flutter/foundation.dart';

class GroupsStore extends ChangeNotifier {
  GroupsStore(this._source);

  GroupsSource _source;
  List<Group>? _groups;
  Object? _error;
  var _generation = 0;
  bool _disposed = false;

  List<Group>? get groups => _groups;
  Object? get error => _error;

  List<Group> get shown => _groups ?? const [];

  Group? byId(String id) {
    for (final group in shown) {
      if (group.id == id) return group;
    }
    return null;
  }

  set source(GroupsSource value) {
    if (identical(value, _source)) return;
    _source = value;
    _groups = null;
    _error = null;
    notifyListeners();
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final groups = await _source.list();
      if (_disposed || generation != _generation) return;
      _groups = groups;
      _error = null;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
      _groups ??= const [];
    }
    notifyListeners();
  }

  Future<Group> create(GroupDraft draft) async {
    if (shown.length >= maxGroups) throw const ApiException(groupsFullText);
    final group = await _source.create(draft);
    _groups = [...shown, group];
    notifyListeners();
    return group;
  }

  Future<Group> update(Group before, GroupDraft after) async {
    final group = await _source.update(before, after);
    _groups = [
      for (final existing in shown) existing.id == group.id ? group : existing,
    ];
    notifyListeners();
    return group;
  }

  Future<void> remove(Group group, {required bool owner}) async {
    if (owner) {
      await _source.delete(group);
    } else {
      await _source.leave(group);
    }
    _groups = [
      for (final existing in shown)
        if (existing.id != group.id) existing,
    ];
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
