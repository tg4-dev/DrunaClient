import 'package:druna_app/features/invites/invite.dart';

typedef InviteSplit = ({
  List<Invite> waiting,
  List<Invite> upcoming,
  List<Invite> past,
});

InviteSplit splitInvites(
  Iterable<Invite> invites, {
  required int meId,
  required DateTime now,
}) {
  final waiting = <Invite>[];
  final upcoming = <Invite>[];
  final past = <Invite>[];
  for (final invite in invites) {
    final status = invite.statusOf(meId);
    if (status == null) continue;
    if (invite.end.isBefore(now)) {
      if (status != RsvpStatus.notGoing) past.add(invite);
    } else if (status == RsvpStatus.pending) {
      waiting.add(invite);
    } else {
      upcoming.add(invite);
    }
  }
  int soonest(Invite a, Invite b) => a.start.compareTo(b.start);
  waiting.sort(soonest);
  upcoming.sort(soonest);
  past.sort((a, b) => b.start.compareTo(a.start));
  return (waiting: waiting, upcoming: upcoming, past: past);
}
