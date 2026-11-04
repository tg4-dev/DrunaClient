import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

const defaultOwnColor = Color(0xFFAF52DE);
const defaultOwnColorSlot = 5;

const avatarPalette = <Color>[
  Color(0xFF34C759),
  Color(0xFFFFD60A),
  Color(0xFFFF9500),
  Color(0xFFFF3B30),
  Color(0xFFFF2D78),
  defaultOwnColor,
  Color(0xFF0A84FF),
  Color(0xFF30C8D6),
];

Color avatarColorFor({required int id, String username = ''}) {
  if (id > 0) return avatarPalette[avatarSlotFor(id)];
  var hash = 0x811C9DC5;
  for (final unit in username.toLowerCase().codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return avatarPalette[hash % avatarPalette.length];
}

const avatarHueStride = 3;

int avatarSlotFor(int id) => (id * avatarHueStride) % avatarPalette.length;

String avatarInitial(String name, [String username = '']) {
  for (final source in [name, username]) {
    final text = source.trim().replaceFirst(RegExp(r'^@+'), '');
    if (text.isNotEmpty) return text.characters.first.toUpperCase();
  }
  return '?';
}

const avatarInk = Colors.white;

class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.id,
    required this.name,
    this.username = '',
    this.size = 48,
    this.color,
    this.font,
    super.key,
  });

  final int id;
  final String name;
  final String username;
  final double size;

  final Color? color;

  final AvatarFont? font;

  @override
  Widget build(BuildContext context) {
    final own = OwnAvatar.maybeOf(context);
    final mine = own != null && id > 0 && own.id == id;
    final color =
        this.color ??
        (mine ? own.color : avatarColorFor(id: id, username: username));
    final font = this.font ?? (mine ? own.font : defaultAvatarFont);
    final label = name.trim().isNotEmpty ? name.trim() : username;
    return Semantics(
      label: 'Аватар $label',
      image: true,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: avatarGradient(color),
          shape: BoxShape.circle,
        ),
        child: AvatarLetter(
          letter: font.cased(avatarInitial(name, username)),
          font: font,
          size: size,
          color: avatarInk,
        ),
      ),
    );
  }
}

class OwnAvatar extends InheritedWidget {
  const OwnAvatar({
    required this.id,
    required this.color,
    required this.font,
    required super.child,
    super.key,
  });

  final int id;
  final Color color;
  final AvatarFont font;

  static OwnAvatar? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OwnAvatar>();

  @override
  bool updateShouldNotify(OwnAvatar old) =>
      old.id != id || old.color != color || old.font != font;
}

const avatarOverflowFill = Color(0x1AFFFFFF);

class AvatarOverflow extends StatelessWidget {
  const AvatarOverflow({required this.count, this.size = 48, super.key});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: PillSurface(
      fill: avatarOverflowFill,
      child: Center(
        child: Text(
          '+$count',
          textScaler: TextScaler.noScaling,
          maxLines: 1,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.36,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    ),
  );
}
