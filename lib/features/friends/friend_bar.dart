import 'package:druna_app/shared/ui/motion.dart';
import 'dart:math' as math;

import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/features/friends/group_chip.dart';
import 'package:druna_app/features/groups/group.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class FriendBarStyle {
  static const avatar = 56.0;

  static const hint = 32.0;
  static const hintGap = 8.0;
  static const step = 68.0;
  static const gutter = 20.0;
  static const height = 64.0;

  static const stackAvatar = 48.0;
  static const stackStep = 22.0;
  static const stackMax = 3;

  static const mineGap = 10.0;
  static const mineCaption = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1,
  );
  static const arrow = Color(0xB3FFFFFF);
  static const arrowSize = 24.0;
  static const arrowDrift = 6.0;
  static const arrowCycle = Duration(milliseconds: 2400);
  static const arrowHidden = 0.6;

  static const flyOver = 48.0;

  static const followGap = 10.0;
  static const followFrom = 0.5;

  static const lag = 0.06;
  static const lagMax = 5;

  static const ring = 3.0;
  static const ringGap = 3.0;

  static const reorder = Motion.medium;
  static const groupMorph = reorder;
  static const select = Duration(milliseconds: 160);
}

const friendBarExtent =
    FriendBarStyle.hint + FriendBarStyle.hintGap + FriendBarStyle.height + 4;

class FriendBar extends StatefulWidget {
  const FriendBar({
    required this.friends,
    required this.selection,
    required this.mode,
    required this.onShowFriends,
    required this.onAddFriends,
    this.schedulesAvailable = true,
    this.groups = const [],
    this.me,
    this.onOpenMine,
    super.key,
  });

  final List<FriendInfo>? friends;
  final FriendSelection selection;
  final ValueListenable<double> mode;

  final VoidCallback onShowFriends;

  final VoidCallback onAddFriends;

  final bool schedulesAvailable;

  final List<Group> groups;

  final Widget? me;

  final VoidCallback? onOpenMine;

  static var arrowDrifts = true;

  @override
  State<FriendBar> createState() => _FriendBarState();
}

class _FriendBarState extends State<FriendBar> {
  final _scroll = ScrollController();

  final _corner = GlobalKey();

  final _opening = <String>{};

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _toggle(FriendInfo friend) {
    HapticFeedback.selectionClick();
    widget.selection.toggle(friend.id);
  }

