import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/features/groups/group_editor.dart';
import 'package:druna_app/features/groups/groups_store.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/features/profile/event_feed.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/people_backdrop.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

List<Color> groupColors(
  List<FriendInfo> people, {
  required int meId,
  required Color own,
}) => [
  for (final person in people)
    person.id == meId
        ? own
        : avatarColorFor(id: person.id, username: person.username),
];

String peopleNames(Iterable<FriendInfo> people) => people
    .map(
      (person) =>
          shownName(person.name.isEmpty ? person.username : person.name),
    )
    .join(', ');

class GroupPage extends StatefulWidget {
  const GroupPage({
    required this.group,
    required this.store,
    required this.friends,
    required this.me,
    required this.own,
    this.invites,
    this.onOpenInvite,
    this.onBusyChanged,
    this.onFoldChanged,
    this.onRemoved,
    this.scene,
    this.sceneIndex = 0,
    this.active = true,
    super.key,
  });

  final Group group;
  final GroupsStore store;
  final List<FriendInfo>? friends;
  final FriendInfo me;
  final Color own;

  final InvitesStore? invites;
  final ValueChanged<String>? onOpenInvite;
  final ValueChanged<bool>? onBusyChanged;
  final ValueChanged<bool>? onFoldChanged;
  final VoidCallback? onRemoved;

  final BackdropScene? scene;
  final int sceneIndex;

  final bool active;

