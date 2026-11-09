import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/pill_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

abstract final class Brand {
  static const accent = Color(0xFF970AB6);

  static const logoAsset = 'assets/branding/druna_logo.svg';

  static const logoAspect = 527.13 / 90.29;
}

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

class ArrowIcon extends StatelessWidget {
  const ArrowIcon({
    required this.color,
    this.back = false,
    this.size = 30,
    super.key,
  });

  final Color color;
  final bool back;

  final double size;

  @override
  Widget build(BuildContext context) => Icon(
    back ? CupertinoIcons.arrow_left : CupertinoIcons.arrow_right,
    color: color,
    size: size,
  );
}

class ChevronIcon extends StatelessWidget {
  const ChevronIcon({
    required this.color,
    this.size = 24,
    this.quarterTurns = 0,
    super.key,
  });

  final Color color;
  final double size;
  final int quarterTurns;

  @override
  Widget build(BuildContext context) => RotatedBox(
    quarterTurns: quarterTurns,
    child: Icon(CupertinoIcons.chevron_left, color: color, size: size),
  );
}

abstract final class ArrowPillStyle {
  static const width = 72.0;
  static const height = PillFieldStyle.height;
  static const ink = Color(0xFF262626);
}

class BackArrowPill extends StatelessWidget {
  const BackArrowPill({
    required this.onPressed,
    this.label = 'Назад',
    this.width = ArrowPillStyle.width,
    this.height = ArrowPillStyle.height,
    this.iconSize = 30,
    super.key,
  });

  final VoidCallback? onPressed;
  final String label;
  final double width;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) => PillButton(
    label: label,
    width: width,
    height: height,
    fill: const Color(0xFFFFFFFF),
    onPressed: onPressed,
    child: ArrowIcon(color: ArrowPillStyle.ink, back: true, size: iconSize),
  );
}
