import 'dart:async';
import 'dart:math' as math;

import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';

/// Everything the app asks about invites. The server has no invites yet
/// (docs/backend-changes.md, «Приглашения на события»), so the app runs on
/// [DemoInvitesSource] or tells the truth with [ServerInvitesSource].
abstract interface class InvitesSource {
  /// Fires when invites change by themselves (someone answered).
  Listenable? get changes;

  /// Every invite the user organizes or is invited to.
  Future<List<Invite>> list();
  Future<Invite> create(InviteDraft draft);
  Future<Invite> update(String id, InviteDraft draft);

  /// The user's own answer.
  Future<void> respond(String id, RsvpStatus status);

  /// The organizer calls the event off.
  Future<void> cancel(String id);

  void dispose();
}

/// The server has no endpoint for invites: every call says so, nothing
/// pretends to work.
class InvitesUnavailable extends ApiException {
  const InvitesUnavailable()
    : super('Приглашения пока не поддерживаются сервером.');
}

class ServerInvitesSource implements InvitesSource {
  const ServerInvitesSource();

  @override
  Listenable? get changes => null;

  @override
  Future<List<Invite>> list() => Future.error(const InvitesUnavailable());
  @override
  Future<Invite> create(InviteDraft draft) =>
      Future.error(const InvitesUnavailable());
  @override
  Future<Invite> update(String id, InviteDraft draft) =>
      Future.error(const InvitesUnavailable());
  @override
  Future<void> respond(String id, RsvpStatus status) =>
      Future.error(const InvitesUnavailable());
  @override
  Future<void> cancel(String id) => Future.error(const InvitesUnavailable());
  @override
  void dispose() {}
}

/// Invites in memory, with the demo friends: one waiting for the user's
/// answer, one they go to, one of their own where some have answered, and
/// one in the past. After the user invites people, they answer one by one
/// a few seconds later, so the invite page comes alive.
class DemoInvitesSource implements InvitesSource {
  DemoInvitesSource({
    required FriendInfo Function() me,
    DateTime? today,
    this.delay = const Duration(milliseconds: 300),
    this.replyDelay = const Duration(seconds: 4),
  }) : _me = me {
    _seed(today ?? DateTime.now());
  }

  final FriendInfo Function() _me;
  final Duration delay;

  /// How long a demo friend takes to answer; null: they never do.
  final Duration? replyDelay;

  /// Every request fails as if there were no network: for the error states.
  bool offline = false;

  final _changes = _Changes();
  final _invites = <Invite>[];
  final _timers = <Timer>[];
  final _random = math.Random(7);
  var _next = 0;

  /// The user inside the stored invites: who they are is only known when
  /// asked, since the profile may load later.
  static const _meId = -1;
  static const _meMark = FriendInfo(id: _meId, name: '', username: '');

  static const alina = FriendInfo(
    id: 101,
    name: 'Алина Смирнова',
    username: 'alina',
  );
  static const mark = FriendInfo(id: 102, name: 'Марк Ли', username: 'mark');
  static const olga = FriendInfo(
    id: 107,
    name: 'Ольга Петрова',
    username: 'olga',
  );
  static const dima = FriendInfo(
    id: 108,
    name: 'Дима Соколов',
    username: 'dima',
  );
  static const katya = FriendInfo(
    id: 109,
    name: 'Катя Лебедева',
    username: 'katya',
  );

  @override
  Listenable get changes => _changes;

