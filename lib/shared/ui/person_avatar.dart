import 'package:flutter/material.dart';

/// Sixteen hues around the colour wheel, about 22.5° apart, bright enough for
/// the black background. Every person in the app gets one of them.
const avatarPalette = <Color>[
  Color(0xFFFF3B30),
  Color(0xFFFF6B2C),
  Color(0xFFFF9500),
  Color(0xFFFFB800),
  Color(0xFFFFD60A),
  Color(0xFFB8D93A),
  Color(0xFF34C759),
  Color(0xFF00C7A3),
  Color(0xFF30C8D6),
  Color(0xFF32ADE6),
  Color(0xFF0A84FF),
  Color(0xFF4C5BFF),
  Color(0xFF7D5CFF),
  Color(0xFFAF52DE),
  Color(0xFFE040C8),
  Color(0xFFFF2D78),
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

/// Coprime with 16: every slot is used once per 16 ids.
const avatarHueStride = 7;

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

/// Black on light colours (yellow, lime), white on the rest.
Color avatarInkFor(Color background) =>
    background.computeLuminance() > 0.5 ? Colors.black : Colors.white;

/// A person: a palette colour and the first letter of their name. There are
/// no photos anywhere in the app.
class PersonAvatar extends StatelessWidget {
  const PersonAvatar({
    required this.id,
    required this.name,
    this.username = '',
    this.size = 48,
    this.color,
    super.key,
  });

  final int id;
  final String name;
  final String username;
  final double size;

  /// A colour the person picked; without it the palette decides by id.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? avatarColorFor(id: id, username: username);
    final label = name.trim().isNotEmpty ? name.trim() : username;
    return Semantics(
      label: 'Аватар $label',
      image: true,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Text(
          avatarInitial(name, username),
          textScaler: TextScaler.noScaling,
          style: TextStyle(
            color: avatarInkFor(color),
            fontSize: size * 0.42,
            fontWeight: FontWeight.w700,
            height: 1,
          ),
        ),
      ),
    );
  }
}
