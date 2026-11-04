import 'package:flutter/widgets.dart';
import 'package:progressive_blur/progressive_blur.dart';

export 'package:progressive_blur/progressive_blur.dart' show LinearGradientBlur;

class EdgeBlur extends StatelessWidget {
  const EdgeBlur({
    required this.sigma,
    required this.gradient,
    required this.child,
    super.key,
  });

  static bool enabled = true;

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
