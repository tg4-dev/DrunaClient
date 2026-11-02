import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The brand: its colour, the logo and the onboarding's arrow
/// (design-system §2, §9.9).
abstract final class Brand {
  /// The app's own colour 🟡: the onboarding's gradient.
  static const accent = Color(0xFF970AB6);

  static const logoAsset = 'assets/branding/druna_logo.svg';
  static const arrowAsset = 'assets/branding/arrow_right.svg';

  /// Width to height of the logo's artwork.
  static const logoAspect = 527.13 / 90.29;
}

/// «DRUNA» in one colour, [width] wide.
class DrunaLogo extends StatelessWidget {
  const DrunaLogo({
    this.width = 217,
    this.color = const Color(0xFFFFFFFF),
    super.key,
  });

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Druna',
    image: true,
    excludeSemantics: true,
    child: SvgPicture.asset(
      Brand.logoAsset,
      width: width,
      height: width / Brand.logoAspect,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    ),
  );
}

/// The thick arrow of the onboarding's buttons; [back] points left.
class ArrowIcon extends StatelessWidget {
  const ArrowIcon({
    required this.color,
    this.back = false,
    this.size = 30,
    super.key,
  });

  final Color color;
  final bool back;

  /// The width; the artwork is 30 × 24.
  final double size;

  @override
  Widget build(BuildContext context) {
    final arrow = SvgPicture.asset(
      Brand.arrowAsset,
      width: size,
      height: size * 24 / 30,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
    if (!back) return arrow;
    return Transform.flip(flipX: true, child: arrow);
  }
}