  @override
  Widget build(BuildContext context) {
    final friends = widget.friends;
    return LayoutBuilder(
      builder: (context, constraints) => ListenableBuilder(
        listenable: widget.selection,
        builder: (context, _) => ModeGate(
          mode: widget.mode,
          builder: (context, expanded) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hint(text: _hint(friends), visible: expanded),
              const SizedBox(height: FriendBarStyle.hintGap),
              SizedBox(
                height: FriendBarStyle.height,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (friends == null)
                      _Placeholder(visible: expanded)
                    else if (friends.isEmpty)
                      _AddFriends(
                        visible: expanded,
                        mode: widget.mode,
                        width: constraints.maxWidth,
                        onTap: widget.onAddFriends,
                      )
                    else
                      _row(context, friends, constraints.maxWidth, expanded),
                    if (widget.me case final me?)
                      _MineCorner(
                        boxKey: _corner,
                        me: me,
                        mode: widget.mode,
                        expanded: expanded,
                        width: constraints.maxWidth,
                        onTap: widget.onOpenMine,
                      ),
                    _SwipeHint(
                      shown: widget.selection.selected.isEmpty,
                      corner: widget.me == null ? null : _corner,
                      mode: widget.mode,
                      expanded: expanded,
                      width: constraints.maxWidth,
                      onTap: widget.onShowFriends,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _hint(List<FriendInfo>? friends) {
    if (friends == null || friends.isEmpty) return null;
    if (widget.selection.selected.isEmpty) {
      return 'Выбери друзей, чтобы увидеть их занятость';
    }
    if (!widget.schedulesAvailable) {
      return 'Расписание друзей пока недоступно';
    }
    return null;
  }

  void _openGroup(Group group, List<FriendInfo> members) {
    HapticFeedback.selectionClick();
    _opening.add(group.id);
    Future<void>.delayed(
      FriendBarStyle.groupMorph,
      () => _opening.remove(group.id),
    );
    widget.selection.openGroup(group.id, [
      for (final member in members) member.id,
    ]);
  }

  void _closeGroup(Group group, List<FriendInfo> members) {
    HapticFeedback.selectionClick();
    final keep = <int>{
      for (final other in widget.groups)
        if (other.id != group.id && widget.selection.isOpen(other.id))
          ...other.memberIds,
    };
    widget.selection.closeGroup(group.id, [
      for (final member in members) member.id,
    ], keep: keep);
  }

  Widget _row(
    BuildContext context,
    List<FriendInfo> friends,
    double width,
    bool expanded,
  ) {
    final selection = widget.selection;
    final byId = {for (final friend in friends) friend.id: friend};
    final picked = [
      for (final id in selection.selected)
        if (byId.containsKey(id)) id,
    ];
    final geometry = _StackGeometry(width: width, selected: picked.length);
    final motion = Listenable.merge([widget.mode, _scroll]);
    const gap = FriendBarStyle.step - FriendBarStyle.avatar;

    final groupSlots = <Widget>[];
    final people = <_Seat>[];
    final groupsById = {for (final group in widget.groups) group.id: group};
    List<FriendInfo> membersOf(Group group) => [
      for (final member in group.members)
        if (byId[member.id] case final friend?) friend,
    ];
    final inside = <int>{};
    final order = selection.barOrder(friends, [
      for (final group in widget.groups)
        if (membersOf(group).isNotEmpty) (id: group.id, name: group.name),
    ]);
    for (final item in order) {
      if (item case BarGroup(:final id) when selection.isOpen(id)) {
        inside.addAll(membersOf(groupsById[id]!).map((member) => member.id));
      }
    }
    final seated = <int>{};
    var left = FriendBarStyle.gutter;
    for (final item in order) {
      switch (item) {
        case BarFriend(:final friend):
          if (inside.contains(friend.id)) continue;
          people.add(_Seat(friend, left, 1, ValueKey(friend.id), false));
          left += FriendBarStyle.step;
        case BarGroup(:final id):
          final group = groupsById[id]!;
          final members = membersOf(group);
          final open = selection.isOpen(group.id);
          final closedWidth = closedGroupChipWidth(
            nameWidth: groupNameWidth(context, group.name, group.font),
            people: members.length,
          );
          final chip = open ? openGroupChipWidth(members.length) : closedWidth;
          groupSlots.add(
            _GroupSlot(
              key: ValueKey('group-${group.id}'),
              group: group,
              members: members,
              left: left,
              closedWidth: closedWidth,
              openWidth: openGroupChipWidth(members.length),
              open: open,
              geometry: geometry,
              motion: motion,
              mode: widget.mode,
              scroll: _scroll,
              onOpen: () => _openGroup(group, members),
              onClose: () => _closeGroup(group, members),
            ),
          );
          if (open) {
            for (var j = 0; j < members.length; j++) {
              if (!seated.add(members[j].id)) continue;
              people.add(
                _Seat(
                  members[j],
                  openGroupMemberLeft(left, j) -
                      (FriendBarStyle.avatar - GroupChipStyle.openAvatar) / 2,
                  GroupChipStyle.openAvatar / FriendBarStyle.avatar,
                  ValueKey(('in-group', group.id, members[j].id)),
                  _opening.contains(group.id),
                ),
              );
            }
          }
          left += chip + gap;
      }
    }
    final contentWidth = left - gap + FriendBarStyle.gutter;
    final unpicked = [
      for (final person in people)
        if (!picked.contains(person.friend.id)) person,
    ];
    final pickedSlots =
        [
          for (final person in people)
            if (picked.contains(person.friend.id)) person,
        ]..sort(
          (a, b) => picked
              .indexOf(a.friend.id)
              .compareTo(picked.indexOf(b.friend.id)),
        );

    Widget slot(_Seat person) {
      final friend = person.friend;
      final stack = picked.indexOf(friend.id);
      return _FriendSlot(
        key: person.key,
        friend: friend,
        left: person.left,
        rowScale: person.scale,
        enters: person.enters,
        stackIndex: stack < 0 ? null : stack,
        geometry: geometry,
        motion: motion,
        mode: widget.mode,
        scroll: _scroll,
        selected: stack >= 0,
        onTap: () => _toggle(friend),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          ignoring: !expanded,
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            physics: expanded
                ? const BouncingScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            clipBehavior: Clip.none,
            child: SizedBox(
              width: contentWidth < width ? width : contentWidth,
              height: FriendBarStyle.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ...groupSlots,
                  for (final person in unpicked) slot(person),
                  for (final person in pickedSlots) slot(person),
                  if (geometry.extra > 0)
                    _MoreSlot(
                      count: geometry.extra,
                      geometry: geometry,
                      motion: motion,
                      mode: widget.mode,
                      scroll: _scroll,
                    ),
                ],
              ),
            ),
          ),
        ),
        if (!expanded && picked.isNotEmpty)
          Positioned(
            left: geometry.slotLeft(0) - 8,
            right: 0,
            top: 0,
            bottom: 0,
            child: Semantics(
              button: true,
              label: 'Показать занятость друзей',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onShowFriends,
              ),
            ),
          ),
      ],
    );
  }
}

class ModeGate extends StatefulWidget {
  const ModeGate({
    required this.mode,
    required this.builder,
    this.threshold = 0.5,
    super.key,
  });

