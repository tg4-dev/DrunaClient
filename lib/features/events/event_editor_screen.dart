import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EventEditorScreen extends StatefulWidget {
  const EventEditorScreen({
    required this.repository,
    this.event,
    this.groupId,
    super.key,
  });
  final DrunaRepository repository;
  final DrunaEvent? event;
  final int? groupId;

  @override
  State<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends State<EventEditorScreen> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late DateTime _start;
  late DateTime _end;
  late String _type;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _title = TextEditingController(text: event?.title ?? '');
    final now = DateTime.now();
    _start = event?.startTime ?? DateTime(now.year, now.month, now.day + 1, 19);
    _end = event?.endTime ?? _start.add(const Duration(hours: 2));
    _type = event?.type ?? (widget.groupId == null ? 'personal' : 'meeting');
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await pickDate(
      context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (date == null) return;
    setState(() {
      final duration = _end.difference(_start);
      _start = DateTime(
        date.year,
        date.month,
        date.day,
        _start.hour,
        _start.minute,
      );
      _end = _start.add(duration);
    });
  }

  Future<void> _pickTime({required bool end}) async {
    final current = end ? _end : _start;
    final time = await pickTime(
      context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null) return;
    setState(() {
      final next = DateTime(
        current.year,
        current.month,
        current.day,
        time.hour,
        time.minute,
      );
      if (end) {
        _end = next.isAfter(_start) ? next : next.add(const Duration(days: 1));
      } else {
        final duration = _end.difference(_start);
        _start = next;
        _end = next.add(
          duration.isNegative ? const Duration(hours: 1) : duration,
        );
      }
    });
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      showMessage(context, 'Окончание должно быть позже начала', error: true);
      return;
    }
    setState(() => _loading = true);
    final event = DrunaEvent(
      id: widget.event?.id ?? 0,
      userId: widget.event?.userId,
      groupId: widget.groupId,
      title: _title.text.trim(),
      startTime: _start,
      endTime: _end,
      type: _type,
    );
    try {
      if (widget.event == null) {
        await widget.repository.createEvent(event, groupId: widget.groupId);
      } else {
        await widget.repository.updateEvent(event, groupId: widget.groupId);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('d MMMM', 'ru_RU').format(_start);
    final time = DateFormat('HH:mm').format(_start);
    final endTime = DateFormat('HH:mm').format(_end);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event == null ? 'Новая встреча' : 'Редактировать'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _key,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              Text(
                'Что планируем?',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Основные детали можно изменить позже',
                style: TextStyle(color: DrunaColors.muted),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Название',
                  hintText: 'Например, боулинг',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Добавь название'
                    : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SettingTile(
                      label: 'Дата',
                      value: date,
                      onTap: _pickDate,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SettingTile(
                      label: 'Начало',
                      value: time,
                      onTap: () => _pickTime(end: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _SettingTile(
                label: 'Окончание',
                value: endTime,
                onTap: () => _pickTime(end: true),
              ),
              const SizedBox(height: 24),
              const Text(
                'Тип',
                style: TextStyle(color: DrunaColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['personal', 'work', 'meeting', 'sport']
                    .map(
                      (type) => ChoiceChip(
                        label: Text(
                          {
                            'personal': 'Личное',
                            'work': 'Работа',
                            'meeting': 'Встреча',
                            'sport': 'Спорт',
                          }[type]!,
                        ),
                        selected: _type == type,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 36),
              DrunaButton(
                label: widget.event == null ? 'Создать встречу' : 'Сохранить',
                onPressed: _save,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: DrunaColors.surfaceRaised,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 5),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

Future<bool?> openEventDetails(
  BuildContext context,
  DrunaRepository repository,
  DrunaEvent event, {
  int? groupId,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: DrunaColors.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  ),
  builder: (sheetContext) => Padding(
    padding: const EdgeInsets.fromLTRB(24, 14, 24, 30),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(
              color: DrunaColors.muted,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(event.title, style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          '${DateFormat('EEEE, d MMMM', 'ru_RU').format(event.startTime)} · ${DateFormat('HH:mm').format(event.startTime)}—${DateFormat('HH:mm').format(event.endTime)}',
          style: const TextStyle(color: DrunaColors.muted),
        ),
        const SizedBox(height: 28),
        DrunaButton(
          label: 'Редактировать',
          onPressed: () async {
            final changed = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => EventEditorScreen(
                  repository: repository,
                  event: event,
                  groupId: groupId,
                ),
              ),
            );
            if (changed == true && sheetContext.mounted) {
              Navigator.of(sheetContext).pop(true);
            }
          },
        ),
        const SizedBox(height: 10),
        DrunaButton(
          label: 'Удалить',
          secondary: true,
          onPressed: () async {
            final confirmed = await confirmAction(
              sheetContext,
              title: 'Удалить встречу?',
              message: 'Это действие нельзя отменить.',
              confirmLabel: 'Удалить',
              destructive: true,
            );
            if (!confirmed) return;
            try {
              await repository.deleteEvent(event.id, groupId: groupId);
              if (sheetContext.mounted) Navigator.of(sheetContext).pop(true);
            } catch (error) {
              if (sheetContext.mounted) {
                showMessage(sheetContext, error.toString(), error: true);
              }
            }
          },
        ),
      ],
    ),
  ),
);
