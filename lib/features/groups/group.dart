import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:flutter/foundation.dart';

const maxGroups = 8;

const groupsFullText = 'Можно не больше $maxGroups групп';

@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.members,
    this.fontId,
    this.ownerId,
  });

  final String id;
  final String name;

  final List<FriendInfo> members;

  final String? fontId;
  final int? ownerId;

  AvatarFont get font => avatarFontById(fontId);

  bool ownedBy(int meId) => ownerId == null || ownerId == meId;

  Set<int> get memberIds => {for (final member in members) member.id};

  Group copyWith({String? name, List<FriendInfo>? members, String? fontId}) =>
      Group(
        id: id,
        name: name ?? this.name,
        members: members ?? this.members,
        fontId: fontId ?? this.fontId,
        ownerId: ownerId,
      );
}

@immutable
class GroupDraft {
  const GroupDraft({
    required this.name,
    required this.fontId,
    required this.members,
  });

  final String name;
  final String fontId;
  final List<FriendInfo> members;
}

bool inviteMatchesGroup(Invite invite, Group group, {required int meId}) {
  final people = {for (final person in invite.people) person.id};
  return setEquals(people, {meId, ...group.memberIds});
}