  final ValueListenable<double> mode;
  final double threshold;
  final Widget Function(BuildContext context, bool on) builder;

  @override
  State<ModeGate> createState() => _ModeGateState();
}

class _ModeGateState extends State<ModeGate> {
  late bool _on = widget.mode.value >= widget.threshold;

  @override
  void initState() {
    super.initState();
    widget.mode.addListener(_check);
  }

  @override
  void didUpdateWidget(covariant ModeGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mode != widget.mode) {
      oldWidget.mode.removeListener(_check);
      widget.mode.addListener(_check);
    }
    _on = widget.mode.value >= widget.threshold;
  }

  @override
  void dispose() {
    widget.mode.removeListener(_check);
    super.dispose();
  }

  void _check() {
    final on = widget.mode.value >= widget.threshold;
    if (on != _on) setState(() => _on = on);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _on);
}

class _StackGeometry {
  _StackGeometry({required this.width, required int selected})
    : shown = selected.clamp(0, FriendBarStyle.stackMax),
      extra = selected > FriendBarStyle.stackMax
          ? selected - FriendBarStyle.stackMax
          : 0;

  final double width;
  final int shown;
  final int extra;

  int get slots => shown + (extra > 0 ? 1 : 0);

  double slotLeft(int k) =>
      width -
      FriendBarStyle.gutter -
      FriendBarStyle.stackAvatar -
      (slots - 1 - k) * FriendBarStyle.stackStep;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _Seat {
  const _Seat(this.friend, this.left, this.scale, this.key, this.enters);

  final FriendInfo friend;
  final double left;
  final double scale;
  final Key key;
  final bool enters;
}

double _offsetOf(ScrollController scroll) =>
    scroll.hasClients ? scroll.positions.last.pixels : 0.0;

double friendBarFold(double mode) =>
    Curves.easeInOutCubic.transform(1 - mode.clamp(0.0, 1.0));

double friendBarFoldAt(double mode, double k) {
  final lag =
      FriendBarStyle.lag * k.clamp(0.0, FriendBarStyle.lagMax.toDouble());
  final open = ((mode.clamp(0.0, 1.0) - lag) / (1 - lag)).clamp(0.0, 1.0);
  return Curves.easeInOutCubic.transform(1 - open);
}

class _FriendSlot extends StatelessWidget {
  const _FriendSlot({
    required this.friend,
    required this.left,
    required this.stackIndex,
    this.rowScale = 1,
    required this.geometry,
    required this.motion,
    required this.mode,
    required this.scroll,
    required this.selected,
    required this.onTap,
    this.enters = false,
    super.key,
  });

  final FriendInfo friend;
  final double left;
  final double rowScale;
  final bool enters;

