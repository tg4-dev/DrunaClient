import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = FriendInfo(id: 1, name: 'Глеб', username: 'gleb');

DemoInvitesSource _demo({Duration? replyDelay}) => DemoInvitesSource(
  me: () => _me,
  today: DateTime(2026, 11, 2),
  delay: Duration.zero,
  replyDelay: replyDelay,
);

void main() {
  group('Invite', () {
    const anna = FriendInfo(id: 2, name: 'Анна Ли', username: 'anna');
    const mark = FriendInfo(id: 3, name: 'Марк', username: 'mark');
    final invite = Invite(
      id: 'x',
      organizer: _me,
      title: 'Ужин',
      start: DateTime(2026, 11, 2, 19),
      end: DateTime(2026, 11, 2, 21),
      participants: const [
        InviteParticipant(anna, RsvpStatus.going),
        InviteParticipant(mark, RsvpStatus.pending),
      ],
    );

    test('the organizer goes; others have their own answer', () {
      expect(invite.statusOf(_me.id), RsvpStatus.going);
      expect(invite.statusOf(anna.id), RsvpStatus.going);
      expect(invite.statusOf(mark.id), RsvpStatus.pending);
      expect(invite.statusOf(99), isNull);
      expect(invite.people.first, _me);
    });

    test('an answer changes only that person', () {
      final next = invite.answered(mark.id, RsvpStatus.notGoing);
      expect(next.statusOf(mark.id), RsvpStatus.notGoing);
      expect(next.statusOf(anna.id), RsvpStatus.going);
      expect(next.withStatus(RsvpStatus.notGoing), [mark]);
    });

    test('names for a sentence', () {
      expect(peopleLabel([anna]), 'Анна');
      expect(peopleLabel([anna, mark]), 'Анна и Марк');
      expect(peopleLabel([anna, mark, _me]), 'Анна, Марк и Глеб');
      expect(peopleLabel([anna, mark, _me, anna]), 'Анна, Марк и ещё 2');
    });
  });

  group('DemoInvitesSource', () {
    test('starts with one to answer, one to go, one own, one past', () async {
      final source = _demo();
      addTearDown(source.dispose);
      final invites = await source.list();
      expect(invites, hasLength(4));
      expect(
        invites.where((i) => i.statusOf(_me.id) == RsvpStatus.pending),
        hasLength(1),
      );
      expect(invites.where((i) => i.isOrganizer(_me.id)), hasLength(1));
      // The user is themselves, not a placeholder.
      expect(invites.first.participants.first.person, _me);
    });

    test('creates, answers, edits and cancels', () async {
      final source = _demo();
      addTearDown(source.dispose);
      final created = await source.create(
        InviteDraft(
          title: 'Каток',
          start: DateTime(2026, 11, 3, 18),
          end: DateTime(2026, 11, 3, 20),
          invitees: const [DemoInvitesSource.alina],
        ),
      );
      expect(created.isOrganizer(_me.id), isTrue);
      expect(created.statusOf(DemoInvitesSource.alina.id), RsvpStatus.pending);

      await source.respond('demo-invite-dinner', RsvpStatus.going);
      final dinner = (await source.list()).firstWhere(
        (i) => i.id == 'demo-invite-dinner',
      );
      expect(dinner.statusOf(_me.id), RsvpStatus.going);

      await source.update(
        created.id,
        InviteDraft(
          title: 'Каток и чай',
          start: created.start,
          end: created.end,
          invitees: const [],
        ),
      );
      expect(
        (await source.list()).firstWhere((i) => i.id == created.id).title,
        'Каток и чай',
      );

      await source.cancel(created.id);
      expect((await source.list()).any((i) => i.id == created.id), isFalse);
    });

    test('invited friends answer by themselves later', () async {
      final source = _demo(replyDelay: const Duration(milliseconds: 20));
      addTearDown(source.dispose);
      var fired = 0;
      source.changes.addListener(() => fired++);
      final created = await source.create(
        InviteDraft(
          title: 'Кофе',
          start: DateTime(2026, 11, 3, 9),
          end: DateTime(2026, 11, 3, 10),
          invitees: const [DemoInvitesSource.alina, DemoInvitesSource.mark],
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      final after = (await source.list()).firstWhere((i) => i.id == created.id);
      expect(fired, 2);
      expect(after.withStatus(RsvpStatus.pending), isEmpty);
    });

    test('offline fails like a network error', () async {
      final source = _demo()..offline = true;
      addTearDown(source.dispose);
      expect(
        source.list(),
        throwsA(isA<ApiException>().having((e) => e.isNetwork, 'net', true)),
      );
    });
  });

  test('the server source says invites are not there yet', () async {
    const source = ServerInvitesSource();
    expect(source.list(), throwsA(isA<InvitesUnavailable>()));
    expect(
      source.respond('x', RsvpStatus.going),
      throwsA(isA<InvitesUnavailable>()),
    );
  });

  group('InvitesStore', () {
    test('loads, then reads back after every change', () async {
      final store = InvitesStore(_demo());
      addTearDown(store.dispose);
      expect(store.invites, isNull);
      await store.load();
      expect(store.invites, hasLength(4));

      await store.respond('demo-invite-dinner', RsvpStatus.notGoing);
      expect(
        store.byId('demo-invite-dinner')!.statusOf(_me.id),
        RsvpStatus.notGoing,
      );

      await store.cancel('demo-invite-games');
      expect(store.byId('demo-invite-games'), isNull);
    });

    test('a failed load keeps an error and an empty list', () async {
      final store = InvitesStore(const ServerInvitesSource());
      addTearDown(store.dispose);
      await store.load();
      expect(store.error, isA<InvitesUnavailable>());
      expect(store.invites, isEmpty);
    });
  });
}
