import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

double myFoldAt(double mode) => (mode * 2).clamp(0.0, 1.0);

double friendsFoldAt(double mode) => ((1 - mode) * 2).clamp(0.0, 1.0);

const chipFoldGap = 2.0;

const chipTitleGone = 0.6;
const chipTitleFade = 0.25;

double chipShownAt(double away, {bool reduce = false}) {
  final a = away.clamp(0.0, 1.0);
  if (reduce) return a < 0.5 ? 1 : 0;
  return 1 - a;
}

double chipTitleAlpha(double shown) =>
    ((shown - chipTitleGone) / chipTitleFade).clamp(0.0, 1.0);

Matrix4 chipFoldTransform({
  required double shown,
  required double homeTop,
  required double line,
}) =>
    Matrix4.translationValues(0, (line - homeTop) * (1 - shown), 0)
      ..scaleByDouble(1, shown, 1, 1);

class ChipMotion extends StatelessWidget {
  const ChipMotion({
    required this.mode,
    required this.awayAt,
    required this.homeTop,
    required this.line,
    required this.child,
    super.key,
  });

  final ValueListenable<double> mode;

  final double Function(double mode) awayAt;
  final double homeTop;

  final double line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    double shownAt(double t) => chipShownAt(awayAt(t), reduce: reduce);
    return ValueListenableBuilder<double>(
      valueListenable: mode,
      child: _ChipFoldScope(
        mode: mode,
        awayAt: awayAt,
        reduce: reduce,
        child: child,
      ),
      builder: (context, t, child) => Transform(
        alignment: Alignment.topCenter,
        transform: chipFoldTransform(
          shown: shownAt(t),
          homeTop: homeTop,
          line: line,
        ),
        child: child,
      ),
    );
  }
}

class _ChipFoldScope extends InheritedWidget {
  const _ChipFoldScope({
    required this.mode,
    required this.awayAt,
    required this.reduce,
    required super.child,
  });

  final ValueListenable<double> mode;
  final double Function(double mode) awayAt;
  final bool reduce;

  double shownAt(double t) => chipShownAt(awayAt(t), reduce: reduce);

  @override
  bool updateShouldNotify(_ChipFoldScope old) =>
      old.mode != mode || old.awayAt != awayAt || old.reduce != reduce;
}

class ChipFoldInk extends StatelessWidget {
  const ChipFoldInk({required this.builder, super.key});

  final Widget Function(BuildContext context, double alpha) builder;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ChipFoldScope>();
    if (scope == null) return builder(context, 1);
    return ValueListenableBuilder<double>(
      valueListenable: scope.mode,
      builder: (context, t, _) {
        final alpha = chipTitleAlpha(scope.shownAt(t));
        return alpha <= 0 ? const SizedBox.shrink() : builder(context, alpha);
      },
    );
  }
}
