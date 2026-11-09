import 'dart:async';
import 'dart:convert';

import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';

abstract interface class GroupsSource {
  Future<List<Group>> list();
  Future<Group> create(GroupDraft draft);
  Future<Group> update(Group before, GroupDraft after);
  Future<void> delete(Group group);
  Future<void> leave(Group group);
}

class GroupsUnsupported extends ApiException {
  const GroupsUnsupported(super.message);
}

class GroupFonts {
  GroupFonts(this._storage);

  final SettingsStorage _storage;
  static const _key = 'groups.fonts';

  Map<String, String> _fonts = {};
  var _loaded = false;

  Future<Map<String, String>> load() async {
    if (_loaded) return _fonts;
    final raw = await _storage.getString(_key);
    if (raw != null && raw.isNotEmpty) {
      try {
        _fonts = Map<String, String>.from(jsonDecode(raw) as Map);
      } catch (_) {
        _fonts = {};
      }
    }
    _loaded = true;
    return _fonts;
  }

  Future<void> put(String groupId, String fontId) async {
    await load();
    _fonts[groupId] = fontId;
    await _storage.setString(_key, jsonEncode(_fonts));
  }
}

class ServerGroupsSource implements GroupsSource {
  ServerGroupsSource(this._repository, this._fonts, {required this.meId});

  final DrunaRepository _repository;
  final GroupFonts _fonts;
  final int Function() meId;

  static const _renameUnsupported = GroupsUnsupported(
    'Переименование группы пока не поддерживается сервером.',
  );
  static const _removeUnsupported = GroupsUnsupported(
    'Убрать участника пока не поддерживается сервером.',
  );

  Group _group(GroupSummary summary, Map<String, String> fonts) {
    final me = meId();
    return Group(
      id: '${summary.id}',
      name: summary.name,
      ownerId: summary.ownerId,
      fontId: fonts['${summary.id}'],
      members: [
        for (final member in summary.members)
          if (member.id != me) member,
      ],
    );
  }

  @override
  Future<List<Group>> list() async {
    final fonts = await _fonts.load();
    final summaries = await _repository.listGroups();
    final full = await Future.wait([
      for (final summary in summaries) _repository.getGroup(summary.id),
    ]);
    return [for (final summary in full) _group(summary, fonts)];
  }

  @override
  Future<Group> create(GroupDraft draft) async {
    final id = await _repository.createGroup(draft.name);
    await _fonts.put('$id', draft.fontId);
    for (final member in draft.members) {
      await _repository.addGroupMember(id, member.username);
    }
    return _group(await _repository.getGroup(id), await _fonts.load());
  }

  @override
  Future<Group> update(Group before, GroupDraft after) async {
    if (after.name.trim() != before.name.trim()) throw _renameUnsupported;
    final keep = {for (final member in after.members) member.id};
    if (before.members.any((member) => !keep.contains(member.id))) {
      throw _removeUnsupported;
    }
    final id = int.parse(before.id);
    final had = before.memberIds;
    for (final member in after.members) {
      if (!had.contains(member.id)) {
        await _repository.addGroupMember(id, member.username);
      }
    }
    await _fonts.put(before.id, after.fontId);
    return _group(await _repository.getGroup(id), await _fonts.load());
  }

  @override
  Future<void> delete(Group group) =>
      _repository.deleteGroup(int.parse(group.id));

  @override
  Future<void> leave(Group group) =>
      _repository.leaveGroup(int.parse(group.id));
}

class DemoGroupsSource implements GroupsSource {
  DemoGroupsSource({this.delay = const Duration(milliseconds: 300)}) {
    _groups.add(
      Group(
        id: 'demo-group-tugachi',
        name: 'Tugachi',
        fontId: 'onest',
        members: const [
          DemoInvitesSource.alina,
          DemoInvitesSource.mark,
          DemoInvitesSource.olga,
        ],
      ),
    );
  }

  final Duration delay;

  bool offline = false;

  final _groups = <Group>[];
  var _next = 0;

  Future<T> _later<T>(T Function() action) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (offline) {
      throw const ApiException(
        'Демо: нет соединения с сервером.',
        isNetwork: true,
      );
    }
    return action();
  }

  int _indexOf(String id) {
    final index = _groups.indexWhere((group) => group.id == id);
    if (index < 0) {
      throw const ApiException('Группа не найдена.', statusCode: 404);
    }
    return index;
  }

  @override
  Future<List<Group>> list() => _later(() => List.of(_groups));

  @override
  Future<Group> create(GroupDraft draft) => _later(() {
    final group = Group(
      id: 'demo-group-${_next++}',
      name: draft.name.trim(),
      fontId: draft.fontId,
      members: draft.members,
    );
    _groups.add(group);
    return group;
  });

  @override
  Future<Group> update(Group before, GroupDraft after) => _later(() {
    final index = _indexOf(before.id);
    final group = _groups[index].copyWith(
      name: after.name.trim(),
      fontId: after.fontId,
      members: after.members,
    );
    _groups[index] = group;
    return group;
  });

  @override
  Future<void> delete(Group group) =>
      _later(() => _groups.removeAt(_indexOf(group.id)));

  @override
  Future<void> leave(Group group) =>
      _later(() => _groups.removeAt(_indexOf(group.id)));
}
