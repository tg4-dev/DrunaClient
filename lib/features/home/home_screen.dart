import 'dart:math' as math;

import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/features/events/event_editor_screen.dart';
import 'package:druna_app/features/friends/friends_screen.dart';
import 'package:druna_app/features/groups/groups_screen.dart';
import 'package:druna_app/features/notifications/notifications_screen.dart';
import 'package:druna_app/features/profile/profile_screen.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    required this.session,
    required this.repository,
    required this.config,
    super.key,
  });
  final SessionController session;
  final DrunaRepository repository;
  final AppConfig config;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<DrunaEvent>? _events;
  List<FriendInfo> _friends = const [];
  List<GroupSummary> _groups = const [];
  int _pendingCount = 0;
  int _active = 0;
  String? _error;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_events != null) setState(() => _refreshing = true);
    try {
      final values = await Future.wait<Object>([
        widget.repository.listEvents(),
        widget.repository.listFriends(),
        widget.repository.listGroups(),
        widget.repository.incomingRequests(),
      ]);
      if (!mounted) return;
      final events = (values[0] as List<DrunaEvent>)
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      setState(() {
        _events = events;
        _friends = values[1] as List<FriendInfo>;
        _groups = values[2] as List<GroupSummary>;
        _pendingCount = (values[3] as List<FriendInfo>).length;
        _active = events.isEmpty
            ? 0
            : _active.clamp(0, events.length - 1).toInt();
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.isUnauthorized) {
        await widget.session.logout();
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _create({int? groupId}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            EventEditorScreen(repository: widget.repository, groupId: groupId),
      ),
    );
    if (changed == true) {
      await _load();
      if (mounted) showMessage(context, 'Встреча создана');
    }
  }

  Future<void> _openEvent(DrunaEvent event) async {
    final changed = await openEventDetails(context, widget.repository, event);
    if (changed == true) await _load();
  }

  Future<void> _showPersonalFreeTime() async {
    final date = await pickDate(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    try {
      final slots = await widget.repository.freeTime(date);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Твоё свободное время',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('d MMMM', 'ru_RU').format(date),
                style: const TextStyle(color: DrunaColors.muted),
              ),
              const SizedBox(height: 18),
              if (slots.isEmpty)
                const Text('Свободных окон в этот день нет')
              else
                ...slots.map(
                  (slot) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: Text(
                      '${DateFormat('HH:mm').format(slot.start)}—${DateFormat('HH:mm').format(slot.end)}',
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final event = _events != null && _events!.isNotEmpty
        ? _events![_active]
        : null;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _EventBackdrop(seed: event?.id ?? 0, type: event?.type),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 12, 0),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Свободное время на день',
                        onPressed: _showPersonalFreeTime,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 44,
                          minHeight: 44,
                        ),
                        icon: Text(
                          DateFormat('E', 'ru_RU')
                              .format(DateTime.now())
                              .replaceAll('.', '')
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if ((_events?.length ?? 0) > 1)
                        Row(
                          children: List.generate(
                            math.min(_events!.length, 5),
                            (index) => GestureDetector(
                              onTap: () => setState(() => _active = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: index == _active ? 36 : 18,
                                height: 5,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: index == _active
                                      ? Colors.white
                                      : Colors.white30,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: 'Создать встречу',
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded),
                      ),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            tooltip: 'Уведомления',
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => NotificationsScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              );
                              _load();
                            },
                            icon: const Icon(Icons.notifications_none_rounded),
                          ),
                          if (_pendingCount > 0)
                            Positioned(
                              right: 6,
                              top: 4,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: DrunaColors.coral,
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '$_pendingCount',
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      IconButton(
                        tooltip: 'Настройки',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              session: widget.session,
                              repository: widget.repository,
                              config: widget.config,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: _events == null && _error == null
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : _error != null && _events == null
                        ? StatePanel(
                            title: 'Не удалось загрузить расписание',
                            message: _error!,
                            onRetry: _load,
                          )
                        : event == null
                        ? _EmptyHero(onCreate: _create)
                        : _EventHero(
                            key: ValueKey(event.id),
                            event: event,
                            onTap: () => _openEvent(event),
                          ),
                  ),
                ),
              ],
            ),
          ),
          DraggableScrollableSheet(
            initialChildSize: .29,
            minChildSize: .19,
            maxChildSize: .78,
            snap: true,
            snapSizes: const [.29, .78],
            builder: (context, controller) => DecoratedBox(
              decoration: BoxDecoration(
                color: DrunaColors.background.withValues(alpha: .97),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(36),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 50,
                    offset: Offset(0, -12),
                  ),
                ],
              ),
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 60),
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF85858A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'БЛИЖАЙШИЕ',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Твои события',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (_refreshing)
                          const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 116,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: (_events?.length ?? 0) + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 11),
                        itemBuilder: (context, index) {
                          if (index == (_events?.length ?? 0)) {
                            return _CreateTile(onTap: _create);
                          }
                          return _EventTile(
                            event: _events![index],
                            active: index == _active,
                            onTap: () => setState(() => _active = index),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 30),
                    _SectionHeader(
                      title: 'Друзья',
                      count: _friends.length,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                FriendsScreen(repository: widget.repository),
                          ),
                        );
                        _load();
                      },
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 78,
                      child: _friends.isEmpty
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => FriendsScreen(
                                      repository: widget.repository,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.person_add_alt_1_rounded,
                                ),
                                label: const Text('Найти друзей'),
                              ),
                            )
                          : ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _friends.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 15),
                              itemBuilder: (context, index) => SizedBox(
                                width: 54,
                                child: Column(
                                  children: [
                                    DrunaAvatar(
                                      name: _friends[index].name,
                                      index: _friends[index].id,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _friends[index].name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 26),
                    _SectionHeader(
                      title: 'Группы',
                      count: _groups.length,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GroupsScreen(repository: widget.repository),
                          ),
                        );
                        _load();
                      },
                    ),
                    const SizedBox(height: 17),
                    SizedBox(
                      height: 86,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _groups.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(width: 13),
                        itemBuilder: (context, index) {
                          if (index == _groups.length) {
                            return _SmallGroupTile(
                              name: 'Добавить',
                              index: index,
                              add: true,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupsScreen(
                                    repository: widget.repository,
                                  ),
                                ),
                              ),
                            );
                          }
                          final group = _groups[index];
                          return _SmallGroupTile(
                            name: group.name,
                            index: index,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailScreen(
                                    repository: widget.repository,
                                    groupId: group.id,
                                  ),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventBackdrop extends StatelessWidget {
  const _EventBackdrop({required this.seed, this.type});
  final int seed;
  final String? type;

  @override
  Widget build(BuildContext context) {
    final palettes = [
      [DrunaColors.blue, DrunaColors.pink, DrunaColors.coral],
      [DrunaColors.green, DrunaColors.gold, DrunaColors.blue],
      [DrunaColors.accent, DrunaColors.coral, DrunaColors.pink],
    ];
    final palette = palettes[seed.abs() % palettes.length];
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [palette[0], const Color(0xFF160021), palette[1]],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(.55, -.45),
              radius: .72,
              colors: [palette[2].withValues(alpha: .85), Colors.transparent],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black12, Colors.transparent, Colors.black54],
            ),
          ),
        ),
      ],
    );
  }
}

