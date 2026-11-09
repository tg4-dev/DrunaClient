import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/features/onboarding/onboarding_rules.dart';
import 'package:druna_app/features/profile/event_feed.dart';
import 'package:druna_app/features/profile/page_bar.dart';
import 'package:druna_app/features/profile/profile_header.dart';
import 'package:druna_app/shared/ui/action_pill.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/onest.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/people_backdrop.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/profile_pickers.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class ProfileStyle {
  static const usernameGap = 4.0;
  static const actionsGap = PageStyle.actionsGap;
  static const actionGap = 8.0;

  static final name = nameStyle(onest(28, letterSpacing: -0.4));
  static final username = onest(15, color: SheetStyle.muted);

  static const link = 'https://druna.tg4.dev/user/';
}

String profileLink(String username) => '${ProfileStyle.link}$username';

double textHeightOf(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    required this.session,
    required this.settings,
    required this.onBack,
    required this.onOpenSettings,
    this.invites,
    this.onOpenInvite,
    this.onBusyChanged,
    this.onFoldChanged,
    this.scene,
    this.sceneIndex = 0,
    this.active = true,
    super.key,
  });

  final SessionController session;
  final AppSettings settings;

  final VoidCallback onBack;
  final VoidCallback onOpenSettings;

  final InvitesStore? invites;
  final ValueChanged<String>? onOpenInvite;

  final ValueChanged<bool>? onBusyChanged;

  final ValueChanged<bool>? onFoldChanged;

  final BackdropScene? scene;
  final int sceneIndex;

  final bool active;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  var _editing = false;
  var _busy = false;
  var _archiveOpen = false;
  var _collapsed = false;

  int? _slot;
  AvatarFont? _font;

  final _name = UpperCaseNameController();
  final _nameFocus = FocusNode();
  String? _savedName;

  final _scroll = ScrollController();
  final _anchor = ValueNotifier<double>(0);

  AppSettings get settings => widget.settings;
  SessionController get session => widget.session;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onName);
    session.addListener(_onSession);
    settings.addListener(_onSession);
    _syncName();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    widget.scene?.forget(this);
    _name.removeListener(_onName);
    session.removeListener(_onSession);
    settings.removeListener(_onSession);
    _name.dispose();
    _nameFocus.dispose();
    _scroll.dispose();
    _anchor.dispose();
    super.dispose();
  }

  void _onName() => setState(() {});

  void _onSession() {
    _syncName();
    setState(() {});
  }

  void _syncName() {
    final saved = session.profile?.name;
    if (saved == null || saved == _savedName) return;
    final drafted =
        _savedName != null && _name.text.trim() != _savedName!.trim();
    _savedName = saved;
    if (!drafted) _name.text = saved;
  }

  int get _savedSlot => settings.ownColorSlot ?? defaultOwnColorSlot;

  bool get _nameChanged =>
      _savedName != null && _name.text.trim() != _savedName!.trim();

  void _reportBusy() {
    widget.onBusyChanged?.call(_editing || _archiveOpen);
    widget.onFoldChanged?.call(_editing);
  }

  Future<void> _startEditing() async {
    if (_scroll.hasClients && _scroll.offset != 0) {
      await _scroll.animateTo(0, duration: Motion.medium, curve: Motion.settle);
    }
    if (!mounted) return;
    setState(() => _editing = true);
    _reportBusy();
  }

  void _stopEditing() {
    if (_scroll.hasClients && _scroll.offset != 0) _scroll.jumpTo(0);
    setState(() => _editing = false);
    _reportBusy();
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_nameChanged) {
      final problem = nameError(_name.text);
      if (problem != null) {
        showToast(context, problem, error: true);
        return;
      }
      setState(() => _busy = true);
      try {
        await session.rename(_name.text);
      } catch (error) {
        if (mounted) {
          setState(() => _busy = false);
          showToast(context, _errorText(error), error: true);
        }
        return;
      }
      if (!mounted) return;
      _savedName = session.profile?.name ?? _name.text.trim();
    }
    final slot = _slot;
    final font = _font;
    if (slot != null && slot != _savedSlot) settings.ownColorSlot = slot;
    if (font != null) settings.ownFontId = font.id;
    HapticFeedback.selectionClick();
    _nameFocus.unfocus();
    setState(() {
      _busy = false;
      _slot = null;
      _font = null;
    });
    _stopEditing();
    showToast(context, 'Профиль сохранён');
  }

  void _cancel() {
    _nameFocus.unfocus();
    setState(() {
      _slot = null;
      _font = null;
      if (_savedName != null) _name.text = _savedName!;
    });
    _stopEditing();
  }

  void _share() {
    final username = session.profile?.username;
    if (username == null || username.isEmpty) return;
    Clipboard.setData(ClipboardData(text: profileLink(username)));
    HapticFeedback.selectionClick();
    showToast(context, 'Ссылка скопирована');
  }

  Size _nameSize(String name, double width) {
    final painter =
        TextPainter(
          text: TextSpan(text: shownName(name), style: ProfileStyle.name),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
          ellipsis: '…',
        )..layout(
          maxWidth:
              width -
              ProfileHeaderStyle.gutter * 2 -
              ProfileHeaderStyle.rowAvatar -
              ProfileHeaderStyle.rowGap,
        );
    final size = painter.size;
    painter.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) {
    final own = _slot == null ? ownColorFor(settings) : avatarPalette[_slot!];
    final padding = MediaQuery.paddingOf(context);
    final barBottom = padding.top + PillStyle.size;
    final width = MediaQuery.sizeOf(context).width;
    final profile = session.profile;
    final typed = _name.text.trim();
    final name = profile == null
        ? ''
        : (typed.isNotEmpty
              ? typed
              : (profile.name.isEmpty ? profile.username : profile.name));
    final nameSize = _nameSize(name.isEmpty ? ' ' : name, width);
    final nickHeight = textHeightOf(context, '@', ProfileStyle.username);
    final nameBottom = headerNameTop() + nameSize.height;
    final nickBand = profile == null
        ? 0.0
        : ProfileStyle.usernameGap + nickHeight;
    final fieldShift = (PillFieldStyle.height - nameSize.height - nickBand) / 2;
    final header =
        nameBottom + nickBand + ProfileStyle.actionsGap + PillStyle.size;
    final font = _font ?? ownFontFor(settings);

    widget.scene?.report(
      this,
      index: widget.sceneIndex,
      colors: [own],
      anchor: _anchor,
    );
    final avatar = IgnorePointer(
      child: RepaintBoundary(
        child: AvatarPreview(
          color: own,
          font: font,
          name: name.isEmpty ? '?' : name,
          size: ProfileHeaderStyle.avatar,
        ),
      ),
    );
    final below = Column(
      children: [
        if (profile != null)
          AnimatedOpacity(
            opacity: _editing ? 0 : 1,
            duration: Motion.long,
            child: Padding(
              padding: const EdgeInsets.only(top: ProfileStyle.usernameGap),
              child: Text('@${profile.username}', style: ProfileStyle.username),
            ),
          ),
        const SizedBox(height: ProfileStyle.actionsGap),
        AnimatedSwitcher(
          duration: Motion.long,
          child: _editing ? _confirmRow() : _actionRow(profile != null),
        ),
      ],
    );
    final title = _title(profile == null, name);

    return OwnAvatar(
      id: profile?.id ?? 0,
      color: own,
      font: font,
      child: Scaffold(
        backgroundColor: widget.scene == null
            ? Colors.black
            : Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            if (widget.scene == null)
              Positioned.fill(
                child: PeopleBackdrop(colors: [own], anchor: _anchor),
              ),
            Positioned.fill(
              child: EventFeed(
                controller: _scroll,
                invites: widget.invites,
                meId: meAsPerson(profile).id,
                own: own,
                barBottom: barBottom,
                header: header,
                collapseDistance: headerCollapseDistance(nameSize.height),
                anchor: _anchor,
                editing: _editing,
                onOpenInvite: widget.onOpenInvite,
                onArchiveChanged: (open) {
                  _archiveOpen = open;
                  _reportBusy();
                },
                onCollapsedChanged: (collapsed) =>
                    setState(() => _collapsed = collapsed),
                expanded: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Column(
                    children: [
                      FontPicker(
                        name: name.isEmpty ? '?' : name,
                        selected: font,
                        onPick: (font) => setState(() => _font = font),
                      ),
                      const SizedBox(height: 14),
                      ColorPicker(
                        selected: _slot ?? _savedSlot,
                        onPick: (slot) => setState(() => _slot = slot),
                      ),
                    ],
                  ),
                ),
                headerLayer: (context, offset, archive) => _headerLayer(
                  archive: archive,
                  tail: header - nameBottom,
                  barBottom: barBottom,
                  width: width,
                  offset: offset,
                  nameSize: nameSize,
                  nameBottom: nameBottom,
                  fieldShift: fieldShift,
                  missing: profile == null,
                  avatar: avatar,
                  title: title,
                  below: below,
                ),
              ),
            ),
            Positioned(
              top: padding.top,
              left: 0,
              right: 0,
              child: PageBar(
                hidden: _editing || _collapsed,
                leading: PillButton(
                  key: const ValueKey('profile-back'),
                  icon: CupertinoIcons.arrow_left,
                  label: 'К календарю',
                  onPressed: widget.onBack,
                ),
                trailing: PillButton(
                  key: const ValueKey('profile-settings'),
                  icon: CupertinoIcons.gear,
                  label: 'Настройки',
                  onPressed: widget.onOpenSettings,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(bool missing, String name) {
    if (missing) return _MissingProfile(session: session);
    return _nameText(name);
  }

  Widget _nameField() {
    return PillField(
      key: const ValueKey('profile-name-field'),
      fieldKey: const ValueKey('profile-name-input'),
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
    );
  }

  Widget _nameText(String name) {
    return IgnorePointer(
      child: Text(
        shownName(name),
        key: const ValueKey('profile-name'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
        style: ProfileStyle.name,
      ),
    );
  }

  Widget _headerLayer({
    required double barBottom,
    required double width,
    required double offset,
    required Size nameSize,
    required double nameBottom,
    required double fieldShift,
    required bool missing,
    required Widget avatar,
    required Widget title,
    required Widget below,
    required double archive,
    required double tail,
  }) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final frame = headerFrame(width: width, offset: offset, name: nameSize);
    const size = ProfileHeaderStyle.avatar;
    return Stack(
      children: [
        Positioned.fill(
          top: ProfileHeaderStyle.row,
          child: ClipRect(
            child: Stack(
              children: [
                Positioned(
                  top:
                      nameBottom -
                      offset -
                      ProfileHeaderStyle.row -
                      archive * (tail + ProfileHeaderStyle.row),
                  left: 0,
                  right: 0,
                  child: below,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          left: frame.avatarCenter.dx - size / 2,
          top: frame.avatarCenter.dy - size / 2,
          width: size,
          height: size,
          child: Transform.scale(scale: frame.avatarScale, child: avatar),
        ),
        if (missing)
          Positioned(
            top: headerNameTop(),
            left: 0,
            right: 0,
            child: Center(child: title),
          )
        else
          TweenAnimationBuilder<double>(
            tween: Tween(end: _editing ? 1 : 0),
            duration: reduce ? Duration.zero : Motion.long,
            curve: Motion.settle,
            builder: (context, t, _) {
              if (t <= 0) {
                return Positioned(
                  left: frame.name.dx,
                  top: frame.name.dy,
                  width: nameSize.width,
                  child: title,
                );
              }
              final fieldTop = headerNameTop() - fieldShift;
              final drift =
                  headerNameTop() +
                  nameSize.height / 2 -
                  (fieldTop + PillFieldStyle.height / 2);
              return Positioned(
                top: fieldTop + drift * (1 - t),
                left: 0,
                right: 0,
                height: PillFieldStyle.height,
                child: Center(
                  child: GrowingField(
                    progress: t,
                    from: nameSize,
                    to: Size(
                      pillFieldWidth(
                        context,
                        _name.text.isEmpty ? 'ИМЯ' : _name.text,
                        PillFieldStyle.name,
                      ),
                      PillFieldStyle.height,
                    ),
                    labelScale:
                        PillFieldStyle.name.fontSize! /
                        ProfileStyle.name.fontSize!,
                    label: title,
                    field: _nameField(),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _actionRow(bool linkable) {
    return Row(
      key: const ValueKey('profile-actions'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        PillButton(
          key: const ValueKey('profile-share'),
          icon: CupertinoIcons.square_arrow_up,
          label: 'Скопировать ссылку на профиль',
          width: PillStyle.wide,
          onPressed: linkable ? _share : null,
        ),
        const SizedBox(width: ProfileStyle.actionGap),
        PillButton(
          key: const ValueKey('profile-edit'),
          icon: CupertinoIcons.pencil,
          label: 'Изменить профиль',
          width: PillStyle.wide,
          onPressed: _startEditing,
        ),
      ],
    );
  }

  Widget _confirmRow() {
    return Row(
      key: const ValueKey('profile-confirm'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ActionPill(
          key: const ValueKey('profile-cancel'),
          icon: CupertinoIcons.xmark,
          label: 'Отменить',
          kind: ActionPillKind.cancel,
          onPressed: _cancel,
        ),
        const SizedBox(width: ProfileStyle.actionGap),
        ActionPill(
          key: const ValueKey('profile-save'),
          icon: CupertinoIcons.checkmark_alt,
          label: 'Сохранить профиль',
          filled: true,
          onPressed: _save,
        ),
      ],
    );
  }
}

String _errorText(Object error) =>
    error is ApiException ? error.message : 'Не получилось';

class _MissingProfile extends StatelessWidget {
  const _MissingProfile({required this.session});

  final SessionController session;

  @override
  Widget build(BuildContext context) {
    return PillButton(
      text: 'Профиль не загружен',
      onPressed: () async {
        try {
          await session.refreshProfile();
        } catch (error) {
          if (context.mounted) showToast(context, _errorText(error));
        }
      },
    );
  }
}
