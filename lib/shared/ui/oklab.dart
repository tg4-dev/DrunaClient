import 'dart:math' as math;
import 'dart:ui';

(double, double, double) oklab(Color color) {
  double linear(double c) =>
      c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  final r = linear(color.r);
  final g = linear(color.g);
  final b = linear(color.b);
  double cbrt(double v) => math.pow(math.max(v, 0), 1 / 3).toDouble();
  final l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color fromOklab((double, double, double) lab) {
  final (l, a, b) = lab;
  double cube(double v) => v * v * v;
  final lms = (
    cube(l + 0.3963377774 * a + 0.2158037573 * b),
    cube(l - 0.1055613458 * a - 0.0638541728 * b),
    cube(l - 0.0894841775 * a - 1.2914855480 * b),
  );
  double srgb(double c) {
    final v = c.clamp(0.0, 1.0);
    return v <= 0.0031308
        ? v * 12.92
        : 1.055 * math.pow(v, 1 / 2.4).toDouble() - 0.055;
  }

  return Color.from(
    alpha: 1,
    red: srgb(
      4.0767416621 * lms.$1 - 3.3077115913 * lms.$2 + 0.2309699292 * lms.$3,
    ),
    green: srgb(
      -1.2684380046 * lms.$1 + 2.6097574011 * lms.$2 - 0.3413193965 * lms.$3,
    ),
    blue: srgb(
      -0.0041960863 * lms.$1 - 0.7034186167 * lms.$2 + 1.7076147010 * lms.$3,
    ),
  );
}

bool inSrgbGamut((double, double, double) lab) {
  final (l, a, b) = lab;
  double cube(double v) => v * v * v;
  final x = cube(l + 0.3963377774 * a + 0.2158037573 * b);
  final y = cube(l - 0.1055613458 * a - 0.0638541728 * b);
  final z = cube(l - 0.0894841775 * a - 1.2914855480 * b);
  bool ok(double c) => c >= -1e-4 && c <= 1 + 1e-4;
  return ok(4.0767416621 * x - 3.3077115913 * y + 0.2309699292 * z) &&
      ok(-1.2684380046 * x + 2.6097574011 * y - 0.3413193965 * z) &&
      ok(-0.0041960863 * x - 0.7034186167 * y + 1.7076147010 * z);
}