  @override
  State<GroupPage> createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage> {
  var _editing = false;
  var _archiveOpen = false;
  var _busy = false;

  final _scroll = ScrollController();
  final _anchor = ValueNotifier<double>(0);
  final _name = UpperCaseNameController();
  final _nameFocus = FocusNode();
  AvatarFont? _font;
  List<FriendInfo>? _members;

  Group get group => widget.group;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onName);
  }

  @override
  void didUpdateWidget(covariant GroupPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  @override
  void dispose() {
    widget.scene?.forget(this);
    _name.removeListener(_onName);
    _scroll.dispose();
    _anchor.dispose();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onName() => setState(() {});

  void _reportBusy() {
    widget.onBusyChanged?.call(_editing || _archiveOpen);
    widget.onFoldChanged?.call(_editing);
  }

  List<FriendInfo> get _shownMembers => _members ?? group.members;

  Future<void> _startEditing() async {
    if (_scroll.hasClients && _scroll.offset != 0) {
      await _scroll.animateTo(0, duration: Motion.medium, curve: Motion.settle);
    }
    if (!mounted) return;
    setState(() {
      _editing = true;
      _name.text = group.name;
      _font = group.font;
      _members = List.of(group.members);
    });
    _reportBusy();
  }

  void _stopEditing() {
    _nameFocus.unfocus();
    if (_scroll.hasClients && _scroll.offset != 0) _scroll.jumpTo(0);
    setState(() {
      _editing = false;
      _font = null;
      _members = null;
    });
    _reportBusy();
  }

  void _toggle(FriendInfo friend) {
    final members = List.of(_shownMembers);
    final index = members.indexWhere((member) => member.id == friend.id);
    if (index >= 0) {
      members.removeAt(index);
    } else {
      members.add(friend);
    }
    setState(() => _members = members);
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Назови группу', error: true);
      return;
    }
    final members = _shownMembers;
    final had = group.memberIds;
    final added = [
      for (final member in members)
        if (!had.contains(member.id)) member,
    ];
    if (added.isNotEmpty) {
      final ok = await confirmAction(
        context,
        title: 'Отправить приглашение в группу?',
        message: peopleNames(added),
        confirmLabel: 'Отправить',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    try {
      await widget.store.update(
        group,
        GroupDraft(
          name: name,
          fontId: (_font ?? group.font).id,
          members: members,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(context, _errorText(error), error: true);
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = false);
    _stopEditing();
  }

  Future<void> _remove() async {
    final owner = group.ownedBy(widget.me.id);
    final ok = await confirmAction(
      context,
      title: owner ? 'Удалить группу?' : 'Выйти из группы?',
      message: owner
          ? 'Группа пропадёт у всех участников.'
          : 'Группа пропадёт из твоего профиля.',
      confirmLabel: owner ? 'Удалить' : 'Выйти',
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await widget.store.remove(group, owner: owner);
    } catch (error) {
      if (mounted) showToast(context, _errorText(error), error: true);
      return;
    }
    if (!mounted) return;
    _editing = false;
    _reportBusy();
    widget.onRemoved?.call();
  }

  void _share() {
    Clipboard.setData(ClipboardData(text: groupLink(group.id)));
    HapticFeedback.selectionClick();
    showToast(context, 'Ссылка скопирована');
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final barBottom = padding.top + PillStyle.size;
    final people = [widget.me, ..._shownMembers];
    final colors = groupColors(people, meId: widget.me.id, own: widget.own);
    widget.scene?.report(
      this,
      index: widget.sceneIndex,
      colors: colors,
      anchor: _anchor,
    );
    final font = _font ?? group.font;
    const orbitBottom = GroupStyle.orbitTop + OrbitStyle.box;
    const header = orbitBottom + GroupStyle.actionsGap + PillStyle.size;

    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final center = TweenAnimationBuilder<double>(
      tween: Tween(end: _editing ? 1 : 0),
      duration: reduce ? Duration.zero : Motion.long,
      curve: Motion.settle,
      builder: (context, t, _) {
        final title = GroupTitle(
          name: _editing ? _name.text : group.name,
          font: font,
        );
        if (t <= 0) return title;
        final width = MediaQuery.sizeOf(context).width;
        final natural = groupTitleSize(context, group.name, font);
        final room = width - 2 * GroupStyle.gutter;
        final from = Size(
          natural.width < room ? natural.width : room,
          natural.height,
        );
        return GrowingField(
          progress: t,
          from: from,
          to: Size(
            pillFieldWidth(
              context,
              _name.text.isEmpty ? 'НАЗВАНИЕ' : _name.text,
              groupFieldStyle(font, PillFieldStyle.name),
            ),
            PillFieldStyle.height,
          ),
          labelScale: PillFieldStyle.name.fontSize! / GroupStyle.titleSize,
          label: SizedBox(width: width, child: title),
          field: GroupNameField(
            controller: _name,
            focusNode: _nameFocus,
            font: font,
          ),
        );
      },
    );
    Widget orbit(double offset) =>
        Orbit(people: people, meId: widget.me.id, center: center);
    final actions = AnimatedSwitcher(
      duration: Motion.long,
      child: _editing
          ? ConfirmRow(
              key: const ValueKey('group-confirm'),
              onCancel: _stopEditing,
              onConfirm: _save,
              confirmLabel: 'Сохранить группу',
            )
          : Row(
              key: const ValueKey('group-actions'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PillButton(
                  key: const ValueKey('group-share'),
                  icon: CupertinoIcons.square_arrow_up,
                  label: 'Скопировать ссылку на группу',
                  width: PillStyle.wide,
                  onPressed: _share,
                ),
                const SizedBox(width: GroupStyle.actionGap),
                PillButton(
                  key: const ValueKey('group-edit'),
                  icon: CupertinoIcons.pencil,
                  label: 'Изменить группу',
                  width: PillStyle.wide,
                  onPressed: _startEditing,
                ),
              ],
            ),
    );

    return Scaffold(
      backgroundColor: widget.scene == null ? Colors.black : Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (widget.scene == null)
            Positioned.fill(
              child: PeopleBackdrop(colors: colors, anchor: _anchor),
            ),
          Positioned.fill(
            child: EventFeed(
              controller: _scroll,
              invites: widget.invites,
              meId: widget.me.id,
              own: widget.own,
              include: (invite) =>
                  inviteMatchesGroup(invite, group, meId: widget.me.id),
              emptyText: 'Здесь будут события, где собирается вся группа',
              barBottom: barBottom,
              header: header,
              collapseDistance: orbitBottom,
              anchor: _anchor,
              editing: _editing,
              onOpenInvite: widget.onOpenInvite,
              onArchiveChanged: (open) {
                _archiveOpen = open;
                _reportBusy();
              },
              expanded: Padding(
                padding: const EdgeInsets.only(top: GroupStyle.pickersGap),
                child: GroupPickers(
                  caption: 'Изменить группу',
                  name: _name.text,
                  font: font,
                  onFont: (font) => setState(() => _font = font),
                  friends: widget.friends,
                  selected: {for (final member in _shownMembers) member.id},
                  onToggle: _toggle,
                  footer: LeaveGroupButton(
                    owner: group.ownedBy(widget.me.id),
                    onPressed: _remove,
                  ),
                ),
              ),
              headerLayer: (context, offset, archive) => ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      top: GroupStyle.orbitTop - offset,
                      left: 0,
                      right: 0,
                      child: orbit(offset),
                    ),
                    Positioned(
                      top:
                          orbitBottom +
                          GroupStyle.actionsGap -
                          offset -
                          archive * (header - orbitBottom),
                      left: 0,
                      right: 0,
                      child: actions,
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

String _errorText(Object error) =>
    error is ApiException ? error.message : 'Не получилось';
