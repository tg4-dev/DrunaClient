import 'dart:ui' as ui;

import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Measurements of the friend bar at the bottom of the calendar.
abstract final class FriendBarStyle {
  static const avatar = 56.0;
  static const step = 68.0;
  static const gutter = 20.0;
  static const height = 64.0;

  /// The stack of selected friends while the user's own events are shown.
  static const stackAvatar = 48.0;
  static const stackStep = 22.0;
  static const stackMax = 3;

  static const ring = 3.0;
  static const ringGap = 3.0;

  static const reorder = Duration(milliseconds: 200);
  static const select = Duration(milliseconds: 160);

  /// Progressive blur at each edge: bands from the edge inwards.
  static const edgeBands = [8.0, 5.0, 3.0, 1.5];
  static const edgeBand = 6.0;
}

/// All friends at the bottom of the calendar. Picked friends get a ring and
/// move to the front; their busy time shows in the month. While the user's
/// own events are shown ([mode] near 0) the bar folds into a stack of the
/// picked friends at the right, following the finger.
class FriendBar extends StatefulWidget {
  const FriendBar({
    required this.friends,
    required this.selection,
    required this.mode,
    required this.onShowFriends,
    required this.onAddFriends,
    this.schedulesAvailable = true,
    super.key,
  });

  /// Null while loading.
  final List<FriendInfo>? friends;
  final FriendSelection selection;
  final ValueListenable<double> mode;

  /// A tap on the folded stack: back to friends' calendar.
  final VoidCallback onShowFriends;

  /// No friends yet: go to the friends page.
  final VoidCallback onAddFriends;

  /// False when there is no way to get friends' busy time.
  final bool schedulesAvailable;

  @override
  State<FriendBar> createState() => _FriendBarState();
}

