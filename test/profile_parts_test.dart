import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invite_split.dart';
import 'package:druna_app/features/profile/chip_time.dart';
import 'package:druna_app/features/profile/profile_header.dart';
import 'package:druna_app/features/profile/profile_page.dart';
import 'package:flutter/painting.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/page_indicator.dart';
import 'package:druna_app/shared/ui/people_backdrop.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('splitInvites', () {
    const me = FriendInfo(id: 1, name: 'Глеб', username: 'gleb');
    const alina = FriendInfo(id: 2, name: 'Алина', username: 'alina');
    final now = DateTime(2026, 11, 7, 12);

    Invite invite(String id, int day, RsvpStatus status, {int length = 2}) =>
        Invite(
          id: id,
          organizer: alina,
          title: id,
          start: DateTime(2026, 11, day, 18),
          end: DateTime(2026, 11, day, 18 + length),
          participants: [InviteParticipant(me, status)],
        );

    test('waiting, upcoming and past by my answer and the clock', () {
      final split = splitInvites(
        [
          invite('later', 12, RsvpStatus.going),
          invite('ask', 9, RsvpStatus.pending),
          invite('soon', 8, RsvpStatus.going),
          invite('declined', 10, RsvpStatus.notGoing),
          invite('old', 1, RsvpStatus.going),
          invite('old-declined', 2, RsvpStatus.notGoing),
          invite('older', 3, RsvpStatus.pending),
        ],
        meId: me.id,
        now: now,
      );
      expect(split.waiting.map((i) => i.id), ['ask']);
      expect(split.upcoming.map((i) => i.id), ['soon', 'declined', 'later']);
      expect(split.past.map((i) => i.id), ['older', 'old']);
    });

    test('an invite I am not in is skipped', () {
      final stranger = Invite(
        id: 'x',
        organizer: alina,
        title: 'x',
        start: DateTime(2026, 11, 9),
        end: DateTime(2026, 11, 9, 1),
        participants: const [],
      );
      final split = splitInvites([stranger], meId: me.id, now: now);
      expect(split.waiting, isEmpty);
      expect(split.upcoming, isEmpty);
    });
  });

  group('chipTime', () {
    test('one day with a time: day, clock, month', () {
      final time = chipTime(
        DateTime(2026, 11, 8, 19),
        DateTime(2026, 11, 8, 21),
        allDay: false,
      );
      expect(time.caption, isNull);
      expect(time.left, '8 ВС');
      expect(time.middle, '19:00');
      expect(time.right, 'НОЯ');
      expect(time.span, isFalse);
    });

    test('a whole day says so in the middle', () {
      final time = chipTime(
        DateTime(2026, 11, 8),
        DateTime(2026, 11, 9),
        allDay: true,
      );
      expect(time.middle, 'весь день');
      expect(time.span, isFalse);
    });

    test('several days: month above, dates and length', () {
      final time = chipTime(
        DateTime(2026, 11, 8, 10),
        DateTime(2026, 11, 9, 10),
        allDay: false,
      );
      expect(time.caption, 'НОЯБРЬ');
      expect(time.left, '08.11');
      expect(time.middle, '1 день');
      expect(time.right, '09.11');
      expect(time.span, isTrue);
    });

    test('across months the caption names both', () {
      final time = chipTime(
        DateTime(2026, 11, 30),
        DateTime(2026, 12, 3),
        allDay: true,
      );
      expect(time.caption, 'НОЯ – ДЕК');
      expect(time.middle, '3 дня');
      expect(time.right, '02.12');
    });
  });

  group('page indicator', () {
    test('the mark under the page is widest, neighbours follow the finger', () {
      expect(pageMarkFocus(0, 0), 1);
      expect(pageMarkFocus(1, 0.25), 0.25);
      expect(pageMarkFocus(2, 0.25), 0);
      expect(pageMarkWidth(PageMark.dot, 0), PageIndicatorStyle.dot);
      expect(pageMarkWidth(PageMark.dot, 1), PageIndicatorStyle.dot);
      expect(pageMarkWidth(PageMark.dash, 1), PageIndicatorStyle.active);
      expect(pageMarkWidth(PageMark.dash, 0.5), 28);
      expect(pageMarkWidth(PageMark.plus, 1), PageIndicatorStyle.plus);
    });
  });

  test('the dark layer is solid up to the first heading', () {
    expect(darkSolidShare(400, 800), 0.5);
    expect(darkSolidShare(0, 800), 0.999);
    expect(darkSolidShare(900, 800), 0);
  });

  group('profile header', () {
    const name = Size(140, 34);

    test('open: big avatar centred above the name', () {
      final frame = headerFrame(width: 400, offset: 0, name: name);
      expect(frame.collapse, 0);
      expect(frame.avatarScale, 1);
      expect(frame.avatarCenter.dx, 200);
      expect(frame.name.dx, 130);
      expect(frame.name.dy, headerNameTop());
    });

    test('collapsed: small avatar left of the name in one row', () {
      final distance = headerCollapseDistance(name.height);
      final frame = headerFrame(width: 400, offset: distance + 50, name: name);
      expect(frame.collapse, 1);
      expect(
        frame.avatarScale,
        ProfileHeaderStyle.rowAvatar / ProfileHeaderStyle.avatar,
      );
      expect(frame.name.dy, (ProfileHeaderStyle.row - name.height) / 2);
      expect(frame.avatarCenter.dy, ProfileHeaderStyle.row / 2);
      final rowLeft = (400 - (36 + 8 + 140)) / 2;
      expect(frame.avatarCenter.dx, rowLeft + 18);
      expect(frame.name.dx, rowLeft + 44);
    });

    test('a sticky label waits, pins, and is pushed by the next one', () {
      const pin = ProfileHeaderStyle.row;
      expect(
        stickyLabelTop(headingTop: 200, nextHeadingTop: 500, labelHeight: 32),
        200,
      );
      expect(
        stickyLabelTop(headingTop: -40, nextHeadingTop: 500, labelHeight: 32),
        pin,
      );
      expect(
        stickyLabelTop(headingTop: -40, nextHeadingTop: 60, labelHeight: 32),
        28,
      );
    });
  });

  test('a heading shrinks into the sticky label over its last 24 pt', () {
    const pin = ProfileHeaderStyle.row;
    expect(stickyProgress(pin + stickyRamp + 10), 0);
    expect(stickyProgress(pin + stickyRamp / 2), 0.5);
    expect(stickyProgress(pin), 1);
  });

  test('the profile link names the user', () {
    expect(profileLink('gleb'), 'https://druna.tg4.dev/user/gleb');
  });
}
