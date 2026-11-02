import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/models/models.dart';

/// What the event page shows: the user's own event, an invite being made,
/// or an invite that already exists.
sealed class EventSubject {
  const EventSubject();
}

/// The user's own event. A new one opens straight in editing.
final class OwnEvent extends EventSubject {
  const OwnEvent(this.event, {this.isNew = false});

  final CalendarEvent event;
  final bool isNew;
}

/// An invite the user is making for [invitees]; it opens in editing and
/// exists only once sent.
final class NewInvite extends EventSubject {
  const NewInvite(this.event, this.invitees);

  final CalendarEvent event;
  final List<FriendInfo> invitees;
}

/// An invite in the store, by its id; it follows the store's changes.
final class SharedInvite extends EventSubject {
  const SharedInvite(this.id);

  final String id;
}
