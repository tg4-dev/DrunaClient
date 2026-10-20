import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Настройки": the page right of the month. The account, the server the
/// build talks to, and switches that make testing easier.
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.session,
    required this.settings,
    required this.config,
    required this.onResetDemo,
    required this.onResetFriends,
    super.key,
  });

  final SessionController session;
  final AppSettings settings;
  final AppConfig config;

  /// Puts the demo friends back as they were at launch.
  final VoidCallback onResetDemo;

  /// Forgets which friends are picked in the friend bar and how often.
  final VoidCallback onResetFriends;

  @override
  Widget build(BuildContext context) {
    // Its own messenger: the other pages of the plane are mounted too.
    return ScaffoldMessenger(child: _page());
  }

  Widget _page() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([session, settings]),
          builder: (context, _) => ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              PageStyle.gutter,
              8,
              PageStyle.gutter,
              40,
            ),
            children: [
              const SizedBox(
                height: 50,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Настройки', style: PageStyle.title),
                ),
              ),
              const SizedBox(height: 16),
              _AccountSection(session: session, settings: settings),
              const SizedBox(height: 12),
              _ServerSection(session: session, config: config),
              if (settings.allowDemo) ...[
                const SizedBox(height: 12),
                BlockSection(
                  icon: CupertinoIcons.lab_flask_solid,
                  title: 'Демо-данные',
                  children: [
                    _SwitchRow(
                      title: 'Демо-друзья',
                      subtitle: '12 друзей и заявка, без сервера',
                      value: settings.demoFriends,
                      onChanged: (value) => settings.demoFriends = value,
                    ),
                    _SwitchRow(
                      title: 'Нет сети',
                      subtitle:
                          'Демо отвечает ошибкой: проверить экраны ошибок',
                      value: settings.demoOffline,
                      onChanged: settings.demoFriends
                          ? (value) => settings.demoOffline = value
                          : null,
                    ),
                    _SwitchRow(
                      title: 'Демо-расписания друзей',
                      subtitle: 'Занятость выбранных друзей в календаре',
                      value: settings.demoSchedules,
                      onChanged: (value) => settings.demoSchedules = value,
                    ),
                    _ActionRow(
                      title: 'Сбросить выбор друзей',
                      subtitle: 'Кто выбран в нижней панели и как часто',
                      onTap: () {
                        onResetFriends();
                        _toast(context, 'Выбор друзей сброшен');
                      },
                    ),
                    _ActionRow(
                      title: 'Сбросить демо-друзей',
                      onTap: settings.demoFriends
                          ? () {
                              onResetDemo();
                              _toast(context, 'Демо-друзья сброшены');
                            }
                          : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              BlockSection(
                icon: CupertinoIcons.wand_stars,
                title: 'Анимации',
                children: [
                  _SwitchRow(
                    title:
                        'Замедлить в '
                        '${AppSettings.slowMotionFactor.round()} раз',
                    subtitle: 'Чтобы разглядеть переходы',
                    value: settings.slowMotion,
                    onChanged: (value) => settings.slowMotion = value,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

String _errorText(Object error) =>
    error is ApiException ? error.message : 'Не получилось';

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.session, required this.settings});

  final SessionController session;
  final AppSettings settings;

  Future<void> _logout(BuildContext context) async {
    final confirmed = await confirmAction(
      context,
      title: 'Выйти из аккаунта?',
      message: 'Токены будут удалены с этого устройства.',
      confirmLabel: 'Выйти',
      destructive: true,
    );
    if (confirmed) await session.logout();
  }

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final own = ownColorFor(settings, profile);
    return BlockSection(
      icon: CupertinoIcons.person_crop_circle_fill,
      title: 'Аккаунт',
      children: [
        if (profile == null)
          _ActionRow(
            title: 'Профиль не загружен',
            subtitle: 'Нажми, чтобы запросить снова',
            onTap: () async {
              try {
                await session.refreshProfile();
              } catch (error) {
                if (context.mounted) _toast(context, _errorText(error));
              }
            },
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                PersonAvatar(
                  id: profile.id,
                  name: profile.name,
                  username: profile.username,
                  color: own,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.name.isEmpty ? profile.username : profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        [
                          '@${profile.username}',
                          if (profile.email.isNotEmpty) profile.email,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _subtitle,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _ColorPicker(
          selected: settings.ownColorSlot,
          current: own,
          onPick: (slot) => settings.ownColorSlot = slot,
        ),
        _ActionRow(
          title: 'Выйти',
          color: SheetStyle.today,
          onTap: () => _logout(context),
        ),
      ],
    );
  }
}

class _ServerSection extends StatefulWidget {
  const _ServerSection({required this.session, required this.config});

  final SessionController session;
  final AppConfig config;

  @override
  State<_ServerSection> createState() => _ServerSectionState();
}

class _ServerSectionState extends State<_ServerSection> {
  _Check? _ping;
  _Check? _refresh;

  Future<void> _run(
    Future<void> Function() action,
    void Function(_Check) store,
  ) async {
    final watch = Stopwatch()..start();
    setState(() => store(const _Check.running()));
    _Check result;
    try {
      await action();
      result = _Check.ok('OK · ${watch.elapsedMilliseconds} мс');
    } catch (error) {
      result = _Check.failed(_errorText(error));
    }
    if (mounted) setState(() => store(result));
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.session.repository;
    final url = widget.config.apiBaseUrl;
    return BlockSection(
      icon: CupertinoIcons.antenna_radiowaves_left_right,
      title: 'Сервер',
      children: [
        _ActionRow(
          title: 'Адрес',
          value: url,
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            _toast(context, 'Адрес скопирован');
          },
        ),
        _ActionRow(
          title: 'Сборка',
          value: '${widget.config.environment} · ${_buildMode()}',
        ),
        _ActionRow(
          title: 'Проверить соединение',
          subtitle: 'GET /ping/',
          status: _ping,
          onTap: _ping?.running == true
              ? null
              : () => _run(repository.ping, (check) => _ping = check),
        ),
        _ActionRow(
          title: 'Проверить обновление токена',
          subtitle: 'Испортить access token и запросить профиль',
          status: _refresh,
          onTap: _refresh?.running == true
              ? null
              : () => _run(() async {
                  repository.debugExpireAccessToken();
                  await widget.session.refreshProfile();
                }, (check) => _refresh = check),
        ),
      ],
    );
  }
}

String _buildMode() => kReleaseMode
    ? 'release'
    : kProfileMode
    ? 'profile'
    : 'debug';

class _Check {
  const _Check.running() : running = true, ok = false, text = '';
  const _Check.ok(this.text) : running = false, ok = true;
  const _Check.failed(this.text) : running = false, ok = false;

  final bool running;
  final bool ok;
  final String text;
}

const _title = TextStyle(color: Colors.white, fontSize: 17);
const _subtitle = TextStyle(color: SheetStyle.muted, fontSize: 13);

/// A row at least 44 pt tall: title, optional subtitle, and on the right a
/// value or the result of a check.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.title,
    this.subtitle,
    this.value,
    this.status,
    this.color = Colors.white,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final _Check? status;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final check = status;
    final enabled = onTap != null || value != null || check != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: SheetStyle.fade,
        opacity: enabled ? 1 : 0.4,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _title.copyWith(color: color)),
                      if (subtitle != null) Text(subtitle!, style: _subtitle),
                    ],
                  ),
                ),
                if (value != null)
                  Flexible(
                    child: Text(
                      value!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: SheetStyle.value,
                    ),
                  ),
                if (check != null)
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: SheetStyle.fade,
                      child: check.running
                          ? const CupertinoActivityIndicator()
                          : Text(
                              check.text,
                              key: ValueKey(check.text),
                              maxLines: 2,
                              textAlign: TextAlign.end,
                              style: SheetStyle.value.copyWith(
                                color: check.ok
                                    ? const Color(0xFF34C759)
                                    : SheetStyle.today,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: SheetStyle.fade,
      opacity: onChanged == null ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: _title),
                  Text(subtitle, style: _subtitle),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IgnorePointer(
              ignoring: onChanged == null,
              child: AdaptiveSwitch(
                value: value,
                onChanged: (next) => onChanged?.call(next),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The user's colour: the sixteen of the palette in two rows, the current
/// one ringed like a picked friend. Repaints the calendar at once.
class _ColorPicker extends StatelessWidget {
  const _ColorPicker({
    required this.selected,
    required this.current,
    required this.onPick,
  });

  /// The picked slot; null while the colour follows the avatar.
  final int? selected;
  final Color current;
  final ValueChanged<int?> onPick;

  static const _dot = 32.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Мой цвет', style: _title),
          const Text('Им рисуются мои события и аватар', style: _subtitle),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final cell = constraints.maxWidth / 8;
              return Wrap(
                children: [
                  for (var slot = 0; slot < avatarPalette.length; slot++)
                    SizedBox(
                      width: cell,
                      height: cell.clamp(44.0, 56.0),
                      child: Semantics(
                        button: true,
                        selected: avatarPalette[slot] == current,
                        label: 'Цвет ${slot + 1}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: ValueKey('own-color-$slot'),
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onPick(slot);
                          },
                          child: Center(child: _swatch(avatarPalette[slot])),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          // Dimmed by the row itself while the colour already follows it.
          _ActionRow(
            title: 'Как у аватара',
            subtitle: 'Цвет, который даёт мой аккаунт',
            onTap: selected == null ? null : () => onPick(null),
          ),
        ],
      ),
    );
  }

  Widget _swatch(Color color) {
    final picked = color == current;
    return AnimatedContainer(
      duration: SheetStyle.fade,
      width: _dot + 8,
      height: _dot + 8,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: picked
              ? Color.lerp(color, Colors.white, 0.55)!
              : Colors.transparent,
          width: 3,
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
