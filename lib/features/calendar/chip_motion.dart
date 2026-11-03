import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The two layers take turns, never moving at once: on the way to friends'
/// calendar the user's chips fold over the first half of the swipe and
/// friends' unfold over the second; the way back mirrors it. Each band
/// follows its own layer.
double myFoldAt(double mode) => (mode * 2).clamp(0.0, 1.0);

double friendsFoldAt(double mode) => ((1 - mode) * 2).clamp(0.0, 1.0);

/// Gap between a week line and a chip folded against it.
const chipFoldGap = 2.0;

/// Below this share of its height a chip's title is gone, so squeezed
/// letters never show; it comes back over [chipTitleFade] above it.
const chipTitleGone = 0.6;
const chipTitleFade = 0.25;

/// How far a layer [away] from being shown is unfolded: 0 folded into its
/// line, 1 in place. The whole layer moves as one, so its chips keep their
/// order and gaps at every step. With [reduce] the layer just switches.
double chipShownAt(double away, {bool reduce = false}) {
  final a = away.clamp(0.0, 1.0);
  if (reduce) return a < 0.5 ? 1 : 0;
  return Curves.easeInOutCubic.transform(1 - a);
}

/// How much of a chip's title shows when its layer is [shown] unfolded.
double chipTitleAlpha(double shown) =>
    ((shown - chipTitleGone) / chipTitleFade).clamp(0.0, 1.0);

/// The transform of a chip whose top is at [homeTop] when its layer is
/// [shown] unfolded: the layer is squeezed towards [line] like an
/// accordion — positions and heights scale together around the line, so
/// no chip ever runs into another. Anchored at the chip's top.
Matrix4 chipFoldTransform({
  required double shown,
  required double homeTop,
  required double line,
}) =>
    Matrix4.translationValues(0, (line - homeTop) * (1 - shown), 0)
      ..scaleByDouble(1, shown, 1, 1);

/// One chip on its way between its place and its line, following the mode.
/// Used by the month and the day timeline alike.
///
/// Only a transform changes per frame — no opacity: an [Opacity] below 1
/// costs an offscreen layer per chip, and dozens of them per frame made the
/// swipe stutter. The tree is the same at every progress, so a landing chip
/// keeps its state. Titles under it fade through [ChipFoldInk].
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

  /// The mode turned into how far this layer is folded: 0 in place, 1 gone.
  final double Function(double mode) awayAt;
  final double homeTop;

  /// Where the layer folds to: the week line, in the chip's coordinates.
  final double line;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    double shownAt(double t) => chipShownAt(awayAt(t), reduce: reduce);
    return ValueListenableBuilder<double>(
      valueListenable: mode,
      child: _ChipFoldScope(mode: mode, shownAt: shownAt, child: child),
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
    required this.shownAt,
    required super.child,
  });

  final ValueListenable<double> mode;
  final double Function(double mode) shownAt;

  @override
  bool updateShouldNotify(_ChipFoldScope old) => old.mode != mode;
}

/// A chip's title under a [ChipMotion]: [builder] gets how much of it
/// shows, 0..1, and puts it into the text colour — only the text repaints,
/// no layer. Outside a [ChipMotion] the title always shows.
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
