import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Look of the glass controls over the blurred top of a page: the round
/// buttons and the title pill of the month and the day (design-system §9.3).
abstract final class GlassStyle {
  static const size = 44.0;
  static const icon = 22.0;
  static const pillPadding = 20.0;

  /// Pressed glass swells a little, as on iOS 26.
  static const pressedScale = 1.06;
  static const press = Duration(milliseconds: 120);
  static const resize = Duration(milliseconds: 200);

  static const title = TextStyle(
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1,
  );
}

/// Fill, rim and shadow of the glass. No backdrop filter of its own: the
/// controls stand over the progressive blur of the page top, which has
/// already blurred and darkened what scrolls under them.
const glassDecoration = ShapeDecoration(
  color: Color(0x24FFFFFF),
  shape: StadiumBorder(),
  shadows: [BoxShadow(color: Color(0x66000000), blurRadius: 12)],
);

/// A rim lighter at the top, painted over the fill.
class _GlassRim extends CustomPainter {
  const _GlassRim();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0x47FFFFFF), Color(0x0FFFFFFF)],
      ).createShader(rect);
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(0.5), radius), paint);
  }

  @override
  bool shouldRepaint(covariant _GlassRim oldDelegate) => false;
}

/// The glass shape around [child], swelling while pressed.
class _Glass extends StatefulWidget {
  const _Glass({
    required this.label,
    required this.onPressed,
    required this.child,
    this.width,
  });

  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final Widget child;

  @override
  State<_Glass> createState() => _GlassState();
}

class _GlassState extends State<_Glass> {
  var _pressed = false;

  void _press(bool pressed) {
    if (widget.onPressed == null || pressed == _pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onPressed == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                widget.onPressed!();
              },
        child: AnimatedScale(
          scale: _pressed ? GlassStyle.pressedScale : 1,
          duration: reduce ? Duration.zero : GlassStyle.press,
          curve: Curves.easeOutCubic,
          child: Container(
            width: widget.width,
            height: GlassStyle.size,
            decoration: glassDecoration,
            child: CustomPaint(
              foregroundPainter: const _GlassRim(),
              child: Center(widthFactor: 1, child: widget.child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A round glass button with an icon.
class GlassButton extends StatelessWidget {
  const GlassButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    super.key,
  });

  final IconData icon;

  /// Read by VoiceOver; the button has no visible text.
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _Glass(
    label: label,
    onPressed: onPressed,
    width: GlassStyle.size,
    child: Icon(icon, color: Colors.white, size: GlassStyle.icon),
  );
}

/// A glass pill with a title; it grows and shrinks with the text.
class GlassPill extends StatelessWidget {
  const GlassPill({
    required this.title,
    this.onPressed,
    this.semanticLabel,
    super.key,
  });

  /// Usually a [Text] in [GlassStyle.title]; may animate between titles.
  final Widget title;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return _Glass(
      label: semanticLabel ?? '',
      onPressed: onPressed,
      child: AnimatedSize(
        duration: reduce ? Duration.zero : GlassStyle.resize,
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: GlassStyle.pillPadding,
          ),
          child: DefaultTextStyle(
            style: GlassStyle.title,
            maxLines: 1,
            softWrap: false,
            child: title,
          ),
        ),
      ),
    );
  }
}
