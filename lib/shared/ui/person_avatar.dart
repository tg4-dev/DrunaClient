import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:flutter/material.dart';

/// Eight colours for everyone (design-system §2.3, docs/avatar.md), the
/// nearest hues of the earlier palette of 16 (softer than Figma's first
/// draft): the
/// user picks theirs, friends get one by id. Change a colour in place and
/// add new ones at the end: the user's choice is kept as an index.
const avatarPalette = <Color>[
  Color(0xFF34C759),
  Color(0xFFFFD60A),
  Color(0xFFFF9500),
  Color(0xFFFF3B30),
  Color(0xFFFF2D78),
  Color(0xFFAF52DE),
  Color(0xFF0A84FF),
  Color(0xFF30C8D6),
];

/// The same person always gets the same colour: by server id, or by username
/// when there is no id yet. The username hash is spelled out rather than
/// `String.hashCode`, which may differ between platforms and runs.
///
/// Ids step through the palette by [avatarHueStride], so people with
/// neighbouring ids (friends who joined together) get far-apart hues.
Color avatarColorFor({required int id, String username = ''}) {
  if (id > 0) return avatarPalette[avatarSlotFor(id)];
  var hash = 0x811C9DC5;
  for (final unit in username.toLowerCase().codeUnits) {
    hash = ((hash ^ unit) * 0x01000193) & 0xFFFFFFFF;
  }
  return avatarPalette[hash % avatarPalette.length];
}

/// Coprime with 8: every slot is used once per 8 ids, and neighbouring ids
/// land three colours apart.
const avatarHueStride = 3;

int avatarSlotFor(int id) => (id * avatarHueStride) % avatarPalette.length;

/// First letter of the name, else of the username, else "?". Takes a whole
/// grapheme, so an emoji or a letter with a combining mark stays intact.
String avatarInitial(String name, [String username = '']) {
  for (final source in [name, username]) {
    final text = source.trim().replaceFirst(RegExp(r'^@+'), '');
    if (text.isNotEmpty) return text.characters.first.toUpperCase();
  }
  return '?';
}

/// The letter is white on every colour, yellow too (design-system §2.3).
const avatarInk = Colors.white;

/// A person: a circle in a 45° gradient of their colour and the first letter
/// of their name in their font (docs/avatar.md). There are no photos
/// anywhere in the app.
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

  /// A colour the person picked; without it the palette decides by id.
  final Color? color;

  /// Without it: the user's own pick for the user ([OwnAvatar]), the
  /// default for friends until the server shares theirs.
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

/// The user's own colour and font, for every [PersonAvatar] of them below:
/// the profile, the faces on an event, the invites.
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
