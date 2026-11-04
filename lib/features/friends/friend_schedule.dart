import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/features/friends/friends_store.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';

abstract interface class FriendScheduleSource {
  Future<List<CalendarEvent>> eventsOf(FriendInfo friend);
}

class NoFriendSchedule implements FriendScheduleSource {
  const NoFriendSchedule();

  @override
  Future<List<CalendarEvent>> eventsOf(FriendInfo friend) async => const [];
}

class DemoFriendSchedule implements FriendScheduleSource {
  DemoFriendSchedule({DateTime? today, this.weeks = 8})
    : today = dateOnly(today ?? DateTime.now());

  final DateTime today;
  final int weeks;

  @override
  Future<List<CalendarEvent>> eventsOf(FriendInfo friend) async {
    final random = math.Random(friend.id * 7919 + 17);
    final thisWeek = weekIndexOf(today);
    final events = <CalendarEvent>[];
    for (var week = thisWeek - weeks; week <= thisWeek + weeks; week++) {
      final monday = mondayOfWeek(week);
      final count = 2 + random.nextInt(3);
      for (var k = 0; k < count; k++) {
        final day = addCalendarDays(monday, random.nextInt(7));
        final id = 'friend-${friend.id}-$week-$k';
        if (random.nextDouble() < 0.12) {
          events.add(
            CalendarEvent(
              id: id,
              title: '',
              start: day,
              end: addCalendarDays(day, 1 + random.nextInt(2)),
              allDay: true,
            ),
          );
          continue;
        }
        final hour = 8 + random.nextInt(13);
        final start = DateTime(day.year, day.month, day.day, hour);
        events.add(
          CalendarEvent(
            id: id,
            title: '',
            start: start,
            end: start.add(Duration(minutes: 60 + 30 * random.nextInt(5))),
          ),
        );
      }
    }
    return events;
  }
}

class FriendSchedules extends ValueNotifier<List<CalendarEvent>> {
  FriendSchedules({
    required this.selection,
    required this.friends,
    required FriendScheduleSource source,
  }) : _source = source,
       super(const []) {
    selection.addListener(_refresh);
    friends.addListener(_friendsChanged);
    _loadedFor = friends.friends;
    _refresh();
  }

  List<FriendInfo>? _loadedFor;

  void _friendsChanged() {
    if (!identical(friends.friends, _loadedFor)) {
      _loadedFor = friends.friends;
      _cache.clear();
    }
    _refresh();
  }

  final FriendSelection selection;
  final FriendsStore friends;
  FriendScheduleSource _source;
  final _cache = <int, List<CalendarEvent>>{};
  var _generation = 0;
  bool _disposed = false;

  set source(FriendScheduleSource value) {
    if (identical(value, _source)) return;
    _source = value;
    _cache.clear();
    _refresh();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final byId = {
      for (final friend in friends.friends ?? const <FriendInfo>[])
        friend.id: friend,
    };
    final chosen = [
      for (final id in selection.selected)
        if (byId[id] != null) byId[id]!,
    ];
    final missing = [
      for (final friend in chosen)
        if (!_cache.containsKey(friend.id)) friend,
    ];
    if (missing.isNotEmpty) {
      final source = _source;
      final loaded = await Future.wait([
        for (final friend in missing) _load(source, friend),
      ]);
      if (_disposed || !identical(source, _source)) return;
      for (var i = 0; i < missing.length; i++) {
        _cache[missing[i].id] = loaded[i];
      }
    }
    if (_disposed || generation != _generation) return;
    value = [for (final friend in chosen) ...?_cache[friend.id]];
  }

  Future<List<CalendarEvent>> _load(
    FriendScheduleSource source,
    FriendInfo friend,
  ) async {
    final color = avatarColorFor(id: friend.id, username: friend.username);
    try {
      final events = await source.eventsOf(friend);
      return [
        for (final event in events)
          event.copyWith(color: color, ownerId: friend.id),
      ];
    } on Object {
      return const [];
    }
  }

  @override
  void dispose() {
    _disposed = true;
    selection.removeListener(_refresh);
    friends.removeListener(_friendsChanged);
    super.dispose();
  }
}