  final int? stackIndex;
  final _StackGeometry geometry;
  final Listenable motion;
  final ValueListenable<double> mode;
  final ScrollController scroll;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const avatar = FriendBarStyle.avatar;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: left),
      duration: reduce ? Duration.zero : FriendBarStyle.reorder,
      curve: Curves.easeOutCubic,
      child: Semantics(
        button: true,
        selected: selected,
        label: friendName(friend),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: enters && !reduce ? 0 : 1, end: 1),
            duration: FriendBarStyle.groupMorph,
            child: RingedAvatar(friend: friend, selected: selected),
            builder: (context, shown, avatar) =>
                Opacity(opacity: shown >= 1 ? 1 : 0, child: avatar),
          ),
        ),
      ),
      builder: (context, rowLeft, child) => AnimatedBuilder(
        animation: motion,
        child: child,
        builder: (context, child) {
          final offset = _offsetOf(scroll);
          final fold = friendBarFoldAt(
            mode.value,
            (rowLeft - FriendBarStyle.gutter - offset) / FriendBarStyle.step,
          );
          final stack = stackIndex;
          final double foldedLeft;
          final double foldedScale;
          var hidden = false;
          if (stack != null && stack < FriendBarStyle.stackMax) {
            foldedLeft =
                geometry.slotLeft(stack) -
                (avatar - FriendBarStyle.stackAvatar) / 2 +
                offset;
            foldedScale = FriendBarStyle.stackAvatar / avatar;
          } else if (stack != null) {
            foldedLeft =
                geometry.slotLeft(FriendBarStyle.stackMax) -
                (avatar - FriendBarStyle.stackAvatar) / 2 +
                offset;
            foldedScale = 0;
            hidden = true;
          } else {
            foldedLeft =
                offset +
                geometry.width +
                FriendBarStyle.gutter +
                math.max(0.0, rowLeft - FriendBarStyle.gutter - offset);
            foldedScale = FriendBarStyle.stackAvatar / avatar;
            hidden = true;
          }
          return Positioned(
            left: _lerp(rowLeft, foldedLeft, fold),
            top: (FriendBarStyle.height - avatar) / 2,
            width: avatar,
            height: avatar,
            child: ExcludeSemantics(
              excluding: hidden && fold > 0.5,
              child: Transform.scale(
                scale: _lerp(rowScale, foldedScale, fold),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

class RingedAvatar extends StatelessWidget {
  const RingedAvatar({required this.friend, required this.selected, super.key});

  final FriendInfo friend;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final color = avatarColorFor(id: friend.id, username: friend.username);
    final ringColor = Color.lerp(color, Colors.white, 0.55)!;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: selected ? 1 : 0),
      duration: reduce ? Duration.zero : FriendBarStyle.select,
      curve: Curves.easeOutCubic,
      builder: (context, ring, _) => LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          final inset = (FriendBarStyle.ring + FriendBarStyle.ringGap) * ring;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (ring > 0)
                Container(
                  key: const ValueKey('friend-ring'),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: ringColor.withValues(alpha: ring),
                      width: FriendBarStyle.ring * ring,
                    ),
                  ),
                ),
              PersonAvatar(
                id: friend.id,
                name: friend.name,
                username: friend.username,
                size: size - inset * 2,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MoreSlot extends StatelessWidget {
  const _MoreSlot({
    required this.count,
    required this.geometry,
    required this.motion,
    required this.mode,
    required this.scroll,
  });

  final int count;
  final _StackGeometry geometry;
  final Listenable motion;
  final ValueListenable<double> mode;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: motion,
      child: AvatarOverflow(count: count, size: FriendBarStyle.stackAvatar),
      builder: (context, child) {
        final offset = _offsetOf(scroll);
        return Positioned(
          left: geometry.slotLeft(FriendBarStyle.stackMax) + offset,
          top: (FriendBarStyle.height - FriendBarStyle.stackAvatar) / 2,
          width: FriendBarStyle.stackAvatar,
          height: FriendBarStyle.stackAvatar,
          child: Transform.scale(
            scale: friendBarFold(mode.value),
            child: child,
          ),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.visible});

  final String? text;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final message = text;
    return SizedBox(
      height: FriendBarStyle.hint,
      child: Center(
        child: AnimatedOpacity(
          duration: FriendBarStyle.select,
          opacity: message != null && visible ? 1 : 0,
          child: message == null
              ? const SizedBox.shrink()
              : Text(
                  message,
                  style: const TextStyle(
                    fontFamily: 'Onest',
                    color: SheetStyle.muted,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: FriendBarStyle.select,
      opacity: visible ? 1 : 0,
      child: Row(
        children: [
          const SizedBox(width: FriendBarStyle.gutter),
          for (var i = 0; i < 3; i++)
            Container(
              width: FriendBarStyle.avatar,
              height: FriendBarStyle.avatar,
              margin: const EdgeInsets.only(
                right: FriendBarStyle.step - FriendBarStyle.avatar,
              ),
              decoration: const BoxDecoration(
                color: SheetStyle.chip,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddFriends extends StatelessWidget {
  const _AddFriends({
    required this.visible,
    required this.mode,
    required this.width,
    required this.onTap,
  });

  final bool visible;
  final ValueListenable<double> mode;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: ValueListenableBuilder<double>(
        valueListenable: mode,
        child: Center(
          child: PillButton(
            key: const ValueKey('add-friends'),
            icon: CupertinoIcons.person_add,
            text: 'Добавить друзей',
            onPressed: onTap,
          ),
        ),
        builder: (context, t, button) => Transform.translate(
          offset: Offset(width * friendBarFold(t), 0),
          child: button,
        ),
      ),
    );
  }
}

Offset _flyIn(double fold, double width) =>
    Offset(-(width + FriendBarStyle.flyOver) * (1 - fold), 0);

class _MineCorner extends StatelessWidget {
  const _MineCorner({
    required this.boxKey,
    required this.me,
    required this.mode,
    required this.expanded,
    required this.width,
    this.onTap,
  });

  final GlobalKey boxKey;
  final Widget me;
  final ValueListenable<double> mode;
  final bool expanded;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    key: boxKey,
    left: FriendBarStyle.gutter,
    top: 0,
    bottom: 0,
    child: IgnorePointer(
      ignoring: onTap == null || expanded,
      child: ValueListenableBuilder<double>(
        valueListenable: mode,
        child: onTap != null
            ? Center(
                child: PillButton(
                  key: const ValueKey('mine-button'),
                  leading: me,
                  text: 'Мои события',
                  label: 'Мои события: календари',
                  onPressed: onTap,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: FriendBarStyle.stackAvatar,
                    child: me,
                  ),
                  const SizedBox(width: FriendBarStyle.mineGap),
                  Text(
                    'Мои события',
                    textScaler: TextScaler.noScaling,
                    style: FriendBarStyle.mineCaption.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
        builder: (context, t, row) => Transform.translate(
          offset: _flyIn(friendBarFold(t), width),
          child: row,
        ),
      ),
    ),
  );
}

class _SwipeHint extends StatefulWidget {
  const _SwipeHint({
    required this.shown,
    required this.corner,
    required this.mode,
    required this.expanded,
    required this.width,
    required this.onTap,
  });

  final bool shown;
  final GlobalKey? corner;
  final ValueListenable<double> mode;
  final bool expanded;
  final double width;
  final VoidCallback onTap;

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint>
    with SingleTickerProviderStateMixin {
  late final _drift = AnimationController(
    vsync: this,
    duration: FriendBarStyle.arrowCycle,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncDrift();
  }

  @override
  void didUpdateWidget(covariant _SwipeHint oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncDrift();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  void _syncDrift() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final on =
        widget.shown && !widget.expanded && !reduce && FriendBar.arrowDrifts;
    if (on && !_drift.isAnimating) {
      _drift.repeat();
    } else if (!on && _drift.isAnimating) {
      _drift
        ..stop()
        ..value = 0;
    }
  }

  double _shift(double t) {
    final fly = _flyIn(friendBarFold(t), widget.width).dx;
    final box = widget.corner?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return fly;
    final beside =
        FriendBarStyle.gutter + box.size.width + FriendBarStyle.followGap;
    final place =
        widget.width - FriendBarStyle.gutter - FriendBarStyle.arrowSize;
    const from = FriendBarStyle.followFrom;
    final away = ((1 - t.clamp(0.0, 1.0) - from) / (1 - from)).clamp(0.0, 1.0);
    return (fly + beside - place) * (1 - Curves.easeInOutCubic.transform(away));
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Positioned(
      right: FriendBarStyle.gutter - 8,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: widget.expanded || !widget.shown,
        child: Semantics(
          button: true,
          label: 'Показать календарь друзей',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: widget.shown ? 1 : 0),
                  duration: reduce ? Duration.zero : Motion.short,
                  curve: widget.shown ? Motion.enter : Motion.exit,
                  child: const ArrowIcon(
                    key: ValueKey('swipe-hint'),
                    color: FriendBarStyle.arrow,
                    back: true,
                    size: FriendBarStyle.arrowSize,
                  ),
                  builder: (context, shown, arrow) => AnimatedBuilder(
                    animation: Listenable.merge([widget.mode, _drift]),
                    child: arrow,
                    builder: (context, arrow) {
                      final visible = shown * friendBarFold(widget.mode.value);
                      const hidden = FriendBarStyle.arrowHidden;
                      return Transform.translate(
                        offset: Offset(
                          _shift(widget.mode.value) -
                              FriendBarStyle.arrowDrift *
                                  arrowDrift(_drift.value),
                          0,
                        ),
                        child: Transform.scale(
                          scale: hidden + (1 - hidden) * visible,
                          child: Opacity(opacity: visible, child: arrow),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double arrowDrift(double t) {
  if (t < 0.5) return Curves.easeInOut.transform(t / 0.5);
  if (t < 0.8) return 1 - Curves.easeInOut.transform((t - 0.5) / 0.3);
  return 0;
}

class _GroupSlot extends StatelessWidget {
  const _GroupSlot({
    required this.group,
    required this.members,
    required this.left,
    required this.closedWidth,
    required this.openWidth,
    required this.open,
    required this.geometry,
    required this.motion,
    required this.mode,
    required this.scroll,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final Group group;
  final List<FriendInfo> members;
  final double left;
  final double closedWidth;
  final double openWidth;
  final bool open;
  final _StackGeometry geometry;
  final Listenable motion;
  final ValueListenable<double> mode;
  final ScrollController scroll;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = reduce ? Duration.zero : FriendBarStyle.groupMorph;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: left),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, boxLeft, _) => TweenAnimationBuilder<double>(
        tween: Tween(end: open ? 1 : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, t, _) => AnimatedBuilder(
          animation: motion,
          builder: (context, _) {
            final width = _lerp(closedWidth, openWidth, t);
            final height = _lerp(
              GroupChipStyle.height,
              GroupChipStyle.openHeight,
              t,
            );
            final offset = _offsetOf(scroll);
            final fold = friendBarFoldAt(
              mode.value,
              (boxLeft - FriendBarStyle.gutter - offset) / FriendBarStyle.step,
            );
            final foldedLeft =
                offset +
                geometry.width +
                FriendBarStyle.gutter +
                math.max(0.0, boxLeft - FriendBarStyle.gutter - offset);
            final face = GroupChipFace(
              key: ValueKey('group-face-${group.id}'),
              name: group.name,
              font: group.font,
              people: members,
              morph: t,
              closedWidth: closedWidth,
              captionFade: 1 - fold,
              onClose: onClose,
            );
            return Positioned(
              left: _lerp(boxLeft, foldedLeft, fold),
              top: (FriendBarStyle.height - height) / 2,
              width: width,
              height: height,
              child: ExcludeSemantics(
                excluding: fold > 0.5,
                child: open
                    ? Semantics(
                        label: shownName(group.name),
                        key: ValueKey('group-caption-${group.id}'),
                        child: face,
                      )
                    : Semantics(
                        button: true,
                        label: 'Группа ${shownName(group.name)}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          key: ValueKey('group-chip-${group.id}'),
                          behavior: HitTestBehavior.opaque,
                          onTap: onOpen,
                          child: face,
                        ),
                      ),
              ),
            );
          },
        ),
      ),
    );
  }
}
