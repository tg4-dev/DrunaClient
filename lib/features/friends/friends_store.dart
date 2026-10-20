import 'package:druna_app/features/friends/friends_source.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';

/// The friends list the calendar's friend bar shows. The friends page loads
/// its own copy and asks this one to reload after every change.
class FriendsStore extends ChangeNotifier {
  FriendsStore(this._source);

  FriendsSource _source;
  List<FriendInfo>? _friends;
  Object? _error;
  var _generation = 0;
  bool _disposed = false;

  /// Null until the first answer.
  List<FriendInfo>? get friends => _friends;
  Object? get error => _error;

  set source(FriendsSource value) {
    if (identical(value, _source)) return;
    _source = value;
    _friends = null;
    notifyListeners();
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    try {
      final friends = await _source.listFriends();
      if (_disposed || generation != _generation) return;
      _friends = friends;
      _error = null;
    } catch (error) {
      if (_disposed || generation != _generation) return;
      _error = error;
      _friends ??= const [];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