class _FriendBarState extends State<FriendBar> {
  final _scroll = ScrollController();

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
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return ListenableBuilder(
          listenable: Listenable.merge([widget.selection, widget.mode]),
          builder: (context, _) {
            final t = widget.mode.value;
            final shown = t >= 0.5;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hint(
                  text: _hint(friends),
                  visible: shown,
                  opacity: ((t - 0.5) * 2).clamp(0.0, 1.0),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: FriendBarStyle.height,
                  child: friends == null
                      ? _Placeholder(opacity: t)
                      : friends.isEmpty
                      ? _AddFriends(opacity: t, onTap: widget.onAddFriends)
                      : _row(friends, width, t),
                ),
              ],
            );
          },
        );
      },
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

  Widget _row(List<FriendInfo> friends, double width, double t) {
    final ordered = widget.selection.ordered(friends);
    final selectedCount = ordered
        .where((friend) => widget.selection.isSelected(friend.id))
        .length;
    final contentWidth =
        FriendBarStyle.gutter * 2 +
        ordered.length * FriendBarStyle.step -
        (FriendBarStyle.step - FriendBarStyle.avatar);
    final geometry = _StackGeometry(width: width, selected: selectedCount);
    final expanded = t >= 0.5;
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
              child: AnimatedBuilder(
                animation: _scroll,
                builder: (context, _) {
                  final offset = _scroll.hasClients ? _scroll.offset : 0.0;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i < ordered.length; i++)
                        _FriendSlot(
                          key: ValueKey(ordered[i].id),
                          friend: ordered[i],
                          index: i,
                          stackIndex: i < selectedCount ? i : null,
                          geometry: geometry,
                          scrollOffset: offset,
                          mode: t,
                          selected: widget.selection.isSelected(ordered[i].id),
                          onTap: () => _toggle(ordered[i]),
                        ),
                      if (geometry.extra > 0)
                        _MoreSlot(
                          count: geometry.extra,
                          left:
                              geometry.slotLeft(FriendBarStyle.stackMax) +
                              offset,
                          opacity: 1 - t,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (!expanded && selectedCount > 0)
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
        if (t > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: const _EdgeBlur(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Where the folded stack of selected friends sits, right-aligned.
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

  /// Screen x of slot [k], counted from the left of the stack.
  double slotLeft(int k) =>
      width -
      FriendBarStyle.gutter -
      FriendBarStyle.stackAvatar -
      (slots - 1 - k) * FriendBarStyle.stackStep;
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// One friend. Its place in the row animates when the order changes; its
/// way into the stack follows [mode] directly.
class _FriendSlot extends StatelessWidget {
  const _FriendSlot({
    required this.friend,
    required this.index,
    required this.stackIndex,
    required this.geometry,
    required this.scrollOffset,
    required this.mode,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FriendInfo friend;
  final int index;

  /// Position in the folded stack; null for friends that are not picked.
  final int? stackIndex;
  final _StackGeometry geometry;
  final double scrollOffset;
  final double mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final fold = Curves.easeOutCubic.transform(1 - mode.clamp(0.0, 1.0));
    return TweenAnimationBuilder<double>(
      tween: Tween(end: index.toDouble()),
      duration: reduce ? Duration.zero : FriendBarStyle.reorder,
      curve: Curves.easeOutCubic,
      builder: (context, slot, child) {
        final rowLeft = FriendBarStyle.gutter + slot * FriendBarStyle.step;
        final stack = stackIndex;
        final double foldedLeft;
        final double foldedSize;
        var foldedOpacity = 1.0;
        if (stack == null) {
          // Not picked: slides off to the right and fades.
          foldedLeft = geometry.width + FriendBarStyle.gutter + slot * 12;
          foldedSize = FriendBarStyle.stackAvatar;
          foldedOpacity = 0;
        } else if (stack < FriendBarStyle.stackMax) {
          foldedLeft = geometry.slotLeft(stack);
          foldedSize = FriendBarStyle.stackAvatar;
        } else {
          // Beyond the stack: tucks under "+N".
          foldedLeft = geometry.slotLeft(FriendBarStyle.stackMax);
          foldedSize = FriendBarStyle.stackAvatar;
          foldedOpacity = 0;
        }
        final size = _lerp(FriendBarStyle.avatar, foldedSize, fold);
        final left = _lerp(rowLeft, foldedLeft + scrollOffset, fold);
        final opacity = _lerp(1, foldedOpacity, fold);
        return Positioned(
          left: left,
          top: (FriendBarStyle.height - size) / 2,
          width: size,
          height: size,
          child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
        );
      },
      child: Semantics(
        button: true,
        selected: selected,
        label: friendName(friend),
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: _RingedAvatar(friend: friend, selected: selected),
        ),
      ),
    );
  }
}

/// The avatar, with a ring in a lighter shade of its colour when picked.
class _RingedAvatar extends StatelessWidget {
  const _RingedAvatar({required this.friend, required this.selected});

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
    required this.left,
    required this.opacity,
  });

  final int count;
  final double left;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final fade = Curves.easeOutCubic.transform(opacity.clamp(0.0, 1.0));
    return Positioned(
      left: left,
      top: (FriendBarStyle.height - FriendBarStyle.stackAvatar) / 2,
      width: FriendBarStyle.stackAvatar,
      height: FriendBarStyle.stackAvatar,
      child: Opacity(
        opacity: fade,
        child: Container(
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SheetStyle.chip,
            shape: BoxShape.circle,
          ),
          child: Text(
            '+$count',
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Blur that grows towards both screen edges, over whatever is under the
/// bar: avatars scrolling out and the calendar behind.
class _EdgeBlur extends StatelessWidget {
  const _EdgeBlur();

  @override
  Widget build(BuildContext context) {
    Widget side({required bool left}) => Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: FriendBarStyle.edgeBand * FriendBarStyle.edgeBands.length,
      child: Row(
        children: [
          for (final sigma
              in left
                  ? FriendBarStyle.edgeBands
                  : FriendBarStyle.edgeBands.reversed)
            SizedBox(
              width: FriendBarStyle.edgeBand,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
    return Stack(children: [side(left: true), side(left: false)]);
  }
}

class _Hint extends StatelessWidget {
  const _Hint({
    required this.text,
    required this.visible,
    required this.opacity,
  });

  final String? text;
  final bool visible;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final message = text;
    return SizedBox(
      height: 32,
      child: Center(
        child: AnimatedOpacity(
          duration: FriendBarStyle.select,
          opacity: message != null && visible ? opacity : 0,
          child: message == null
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                    color: SheetStyle.block.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: SheetStyle.muted,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
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
  const _AddFriends({required this.opacity, required this.onTap});

  final double opacity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: opacity < 0.5,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Center(
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SheetStyle.block,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Добавить друзей',
                style: TextStyle(
                  color: SheetStyle.accent,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
