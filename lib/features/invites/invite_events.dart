import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/painting.dart';

/// Everyone's colour in [invite], the organizer first; the user is in their
/// own colour [own], as on their events.
List<Color> inviteColors(
  Invite invite, {
  required int meId,
  required Color own,
}) => [
  for (final person in invite.people)
    person.id == meId
        ? own
        : avatarColorFor(id: person.id, username: person.username),
];

/// [invite] as an event on the user's calendar.
CalendarEvent inviteEvent(
  Invite invite, {
  required int meId,
  required Color own,
}) => CalendarEvent(
  id: 'invite-${invite.id}',
  title: invite.title,
  start: invite.start,
  end: invite.end,
  allDay: invite.allDay,
  invite: EventInvite(
    id: invite.id,
    colors: inviteColors(invite, meId: meId, own: own),
    pending: invite.statusOf(meId) == RsvpStatus.pending,
    mine: invite.isOrganizer(meId),
  ),
);

/// The invites the calendar shows: all but those the user said no to.
List<CalendarEvent> inviteEvents(
  List<Invite>? invites, {
  required int meId,
  required Color own,
}) => [
  for (final invite in invites ?? const <Invite>[])
    if (invite.statusOf(meId) case final status?
        when status != RsvpStatus.notGoing)
      normalizeEvent(inviteEvent(invite, meId: meId, own: own)),
];
