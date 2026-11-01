import 'dart:math' as math;

import 'package:druna_app/core/api/api_exception.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/invites/invite.dart';
import 'package:druna_app/features/invites/invite_events.dart';
import 'package:druna_app/features/invites/invites_source.dart';
import 'package:druna_app/features/invites/invites_store.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/page_parts.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Measurements of the invite cards in the profile (design-system §9.8).
abstract final class InviteCardStyle {
  /// A card takes this share of the page width, so the next one peeks in.
  static const share = 0.8;
  static const maxWidth = 320.0;
  static const height = 196.0;
  static const gap = 12.0;
  static const radius = 28.0;
  static const padding = 18.0;

  /// Past cards are smaller and darker.
  static const pastShare = 0.6;
  static const pastHeight = 124.0;
  static const pastDim = 0.45;

  static const avatar = 28.0;
  static const avatarStep = 20.0;
  static const avatarsShown = 4;
}

/// The user's invites in the profile: a shelf of large cards, those waiting
/// for an answer first, then what is coming; under it a shelf of the past.
/// Both scroll sideways and stop at a card. Full width of the screen: the
/// page gives it no side margins (design-system §9.3, §9.8).
class InvitesSection extends StatelessWidget {
  const InvitesSection({
    required this.store,
    required this.me,
    required this.own,
    required this.onOpen,
    this.now,
    super.key,
  });

  final InvitesStore store;
  final FriendInfo me;
  final Color own;
  final ValueChanged<String> onOpen;

  /// For tests; the clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _children(constraints.maxWidth),
        ),
      ),
    );
  }

  List<Widget> _children(double width) {
    final invites = store.invites;
    final error = store.error;
    Widget note(Widget child) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: PageStyle.gutter),
      child: DecoratedBox(
        decoration: SheetStyle.blockDecoration,
        child: Padding(padding: SheetStyle.blockPadding, child: child),
      ),
    );
    if (invites == null) {
      return [const _Header(), note(const CupertinoActivityIndicator())];
    }
    if (error != null && invites.isEmpty) {
      return [
        const _Header(),
        note(
          _Note(
            text: error is ApiException
                ? error.message
                : 'Не удалось загрузить события',
            // Nothing to retry while the server has no invites at all.
            action: error is InvitesUnavailable ? null : 'Повторить',
            onAction: store.load,
          ),
        ),
      ];
    }
    final now = this.now ?? DateTime.now();
    final waiting = <Invite>[];
    final coming = <Invite>[];
    final past = <Invite>[];
    for (final invite in invites) {
      final status = invite.statusOf(me.id);
      if (status == null) continue;
      if (invite.end.isBefore(now)) {
        if (status != RsvpStatus.notGoing) past.add(invite);
      } else if (status == RsvpStatus.pending) {
        waiting.add(invite);
      } else {
        coming.add(invite);
      }
    }
    int soonest(Invite a, Invite b) => a.start.compareTo(b.start);
    waiting.sort(soonest);
    coming.sort(soonest);
    past.sort((a, b) => b.start.compareTo(a.start));

    final page = width - PageStyle.gutter * 2;
    final card = math.min(
      page * InviteCardStyle.share,
      InviteCardStyle.maxWidth,
    );
    final upcoming = [...waiting, ...coming];
    return [
      _Header(waiting: waiting.length),
      if (upcoming.isEmpty)
        note(
          const _Note(text: 'Зажми день в календаре друзей, чтобы позвать их'),
        )
      else
        _Shelf(
          itemWidth: card,
          height: InviteCardStyle.height,
          children: [for (final invite in upcoming) _card(invite, card)],
        ),
      if (past.isNotEmpty) ...[
        const Padding(
          padding: EdgeInsets.fromLTRB(PageStyle.gutter, 20, 0, 8),
          child: Text('ПРОШЕДШИЕ', style: SheetStyle.caption),
        ),
        _Shelf(
          itemWidth: card * InviteCardStyle.pastShare / InviteCardStyle.share,
          height: InviteCardStyle.pastHeight,
          children: [
            for (final invite in past)
              _card(
                invite,
                card * InviteCardStyle.pastShare / InviteCardStyle.share,
                past: true,
              ),
          ],
        ),
      ],
    ];
  }

  Widget _card(Invite invite, double width, {bool past = false}) {
    final status = invite.statusOf(me.id)!;
    final organizer = invite.isOrganizer(me.id);
    final others = [
      for (final person in invite.people)
        if (person.id != me.id) person,
    ];
    final when = invite.allDay ? 'Весь день' : clockLabel(invite.start);
    var colors = inviteColors(invite, meId: me.id, own: own);
    if (past) {
      colors = [
        for (final color in colors)
          Color.lerp(color, Colors.black, InviteCardStyle.pastDim)!,
      ];
    }
    return _InviteCard(
      key: ValueKey('invite-row-${invite.id}'),
      colors: colors,
      day: invite.start,
      title: invite.title.trim().isEmpty ? 'Без названия' : invite.title,
      subtitle: [when, if (others.isNotEmpty) peopleLabel(others)].join(' · '),
      people: others,
      status: organizer ? 'Организую' : rsvpLabel(status),
      waiting: status == RsvpStatus.pending && !past,
      past: past,
      onTap: () => onOpen(invite.id),
    );
  }
}

