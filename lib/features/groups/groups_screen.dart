import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/features/events/event_editor_screen.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({required this.repository, super.key});
  final DrunaRepository repository;

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<GroupSummary>? _groups;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final groups = await widget.repository.listGroups();
      if (mounted) setState(() => _groups = groups);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _create() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Новая группа'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Название'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty) return;
    try {
      final id = await widget.repository.createGroup(name);
      await _load();
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                GroupDetailScreen(repository: widget.repository, groupId: id),
          ),
        );
        await _load();
      }
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Группы'),
      actions: [
        IconButton(
          tooltip: 'Создать группу',
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: _load,
      child: _error != null
          ? ListView(
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * .18),
                StatePanel(
                  title: 'Группы не загрузились',
                  message: _error!,
                  onRetry: _load,
                ),
              ],
            )
          : _groups == null
          ? ListView(
              children: const [
                SizedBox(height: 180),
                Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            )
          : _groups!.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 100),
                StatePanel(
                  title: 'Собери свою первую группу',
                  message: 'Добавляй друзей и создавай общие встречи.',
                  icon: Icons.group_work_outlined,
                  onRetry: _create,
                ),
              ],
            )
          : GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.12,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _groups!.length,
              itemBuilder: (context, index) => _GroupTile(
                group: _groups![index],
                index: index,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => GroupDetailScreen(
                        repository: widget.repository,
                        groupId: _groups![index].id,
                      ),
                    ),
                  );
                  _load();
                },
              ),
            ),
    ),
  );
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.group,
    required this.index,
    required this.onTap,
  });
  final GroupSummary group;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = [
      [DrunaColors.blue, DrunaColors.pink],
      [DrunaColors.gold, DrunaColors.accent],
      [DrunaColors.green, DrunaColors.blue],
    ][index % 3];
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name.isEmpty ? '?' : group.name[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  group.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${group.members.length} участников',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GroupDetailScreen extends StatefulWidget {
  const GroupDetailScreen({
    required this.repository,
    required this.groupId,
    super.key,
  });
  final DrunaRepository repository;
  final int groupId;

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  GroupSummary? _group;
  List<DrunaEvent>? _events;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait([
        widget.repository.getGroup(widget.groupId),
        widget.repository.listEvents(groupId: widget.groupId),
      ]);
      if (!mounted) return;
      setState(() {
        _group = values[0] as GroupSummary;
        _events = values[1] as List<DrunaEvent>;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _addMember() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить друга'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(labelText: 'Ник друга'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (username == null || username.isEmpty) return;
    try {
      await widget.repository.addGroupMember(widget.groupId, username);
      await _load();
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _freeTime() async {
    final date = await pickDate(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    try {
      final slots = await widget.repository.freeTime(
        date,
        groupId: widget.groupId,
      );
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
                'Общие окна',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                DateFormat('d MMMM', 'ru_RU').format(date),
                style: const TextStyle(color: DrunaColors.muted),
              ),
              const SizedBox(height: 18),
              if (slots.isEmpty)
                const Text('В этот день общего свободного времени нет')
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

  Future<void> _confirmTime() async {
    final date = await pickDate(
      context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await pickTime(context, initialTime: TimeOfDay.now());
    if (time == null) return;
    final value = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    try {
      await widget.repository.confirmGroupTime(widget.groupId, value);
      if (mounted) showMessage(context, 'Время подтверждено');
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  Future<void> _groupAction(String action) async {
    final deleting = action == 'delete';
    final confirmed = await confirmAction(
      context,
      title: deleting ? 'Удалить группу?' : 'Выйти из группы?',
      message: deleting
          ? 'Группа и её события будут удалены для всех участников.'
          : 'Вернуться можно будет только по новому приглашению.',
      confirmLabel: deleting ? 'Удалить' : 'Выйти',
      destructive: true,
    );
    if (!confirmed) return;
    try {
      if (deleting) {
        await widget.repository.deleteGroup(widget.groupId);
      } else {
        await widget.repository.leaveGroup(widget.groupId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_group?.name ?? 'Группа'),
      actions: [
        IconButton(
          tooltip: 'Добавить участника',
          onPressed: _group == null ? null : _addMember,
          icon: const Icon(Icons.person_add_alt_1_rounded),
        ),
        AdaptivePopupMenuButton.icon<String>(
          icon: PlatformInfo.isIOS26OrHigher()
              ? 'ellipsis.circle'
              : Icons.more_vert_rounded,
          items: const [
            AdaptivePopupMenuItem(
              label: 'Выйти из группы',
              value: 'leave',
              isDestructive: true,
            ),
            AdaptivePopupMenuItem(
              label: 'Удалить группу',
              value: 'delete',
              isDestructive: true,
            ),
          ],
          onSelected: (_, item) => _groupAction(item.value!),
          buttonStyle: PopupButtonStyle.plain,
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      tooltip: 'Создать событие группы',
      onPressed: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => EventEditorScreen(
              repository: widget.repository,
              groupId: widget.groupId,
            ),
          ),
        );
        if (changed == true) _load();
      },
      child: const Icon(Icons.add_rounded),
    ),
    body: _error != null
        ? StatePanel(
            title: 'Не удалось открыть группу',
            message: _error!,
            onRetry: _load,
          )
        : _group == null
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
        : RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
              children: [
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _group!.members.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      if (index == _group!.members.length) {
                        return GestureDetector(
                          onTap: _addMember,
                          child: const Column(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: DrunaColors.surfaceRaised,
                                child: Icon(Icons.add_rounded),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Добавить',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: DrunaColors.muted,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      final member = _group!.members[index];
                      return Column(
                        children: [
                          DrunaAvatar(name: member.name, index: member.id),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 54,
                            child: Text(
                              member.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
                DrunaButton(
                  label: 'Найти общее время',
                  icon: Icons.schedule_rounded,
                  onPressed: _freeTime,
                ),
                const SizedBox(height: 10),
                DrunaButton(
                  label: 'Подтвердить время',
                  secondary: true,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _confirmTime,
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Text(
                      'События группы',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    Text(
                      '${_events?.length ?? 0}',
                      style: const TextStyle(color: DrunaColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_events == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_events!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 28),
                    child: Text(
                      'Пока нет общих событий',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DrunaColors.muted),
                    ),
                  )
                else
                  ..._events!.map(
                    (event) => Card(
                      color: DrunaColors.surface,
                      child: ListTile(
                        onTap: () async {
                          final changed = await openEventDetails(
                            context,
                            widget.repository,
                            event,
                            groupId: widget.groupId,
                          );
                          if (changed == true) _load();
                        },
                        title: Text(event.title),
                        subtitle: Text(
                          DateFormat(
                            'd MMMM · HH:mm',
                            'ru_RU',
                          ).format(event.startTime),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    ),
                  ),
              ],
            ),
          ),
  );
}
