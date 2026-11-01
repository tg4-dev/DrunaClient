import 'dart:math' as math;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// "Отметить присутствие" on a shared event (design-system §9.8): "Да" and
/// "Нет" with the people who gave that answer. Who has not answered shows
/// under the title, in "Вместе с".
/// The user's answer fills its button in their colour; ✕ by the title
/// takes it back. The organizer always goes: "Нет" shakes, and a second
/// tap soon after asks to call the event off.
class AttendanceBlock extends StatefulWidget {
  const AttendanceBlock({
    required this.me,
    required this.own,
    required this.mine,
    required this.organizer,
    required this.going,
    required this.notGoing,
    required this.onAnswer,
    required this.onCancelEvent,
    this.enabled = true,
    super.key,
  });

  final FriendInfo me;
  final Color own;
  final RsvpStatus mine;

  /// The user organizes it: their answer is always yes.
  final bool organizer;
  final List<FriendInfo> going;
  final List<FriendInfo> notGoing;
  final ValueChanged<RsvpStatus> onAnswer;
  final VoidCallback onCancelEvent;
  final bool enabled;

  /// A second "Нет" from the organizer within this asks to cancel.
  static const doubleTap = Duration(milliseconds: 1500);

  @override
  State<AttendanceBlock> createState() => _AttendanceBlockState();
}

class _AttendanceBlockState extends State<AttendanceBlock>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  DateTime? _lastNo;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(RsvpStatus answer) {
    if (!widget.organizer) {
      if (answer != widget.mine) widget.onAnswer(answer);
      return;
    }
    if (answer == RsvpStatus.going) return;
    final now = DateTime.now();
    final last = _lastNo;
    if (last != null && now.difference(last) <= AttendanceBlock.doubleTap) {
      _lastNo = null;
      widget.onCancelEvent();
      return;
    }
    _lastNo = now;
    HapticFeedback.heavyImpact();
    _shake.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final ink = eventInk(widget.own);
    final mine = widget.mine;
    final answered = mine != RsvpStatus.pending && !widget.organizer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Отметить присутствие',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: EventPageStyle.label.copyWith(
                  color: const Color(0xE6FFFFFF),
                ),
              ),
            ),
            // The organizer always goes: nothing to answer or take back.
            if (!widget.organizer) ...[
              const SizedBox(width: 10),
              // One fixed slot for the avatar and ✕, so swapping them
              // moves nothing.
              SizedBox(
                width: 32,
                height: 32,
                child: AnimatedSwitcher(
                  duration: EventPageStyle.fade,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: answered
                      ? Semantics(
                          key: const ValueKey('rsvp-reset'),
                          button: true,
                          label: 'Убрать ответ',
                          excludeSemantics: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: widget.enabled
                                ? () => widget.onAnswer(RsvpStatus.pending)
                                : null,
                            child: const Center(
                              child: Icon(
                                CupertinoIcons.xmark,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          key: const ValueKey('rsvp-me'),
                          child: PersonAvatar(
                            id: widget.me.id,
                            name: widget.me.name,
                            username: widget.me.username,
                            size: 28,
                            color: widget.own,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        _row(
          button: _answer(
            key: const ValueKey('rsvp-going'),
            text: 'Да',
            picked: mine == RsvpStatus.going,
            ink: ink,
            onTap: () => _tap(RsvpStatus.going),
          ),
          people: widget.going,
        ),
        const SizedBox(height: 14),
        _row(
          button: AnimatedBuilder(
            animation: _shake,
            builder: (context, child) {
              final t = _shake.value;
              final dx = math.sin(t * math.pi * 6) * 9 * (1 - t);
              return Transform.translate(offset: Offset(dx, 0), child: child);
            },
            child: _answer(
              key: const ValueKey('rsvp-not-going'),
              text: 'Нет',
              picked: mine == RsvpStatus.notGoing,
              ink: ink,
              onTap: () => _tap(RsvpStatus.notGoing),
            ),
          ),
          people: widget.notGoing,
        ),
      ],
    );
  }

  Widget _answer({
    required Key key,
    required String text,
    required bool picked,
    required Color ink,
    required VoidCallback onTap,
  }) {
    return PillButton(
      key: key,
      text: text,
      width: PillStyle.wide,
      fill: picked ? widget.own : PillStyle.fill,
      color: picked ? ink : Colors.white,
      onPressed: widget.enabled ? onTap : null,
    );
  }

  Widget _row({required Widget button, required List<FriendInfo> people}) {
    return Row(
      children: [
        button,
        const SizedBox(width: 16),
        Expanded(
          child: _Faces(people: people, me: widget.me, own: widget.own),
        ),
      ],
    );
  }
}

/// Overlapping avatars, left to right, each lying over the one on its
/// right. One that arrives after the row was first shown lands from the
/// left on top of the others while they slide right to make room.
class _Faces extends StatefulWidget {
  const _Faces({required this.people, required this.me, required this.own});

  final List<FriendInfo> people;
  final FriendInfo me;
  final Color own;

  @override
  State<_Faces> createState() => _FacesState();
}

class _FacesState extends State<_Faces> {
  /// A little smaller than the button beside them.
  static const _size = 36.0;
  static const _step = 26.0;
  static const _shown = 6;

  /// Who was in the row when it was first shown: they do not land.
  late final Set<int> _first = {for (final person in widget.people) person.id};

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final shown = widget.people.take(_shown).toList();
    final extra = widget.people.length - shown.length;
    final width = shown.isEmpty ? 0.0 : _size + (shown.length - 1) * _step;
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : EventPageStyle.motion,
        curve: Curves.easeOutCubic,
        width: width + (extra > 0 ? 44 : 0),
        height: _size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Painted right to left: the leftmost ends up on top.
            for (var i = shown.length - 1; i >= 0; i--)
              AnimatedPositioned(
                key: ValueKey('face-${shown[i].id}'),
                duration: reduce ? Duration.zero : EventPageStyle.motion,
                curve: Curves.easeOutCubic,
                left: i * _step,
                top: 0,
                child: _Land(
                  play: !reduce && !_first.contains(shown[i].id),
                  from: _step,
                  child: PersonAvatar(
                    id: shown[i].id,
                    name: shown[i].name,
                    username: shown[i].username,
                    size: _size,
                    color: shown[i].id == widget.me.id ? widget.own : null,
                  ),
                ),
              ),
            if (extra > 0)
              Positioned(
                left: width + 8,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Text('+$extra', style: EventPageStyle.caption),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Drops in the first time it is built: from [from] to the left and a
/// little above, slightly large and clear, onto its place.
class _Land extends StatelessWidget {
  const _Land({required this.play, required this.from, required this.child});

  final bool play;
  final double from;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!play) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-from * (1 - t), -14 * (1 - t)),
          child: Transform.scale(scale: 1.25 - 0.25 * t, child: child),
        ),
      ),
    );
  }
}