/// "События" with its icon, like the title of a block; on the right how
/// many invites wait for an answer.
class _Header extends StatelessWidget {
  const _Header({this.waiting = 0});

  final int waiting;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PageStyle.gutter + 4,
        0,
        PageStyle.gutter + 4,
        12,
      ),
      child: Row(
        children: [
          const Icon(
            CupertinoIcons.calendar_badge_plus,
            color: SheetStyle.muted,
            size: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(child: Text('События', style: SheetStyle.title)),
          if (waiting > 0)
            Text(
              'Ждут ответа · $waiting',
              style: SheetStyle.caption.copyWith(color: SheetStyle.accent),
            ),
        ],
      ),
    );
  }
}

/// A row of cards that scrolls sideways and stops with a card at the left
/// margin; the next one peeks in from the right.
class _Shelf extends StatelessWidget {
  const _Shelf({
    required this.itemWidth,
    required this.height,
    required this.children,
  });

  final double itemWidth;
  final double height;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: _SnapPhysics(
          step: itemWidth + InviteCardStyle.gap,
          parent: const BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: PageStyle.gutter),
        itemCount: children.length,
        separatorBuilder: (context, _) =>
            const SizedBox(width: InviteCardStyle.gap),
        itemBuilder: (context, index) =>
            SizedBox(width: itemWidth, child: children[index]),
      ),
    );
  }
}

/// Settles on a multiple of [step], like [PageScrollPhysics] but for items
/// narrower than the view; the end of the list still stops at its edge.
class _SnapPhysics extends ScrollPhysics {
  const _SnapPhysics({required this.step, super.parent});

  final double step;

  @override
  _SnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _SnapPhysics(step: step, parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    var item = position.pixels / step;
    if (velocity < -tolerance.velocity) {
      item -= 0.5;
    } else if (velocity > tolerance.velocity) {
      item += 0.5;
    }
    final target = (item.roundToDouble() * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < tolerance.distance) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target,
      velocity,
      tolerance: tolerance,
    );
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _Note extends StatelessWidget {
  const _Note({required this.text, this.action, this.onAction});

  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: SheetStyle.row),
        if (action != null)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: PillButton(text: action, onPressed: onAction),
          ),
      ],
    );
  }
}

/// One invite: a card in the gradient of the people's colours with the
/// day, the user's answer, the title, when and with whom.
class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.colors,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.people,
    required this.status,
    required this.waiting,
    required this.past,
    required this.onTap,
    super.key,
  });

  final List<Color> colors;
  final DateTime day;
  final String title;
  final String subtitle;
  final List<FriendInfo> people;
  final String status;

  /// No answer yet: the status reads "Ответить" and stands out.
  final bool waiting;
  final bool past;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = eventInk(mixedColor(colors));
    final soft = ink.withValues(alpha: 0.75);
    return Semantics(
      button: true,
      label: '$title, ${eventDateLabel(day)}, $subtitle, $status',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(InviteCardStyle.radius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors.length > 1 ? colors : [...colors, ...colors],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(InviteCardStyle.padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Date(day: day, ink: ink, soft: soft, small: past),
                    const Spacer(),
                    _Status(text: status, waiting: waiting, ink: ink),
                  ],
                ),
                const Spacer(),
                Text(
                  title,
                  maxLines: past ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ink,
                    fontSize: past ? 17 : 21,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (!past && people.isNotEmpty) ...[
                      _Faces(people: people, ring: mixedColor(colors)),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: soft,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "СБ" over "8".
class _Date extends StatelessWidget {
  const _Date({
    required this.day,
    required this.ink,
    required this.soft,
    required this.small,
  });

  final DateTime day;
  final Color ink;
  final Color soft;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${weekdayShort(day)} · ${monthShort(day)}'.toUpperCase(),
          style: TextStyle(
            color: soft,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        Text(
          '${day.day}',
          style: TextStyle(
            color: ink,
            fontSize: small ? 26 : 36,
            fontWeight: FontWeight.w700,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

/// The user's answer in a capsule; white with dark text while waiting.
class _Status extends StatelessWidget {
  const _Status({required this.text, required this.waiting, required this.ink});

  final String text;
  final bool waiting;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: const StadiumBorder(),
        color: waiting ? Colors.white : const Color(0x29000000),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Text(
          waiting ? 'Ответить' : text,
          style: TextStyle(
            color: waiting ? Colors.black : ink,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// The others in the invite, overlapping, each ringed in the card's colour.
class _Faces extends StatelessWidget {
  const _Faces({required this.people, required this.ring});

  final List<FriendInfo> people;
  final Color ring;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(InviteCardStyle.avatarsShown).toList();
    const size = InviteCardStyle.avatar;
    return SizedBox(
      width: size + (shown.length - 1) * InviteCardStyle.avatarStep,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * InviteCardStyle.avatarStep,
              child: Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
                child: PersonAvatar(
                  id: shown[i].id,
                  name: shown[i].name,
                  username: shown[i].username,
                  size: size - 4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
