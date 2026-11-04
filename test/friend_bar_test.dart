import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _friends = [
  FriendInfo(id: 1, name: 'Алина', username: 'alina'),
  FriendInfo(id: 2, name: 'Борис', username: 'boris'),
  FriendInfo(id: 3, name: 'Вера', username: 'vera'),
  FriendInfo(id: 4, name: 'Глеб', username: 'gleb'),
  FriendInfo(id: 5, name: 'Дина', username: 'dina'),
];

void main() {
  late FriendSelection selection;
  late ValueNotifier<double> mode;
  var shownFriends = 0;

  setUp(() {
    selection = FriendSelection(MemorySettingsStorage());
    mode = ValueNotifier(1);
    shownFriends = 0;
  });

  Future<void> pumpBar(
    WidgetTester tester, {
    List<FriendInfo>? friends = _friends,
    bool schedules = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: FriendBar(
              friends: friends,
              selection: selection,
              mode: mode,
              schedulesAvailable: schedules,
              onShowFriends: () => shownFriends++,
              onAddFriends: () {},
              me: const SizedBox(key: ValueKey('me')),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  double leftOf(WidgetTester tester, String name) =>
      tester.getRect(find.bySemanticsLabel(name)).left;

  testWidgets('a tap picks a friend: ring, and first in the row', (
    tester,
  ) async {
    await pumpBar(tester);
    expect(find.text('Выбери друзей, чтобы увидеть их занятость'), findsOne);
    expect(leftOf(tester, 'АЛИНА'), lessThan(leftOf(tester, 'ВЕРА')));

    await tester.tap(find.bySemanticsLabel('ВЕРА'));
    await tester.pumpAndSettle();

    expect(selection.selected, [3]);
    expect(find.byKey(const ValueKey('friend-ring')), findsOneWidget);
    expect(leftOf(tester, 'ВЕРА'), lessThan(leftOf(tester, 'АЛИНА')));
    expect(
      find.text('Выбери друзей, чтобы увидеть их занятость'),
      findsNothing,
    );
  });

  testWidgets('folded: the picked friends stack at the right, "+N" after 3', (
    tester,
  ) async {
    for (final id in [1, 2, 3, 4]) {
      selection.toggle(id);
    }
    mode.value = 0;
    await pumpBar(tester);

    expect(find.text('+1'), findsOneWidget);
    expect(leftOf(tester, 'АЛИНА'), greaterThan(600));
    final dina = find.bySemanticsLabel('ДИНА');
    expect(dina.evaluate().isEmpty || tester.getRect(dina).left > 800, isTrue);

    await tester.tap(find.bySemanticsLabel('Показать занятость друзей'));
    expect(shownFriends, 1);
  });

  testWidgets('the row has no edge blur', (tester) async {
    await pumpBar(tester);
    expect(
      find.ancestor(
        of: find.bySemanticsLabel('АЛИНА'),
        matching: find.byType(EdgeBlur),
      ),
      findsNothing,
    );
  });

  testWidgets('says when friends’ schedules are unavailable', (tester) async {
    selection.toggle(1);
    await pumpBar(tester, schedules: false);
    expect(find.text('Расписание друзей пока недоступно'), findsOneWidget);
  });

  testWidgets('no friends yet: offers to add some', (tester) async {
    await pumpBar(tester, friends: const []);
    expect(find.text('Добавить друзей'), findsOneWidget);
    final button = find.byKey(const ValueKey('add-friends'));
    final open = tester.getRect(button).left;
    mode.value = 0.5;
    await tester.pump();
    final width = tester.getSize(find.byType(FriendBar)).width;
    expect(tester.getRect(button).left, greaterThan(open));
    mode.value = 0;
    await tester.pump();
    expect(tester.getRect(button).left, greaterThan(width));
  });

  testWidgets('the row comes in as a staircase, the left first', (
    tester,
  ) async {
    await pumpBar(tester);
    final step = leftOf(tester, 'БОРИС') - leftOf(tester, 'АЛИНА');
    mode.value = 0.6;
    await tester.pump();
    final gap1 = leftOf(tester, 'БОРИС') - leftOf(tester, 'АЛИНА');
    final gap2 = leftOf(tester, 'ВЕРА') - leftOf(tester, 'БОРИС');
    expect(gap1, greaterThan(step));
    expect(gap2, greaterThan(step));
    expect(friendBarFoldAt(0.6, 0), lessThan(friendBarFoldAt(0.6, 1)));
    expect(friendBarFoldAt(1, 5), 0);
    expect(friendBarFoldAt(0, 0), 1);
  });

  testWidgets('in my mode: my avatar with "Мои события", and an arrow to '
      'friends\' calendar while nobody is picked', (tester) async {
    mode.value = 0;
    await pumpBar(tester);
    double shiftOf(Finder finder) => tester
        .widget<Transform>(
          find.ancestor(of: finder, matching: find.byType(Transform)).first,
        )
        .transform
        .storage[12];
    expect(find.text('Мои события'), findsOneWidget);
    expect(shiftOf(find.byKey(const ValueKey('me'))), closeTo(0, 1e-6));
    final arrow = find.byKey(const ValueKey('swipe-hint'));
    expect(arrow, findsOneWidget);
    expect(shiftOf(arrow), closeTo(0, 1e-6));

    await tester.tap(arrow);
    expect(shownFriends, 1);

    mode.value = 1;
    await tester.pumpAndSettle();
    final width = tester.getSize(find.byType(FriendBar)).width;
    expect(shiftOf(find.byKey(const ValueKey('me'))), lessThan(-width));

    selection.toggle(1);
    mode.value = 0;
    await tester.pumpAndSettle();
    expect(arrow, findsNothing);
  });
}
