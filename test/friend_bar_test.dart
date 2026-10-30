import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progressive_background_blur/progressive_background_blur.dart';

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
    expect(leftOf(tester, 'Алина'), lessThan(leftOf(tester, 'Вера')));

    await tester.tap(find.bySemanticsLabel('Вера'));
    await tester.pumpAndSettle();

    expect(selection.selected, [3]);
    expect(find.byKey(const ValueKey('friend-ring')), findsOneWidget);
    expect(leftOf(tester, 'Вера'), lessThan(leftOf(tester, 'Алина')));
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
    expect(leftOf(tester, 'Алина'), greaterThan(600));
    // Not picked: slid off past the right edge.
    final dina = find.bySemanticsLabel('Дина');
    expect(dina.evaluate().isEmpty || tester.getRect(dina).left > 800, isTrue);

    await tester.tap(find.bySemanticsLabel('Показать занятость друзей'));
    expect(shownFriends, 1);
  });

  testWidgets('the edge blur is clipped to the bar', (tester) async {
    // Unclipped, the backdrop layer would blur both edges of the whole
    // screen, the month's chips included.
    await pumpBar(tester);
    final blurs = find.byType(ProgressiveBlur);
    expect(blurs, findsNWidgets(2));
    for (final element in blurs.evaluate()) {
      final clip = find.ancestor(
        of: find.byWidget(element.widget),
        matching: find.byType(ClipRect),
      );
      expect(clip, findsWidgets);
      expect(tester.getRect(clip.first).width, FriendBarStyle.edge);
    }
  });

  testWidgets('says when friends’ schedules are unavailable', (tester) async {
    selection.toggle(1);
    await pumpBar(tester, schedules: false);
    expect(find.text('Расписание друзей пока недоступно'), findsOneWidget);
  });

  testWidgets('no friends yet: offers to add some', (tester) async {
    await pumpBar(tester, friends: const []);
    expect(find.text('Добавить друзей'), findsOneWidget);
  });
}
