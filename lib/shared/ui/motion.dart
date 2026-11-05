import 'package:flutter/animation.dart';

abstract final class Motion {
  static const fast = Duration(milliseconds: 120);
  static const short = Duration(milliseconds: 160);
  static const medium = Duration(milliseconds: 260);
  static const long = Duration(milliseconds: 360);

  static const enter = Curves.easeOutCubic;
  static const exit = Curves.easeInCubic;
  static const settle = Curves.easeInOutCubic;
}
