import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/features/groups/group_editor.dart';
import 'package:druna_app/features/groups/group_page.dart';
import 'package:druna_app/features/groups/groups_store.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/adaptive_dialogs.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/people_backdrop.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({
    required this.store,
    required this.friends,
    required this.me,
    required this.own,
    this.onCreated,
    this.scene,
    this.sceneIndex = 0,
    this.full = false,
    super.key,
  });

  final GroupsStore store;
  final List<FriendInfo>? friends;
  final FriendInfo me;
  final Color own;

  final ValueChanged<Group>? onCreated;

  final BackdropScene? scene;
  final int sceneIndex;

  final bool full;

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _name = UpperCaseNameController();
  final _nameFocus = FocusNode();
  final _anchor = ValueNotifier<double>(0);
  final _captionKey = GlobalKey();
  final _pageKey = GlobalKey();
  AvatarFont _font = defaultAvatarFont;
  final _members = <FriendInfo>[];
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _name.addListener(_onName);
    _nameFocus.addListener(_onName);
  }

  @override
  void dispose() {
    widget.scene?.forget(this);
    _name.removeListener(_onName);
    _name.dispose();
    _nameFocus.dispose();
    _anchor.dispose();
    super.dispose();
  }

  void _onName() => setState(() {});

  bool get _dirty =>
      _name.text.trim().isNotEmpty ||
      _members.isNotEmpty ||
      _font.id != defaultAvatarFont.id ||
      _nameFocus.hasFocus;

  void _toggle(FriendInfo friend) {
    setState(() {
      final index = _members.indexWhere((member) => member.id == friend.id);
      if (index >= 0) {
        _members.removeAt(index);
      } else {
        _members.add(friend);
      }
    });
  }

  void _reset() {
    _nameFocus.unfocus();
    setState(() {
      _name.clear();
      _members.clear();
      _font = defaultAvatarFont;
    });
  }

  Future<void> _create() async {
    if (_busy) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Назови группу', error: true);
      return;
    }
    if (_members.isEmpty) {
      showToast(context, 'Выбери друзей для группы', error: true);
      return;
    }
    _nameFocus.unfocus();
    final ok = await confirmAction(
      context,
      title: 'Отправить приглашение в группу?',
      message: peopleNames(_members),
      confirmLabel: 'Отправить',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    final Group group;
    try {
      group = await widget.store.create(
        GroupDraft(name: name, fontId: _font.id, members: List.of(_members)),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        showToast(
          context,
          error is ApiException ? error.message : 'Не получилось',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = false);
    _reset();
    widget.onCreated?.call(group);
  }

  void _measure() {
    final caption = _captionKey.currentContext?.findRenderObject();
    final page = _pageKey.currentContext?.findRenderObject();
    if (caption is! RenderBox || page is! RenderBox) return;
    if (!caption.attached || !page.attached) return;
    _anchor.value = caption.localToGlobal(Offset.zero, ancestor: page).dy;
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measure();
    });
    final padding = MediaQuery.paddingOf(context);
    final barBottom = padding.top + PillStyle.size;
    final people = _dirty ? [widget.me, ..._members] : const <FriendInfo>[];
    final colors = groupColors(
      [widget.me, ..._members],
      meId: widget.me.id,
      own: widget.own,
    );
    widget.scene?.report(
      this,
      index: widget.sceneIndex,
      colors: colors,
      anchor: _anchor,
    );
    return Scaffold(
      key: _pageKey,
      backgroundColor: widget.scene == null ? Colors.black : Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          if (widget.scene == null)
            Positioned.fill(
              child: PeopleBackdrop(colors: colors, anchor: _anchor),
            ),
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _measure();
                return false;
              },
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(
                  top: barBottom + GroupStyle.orbitTop,
                  bottom: GroupStyle.orbitTop,
                ),
                child: Column(
                  children: [
                    if (widget.full)
                      Orbit(
                        people: const [],
                        meId: widget.me.id,
                        center: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: GroupStyle.gutter,
                          ),
                          child: Text(
                            groupsFullText,
                            key: const ValueKey('groups-full'),
                            textAlign: TextAlign.center,
                            style: GroupStyle.note,
                          ),
                        ),
                      )
                    else ...[
                      Orbit(
                        people: people,
                        meId: widget.me.id,
                        center: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            GroupNameField(
                              controller: _name,
                              focusNode: _nameFocus,
                              font: _font,
                            ),
                            Positioned(
                              bottom:
                                  PillFieldStyle.height + GroupStyle.captionGap,
                              child: IgnorePointer(
                                child: AnimatedOpacity(
                                  key: const ValueKey('group-create-caption'),
                                  opacity: _dirty ? 0 : 1,
                                  duration: SheetStyle.fade,
                                  child: Text(
                                    'Создать группу',
                                    style: GroupStyle.caption,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Reveal(
                        open: _dirty,
                        child: Padding(
                          padding: const EdgeInsets.only(
                            top: GroupStyle.actionsGap,
                          ),
                          child: ConfirmRow(
                            onCancel: _reset,
                            onConfirm: _create,
                            confirmLabel: 'Создать группу',
                          ),
                        ),
                      ),
                      const SizedBox(height: GroupStyle.pickersGap),
                      KeyedSubtree(
                        key: _captionKey,
                        child: GroupPickers(
                          name: _name.text,
                          font: _font,
                          onFont: (font) => setState(() => _font = font),
                          friends: widget.friends,
                          selected: {for (final member in _members) member.id},
                          onToggle: _toggle,
                        ),
                      ),
                    ],
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
