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

/// How much later each lower lane starts to unfold, as a share of the way.
/// Small, so each chip still travels over most of the swipe and its speed
/// stays close to the finger's.
const chipUnfoldStagger = 0.06;

/// The first part of a chip's way during which it grows out of the line.
const chipBirth = 0.5;

/// How far a chip in [lane] has unfolded, 0 folded to 1 in place, when its
/// layer is [away] from being shown. Lower lanes start a little later.
double chipUnfoldProgress({
  required double away,
  required int lane,
  required int lanes,
}) {
  final spread = chipUnfoldStagger * (lanes > 1 ? lanes - 1 : 0);
  final shown = 1 - away.clamp(0.0, 1.0);
  return (shown * (1 + spread) - chipUnfoldStagger * lane).clamp(0.0, 1.0);
}

/// The transform of a chip [away] from its place: it travels from [homeTop]
/// to [foldTop] and, near the line, shrinks into it from the side that
/// touches the line.
Matrix4 chipFoldTransform({
  required double away,
  required int lane,
  required int lanes,
  required double homeTop,
  required double foldTop,
}) {
  final progress = chipUnfoldProgress(away: away, lane: lane, lanes: lanes);
  // Eased at both ends: a layer starts moving exactly where the other one
  // stopped, and a curve that starts at full speed made it jump there.
  final travel = Curves.easeInOutCubic.transform(progress);
  final grow = Curves.easeInOut.transform(
    (progress / chipBirth).clamp(0.0, 1.0),
  );
  return Matrix4.translationValues(0, (foldTop - homeTop) * (1 - travel), 0)
    ..scaleByDouble(1, grow, 1, 1);
}

/// Where [chipFoldTransform] anchors its scale.
Alignment chipFoldAlignment({
  required double homeTop,
  required double foldTop,
}) => foldTop <= homeTop ? Alignment.topCenter : Alignment.bottomCenter;

/// One chip on its way between its place and its line, following the mode.
/// Folded, all chips of a day lie in one stack against the line; they
/// unfold lane by lane, the first lane first, and are born from the line by
/// growing out of it. Used by the month and the day timeline alike.
///
/// Only a transform changes per frame — no opacity: an [Opacity] below 1
/// costs an offscreen layer per chip, and dozens of them per frame made the
/// swipe stutter. The tree is the same at every progress, so a landing chip
/// keeps its state.
class ChipMotion extends StatelessWidget {
  const ChipMotion({
    required this.mode,
    required this.awayAt,
    required this.lane,
    required this.lanes,
    required this.homeTop,
    required this.foldTop,
    required this.child,
    super.key,
  });

  final ValueListenable<double> mode;

  /// The mode turned into how far this layer is folded: 0 in place, 1 gone.
  final double Function(double mode) awayAt;
  final int lane;
  final int lanes;
  final double homeTop;
  final double foldTop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: mode,
      child: child,
      builder: (context, t, child) => Transform(
        alignment: chipFoldAlignment(homeTop: homeTop, foldTop: foldTop),
        transform: chipFoldTransform(
          away: awayAt(t),
          lane: lane,
          lanes: lanes,
          homeTop: homeTop,
          foldTop: foldTop,
        ),
        child: child,
      ),
    );
  }
}