  void _seed(DateTime today) {
    DateTime at(int days, int hour, [int minute = 0]) =>
        DateTime(today.year, today.month, today.day + days, hour, minute);
    _invites.addAll([
      Invite(
        id: 'demo-invite-dinner',
        organizer: alina,
        title: 'Ужин у Алины',
        description: 'Готовлю пасту, с вас десерт.',
        start: at(2, 19),
        end: at(2, 22),
        participants: const [
          InviteParticipant(_meMark, RsvpStatus.pending),
          InviteParticipant(mark, RsvpStatus.going),
          InviteParticipant(olga, RsvpStatus.pending),
        ],
      ),
      Invite(
        id: 'demo-invite-cinema',
        organizer: mark,
        title: 'Кино',
        start: at(5, 20),
        end: at(5, 22, 30),
        participants: const [
          InviteParticipant(_meMark, RsvpStatus.going),
          InviteParticipant(dima, RsvpStatus.pending),
        ],
      ),
      Invite(
        id: 'demo-invite-games',
        organizer: _meMark,
        title: 'Настолки',
        description: 'Берите любые игры, чай за мной.',
        start: at(8, 18),
        end: at(8, 23),
        participants: const [
          InviteParticipant(alina, RsvpStatus.going),
          InviteParticipant(katya, RsvpStatus.notGoing),
          InviteParticipant(dima, RsvpStatus.pending),
        ],
      ),
      Invite(
        id: 'demo-invite-picnic',
        organizer: olga,
        title: 'Пикник',
        start: at(-6, 12),
        end: at(-6, 16),
        participants: const [
          InviteParticipant(_meMark, RsvpStatus.going),
          InviteParticipant(alina, RsvpStatus.going),
        ],
      ),
    ]);
  }

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

  FriendInfo _person(FriendInfo person) => person.id == _meId ? _me() : person;

  /// A stored invite as the app sees it: the user is themselves.
  Invite _out(Invite invite) => Invite(
    id: invite.id,
    organizer: _person(invite.organizer),
    title: invite.title,
    description: invite.description,
    start: invite.start,
    end: invite.end,
    allDay: invite.allDay,
    participants: [
      for (final participant in invite.participants)
        InviteParticipant(_person(participant.person), participant.status),
    ],
  );

  int _indexOf(String id) {
    final index = _invites.indexWhere((invite) => invite.id == id);
    if (index < 0) {
      throw const ApiException('Приглашение не найдено.', statusCode: 404);
    }
    return index;
  }

  @override
  Future<List<Invite>> list() =>
      _later(() => [for (final i in _invites) _out(i)]);

  @override
  Future<Invite> create(InviteDraft draft) => _later(() {
    final invite = Invite(
      id: 'demo-invite-${_next++}',
      organizer: _meMark,
      title: draft.title,
      description: draft.description,
      start: draft.start,
      end: draft.end,
      allDay: draft.allDay,
      participants: [
        for (final person in draft.invitees)
          InviteParticipant(person, RsvpStatus.pending),
      ],
    );
    _invites.add(invite);
    _scheduleReplies(invite);
    return _out(invite);
  });

  @override
  Future<Invite> update(String id, InviteDraft draft) => _later(() {
    final index = _indexOf(id);
    final invite = _invites[index].copyWith(
      title: draft.title,
      description: draft.description,
      start: draft.start,
      end: draft.end,
      allDay: draft.allDay,
    );
    _invites[index] = invite;
    return _out(invite);
  });

  @override
  Future<void> respond(String id, RsvpStatus status) => _later(() {
    final index = _indexOf(id);
    _invites[index] = _invites[index].answered(_meId, status);
  });

  @override
  Future<void> cancel(String id) => _later(() {
    _invites.removeAt(_indexOf(id));
  });

  /// Each invitee answers on their own, a little later than the last.
  void _scheduleReplies(Invite invite) {
    final wait = replyDelay;
    if (wait == null) return;
    const answers = [RsvpStatus.going, RsvpStatus.going, RsvpStatus.notGoing];
    var step = 0;
    for (final participant in invite.participants) {
      final answer = answers[_random.nextInt(answers.length)];
      step++;
      _timers.add(
        Timer(wait * step, () {
          final index = _invites.indexWhere((item) => item.id == invite.id);
          if (index < 0) return;
          _invites[index] = _invites[index].answered(
            participant.person.id,
            answer,
          );
          _changes.fire();
        }),
      );
    }
  }

  @override
  void dispose() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _changes.dispose();
  }
}

class _Changes extends ChangeNotifier {
  void fire() => notifyListeners();
}
