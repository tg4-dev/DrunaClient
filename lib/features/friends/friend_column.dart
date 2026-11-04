import 'package:druna_app/features/calendar/day_friends.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class FriendColumnStyle {
  static const hintSize = 24.0;
  static const hintGap = 8.0;

  static const blurSigma = 30.0;
  static const shade = [
    Color(0xE6000000),
    Color(0x99000000),
    Color(0x00000000),
  ];
  static const shadeStops = [0.0, 0.55, 1.0];

  static const divider = Color(0x3DFFFFFF);
}

class FriendColumn extends StatelessWidget {
  const FriendColumn({
    required this.friends,
    required this.selection,
    required this.mode,
    required this.offset,
    required this.geometry,
    required this.me,
    required this.onShowFriends,
    super.key,
  });

  final List<FriendInfo>? friends;
  final FriendSelection selection;
  final ValueListenable<double> mode;
  final ValueListenable<double> offset;
  final DayFriendsGeometry geometry;

  final Widget me;

  final VoidCallback onShowFriends;

  void _toggle(FriendInfo friend) {
    HapticFeedback.selectionClick();
    selection.toggle(friend.id);
  }

  @override
  Widget build(BuildContext context) {
    const width = DayFriendsGeometry.columnWidth;
    const gutter = DayFriendsGeometry.gutter;
    const avatar = DayFriendsGeometry.avatar;
    const clipTop = DayFriendsGeometry.dividerY + 1;
    final friends = this.friends ?? const <FriendInfo>[];
    return SizedBox(
      width: width,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: FriendColumnStyle.shade,
                    stops: FriendColumnStyle.shadeStops,
                  ),
                ),
                child: SizedBox.expand(),
              ),
            ),
          ),
          Positioned(
            top: clipTop,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: ListenableBuilder(
                listenable: selection,
                builder: (context, _) => ModeGate(
                  mode: mode,
                  builder: (context, open) =>
                      _friends(friends, open, shift: clipTop),
                ),
              ),
            ),
          ),
          Positioned(
            top: DayFriendsGeometry.dividerY,
            left: gutter,
            width: avatar,
            height: 1,
            child: ValueListenableBuilder<double>(
              valueListenable: mode,
              builder: (context, t, _) => Opacity(
                opacity: 1 - dayFriendsFold(t),
                child: const ColoredBox(color: FriendColumnStyle.divider),
              ),
            ),
          ),
          Positioned(
            top: DayFriendsGeometry.myRowTop + DayFriendsGeometry.avatarInset,
            left: gutter,
            width: avatar,
            height: avatar,
            child: me,
          ),
        ],
      ),
    );
  }

  Widget _friends(
    List<FriendInfo> friends,
    bool open, {
    required double shift,
  }) {
    final ordered = selection.ordered(friends);
    final selectedCount = ordered
        .where((friend) => selection.isSelected(friend.id))
        .length;
    final extra = selectedCount > DayFriendsGeometry.stackMax
        ? selectedCount - DayFriendsGeometry.stackMax
        : 0;
    final motion = Listenable.merge([mode, offset]);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final i in [
          for (var k = selectedCount; k < ordered.length; k++) k,
          for (var k = 0; k < selectedCount; k++) k,
        ])
          _ColumnSlot(
            key: ValueKey(ordered[i].id),
            friend: ordered[i],
            index: i,
            stackIndex: i < selectedCount ? i : null,
            geometry: geometry,
            motion: motion,
            mode: mode,
            offset: offset,
            shift: shift,
            selected: selection.isSelected(ordered[i].id),
            onTap: open ? () => _toggle(ordered[i]) : null,
          ),
        if (extra > 0)
          _ColumnMore(
            count: extra,
            top: geometry.stackTop(DayFriendsGeometry.stackMax) - shift,
            mode: mode,
          ),
        _ColumnHint(
          top:
              (selectedCount > 0
                  ? geometry.bandTop - FriendColumnStyle.hintGap
                  : geometry.bandBottom) -
              FriendColumnStyle.hintSize -
              shift,
          travel: geometry.height,
          mode: mode,
          open: open,
          onTap: onShowFriends,
        ),
        if (!open && selectedCount > 0)
          Positioned(
            left: 0,
            right: 0,
            top: geometry.bandTop - shift - 8,
            height: geometry.bandHeight + 16,
            child: Semantics(
              button: true,
              label: 'Показать занятость друзей',
              child: GestureDetector(
                key: const ValueKey('friend-column-stack'),
                behavior: HitTestBehavior.opaque,
                onTap: onShowFriends,
              ),
            ),
          ),
      ],
    );
  }
}

