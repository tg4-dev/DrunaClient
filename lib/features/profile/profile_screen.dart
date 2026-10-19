import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    required this.session,
    required this.repository,
    required this.config,
    super.key,
  });
  final SessionController session;
  final DrunaRepository repository;
  final AppConfig config;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _avatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.session.profile?.name ?? '');
    _avatar = TextEditingController(
      text: widget.session.profile?.avatarUrl ?? '',
    );
    if (widget.session.profile == null) _load();
  }

  Future<void> _load() async {
    try {
      await widget.session.refreshProfile();
      _name.text = widget.session.profile?.name ?? '';
      _avatar.text = widget.session.profile?.avatarUrl ?? '';
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showMessage(context, 'Имя не может быть пустым', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.repository.updateProfile(
        name: _name.text.trim(),
        avatarUrl: _avatar.text.trim(),
      );
      await widget.session.refreshProfile();
      if (mounted) showMessage(context, 'Профиль обновлён');
    } catch (error) {
      if (mounted) showMessage(context, error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.session.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 34),
        children: [
          Center(
            child: DrunaAvatar(
              name: profile?.name ?? '?',
              index: profile?.id ?? 0,
              size: 86,
              selected: true,
              imageUrl: profile?.avatarUrl,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            profile == null ? 'Профиль' : '@${profile.username}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (profile?.email.isNotEmpty ?? false)
            Text(
              profile!.email,
              textAlign: TextAlign.center,
              style: const TextStyle(color: DrunaColors.muted),
            ),
          const SizedBox(height: 30),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Имя'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _avatar,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Ссылка на аватар',
              hintText: 'https://…',
            ),
          ),
          const SizedBox(height: 14),
          DrunaButton(label: 'Сохранить', onPressed: _save, loading: _saving),
          const SizedBox(height: 30),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: DrunaColors.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.lock_outline_rounded),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Приватность по умолчанию',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Друзья видят только свободные окна, а не содержимое событий',
                        style: TextStyle(
                          color: DrunaColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('Внешние календари'),
            subtitle: const Text('Интеграция ожидает backend endpoint'),
            trailing: const Icon(Icons.info_outline_rounded),
            onTap: () => showMessage(
              context,
              'Backend пока не предоставляет подключение Apple, Google или Outlook Calendar',
            ),
          ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Сервер'),
            subtitle: Text(
              '${widget.config.environment} · ${widget.config.apiBaseUrl}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 18),
          DrunaButton(
            label: 'Выйти',
            secondary: true,
            onPressed: () async {
              final confirmed = await confirmAction(
                context,
                title: 'Выйти из аккаунта?',
                message:
                    'Токены и приватные данные этой сессии будут удалены с устройства.',
                confirmLabel: 'Выйти',
              );
              if (confirmed) {
                if (!context.mounted) return;
                Navigator.of(context).pop();
                await widget.session.logout();
              }
            },
          ),
        ],
      ),
    );
  }
}
