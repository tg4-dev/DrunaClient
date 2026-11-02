import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The profile's look, chosen in the onboarding and in the settings
/// (design-system §9.11): the avatar as it will be, a picker of fonts and
/// one of colours.
abstract final class ProfilePickerStyle {
  static const width = 258.0;

  /// The font picker: a capsule with the letters in a row.
  static const fontHeight = 64.0;
  static const fontItem = 64.0;
  static const fontInset = 6.0;

  /// The colour picker: a block of 4 × 2.
  static const colorCell = 58.0;
  static const colorDot = 42.0;
  static const colorRing = 56.0;
  static const colorRadius = 36.0;
  static const colorInset = 8.0;

  /// Under the picked item.
  static const picked = Color(0x2EFFFFFF);

  static const move = Duration(milliseconds: 260);
  static const recolor = Duration(milliseconds: 300);
  static const swap = Duration(milliseconds: 220);
}

/// The avatar with [color] and [font]; a new colour flows in, a new font's
/// letter grows in over the old one.
class AvatarPreview extends StatelessWidget {
  const AvatarPreview({
    required this.color,
    required this.font,
    required this.name,
    this.size = 120,
    super.key,
  });

  final Color color;
  final AvatarFont font;

  /// Its first letter is drawn.
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final letter = font.cased(avatarInitial(name));
    return Semantics(
      label: 'Аватар: ${font.label}',
      image: true,
      excludeSemantics: true,
      child: TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: color),
        duration: reduce ? Duration.zero : ProfilePickerStyle.recolor,
        curve: Curves.easeOutCubic,
        builder: (context, value, _) {
          final fill = value ?? color;
          return SizedBox.square(
            dimension: size,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: avatarGradient(fill),
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : ProfilePickerStyle.swap,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.85, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: AvatarLetter(
                  key: ValueKey('${font.id}-$letter'),
                  letter: letter,
                  font: font,
                  size: size,
                  color: avatarInkFor(fill),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The fonts, each writing the first letter of the name in its own case;
/// the row scrolls. A tap picks, the light slides under it.
class FontPicker extends StatefulWidget {
  const FontPicker({
    required this.name,
    required this.selected,
    required this.onPick,
    this.width = ProfilePickerStyle.width,
    super.key,
  });

  final String name;
  final AvatarFont selected;
  final ValueChanged<AvatarFont> onPick;
  final double width;

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  int get _index =>
      avatarFonts.indexWhere((font) => font.id == widget.selected.id);

  void _pick(int index) {
    final font = avatarFonts[index];
    if (font.id == widget.selected.id) return;
    HapticFeedback.selectionClick();
    widget.onPick(font);
    // The picked one comes into view, towards the middle.
    if (!_scroll.hasClients) return;
    const item = ProfilePickerStyle.fontItem;
    final target = (index * item - (widget.width - item) / 2).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(
      target,
      duration: ProfilePickerStyle.move,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    const inset = ProfilePickerStyle.fontInset;
    const item = ProfilePickerStyle.fontItem;
    const height = ProfilePickerStyle.fontHeight;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final initial = avatarInitial(widget.name);
    final index = _index < 0 ? 0 : _index;
    return SizedBox(
      width: widget.width,
      height: height,
      child: PillSurface(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: SingleChildScrollView(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: inset),
            child: SizedBox(
              width: avatarFonts.length * item,
              height: height,
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: reduce ? Duration.zero : ProfilePickerStyle.move,
                    curve: Curves.easeOutCubic,
                    left: index * item,
                    top: inset,
                    width: item,
                    height: height - 2 * inset,
                    child: const PillSurface(
                      fill: ProfilePickerStyle.picked,
                      child: SizedBox.expand(),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < avatarFonts.length; i++)
                        Semantics(
                          button: true,
                          selected: i == index,
                          label: 'Шрифт: ${avatarFonts[i].label}',
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: ValueKey('font-${avatarFonts[i].id}'),
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _pick(i),
                            child: SizedBox(
                              width: item,
                              height: height,
                              child: Center(
                                child: AvatarLetter(
                                  letter: avatarFonts[i].cased(initial),
                                  font: avatarFonts[i],
                                  size: height - 2 * inset,
                                ),
                              ),
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
      ),
    );
  }
}

/// The colours in a block of 4 × 2; a ring sits under the picked one and
/// moves to the next.
class ColorPicker extends StatelessWidget {
  const ColorPicker({required this.selected, required this.onPick, super.key});

  /// A slot of [avatarPalette].
  final int selected;
  final ValueChanged<int> onPick;

  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    const cell = ProfilePickerStyle.colorCell;
    const inset = ProfilePickerStyle.colorInset;
    final rows = (avatarPalette.length / _columns).ceil();
    final gap =
        (ProfilePickerStyle.width - 2 * inset - _columns * cell) /
        (_columns - 1);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Offset at(int slot) => Offset(
      inset + (slot % _columns) * (cell + gap),
      inset + (slot ~/ _columns) * cell,
    );
    final ring = at(selected.clamp(0, avatarPalette.length - 1));
    const ringInset = (cell - ProfilePickerStyle.colorRing) / 2;
    return SizedBox(
      width: ProfilePickerStyle.width,
      height: rows * cell + 2 * inset,
      child: PillSurface(
        radius: ProfilePickerStyle.colorRadius,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: reduce ? Duration.zero : ProfilePickerStyle.move,
              curve: Curves.easeOutCubic,
              left: ring.dx + ringInset,
              top: ring.dy + ringInset,
              width: ProfilePickerStyle.colorRing,
              height: ProfilePickerStyle.colorRing,
              child: const PillSurface(
                fill: ProfilePickerStyle.picked,
                child: SizedBox.expand(),
              ),
            ),
            for (var slot = 0; slot < avatarPalette.length; slot++)
              Positioned(
                left: at(slot).dx,
                top: at(slot).dy,
                width: cell,
                height: cell,
                child: _Swatch(
                  key: ValueKey('color-$slot'),
                  color: avatarPalette[slot],
                  selected: slot == selected,
                  onTap: () {
                    if (slot == selected) return;
                    HapticFeedback.selectionClick();
                    onPick(slot);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.color,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: widget.selected,
    label: 'Цвет',
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: Center(
        child: AnimatedScale(
          scale: _pressed ? 1.12 : 1,
          duration: PillStyle.press,
          curve: Curves.easeOutCubic,
          child: Container(
            width: ProfilePickerStyle.colorDot,
            height: ProfilePickerStyle.colorDot,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}
