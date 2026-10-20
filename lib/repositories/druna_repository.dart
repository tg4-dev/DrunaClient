import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/models/models.dart';

class DrunaRepository {
  DrunaRepository(this._api);

  final ApiClient _api;

  Future<bool> restoreSession() => _api.restoreSession();
  Future<void> logout() => _api.clearSession();
  void debugExpireAccessToken() => _api.debugExpireAccessToken();

  /// `GET /ping/`: the server and its database answer.
  Future<void> ping() => _api.publicRequest<void>('/ping/', decode: (_) {});

  Future<void> signIn(String username, String password) async {
    final tokens = await _api.publicRequest<TokenPair>(
      '/auth/sign-in',
      method: 'POST',
      data: {'username': username.trim(), 'password': password},
      decode: (data) =>
          TokenPair.fromJson(Map<String, dynamic>.from(data as Map)),
    );
    await _api.saveTokens(tokens);
  }

  Future<void> signUp({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    await _api.publicRequest<void>(
      '/auth/sign-up',
      method: 'POST',
      data: {
        'name': name.trim(),
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
      },
      decode: (_) {},
    );
    await signIn(username, password);
  }

  Future<UserProfile> getProfile() => _api.request(
    '/api/v1/users/me',
    decode: (data) =>
        UserProfile.fromJson(Map<String, dynamic>.from(data as Map)),
  );

  Future<UserProfile> updateProfile({String? name, String? avatarUrl}) async {
    await _api.request<void>(
      '/api/v1/users/me',
      method: 'PATCH',
      data: {
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatarURL': avatarUrl,
      },
      decode: (_) {},
    );
    return getProfile();
  }

  Future<List<DrunaEvent>> listEvents({int? groupId}) {
    final path = groupId == null
        ? '/api/v1/events/'
        : '/api/v1/groups/$groupId/events';
    return _api.request(
      path,
      decode: (data) {
        final map = Map<String, dynamic>.from(data as Map);
        return mapList(map['events']).map(DrunaEvent.fromJson).toList();
      },
    );
  }

  Future<int> createEvent(DrunaEvent event, {int? groupId}) => _api.request(
    groupId == null ? '/api/v1/events/' : '/api/v1/groups/$groupId/events',
    method: 'POST',
    data: event.toRequest(),
    decode: (data) {
      final map = Map<String, dynamic>.from(data as Map);
      return ((map['eventId'] ?? map['eventID']) as num).toInt();
    },
  );

  Future<void> updateEvent(DrunaEvent event, {int? groupId}) => _api.request(
    groupId == null
        ? '/api/v1/events/${event.id}'
        : '/api/v1/groups/$groupId/events/${event.id}',
    method: 'PATCH',
    data: event.toRequest(),
    decode: (_) {},
  );

  Future<void> deleteEvent(int id, {int? groupId}) => _api.request(
    groupId == null
        ? '/api/v1/events/$id'
        : '/api/v1/groups/$groupId/events/$id',
    method: 'DELETE',
    decode: (_) {},
  );

  Future<List<FreeSlot>> freeTime(DateTime date, {int? groupId}) =>
      _api.request(
        groupId == null
            ? '/api/v1/events/free-time'
            : '/api/v1/groups/$groupId/free-time',
        method: 'POST',
        data: {'date': date.toIso8601String().substring(0, 10)},
        decode: (data) {
          final map = Map<String, dynamic>.from(data as Map);
          return mapList(map['freeSlots']).map(FreeSlot.fromJson).toList();
        },
      );

  Future<List<FriendInfo>> listFriends() =>
      _friendList('/api/v1/friends/list', 'friends');
  Future<List<FriendInfo>> incomingRequests() =>
      _friendList('/api/v1/friends/requests/incoming', 'requests');
  Future<List<FriendInfo>> outgoingRequests() =>
      _friendList('/api/v1/friends/requests/outgoing', 'requests');
  Future<List<FriendInfo>> searchFriends(String username) => _friendList(
    '/api/v1/friends/search',
    'users',
    query: {'username': username},
  );

  Future<List<FriendInfo>> _friendList(
    String path,
    String key, {
    Map<String, dynamic>? query,
  }) => _api.request(
    path,
    query: query,
    decode: (data) {
      final map = Map<String, dynamic>.from(data as Map);
      final raw = map[key] ?? map['friends'] ?? map['users'] ?? const [];
      return mapList(raw).map(FriendInfo.fromJson).toList();
    },
  );

  Future<void> sendFriendRequest(String username) =>
      _friendAction('/api/v1/friends/request', username);
  Future<void> acceptFriend(String username) =>
      _friendAction('/api/v1/friends/accept', username);
  Future<void> rejectFriend(String username) =>
      _friendAction('/api/v1/friends/reject', username);
  Future<void> deleteFriend(String username) =>
      _friendAction('/api/v1/friends/', username, method: 'DELETE');

  Future<void> _friendAction(
    String path,
    String username, {
    String method = 'POST',
  }) => _api.request(
    path,
    method: method,
    data: {'username': username},
    decode: (_) {},
  );

  Future<List<GroupSummary>> listGroups() => _api.request(
    '/api/v1/groups/list',
    decode: (data) {
      final map = Map<String, dynamic>.from(data as Map);
      return mapList(map['groups']).map(GroupSummary.fromJson).toList();
    },
  );

  Future<GroupSummary> getGroup(int id) => _api.request(
    '/api/v1/groups/$id',
    decode: (data) =>
        GroupSummary.fromJson(Map<String, dynamic>.from(data as Map)),
  );

  Future<int> createGroup(String name) => _api.request(
    '/api/v1/groups/create',
    method: 'POST',
    data: {'name': name.trim()},
    decode: (data) {
      final map = Map<String, dynamic>.from(data as Map);
      return ((map['groupId'] ?? map['groupID']) as num).toInt();
    },
  );

  Future<void> addGroupMember(int id, String username) => _api.request(
    '/api/v1/groups/$id/members',
    method: 'POST',
    data: {'username': username},
    decode: (_) {},
  );

  Future<void> confirmGroupTime(int id, DateTime time) => _api.request(
    '/api/v1/groups/$id/confirm',
    method: 'POST',
    data: {'confirmedTime': time.toUtc().toIso8601String()},
    decode: (_) {},
  );

  Future<void> leaveGroup(int id) =>
      _api.request('/api/v1/groups/$id/leave', method: 'POST', decode: (_) {});

  Future<void> deleteGroup(int id) =>
      _api.request('/api/v1/groups/$id', method: 'DELETE', decode: (_) {});
}
