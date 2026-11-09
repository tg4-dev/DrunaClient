import 'package:druna_app/features/profile/event_chip.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/features/settings/avatar_tuning_page.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/floating_sheet.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:druna_app/shared/ui/setting_rows.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    required this.session,
    required this.settings,
    required this.config,
    required this.onResetDemo,
    required this.onResetFriends,
    required this.onClosing,
    required this.onGone,
    this.onResetInvites,
    this.calendarSync,
    super.key,
  });

  final CalendarSync? calendarSync;

  final VoidCallback? onResetInvites;

  final SessionController session;
  final AppSettings settings;
  final AppConfig config;

  final VoidCallback onResetDemo;

  final VoidCallback onResetFriends;

  final VoidCallback onClosing;
  final VoidCallback onGone;

  @override
  Widget build(BuildContext context) => FloatingSheet(
    scrimKey: const ValueKey('settings-scrim'),
    icon: CupertinoIcons.gear,
    title: 'Настройки',
    onClosing: onClosing,
    onGone: onGone,
    child: ListenableBuilder(
      listenable: Listenable.merge([session, settings]),
      builder: (context, _) => _options(context),
    ),
  );

  Future<void> _switchDemo(BuildContext context, bool demo) async {
    final ok = await confirmAction(
      context,
      title: demo ? 'Перейти в демо-версию?' : 'Выйти из демо-версии?',
      message: demo
          ? 'Аккаунт и данные будут только на этом устройстве, сервер не '
                'используется. Ты выйдешь из аккаунта.'
          : 'Приложение подключится к серверу. Ты выйдешь из демо-аккаунта.',
      confirmLabel: demo ? 'Перейти' : 'Выйти',
    );
    if (ok) settings.demo = demo;
  }

  Widget _options(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DeveloperSection(
              children: [
                _ServerSection(session: session, config: config),
                const SizedBox(height: 12),
                BlockSection(
                  icon: CupertinoIcons.lab_flask_solid,
                  title: 'Демо-данные',
                  children: [
                    SettingSwitchRow(
                      title: 'Демо-версия',
                      subtitle:
                          'Всё на устройстве, без сервера и '
                          'без календаря iOS',
                      value: settings.demo,
                      onChanged: (value) => _switchDemo(context, value),
                    ),
                    SettingRow(
                      title: 'Пройти онбординг',
                      subtitle:
                          'Регистрация без сервера, аккаунт не '
                          'создаётся; ник demo — вход',
                      onTap: () => showOnboardingRehearsal(
                        context,
                        colorSlot: settings.ownColorSlot,
                        font: ownFontFor(settings),
                        calendarSync: calendarSync,
                      ),
                    ),
                    SettingRow(
                      title: 'Пройти вход',
                      subtitle:
                          'Любой ник ведёт ко входу; пароль '
                          'wrongpass — ошибка',
                      onTap: () => showOnboardingRehearsal(
                        context,
                        signIn: true,
                        colorSlot: settings.ownColorSlot,
                        font: ownFontFor(settings),
                      ),
                    ),
                    SettingRow(
                      title: 'Подгонка аватаров',
                      subtitle:
                          'Для разработчика: шрифты буквы, '
                          'docs/avatar.md',
                      onTap: () => showAvatarTuning(context),
                    ),
                    SettingSwitchRow(
                      title: 'Нет сети',
                      subtitle:
                          'Демо отвечает ошибкой: проверить экраны ошибок',
                      value: settings.demoOffline,
                      onChanged: settings.demo
                          ? (value) => settings.demoOffline = value
                          : null,
                    ),
                    SettingRow(
                      title: 'Сбросить выбор друзей',
                      subtitle: 'Кто выбран в нижней панели и как часто',
                      onTap: () {
                        onResetFriends();
                        _toast(context, 'Выбор друзей сброшен');
                      },
                    ),
                    SettingRow(
                      title: 'Сбросить демо-друзей',
                      onTap: settings.demo
                          ? () {
                              onResetDemo();
                              _toast(context, 'Демо-друзья сброшены');
                            }
                          : null,
                    ),
                    SettingRow(
                      title: 'Сбросить демо-приглашения',
                      subtitle: 'Приглашения работают с демо-друзьями',
                      onTap: settings.demo && onResetInvites != null
                          ? () {
                              onResetInvites!();
                              _toast(context, 'Демо-приглашения сброшены');
                            }
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                BlockSection(
                  icon: CupertinoIcons.wand_stars,
                  title: 'Анимации',
                  children: [
                    SettingSwitchRow(
                      title:
                          'Замедлить в '
                          '${AppSettings.slowMotionFactor.round()} раз',
                      subtitle: 'Чтобы разглядеть переходы',
                      value: settings.slowMotion,
                      onChanged: (value) => settings.slowMotion = value,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _HeavyEffects(),
              ],
            ),
            const SizedBox(height: 12),
            _LogoutBlock(session: session),
          ],
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  showToast(context, message);
}

String _errorText(Object error) =>
    error is ApiException ? error.message : 'Не получилось';

class _LogoutBlock extends StatelessWidget {
  const _LogoutBlock({required this.session});

  final SessionController session;

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
    return DecoratedBox(
      decoration: SheetStyle.blockDecoration,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
        child: SettingRow(
          title: 'Выйти',
          color: SheetStyle.today,
          onTap: () => _logout(context),
        ),
      ),
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
  SettingCheck? _ping;
  SettingCheck? _refresh;

  Future<void> _run(
    Future<void> Function() action,
    void Function(SettingCheck) store,
  ) async {
    final watch = Stopwatch()..start();
    setState(() => store(const SettingCheck.running()));
    SettingCheck result;
    try {
      await action();
      result = SettingCheck.ok('OK · ${watch.elapsedMilliseconds} мс');
    } catch (error) {
      result = SettingCheck.failed(_errorText(error));
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
        SettingRow(
          title: 'Адрес',
          value: url,
          onTap: () {
            Clipboard.setData(ClipboardData(text: url));
            _toast(context, 'Адрес скопирован');
          },
        ),
        SettingRow(title: 'Сборка', value: _buildMode()),
        SettingRow(
          title: 'Проверить соединение',
          subtitle: 'GET /ping/',
          status: _ping,
          onTap: _ping?.running == true
              ? null
              : () => _run(repository.ping, (check) => _ping = check),
        ),
        SettingRow(
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

class _DeveloperSection extends StatefulWidget {
  const _DeveloperSection({required this.children});

  final List<Widget> children;

  @override
  State<_DeveloperSection> createState() => _DeveloperSectionState();
}

class _DeveloperSectionState extends State<_DeveloperSection> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: SheetStyle.blockDecoration,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
            child: Semantics(
              expanded: _open,
              child: SettingRow(
                key: const ValueKey('developer-section'),
                title: 'Для разработчика',
                subtitle: 'Сервер, демо-данные, анимации',
                trailing: AnimatedRotation(
                  turns: _open ? 0.25 : 0,
                  duration: SheetStyle.motion,
                  curve: Curves.easeOutCubic,
                  child: const Icon(
                    CupertinoIcons.chevron_right,
                    size: 14,
                    color: SheetStyle.muted,
                  ),
                ),
                onTap: () => setState(() => _open = !_open),
              ),
            ),
          ),
        ),
        Reveal(
          open: _open,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.children,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeavyEffects extends StatefulWidget {
  const _HeavyEffects();

  @override
  State<_HeavyEffects> createState() => _HeavyEffectsState();
}

class _HeavyEffectsState extends State<_HeavyEffects> {
  void _apply(VoidCallback change) {
    setState(change);
    WidgetsBinding.instance.reassembleApplication();
  }

  @override
  Widget build(BuildContext context) {
    return BlockSection(
      icon: CupertinoIcons.speedometer,
      title: 'Производительность',
      children: [
        SettingSwitchRow(
          title: 'Размытие ленты',
          subtitle: 'Профиль и группы',
          value: EdgeBlur.enabled,
          onChanged: (value) => _apply(() => EdgeBlur.enabled = value),
        ),
        SettingSwitchRow(
          title: 'Живой фон',
          value: EventGradient.enabled,
          onChanged: (value) => _apply(() => EventGradient.enabled = value),
        ),
        SettingSwitchRow(
          title: 'Вращение орбиты',
          value: Orbit.enabled,
          onChanged: (value) => _apply(() => Orbit.enabled = value),
        ),
        SettingSwitchRow(
          title: 'Свечение «Ждёт ответа»',
          value: EventChip.glows,
          onChanged: (value) => _apply(() => EventChip.glows = value),
        ),
      ],
    );
  }
}
