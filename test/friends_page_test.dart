import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/friends/friends_page.dart';
import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpPage(WidgetTester tester, FriendsSource source) async {
    await tester.pumpWidget(MaterialApp(home: FriendsPage(source: source)));
    await tester.pumpAndSettle();
  }

  testWidgets('shows two demo friends and an incoming request', (tester) async {
    await pumpPage(tester, DemoFriendsSource(delay: Duration.zero));

    expect(find.text('Алина Смирнова'), findsOneWidget);
    expect(find.text('Марк Ли'), findsOneWidget);
    expect(find.text('2 друга'), findsOneWidget);
    expect(find.text('Заявки'), findsOneWidget);
    expect(find.text('Ника Орлова'), findsOneWidget);
  });

  testWidgets('✓ turns the request into a friend', (tester) async {
    await pumpPage(tester, DemoFriendsSource(delay: Duration.zero));

    await tester.tap(find.bySemanticsLabel('Принять заявку от Ника Орлова'));
    await tester.pumpAndSettle();

    expect(find.text('3 друга'), findsOneWidget);
    expect(find.text('Заявки'), findsNothing);
    expect(find.text('Ника Орлова'), findsOneWidget);
  });

  testWidgets('✕ drops the request', (tester) async {
    await pumpPage(tester, DemoFriendsSource(delay: Duration.zero));

    await tester.tap(find.bySemanticsLabel('Отклонить заявку от Ника Орлова'));
    await tester.pumpAndSettle();

    expect(find.text('2 друга'), findsOneWidget);
    expect(find.text('Ника Орлова'), findsNothing);
  });

  testWidgets('search finds people and sends a request', (tester) async {
    await pumpPage(tester, DemoFriendsSource(delay: Duration.zero));

    await tester.enterText(find.byType(TextField), 'ma');
    await tester.pump(FriendsStyle.searchDebounce);
    await tester.pumpAndSettle();

    expect(find.text('Максим Белов'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Добавить Максим Белов в друзья'));
    await tester.pumpAndSettle();
    expect(find.text('Заявка отправлена'), findsOneWidget);
  });

  testWidgets('a failed load offers to try again', (tester) async {
    final source = _FailingSource();
    await pumpPage(tester, source);

    expect(find.text('Не удалось загрузить друзей'), findsOneWidget);
    expect(find.text('Нет сети'), findsOneWidget);

    source.fail = false;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.text('Здесь появятся твои друзья'), findsOneWidget);
  });

  test('counts friends in Russian', () {
    expect(friendsCountLabel(0), '0 друзей');
    expect(friendsCountLabel(1), '1 друг');
    expect(friendsCountLabel(3), '3 друга');
    expect(friendsCountLabel(11), '11 друзей');
    expect(friendsCountLabel(21), '21 друг');
    expect(friendsCountLabel(24), '24 друга');
  });
}

class _FailingSource implements FriendsSource {
  var fail = true;

  Future<List<FriendInfo>> _list() async {
    if (fail) throw const ApiException('Нет сети', isNetwork: true);
    return const [];
  }

  @override
  Future<List<FriendInfo>> listFriends() => _list();
  @override
  Future<List<FriendInfo>> incomingRequests() => _list();
  @override
  Future<List<FriendInfo>> outgoingRequests() => _list();
  @override
  Future<List<FriendInfo>> search(String username) => _list();
  @override
  Future<void> sendRequest(String username) async {}
  @override
  Future<void> accept(String username) async {}
  @override
  Future<void> reject(String username) async {}
  @override
  Future<void> remove(String username) async {}
}
