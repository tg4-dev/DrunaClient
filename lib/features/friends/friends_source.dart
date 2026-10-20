import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';

/// Everything the friends page asks of the server, so the page can run on
/// demo data until the new UI is wired to a live backend.
abstract interface class FriendsSource {
  Future<List<FriendInfo>> listFriends();
  Future<List<FriendInfo>> incomingRequests();
  Future<List<FriendInfo>> outgoingRequests();
  Future<List<FriendInfo>> search(String username);
  Future<void> sendRequest(String username);
  Future<void> accept(String username);
  Future<void> reject(String username);
  Future<void> remove(String username);
}

class ServerFriendsSource implements FriendsSource {
  const ServerFriendsSource(this._repository);

  final DrunaRepository _repository;

  @override
  Future<List<FriendInfo>> listFriends() => _repository.listFriends();
  @override
  Future<List<FriendInfo>> incomingRequests() => _repository.incomingRequests();
  @override
  Future<List<FriendInfo>> outgoingRequests() => _repository.outgoingRequests();
  @override
  Future<List<FriendInfo>> search(String username) =>
      _repository.searchFriends(username);
  @override
  Future<void> sendRequest(String username) =>
      _repository.sendFriendRequest(username);
  @override
  Future<void> accept(String username) => _repository.acceptFriend(username);
  @override
  Future<void> reject(String username) => _repository.rejectFriend(username);
  @override
  Future<void> remove(String username) => _repository.deleteFriend(username);
}

/// In-memory friends for trying the page without a server: twelve friends
/// (enough to overflow the friend bar), one incoming request and a few
/// people to find by username.
class DemoFriendsSource implements FriendsSource {
  DemoFriendsSource({this.delay = const Duration(milliseconds: 300)});

  final Duration delay;

  /// Every request fails as if there were no network: for the error states.
  bool offline = false;

  final _friends = <FriendInfo>[
    const FriendInfo(id: 101, name: 'Алина Смирнова', username: 'alina'),
    const FriendInfo(id: 102, name: 'Марк Ли', username: 'mark'),
    // Ten more, to see the friend bar and the month overflow.
    const FriendInfo(id: 107, name: 'Ольга Петрова', username: 'olga'),
    const FriendInfo(id: 108, name: 'Дима Соколов', username: 'dima'),
    const FriendInfo(id: 109, name: 'Катя Лебедева', username: 'katya'),
    const FriendInfo(id: 110, name: 'Артём Ковалёв', username: 'artem'),
    const FriendInfo(id: 111, name: 'Соня', username: 'sonya'),
    const FriendInfo(id: 112, name: 'Илья Морозов', username: 'ilya'),
    const FriendInfo(id: 113, name: 'Вика Новикова', username: 'vika'),
    const FriendInfo(
      id: 114,
      name: 'Константин Константинопольский',
      username: 'konstantin_konstantinopolsky',
    ),
    const FriendInfo(id: 115, name: 'Юля Фёдорова', username: 'yulia'),
    const FriendInfo(id: 116, name: 'Гоша', username: 'gosha'),
  ];
  final _incoming = <FriendInfo>[
    const FriendInfo(id: 103, name: 'Ника Орлова', username: 'nika'),
  ];
  final _outgoing = <FriendInfo>[];
  final _others = <FriendInfo>[
    const FriendInfo(id: 104, name: 'Максим Белов', username: 'max'),
    const FriendInfo(id: 105, name: 'Ева Ким', username: 'eva'),
    const FriendInfo(id: 106, name: 'Никита Иванов', username: 'nikita'),
  ];

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

  FriendInfo _take(List<FriendInfo> from, String username) {
    final index = from.indexWhere((person) => person.username == username);
    if (index < 0) throw StateError('Нет пользователя @$username');
    return from.removeAt(index);
  }

  @override
  Future<List<FriendInfo>> listFriends() => _later(() => [..._friends]);
  @override
  Future<List<FriendInfo>> incomingRequests() => _later(() => [..._incoming]);
  @override
  Future<List<FriendInfo>> outgoingRequests() => _later(() => [..._outgoing]);

  @override
  Future<List<FriendInfo>> search(String username) => _later(() {
    final query = username.trim().toLowerCase();
    return [
      for (final person in [..._others, ..._outgoing, ..._incoming])
        if (person.username.contains(query)) person,
    ];
  });

  @override
  Future<void> sendRequest(String username) =>
      _later(() => _outgoing.add(_take(_others, username)));
  @override
  Future<void> accept(String username) =>
      _later(() => _friends.add(_take(_incoming, username)));
  @override
  Future<void> reject(String username) =>
      _later(() => _others.add(_take(_incoming, username)));
  @override
  Future<void> remove(String username) =>
      _later(() => _others.add(_take(_friends, username)));
}