class _EventHero extends StatelessWidget {
  const _EventHero({required this.event, required this.onTap, super.key});
  final DrunaEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date = DateTime(
      event.startTime.year,
      event.startTime.month,
      event.startTime.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final day = date == today
        ? 'СЕГОДНЯ'
        : date == today.add(const Duration(days: 1))
        ? 'ЗАВТРА'
        : DateFormat('EEEE', 'ru_RU').format(event.startTime).toUpperCase();
    return Semantics(
      button: true,
      label: 'Открыть событие ${event.title}',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(30, 48, 30, 190),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: math.min(MediaQuery.sizeOf(context).width - 40, 310),
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 210,
                      height: 210,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                    ),
                    Container(
                      width: 155,
                      height: 155,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white12),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day,
                            style: const TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            event.title,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 31,
                              height: 1.02,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${DateFormat('HH:mm').format(event.startTime)}—${DateFormat('HH:mm').format(event.endTime)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('d MMMM', 'ru_RU').format(event.startTime),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 70, 36, 200),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BrandMark(size: 66),
        const SizedBox(height: 28),
        Text(
          'Время для новой встречи',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 10),
        const Text(
          'Создай первое событие — оно появится здесь',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: 210,
          child: DrunaButton(label: 'Создать', onPressed: onCreate),
        ),
      ],
    ),
  );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.active,
    required this.onTap,
  });
  final DrunaEvent event;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = personPalette[event.id.abs() % personPalette.length];
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 132,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color, const Color(0xFF24102F)],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active ? Colors.white : Colors.white12,
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('d MMM', 'ru_RU').format(event.startTime),
              style: const TextStyle(fontSize: 9, color: Colors.white70),
            ),
            const Spacer(),
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                height: 1.05,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              DateFormat('HH:mm').format(event.startTime),
              style: const TextStyle(fontSize: 9, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTile extends StatelessWidget {
  const _CreateTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      width: 132,
      decoration: BoxDecoration(
        color: DrunaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: DrunaColors.line),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_rounded, size: 28),
          SizedBox(height: 9),
          Text('Создать', style: TextStyle(fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text(
            'Новое событие',
            style: TextStyle(fontSize: 9, color: DrunaColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    required this.onTap,
  });
  final String title;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(width: 8),
        Text('$count', style: const TextStyle(color: DrunaColors.muted)),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: DrunaColors.muted),
      ],
    ),
  );
}

class _SmallGroupTile extends StatelessWidget {
  const _SmallGroupTile({
    required this.name,
    required this.index,
    required this.onTap,
    this.add = false,
  });
  final String name;
  final int index;
  final VoidCallback onTap;
  final bool add;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 66,
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: add ? DrunaColors.surfaceRaised : null,
              gradient: add
                  ? null
                  : LinearGradient(
                      colors: [
                        personPalette[index % personPalette.length],
                        personPalette[(index + 2) % personPalette.length],
                      ],
                    ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white24),
            ),
            alignment: Alignment.center,
            child: Text(
              add ? '+' : (name.isEmpty ? '?' : name[0].toUpperCase()),
              style: TextStyle(
                fontSize: add ? 22 : 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9, color: Color(0xFFB6B6BC)),
          ),
        ],
      ),
    ),
  );
}
