import 'package:druna_app/shared/ui/motion.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

abstract final class PageIndicatorStyle {
  static const dot = 10.0;
  static const thickness = 8.0;
  static const dash = 20.0;
  static const active = 36.0;
  static const gap = 6.0;
  static const plus = 12.0;
  static const plusStroke = 2.5;
  static const height = 44.0;

  static const on = Color(0xFFFFFFFF);
  static const off = Color(0x66FFFFFF);

  static const collapse = Motion.long;
}

enum PageMark { dot, dash, plus }

double pageMarkWidth(PageMark mark, double focus) {
  final rest = switch (mark) {
    PageMark.dot => PageIndicatorStyle.dot,
    PageMark.dash => PageIndicatorStyle.dash,
    PageMark.plus => PageIndicatorStyle.plus,
  };
  if (mark != PageMark.dash) return rest;
  return rest + (PageIndicatorStyle.active - rest) * focus;
}

double pageMarkFocus(int index, double position) =>
    (1 - (position - index).abs()).clamp(0.0, 1.0);

class PageIndicator extends StatelessWidget {
  const PageIndicator({
    required this.marks,
    required this.position,
    this.collapsed = false,
    this.onTap,
    super.key,
  });

  final List<PageMark> marks;

  final ValueListenable<double> position;

  final bool collapsed;

  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: collapsed ? 1 : 0),
      duration: reduce ? Duration.zero : PageIndicatorStyle.collapse,
      curve: Motion.settle,
      builder: (context, fold, _) => ValueListenableBuilder<double>(
        valueListenable: position,
        builder: (context, at, _) => _row(at, fold),
      ),
    );
  }

  Widget _row(double at, double fold) {
    final current = at.round().clamp(0, marks.length - 1);
    return Semantics(
      label: 'Страница ${current + 1} из ${marks.length}',
      child: SizedBox(
        height: PageIndicatorStyle.height,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < marks.length; i++)
              _mark(i, pageMarkFocus(i, at), fold, i == current),
          ],
        ),
      ),
    );
  }

  Widget _mark(int index, double focus, double fold, bool current) {
    final mark = marks[index];
    final open = pageMarkWidth(mark, focus);
    final round = mark == PageMark.dot;
    final width = current
        ? open + ((round ? open : PageIndicatorStyle.thickness) - open) * fold
        : open * (1 - fold);
    final height = round ? open : PageIndicatorStyle.thickness;
    final gap = index == 0 ? 0.0 : PageIndicatorStyle.gap * (1 - fold);
    final color = Color.lerp(
      PageIndicatorStyle.off,
      PageIndicatorStyle.on,
      current ? focus + (1 - focus) * fold : focus,
    )!;
    final Widget shape = mark == PageMark.plus
        ? CustomPaint(
            size: Size.square(
              PageIndicatorStyle.plus * (current ? 1 : 1 - fold),
            ),
            painter: _PlusPainter(color),
          )
        : Container(
            width: width,
            height: height,
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: color,
            ),
          );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap == null || fold > 0 ? null : () => onTap!(index),
      child: Padding(
        padding: EdgeInsets.only(left: gap),
        child: SizedBox(
          height: PageIndicatorStyle.height,
          width: mark == PageMark.plus
              ? PageIndicatorStyle.plus * (current ? 1 : 1 - fold)
              : width,
          child: Center(child: shape),
        ),
      ),
    );
  }
}

class _PlusPainter extends CustomPainter {
  const _PlusPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawPath(plusPath(size), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _PlusPainter old) => old.color != color;
}

Path plusPath(Size size) {
  final stroke =
      PageIndicatorStyle.plusStroke * size.width / PageIndicatorStyle.plus;
  final cap = Radius.circular(stroke / 2);
  final mid = size.width / 2;
  final vertical = Path()
    ..addRRect(
      RRect.fromLTRBR(mid - stroke / 2, 0, mid + stroke / 2, size.height, cap),
    );
  final horizontal = Path()
    ..addRRect(
      RRect.fromLTRBR(0, mid - stroke / 2, size.width, mid + stroke / 2, cap),
    );
  return Path.combine(PathOperation.union, vertical, horizontal);
}
