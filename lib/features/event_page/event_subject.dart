import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/models/models.dart';

sealed class EventSubject {
  const EventSubject();
}

final class OwnEvent extends EventSubject {
  const OwnEvent(this.event, {this.isNew = false});

  final CalendarEvent event;
  final bool isNew;
}

final class NewInvite extends EventSubject {
  const NewInvite(this.event, this.invitees);

  final CalendarEvent event;
  final List<FriendInfo> invitees;
}

final class SharedInvite extends EventSubject {
  const SharedInvite(this.id);

  final String id;
}

final class DeviceEventSubject extends EventSubject {
  const DeviceEventSubject(this.event);

  final CalendarEvent event;
}
