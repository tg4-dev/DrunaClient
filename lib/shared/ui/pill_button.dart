import 'package:druna_app/shared/ui/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class PillStyle {
  static const size = 44.0;
  static const compact = 36.0;

  static const wide = 80.0;
  static const icon = 22.0;
  static const padding = 20.0;
  static const gap = 6.0;

  static const leadingInset = 6.0;
  static const leadingGap = 10.0;

  static const fill = Color(0x24FFFFFF);

  static const rimTop = Color(0x47FFFFFF);
  static const rimBottom = Color(0x0FFFFFFF);
  static const rimWidth = 1.0;

  static const pressedScale = 1.06;
  static const press = Motion.fast;

  static const glow = Color(0x52FFFFFF);

  static const glowOnLight = Color(0x1A000000);
  static const glowIn = Motion.short;
  static const glowOut = Motion.long;
  static const resize = Motion.medium;
  static const fade = Motion.short;

  static const title = TextStyle(
    fontFamily: 'Onest',
    fontVariations: [FontVariation('wght', 600)],
    color: Colors.white,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1,
  );
}

class PillSurface extends StatelessWidget {
  const PillSurface({
    required this.child,
    this.fill = PillStyle.fill,
    this.glow = 0,
    this.radius,
    super.key,
  });

  final Color fill;

  final double? radius;

  final double glow;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _PillPainter(fill, glow, radius), child: child);
}

class _PillPainter extends CustomPainter {
  const _PillPainter(this.fill, this.glow, this.corner);

  final Color fill;
  final double glow;
  final double? corner;

  static const _rim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PillStyle.rimTop, PillStyle.rimBottom],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = Radius.circular(corner ?? size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = fill,
    );
    if (glow > 0) {
      final light = fill.a > 0.5 && fill.computeLuminance() > 0.5;
      final color = light ? PillStyle.glowOnLight : PillStyle.glow;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..shader = RadialGradient(
            radius: 0.5 * size.width / size.shortestSide,
            colors: [
              color.withValues(alpha: color.a * glow),
              color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
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
      oldDelegate.fill != fill ||
      oldDelegate.glow != glow ||
      oldDelegate.corner != corner;
}

class PillButton extends StatefulWidget {
  const PillButton({
    required this.onPressed,
    this.icon,
    this.text,
    this.child,
    this.leading,
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
  final Widget? leading;

  final String? label;
  final double? width;
  final double height;
  final double iconSize;

  final Color color;

  final Color fill;

  final TextStyle? textStyle;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton>
    with SingleTickerProviderStateMixin {
  var _pressed = false;
  late final _glow = AnimationController(
    vsync: this,
    duration: PillStyle.glowIn,
    reverseDuration: PillStyle.glowOut,
  );

  late final _glowCurve = CurvedAnimation(
    parent: _glow,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  @override
  void dispose() {
    _glowCurve.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _press(bool pressed) {
    if (widget.onPressed == null || pressed == _pressed) return;
    setState(() => _pressed = pressed);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return;
    if (pressed) {
      _glow.forward();
    } else if (_glow.isForwardOrCompleted && _glow.value < 1) {
      _glow.forward().then((_) {
        if (mounted && !_pressed) _glow.reverse();
      });
    } else {
      _glow.reverse();
    }
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
                child: TweenAnimationBuilder<Color?>(
                  tween: ColorTween(end: widget.color),
                  duration: reduce ? Duration.zero : PillStyle.fade,
                  builder: (context, color, _) => Center(
                    widthFactor: 1,
                    child: _content(reduce, color ?? widget.color),
                  ),
                ),
                builder: (context, fill, child) => AnimatedBuilder(
                  animation: _glowCurve,
                  child: child,
                  builder: (context, child) => PillSurface(
                    fill: fill ?? widget.fill,
                    glow: _glowCurve.value,
                    child: child!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(bool reduce, Color color) {
    final icon = widget.icon == null
        ? null
        : Icon(widget.icon, color: color, size: widget.iconSize);
    final text =
        widget.child ?? (widget.text == null ? null : Text(widget.text!));
    if (text == null) return icon!;
    final leading = widget.leading;
    if (leading != null) {
      final size = widget.height - 2 * PillStyle.leadingInset;
      return Padding(
        padding: const EdgeInsets.only(
          left: PillStyle.leadingInset,
          right: PillStyle.padding,
        ),
        child: DefaultTextStyle(
          style: (widget.textStyle ?? PillStyle.title).copyWith(color: color),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(dimension: size, child: leading),
              const SizedBox(width: PillStyle.leadingGap),
              Flexible(child: text),
            ],
          ),
        ),
      );
    }
    return AnimatedSize(
      duration: reduce ? Duration.zero : PillStyle.resize,
      curve: Curves.easeOutCubic,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: icon == null ? PillStyle.padding : PillStyle.padding - 4,
        ),
        child: DefaultTextStyle(
          style: (widget.textStyle ?? PillStyle.title).copyWith(color: color),
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[icon, const SizedBox(width: PillStyle.gap)],
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}
