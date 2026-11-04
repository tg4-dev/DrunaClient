import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/features/settings/avatar_tuning_page.dart';
import 'package:druna_app/features/invites/invites_section.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/shared/ui/action_pill.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:druna_app/shared/ui/setting_rows.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The page right of the month: the user's profile on top (name, the
/// invites, their colour), then the server the build talks to and switches
/// that make testing easier (design-system §9.3).
class SettingsPage extends StatelessWidget {
  const SettingsPage({
    required this.session,
    required this.settings,
    required this.config,
    required this.onResetDemo,
    required this.onResetFriends,
    this.invites,
    this.onOpenInvite,
    this.onResetInvites,
    this.calendarSync,
    super.key,
  });

  /// For the calendar step of the onboarding rehearsal.
  final CalendarSync? calendarSync;

  /// The user's invites for the «События» block; none without it.
  final InvitesStore? invites;
  final ValueChanged<String>? onOpenInvite;

  /// Puts the demo invites back as they were at launch.
  final VoidCallback? onResetInvites;

  final SessionController session;
  final AppSettings settings;
  final AppConfig config;

  /// Puts the demo friends back as they were at launch.
  final VoidCallback onResetDemo;

  /// Forgets which friends are picked in the friend bar and how often.
  final VoidCallback onResetFriends;

  @override
  Widget build(BuildContext context) => _page();

  Widget _page() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([session, settings]),
          builder: (context, _) {
            final own = ownColorFor(settings, session.profile);
            final invites = this.invites;
            return ListView(
              physics: const BouncingScrollPhysics(),
              // No side margins: the invite shelves run to the screen edges;
              // everything else is inset by [PageStyle.gutter].
              padding: const EdgeInsets.only(top: 8, bottom: 40),
              children: [
                _inset(
                  _ProfileHeader(
                    session: session,
                    settings: settings,
                    own: own,
                  ),
                ),
                const SizedBox(height: 28),
                if (invites != null) ...[
                  InvitesSection(
                    store: invites,
                    me: meAsPerson(session.profile),
                    own: own,
                    onOpen: (id) => onOpenInvite?.call(id),
                  ),
                  const SizedBox(height: 20),
                ],
                _inset(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DeveloperSection(
                        children: [
                          _ServerSection(session: session, config: config),
                          if (settings.allowDemo) ...[
                            const SizedBox(height: 12),
                            BlockSection(
                              icon: CupertinoIcons.lab_flask_solid,
                              title: 'Демо-данные',
                              children: [
                                SettingRow(
                                  title: 'Пройти онбординг',
                                  subtitle:
                                      'Регистрация без сервера, аккаунт не '
                                      'создаётся; demo@druna.app — вход',
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
                                      'Любая почта ведёт ко входу; пароль '
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
                                  title: 'Демо-друзья',
                                  subtitle: '12 друзей и заявка, без сервера',
                                  value: settings.demoFriends,
                                  onChanged: (value) =>
                                      settings.demoFriends = value,
                                ),
                                SettingSwitchRow(
                                  title: 'Нет сети',
                                  subtitle:
                                      'Демо отвечает ошибкой: проверить экраны ошибок',
                                  value: settings.demoOffline,
                                  onChanged: settings.demoFriends
                                      ? (value) => settings.demoOffline = value
                                      : null,
                                ),
                                SettingSwitchRow(
                                  title: 'Демо-расписания друзей',
                                  subtitle:
                                      'Занятость выбранных друзей в календаре',
                                  value: settings.demoSchedules,
                                  onChanged: (value) =>
                                      settings.demoSchedules = value,
                                ),
                                SettingRow(
                                  title: 'Сбросить выбор друзей',
                                  subtitle:
                                      'Кто выбран в нижней панели и как часто',
                                  onTap: () {
                                    onResetFriends();
                                    _toast(context, 'Выбор друзей сброшен');
                                  },
                                ),
                                SettingRow(
                                  title: 'Сбросить демо-друзей',
                                  onTap: settings.demoFriends
                                      ? () {
                                          onResetDemo();
                                          _toast(
                                            context,
                                            'Демо-друзья сброшены',
                                          );
                                        }
                                      : null,
                                ),
                                SettingRow(
                                  title: 'Сбросить демо-приглашения',
                                  subtitle:
                                      'Приглашения работают с демо-друзьями',
                                  onTap:
                                      settings.demoFriends &&
                                          onResetInvites != null
                                      ? () {
                                          onResetInvites!();
                                          _toast(
                                            context,
                                            'Демо-приглашения сброшены',
                                          );
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
                              SettingSwitchRow(
                                title:
                                    'Замедлить в '
                                    '${AppSettings.slowMotionFactor.round()} раз',
                                subtitle: 'Чтобы разглядеть переходы',
                                value: settings.slowMotion,
                                onChanged: (value) =>
                                    settings.slowMotion = value,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _LogoutBlock(session: session),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Widget _inset(Widget child) => Padding(
  padding: const EdgeInsets.symmetric(horizontal: PageStyle.gutter),
  child: child,
);

void _toast(BuildContext context, String message) {
  showToast(context, message);
}

String _errorText(Object error) =>
    error is ApiException ? error.message : 'Не получилось';

/// The user on top of the page (design-system §9.3, §9.11): the avatar as
/// it is, the name in a field of the app's own style, the username and the
/// email, then the same pickers of font and colour as in the onboarding.
///
/// The font and the colour are a draft until ✓: the avatar shows them at
/// once, the rest of the app (the events, the calendar «Druna» on the
/// device) only after. ✕ drops the draft.
class _ProfileHeader extends StatefulWidget {
  const _ProfileHeader({
    required this.session,
    required this.settings,
    required this.own,
  });

  final SessionController session;
  final AppSettings settings;
  final Color own;

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  static const _avatar = 120.0;
  static const _ring = 3.0;
  static const _ringGap = 4.0;

  /// Picked but not saved; null — as saved.
  int? _slot;
  AvatarFont? _font;

  AppSettings get settings => widget.settings;
  SessionController get session => widget.session;

  int get _savedSlot =>
      settings.ownColorSlot ??
      avatarPalette.indexOf(widget.own).clamp(0, avatarPalette.length - 1);

  bool get _changed =>
      (_slot != null && _slot != _savedSlot) ||
      (_font != null && _font!.id != ownFontFor(settings).id);

  void _save() {
    final slot = _slot;
    final font = _font;
    if (slot != null && slot != _savedSlot) settings.ownColorSlot = slot;
    if (font != null) settings.ownFontId = font.id;
    setState(() {
      _slot = null;
      _font = null;
    });
    showToast(context, 'Профиль сохранён');
  }

  void _cancel() => setState(() {
    _slot = null;
    _font = null;
  });

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final font = _font ?? ownFontFor(settings);
    final slot = _slot;
    final own = slot == null ? widget.own : avatarPalette[slot];
    final name = profile == null
        ? ''
        : (typed.isNotEmpty
              ? typed
              : (profile.name.isEmpty ? profile.username : profile.name));
    const outer = _avatar + (_ring + _ringGap) * 2;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: Color.lerp(own, Colors.white, 0.55)),
            duration: ProfilePickerStyle.recolor,
            builder: (context, ring, child) => Container(
              width: outer,
              height: outer,
              padding: const EdgeInsets.all(_ringGap),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring ?? own, width: _ring),
              ),
              child: child,
            ),
            child: AvatarPreview(
              color: own,
              font: font,
              name: name.isEmpty ? '?' : name,
              size: _avatar,
            ),
          ),
          const SizedBox(height: 18),
          if (profile == null)
            SettingRow(
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
          else ...[
            PillField(
              fieldKey: const ValueKey('profile-name-field'),
              controller: _name,
              focusNode: _nameFocus,
              hint: 'ИМЯ',
              width: null,
              style: PillFieldStyle.name,
              hintStyle: PillFieldStyle.nameHint,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
              textInputAction: TextInputAction.done,
              keepFocus: false,
            ),
            const SizedBox(height: 8),
            Text(
              '@${profile.username}',
              style: SheetStyle.value.copyWith(fontSize: 15),
            ),
            if (profile.email.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(profile.email, style: SettingRowStyle.subtitle),
            ],
          ],
          const SizedBox(height: 20),
          FontPicker(
            name: name.isEmpty ? '?' : name,
            selected: font,
            onPick: (font) => setState(() => _font = font),
          ),
          const SizedBox(height: 14),
          ColorPicker(
            selected: slot ?? _savedSlot,
            onPick: (slot) => setState(() => _slot = slot),
          ),
          Reveal(
            open: _changed,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ActionPill(
                    key: const ValueKey('profile-cancel'),
                    icon: CupertinoIcons.xmark,
                    label: 'Отменить',
                    kind: ActionPillKind.cancel,
                    onPressed: _cancel,
                  ),
                  const SizedBox(width: 8),
                  ActionPill(
                    key: const ValueKey('profile-save'),
                    icon: CupertinoIcons.checkmark_alt,
                    label: 'Сохранить профиль',
                    filled: true,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        SettingRow(
          title: 'Сборка',
          value: '${widget.config.environment} · ${_buildMode()}',
        ),
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

/// The server, the demo and the slow motion: closed until asked for, so the
/// page is the user's profile first.
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
