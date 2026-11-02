import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/features/settings/avatar_tuning_page.dart';
import 'package:druna_app/features/invites/invites_section.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
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
    super.key,
  });

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
                      _ServerSection(session: session, config: config),
                      if (settings.allowDemo) ...[
                        const SizedBox(height: 12),
                        BlockSection(
                          icon: CupertinoIcons.lab_flask_solid,
                          title: 'Демо-данные',
                          children: [
                            _ActionRow(
                              title: 'Пройти онбординг',
                              subtitle:
                                  'Регистрация без сервера, аккаунт не '
                                  'создаётся; demo@druna.app — вход',
                              onTap: () => showOnboardingRehearsal(context),
                            ),
                            _ActionRow(
                              title: 'Пройти вход',
                              subtitle:
                                  'Любая почта ведёт ко входу; пароль '
                                  'wrongpass — ошибка',
                              onTap: () => showOnboardingRehearsal(
                                context,
                                signIn: true,
                              ),
                            ),
                            _ActionRow(
                              title: 'Подгонка аватаров',
                              subtitle:
                                  'Для разработчика: шрифты буквы, '
                                  'docs/avatar.md',
                              onTap: () => showAvatarTuning(context),
                            ),
                            _SwitchRow(
                              title: 'Демо-друзья',
                              subtitle: '12 друзей и заявка, без сервера',
                              value: settings.demoFriends,
                              onChanged: (value) =>
                                  settings.demoFriends = value,
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
                              subtitle:
                                  'Занятость выбранных друзей в календаре',
                              value: settings.demoSchedules,
                              onChanged: (value) =>
                                  settings.demoSchedules = value,
                            ),
                            _ActionRow(
                              title: 'Сбросить выбор друзей',
                              subtitle:
                                  'Кто выбран в нижней панели и как часто',
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
                            _ActionRow(
                              title: 'Сбросить демо-приглашения',
                              subtitle: 'Приглашения работают с демо-друзьями',
                              onTap:
                                  settings.demoFriends && onResetInvites != null
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
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.session,
    required this.settings,
    required this.own,
  });

  final SessionController session;
  final AppSettings settings;
  final Color own;

  static const _avatar = 120.0;
  static const _ring = 3.0;
  static const _ringGap = 4.0;

  @override
  Widget build(BuildContext context) {
    final profile = session.profile;
    final font = ownFontFor(settings);
    final name = profile == null
        ? ''
        : (profile.name.isEmpty ? profile.username : profile.name);
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
          else ...[
            _NameField(
              key: ValueKey('profile-name-${profile.id}'),
              session: session,
              name: profile.name,
            ),
            const SizedBox(height: 8),
            Text(
              '@${profile.username}',
              style: SheetStyle.value.copyWith(fontSize: 15),
            ),
            if (profile.email.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(profile.email, style: _subtitle),
            ],
          ],
          const SizedBox(height: 20),
          FontPicker(
            name: name.isEmpty ? '?' : name,
            selected: font,
            onPick: (font) => settings.ownFontId = font.id,
          ),
          const SizedBox(height: 14),
          ColorPicker(
            selected:
                settings.ownColorSlot ??
                avatarPalette.indexOf(own).clamp(0, avatarPalette.length - 1),
            onPick: (slot) => settings.ownColorSlot = slot,
          ),
        ],
      ),
    );
  }
}

/// The name in the app's field: bold, drawn in capitals. A change shows ✓
/// at the right; it, or the keyboard's return, saves through the server
/// (`PATCH /users/me`) or, without one, on the device.
class _NameField extends StatefulWidget {
  const _NameField({required this.session, required this.name, super.key});

  final SessionController session;
  final String name;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  late final _name = UpperCaseNameController(text: widget.name);
  final _focus = FocusNode();
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant _NameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Renamed elsewhere (a refresh): show it unless the user is typing.
    if (oldWidget.name != widget.name && !_focus.hasFocus) {
      _name.text = widget.name;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _changed => _name.text.trim() != widget.name.trim();

  /// ✓ or «готово»: saves a change; with none, just ends the editing.
  Future<void> _save() async {
    if (_busy) return;
    if (!_changed) {
      _focus.unfocus();
      return;
    }
    final problem = nameError(_name.text);
    if (problem != null) {
      showToast(context, problem, error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.session.rename(_name.text);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      _focus.unfocus();
      showToast(context, 'Имя сохранено');
    } catch (error) {
      if (mounted) showToast(context, _errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PillField(
    fieldKey: const ValueKey('profile-name-field'),
    controller: _name,
    focusNode: _focus,
    hint: 'ИМЯ',
    width: null,
    style: PillFieldStyle.name,
    hintStyle: PillFieldStyle.nameHint,
    keyboardType: TextInputType.name,
    textCapitalization: TextCapitalization.words,
    autofillHints: const [AutofillHints.givenName],
    textInputAction: TextInputAction.done,
    keepFocus: false,
    onSubmitted: _save,
    trailing: _busy
        ? const CupertinoActivityIndicator(color: Colors.white)
        : _changed || _focus.hasFocus
        ? Semantics(
            button: true,
            label: _changed ? 'Сохранить имя' : 'Готово',
            excludeSemantics: true,
            child: GestureDetector(
              key: const ValueKey('profile-name-save'),
              behavior: HitTestBehavior.opaque,
              onTap: _save,
              child: const SizedBox.square(
                dimension: 44,
                child: Icon(
                  CupertinoIcons.checkmark_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          )
        : null,
  );
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
        child: _ActionRow(
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
