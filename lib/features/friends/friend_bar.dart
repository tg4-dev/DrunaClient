import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/friends/friend_selection.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:progressive_background_blur/progressive_background_blur.dart';

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

  /// Progressive blur at each edge: strongest at the edge, gone at [edge]
  /// from it. Sigma is in physical pixels, as the shader takes it.
  static const edge = 28.0;
  static const edgeSigma = 24.0;
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
    // Rebuilt for the selection and when the swipe crosses the middle —
    // never per frame. Per frame only the avatars move ([_FriendSlot]).
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
              const SizedBox(height: 8),
              SizedBox(
                height: FriendBarStyle.height,
                child: friends == null
                    ? _Placeholder(visible: expanded)
                    : friends.isEmpty
                    ? _AddFriends(visible: expanded, onTap: widget.onAddFriends)
                    : _row(friends, constraints.maxWidth, expanded),
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

  Widget _row(List<FriendInfo> friends, double width, bool expanded) {
    final ordered = widget.selection.ordered(friends);
    final selectedCount = ordered
        .where((friend) => widget.selection.isSelected(friend.id))
        .length;
    final contentWidth =
        FriendBarStyle.gutter * 2 +
        ordered.length * FriendBarStyle.step -
        (FriendBarStyle.step - FriendBarStyle.avatar);
    final geometry = _StackGeometry(width: width, selected: selectedCount);
    final motion = Listenable.merge([widget.mode, _scroll]);
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
                  // Not picked first, so the picked ones paint over them and
                  // the stack hides friends sliding out under it.
                  for (final i in [
                    for (var k = selectedCount; k < ordered.length; k++) k,
                    for (var k = 0; k < selectedCount; k++) k,
                  ])
                    _FriendSlot(
                      key: ValueKey(ordered[i].id),
                      friend: ordered[i],
                      index: i,
                      stackIndex: i < selectedCount ? i : null,
                      geometry: geometry,
                      motion: motion,
                      mode: widget.mode,
                      scroll: _scroll,
                      selected: widget.selection.isSelected(ordered[i].id),
                      onTap: () => _toggle(ordered[i]),
                    ),
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
        // The edge blur costs backdrop filters: it shows only once the bar
        // has settled open, never while it moves.
        Positioned.fill(
          child: IgnorePointer(
            child: ModeGate(
              mode: widget.mode,
              threshold: 0.999,
              builder: (context, open) => AnimatedOpacity(
                duration: FriendBarStyle.select,
                opacity: open ? 1 : 0,
                child: open ? const _EdgeBlur() : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Rebuilds [builder] only when [mode] crosses [threshold], so whatever
/// depends on "open or folded" does not rebuild on every frame of a swipe.
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

/// How far the bar is folded into the stack: 0 open, 1 folded.
double friendBarFold(double mode) =>
    Curves.easeInOutCubic.transform(1 - mode.clamp(0.0, 1.0));

/// One friend. Its place in the row animates when the order changes; its
/// way into the stack follows the mode directly. Per frame only a position
/// and a scale change: no opacity, no relayout of the avatar.
class _FriendSlot extends StatelessWidget {
  const _FriendSlot({
    required this.friend,
    required this.index,
    required this.stackIndex,
    required this.geometry,
    required this.motion,
    required this.mode,
    required this.scroll,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final FriendInfo friend;
  final int index;

  /// Position in the folded stack; null for friends that are not picked.
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
          final fold = friendBarFold(mode.value);
          final offset = scroll.hasClients ? scroll.offset : 0.0;
          final rowLeft = FriendBarStyle.gutter + slot * FriendBarStyle.step;
          final stack = stackIndex;
          // Picked friends glide into the stack; the rest always slide off
          // to the right, under the stack (they are painted below it).
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
            // Beyond the stack: shrinks under "+N".
            foldedLeft =
                geometry.slotLeft(FriendBarStyle.stackMax) -
                (avatar - FriendBarStyle.stackAvatar) / 2 +
                offset;
            foldedScale = 0;
            hidden = true;
          } else {
            // Past the right edge of the screen, keeping their order.
            foldedLeft =
                geometry.width + FriendBarStyle.gutter + slot * 12 + offset;
            foldedScale = FriendBarStyle.stackAvatar / avatar;
            hidden = true;
          }
          return Positioned(
            left: _lerp(rowLeft, foldedLeft, fold),
            top: (FriendBarStyle.height - avatar) / 2,
            width: avatar,
            height: avatar,
            // Off screen or under "+N": gone for VoiceOver too.
            child: ExcludeSemantics(
              excluding: hidden && fold > 0.5,
              child: Transform.scale(
                scale: _lerp(1, foldedScale, fold),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The avatar, with a ring in a lighter shade of its colour when picked.
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
      builder: (context, child) {
        final offset = scroll.hasClients ? scroll.offset : 0.0;
        return Positioned(
          left: geometry.slotLeft(FriendBarStyle.stackMax) + offset,
          top: (FriendBarStyle.height - FriendBarStyle.stackAvatar) / 2,
          width: FriendBarStyle.stackAvatar,
          height: FriendBarStyle.stackAvatar,
          // Grows in as the bar folds; a scale, not a fade.
          child: Transform.scale(
            scale: friendBarFold(mode.value),
            child: child,
          ),
        );
      },
    );
  }
}

/// Blur that grows towards both screen edges, over whatever is under the
/// bar: avatars scrolling out and the calendar behind.
class _EdgeBlur extends StatelessWidget {
  const _EdgeBlur();

  @override
  Widget build(BuildContext context) {
    // One continuous blur per edge (`progressive_background_blur`), instead
    // of stepped bands of backdrop filters, which showed their seams.
    // The clip is required: unclipped, the backdrop layer filters the whole
    // screen, and the blur ran down both edges of the month.
    Widget side({required bool left}) => Positioned(
      left: left ? 0 : null,
      right: left ? null : 0,
      top: 0,
      bottom: 0,
      width: FriendBarStyle.edge,
      child: ClipRect(
        child: ProgressiveBlur(
          begin: left ? Alignment.centerLeft : Alignment.centerRight,
          end: left ? Alignment.centerRight : Alignment.centerLeft,
          sigmaStart: FriendBarStyle.edgeSigma,
          sigmaEnd: 0,
          child: const SizedBox.expand(),
        ),
      ),
    );
    return Stack(children: [side(left: true), side(left: false)]);
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
      height: 32,
      child: Center(
        child: AnimatedOpacity(
          duration: FriendBarStyle.select,
          opacity: message != null && visible ? 1 : 0,
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
  const _AddFriends({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedOpacity(
        duration: FriendBarStyle.select,
        opacity: visible ? 1 : 0,
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
