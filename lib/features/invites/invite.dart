import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';

/// A guest's answer to an invite: yes, no, or not yet (design-system §9.8).
enum RsvpStatus { pending, going, notGoing }

String rsvpLabel(RsvpStatus status) => switch (status) {
  RsvpStatus.going => 'Иду',
  RsvpStatus.notGoing => 'Не иду',
  RsvpStatus.pending => 'Ждём ответа',
};

/// Someone invited to an event, with their answer.
@immutable
class InviteParticipant {
  const InviteParticipant(this.person, this.status);

  final FriendInfo person;
  final RsvpStatus status;
}

/// An event with people in it: the organizer and the friends they invited,
/// each with an answer. The organizer always goes.
@immutable
class Invite {
  const Invite({
    required this.id,
    required this.organizer,
    required this.title,
    required this.start,
    required this.end,
    required this.participants,
    this.description = '',
    this.allDay = false,
  });

  final String id;
  final FriendInfo organizer;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;

  /// The invited, without the organizer.
  final List<InviteParticipant> participants;

  /// Everyone in it, the organizer first.
  List<FriendInfo> get people => [
    organizer,
    for (final participant in participants) participant.person,
  ];

  bool isOrganizer(int personId) => organizer.id == personId;

  /// The answer of [personId]; null when they are not in it.
  RsvpStatus? statusOf(int personId) {
    if (organizer.id == personId) return RsvpStatus.going;
    for (final participant in participants) {
      if (participant.person.id == personId) return participant.status;
    }
    return null;
  }

  /// The invited with this answer, in the order they were invited.
  List<FriendInfo> withStatus(RsvpStatus status) => [
    for (final participant in participants)
      if (participant.status == status) participant.person,
  ];

  Invite copyWith({
    String? title,
    String? description,
    DateTime? start,
    DateTime? end,
    bool? allDay,
    List<InviteParticipant>? participants,
  }) => Invite(
    id: id,
    organizer: organizer,
    title: title ?? this.title,
    description: description ?? this.description,
    start: start ?? this.start,
    end: end ?? this.end,
    allDay: allDay ?? this.allDay,
    participants: participants ?? this.participants,
  );

  /// [personId]'s answer changed; everyone else's stays.
  Invite answered(int personId, RsvpStatus status) => copyWith(
    participants: [
      for (final participant in participants)
        participant.person.id == personId
            ? InviteParticipant(participant.person, status)
            : participant,
    ],
  );
}

/// What the organizer fills in: the invite before it exists.
@immutable
class InviteDraft {
  const InviteDraft({
    required this.title,
    required this.start,
    required this.end,
    required this.invitees,
    this.description = '',
    this.allDay = false,
  });

  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final List<FriendInfo> invitees;
}

/// The user as a person in an invite.
FriendInfo meAsPerson(UserProfile? profile) => FriendInfo(
  id: profile?.id ?? 0,
  name: profile?.name ?? '',
  username: profile?.username ?? 'я',
);

/// Names for a sentence: "Аня, Миша и ещё 2".
String peopleLabel(List<FriendInfo> people, {int shown = 2}) {
  String nameOf(FriendInfo person) {
    final name = person.name.trim();
    final first = name.isEmpty ? person.username : name.split(' ').first;
    return first;
  }

  if (people.isEmpty) return '';
  if (people.length <= shown + 1) {
    final names = people.map(nameOf).toList();
    if (names.length == 1) return names.single;
    return '${names.sublist(0, names.length - 1).join(', ')} и ${names.last}';
  }
  final names = people.take(shown).map(nameOf).join(', ');
  return '$names и ещё ${people.length - shown}';
}