class _ColumnSlot extends StatelessWidget {
  const _ColumnSlot({
    required this.friend,
    required this.index,
    required this.stackIndex,
    required this.geometry,
    required this.motion,
    required this.mode,
    required this.offset,
    required this.shift,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FriendInfo friend;
  final int index;

  final int? stackIndex;
  final DayFriendsGeometry geometry;
  final Listenable motion;
  final ValueListenable<double> mode;
  final ValueListenable<double> offset;
  final double shift;
  final bool selected;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    const avatar = DayFriendsGeometry.avatar;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: index.toDouble()),
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
          child: RingedAvatar(friend: friend, selected: selected),
        ),
      ),
      builder: (context, slot, child) => AnimatedBuilder(
        animation: motion,
        child: child,
        builder: (context, child) {
          final fold = dayFriendsFold(mode.value);
          final stack = stackIndex;
          final double top;
          var foldedScale = 1.0;
          var hidden = false;
          if (stack != null) {
            top = geometry.avatarTop(
              row: slot,
              stack: stack,
              offset: offset.value,
              fold: fold,
            );
            if (stack >= DayFriendsGeometry.stackMax) {
              foldedScale = 0;
              hidden = true;
            }
          } else {
            top = geometry.hiddenTop(
              row: slot,
              offset: offset.value,
              fold: fold,
            );
            hidden = true;
          }
          return Positioned(
            left: DayFriendsGeometry.gutter,
            top: top - shift,
            width: avatar,
            height: avatar,
            child: ExcludeSemantics(
              excluding: hidden && fold > 0.5,
              child: Transform.scale(
                scale: _lerp(1, foldedScale, _settling(fold)),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

double _settling(double fold) =>
    Curves.easeOut.transform(((fold - 0.6) / 0.4).clamp(0.0, 1.0));

class _ColumnMore extends StatelessWidget {
  const _ColumnMore({
    required this.count,
    required this.top,
    required this.mode,
  });

  final int count;
  final double top;
  final ValueListenable<double> mode;

  @override
  Widget build(BuildContext context) {
    const avatar = DayFriendsGeometry.avatar;
    return Positioned(
      left: DayFriendsGeometry.gutter,
      top: top,
      width: avatar,
      height: avatar,
      child: ValueListenableBuilder<double>(
        valueListenable: mode,
        child: AvatarOverflow(count: count, size: DayFriendsGeometry.avatar),
        builder: (context, t, child) =>
            Transform.scale(scale: _settling(dayFriendsFold(t)), child: child),
      ),
    );
  }
}

class _ColumnHint extends StatelessWidget {
  const _ColumnHint({
    required this.top,
    required this.travel,
    required this.mode,
    required this.open,
    required this.onTap,
  });

  final double top;
  final double travel;
  final ValueListenable<double> mode;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    left: 0,
    right: 0,
    top: top,
    height: FriendColumnStyle.hintSize,
    child: IgnorePointer(
      ignoring: open,
      child: Semantics(
        button: true,
        label: 'Показать строки друзей',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ValueListenableBuilder<double>(
            valueListenable: mode,
            child: const Center(
              child: ChevronIcon(
                key: ValueKey('day-swipe-hint'),
                color: FriendBarStyle.arrow,
                size: FriendColumnStyle.hintSize,
                quarterTurns: 1,
              ),
            ),
            builder: (context, t, chevron) => Transform.translate(
              offset: Offset(0, travel * (1 - dayFriendsFold(t))),
              child: chevron,
            ),
          ),
        ),
      ),
    ),
  );
}
