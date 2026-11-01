import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The one button of the app (design-system §9.5): a capsule with a
/// translucent fill and a rim lighter at the top. With an icon, a text or
/// both.
abstract final class PillStyle {
  static const size = 44.0;
  static const compact = 36.0;

  /// A capsule for a short action: ✓ / ✕ (`ActionPill`), «Да» / «Нет».
  static const wide = 80.0;
  static const icon = 22.0;
  static const padding = 20.0;
  static const gap = 6.0;

  /// White over whatever is under the button: over black it is a grey,
  /// over a coloured event a lighter shade of that colour. No blur.
  static const fill = Color(0x24FFFFFF);

  /// The rim, lighter at the top than at the bottom.
  static const rimTop = Color(0x47FFFFFF);
  static const rimBottom = Color(0x0FFFFFFF);
  static const rimWidth = 1.0;

  /// Pressed, the button swells a little, as on iOS 26.
  static const pressedScale = 1.06;
  static const press = Duration(milliseconds: 120);
  static const resize = Duration(milliseconds: 200);
  static const fade = Duration(milliseconds: 180);

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1,
  );
}

/// The fill and the rim, painted in one pass: no layer, no filter, no
/// shadow, so a list full of buttons costs as much as plain shapes.
class PillSurface extends StatelessWidget {
  const PillSurface({
    required this.child,
    this.fill = PillStyle.fill,
    super.key,
  });

  final Color fill;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PillPainter(fill), child: child);
}

class _PillPainter extends CustomPainter {
  const _PillPainter(this.fill);

  final Color fill;

  static const _rim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PillStyle.rimTop, PillStyle.rimBottom],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = fill,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(PillStyle.rimWidth / 2), radius),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PillStyle.rimWidth
        ..shader = _rim.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) =>
      oldDelegate.fill != fill;
}

/// A [PillSurface] that presses. Give it an [icon], a [text] or both; a
/// [child] replaces them (the month title animates between texts). With an
/// icon alone and no [width] it is a circle.
class PillButton extends StatefulWidget {
  const PillButton({
    required this.onPressed,
    this.icon,
    this.text,
    this.child,
    this.label,
    this.width,
    this.height = PillStyle.size,
    this.iconSize = PillStyle.icon,
    this.color = Colors.white,
    this.fill = PillStyle.fill,
    this.textStyle,
    super.key,
  }) : assert(icon != null || text != null || child != null);

  final VoidCallback? onPressed;
  final IconData? icon;
  final String? text;
  final Widget? child;

  /// Read by VoiceOver; required in practice when there is no [text].
  final String? label;
  final double? width;
  final double height;
  final double iconSize;

  /// Of the icon and the text.
  final Color color;

  /// The fill; a picked answer takes the user's colour. Changes cross-fade.
  final Color fill;

  /// Replaces [PillStyle.title] for the text; its colour is still [color].
  final TextStyle? textStyle;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  var _pressed = false;

  void _press(bool pressed) {
    if (widget.onPressed == null || pressed == _pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final enabled = widget.onPressed != null;
    final width =
        widget.width ??
        (widget.text == null && widget.child == null ? widget.height : null);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label ?? widget.text,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedOpacity(
          duration: reduce ? Duration.zero : PillStyle.fade,
          opacity: enabled ? 1 : 0.4,
          child: AnimatedScale(
            scale: _pressed ? PillStyle.pressedScale : 1,
            duration: reduce ? Duration.zero : PillStyle.press,
            curve: Curves.easeOutCubic,
            child: SizedBox(
              width: width,
              height: widget.height,
              child: TweenAnimationBuilder<Color?>(
                tween: ColorTween(end: widget.fill),
                duration: reduce ? Duration.zero : PillStyle.fade,
                child: Center(widthFactor: 1, child: _content(reduce)),
                builder: (context, fill, child) =>
                    PillSurface(fill: fill ?? widget.fill, child: child!),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool reduce) {
    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, color: widget.color, size: widget.iconSize);
    final text =
        widget.child ?? (widget.text == null ? null : Text(widget.text!));
    if (text == null) return icon!;
    return AnimatedSize(
      duration: reduce ? Duration.zero : PillStyle.resize,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: icon == null ? PillStyle.padding : PillStyle.padding - 4,
        ),
        child: DefaultTextStyle(
          style: (widget.textStyle ?? PillStyle.title).copyWith(
            color: widget.color,
          ),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon, const SizedBox(width: PillStyle.gap)],
              // A fixed width never lets the text spill out of the capsule.
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}
