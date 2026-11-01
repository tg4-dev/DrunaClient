import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

export 'package:progressive_blur/progressive_blur.dart' show LinearGradientBlur;

/// Blurs [child] by [gradient]: full [sigma] where it is 1, sharp where it
/// is 0 (`progressive_blur`, which blurs its child, not what is behind it).
/// Used where content runs under the pinned top, the friend bar or the
/// friends column.
class EdgeBlur extends StatelessWidget {
  const EdgeBlur({
    required this.sigma,
    required this.gradient,
    required this.child,
    super.key,
  });

  /// Off in widget tests (`test/flutter_test_config.dart`): the blur
  /// captures the whole child into an image on every frame, which the test
  /// renderer does in software, and `pumpAndSettle` took close to a minute.
  static bool enabled = true;

  /// Physical pixels, as the shader takes it.
  final double sigma;
  final LinearGradientBlur gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ProgressiveBlurWidget(
      sigma: sigma,
      linearGradientBlur: gradient,
      child: child,
    );
  }
}
