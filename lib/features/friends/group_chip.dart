import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/profile/event_chip.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter/cupertino.dart';

abstract final class GroupChipStyle {
  static const height = 56.0;
  static const maxWidth = 260.0;
  static const padding = 16.0;
  static const gap = 8.0;

  static const face = 20.0;
  static const faceStep = 12.0;
  static const faceMax = 3;

  static const openHeight = 64.0;
  static const openInset = 12.0;
  static const openAvatar = 48.0;
  static const openStep = 56.0;
  static const close = 22.0;
  static const closeGap = 16.0;

  static const nameSize = 20.0;
  static const captionSize = 13.0;
  static const captionGap = 4.0;

  static const fade = 16.0;
  static const dim = EventChipStyle.dim;

  static const closeColor = Color(0x99FFFFFF);
  static const captionColor = Color(0x99FFFFFF);
}

TextStyle groupChipNameStyle(AvatarFont font) =>
    font.style(GroupChipStyle.nameSize, const Color(0xFFFFFFFF));

double groupFacesWidth(int people) {
  if (people <= 0) return 0;
  final shown = people.clamp(1, GroupChipStyle.faceMax);
  return GroupChipStyle.face + GroupChipStyle.faceStep * (shown - 1);
}

double groupNameRoom(int people) =>
    GroupChipStyle.maxWidth -
    2 * GroupChipStyle.padding -
    (people > 0 ? GroupChipStyle.gap + groupFacesWidth(people) : 0);

double closedGroupChipWidth({required double nameWidth, required int people}) {
  final room = groupNameRoom(people);
  final name = nameWidth < room ? nameWidth : room;
  return 2 * GroupChipStyle.padding +
      name +
      (people > 0 ? GroupChipStyle.gap + groupFacesWidth(people) : 0);
}

double openGroupChipWidth(int people) =>
    GroupChipStyle.openInset +
    people * GroupChipStyle.openStep -
    (GroupChipStyle.openStep - GroupChipStyle.openAvatar) +
    GroupChipStyle.closeGap +
    GroupChipStyle.close +
    GroupChipStyle.closeGap;

double openGroupMemberLeft(double chipLeft, int index) =>
    chipLeft + GroupChipStyle.openInset + index * GroupChipStyle.openStep;

