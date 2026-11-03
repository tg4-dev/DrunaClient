import 'package:druna_app/features/event_page/attendance_block.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const me = FriendInfo(id: 1, name: 'Глеб', username: 'gleb');
  const organizer = FriendInfo(id: 2, name: 'Алина', username: 'alina');

  Widget block(List<FriendInfo> notGoing) => MaterialApp(
    home: Scaffold(
      body: AttendanceBlock(
        me: me,
        own: Colors.green,
        mine: notGoing.isEmpty ? RsvpStatus.pending : RsvpStatus.notGoing,
        organizer: false,
        going: const [organizer],
        notGoing: notGoing,
        onAnswer: (_) {},
        onCancelEvent: () {},
      ),
    ),
  );

  testWidgets('the first one into an empty row lands like everyone else', (
    tester,
  ) async {
    await tester.pumpWidget(block(const []));
    await tester.pumpAndSettle();
    await tester.pumpWidget(block(const [me]));
    await tester.pump(const Duration(milliseconds: 60));
    final face = find.byWidgetPredicate(
      (w) => w is PersonAvatar && w.id == me.id && w.size == 36,
    );
    expect(face, findsOneWidget);
    final fading = tester
        .widgetList<Opacity>(
          find.ancestor(of: face, matching: find.byType(Opacity)),
        )
        .where((o) => o.opacity < 1);
    expect(fading, isNotEmpty, reason: 'the avatar is still landing');
    await tester.pumpAndSettle();
  });

  testWidgets('«Да» and «Нет» stand in a centred block, off the left edge', (
    tester,
  ) async {
    await tester.pumpWidget(block(const []));
    await tester.pumpAndSettle();
    final yes = tester.getRect(find.byKey(const ValueKey('rsvp-going')));
    final screen = tester.getSize(find.byType(Scaffold));
    final blockWidth = PillStyle.wide + 16 + 36 + 5 * 26 + 44;
    expect(yes.left, closeTo((screen.width - blockWidth) / 2, 0.5));
  });
}