double groupNameWidth(BuildContext context, String name, AvatarFont font) {
  final painter = TextPainter(
    text: TextSpan(text: shownName(name), style: groupChipNameStyle(font)),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

double capCenterShift(BuildContext context, TextStyle style, AvatarFont font) {
  final scaler = MediaQuery.textScalerOf(context);
  final painter = TextPainter(
    text: TextSpan(text: 'Н', style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final baseline = painter.computeDistanceToActualBaseline(
    TextBaseline.alphabetic,
  );
  final height = painter.height;
  painter.dispose();
  final size = scaler.scale(style.fontSize ?? GroupChipStyle.nameSize);
  return height / 2 - (baseline - font.capHeight * size / 2);
}

List<Color> groupChipColors(List<FriendInfo> people) => [
  for (final person in people)
    Color.lerp(
      avatarColorFor(id: person.id, username: person.username),
      const Color(0xFF000000),
      GroupChipStyle.dim,
    )!,
];

class GroupChipFace extends StatelessWidget {
  const GroupChipFace({
    required this.name,
    required this.font,
    required this.people,
    required this.morph,
    required this.closedWidth,
    required this.onClose,
    this.captionFade = 1,
    super.key,
  });

  final String name;
  final AvatarFont font;
  final List<FriendInfo> people;

  final double morph;
  final double closedWidth;
  final double captionFade;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = morph;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return CustomPaint(
          painter: ChipFill(colors: groupChipColors(people), radius: null),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (t <= 0) _faces() else if (t < 1) ..._morphing(size),
              _name(context, size),
              if (t > 0) _close(),
            ],
          ),
        );
      },
    );
  }

  Widget _faces() {
    if (people.isEmpty) return const SizedBox.shrink();
    return Positioned(
      right: GroupChipStyle.padding,
      top: 0,
      bottom: 0,
      child: Center(
        child: FaceStack(
          people: people,
          size: GroupChipStyle.face,
          max: GroupChipStyle.faceMax,
          step: GroupChipStyle.faceStep,
        ),
      ),
    );
  }

  List<Widget> _morphing(Size size) {
    final t = morph;
    final facesLeft =
        closedWidth - GroupChipStyle.padding - groupFacesWidth(people.length);
    final previews = people.length.clamp(1, GroupChipStyle.faceMax);
    const avatar = FriendBarStyle.avatar;
    return [
      for (var i = 0; i < people.length; i++)
        () {
          final preview = i < previews ? i : previews - 1;
          final fromX =
              facesLeft +
              preview * GroupChipStyle.faceStep +
              GroupChipStyle.face / 2;
          final toX =
              GroupChipStyle.openInset +
              i * GroupChipStyle.openStep +
              GroupChipStyle.openAvatar / 2;
          final fromScale = i < previews ? GroupChipStyle.face / avatar : 0.0;
          const toScale = GroupChipStyle.openAvatar / avatar;
          final x = fromX + (toX - fromX) * t;
          return Positioned(
            left: x - avatar / 2,
            top: (size.height - avatar) / 2,
            width: avatar,
            height: avatar,
            child: IgnorePointer(
              child: Transform.scale(
                scale: fromScale + (toScale - fromScale) * t,
                child: RingedAvatar(friend: people[i], selected: true),
              ),
            ),
          );
        }(),
    ];
  }

  Widget _name(BuildContext context, Size size) {
    final t = morph;
    final style = groupChipNameStyle(font);
    const scale = GroupChipStyle.captionSize / GroupChipStyle.nameSize;
    final room =
        closedWidth -
        2 * GroupChipStyle.padding -
        (people.isEmpty
            ? 0
            : GroupChipStyle.gap + groupFacesWidth(people.length));
    final fit = fitTitle(
      shownName(name),
      style,
      groupNameRoom(people.length),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    );
    final color = Color.lerp(
      const Color(0xFFFFFFFF),
      GroupChipStyle.captionColor,
      t,
    )!;
    final fade = 1 - (1 - captionFade) * t;
    Widget title = FitTitle(
      text: name,
      style: style.copyWith(color: color.withValues(alpha: color.a * fade)),
      maxLines: 1,
    );
    if (fit.overflows) {
      title = ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => LinearGradient(
          colors: const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          stops: [1 - GroupChipStyle.fade / rect.width, 1],
        ).createShader(rect),
        child: title,
      );
    }
    final lineHeight = fit.lineHeight;
    final shift = capCenterShift(
      context,
      style.copyWith(fontSize: fit.fontSize),
      font,
    );
    final closedTop = (size.height - lineHeight) / 2 + shift;
    final openTop = -GroupChipStyle.captionGap - lineHeight * scale;
    final left =
        GroupChipStyle.padding +
        (GroupChipStyle.openInset - GroupChipStyle.padding) * t;
    return Positioned(
      left: left,
      top: closedTop + (openTop - closedTop) * t,
      width: room,
      height: lineHeight,
      child: IgnorePointer(
        child: Transform.scale(
          key: const ValueKey('group-chip-name'),
          alignment: Alignment.topLeft,
          scale: 1 + (scale - 1) * t,
          child: ClipRect(child: title),
        ),
      ),
    );
  }

  Widget _close() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: Semantics(
        button: true,
        label: 'Закрыть группу ${shownName(name)}',
        excludeSemantics: true,
        child: GestureDetector(
          key: const ValueKey('group-chip-close'),
          behavior: HitTestBehavior.opaque,
          onTap: morph >= 1 ? onClose : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: GroupChipStyle.closeGap,
            ),
            child: Center(
              child: Transform.scale(
                scale: morph,
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: GroupChipStyle.close,
                  color: GroupChipStyle.closeColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
