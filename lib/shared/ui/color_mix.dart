import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Mixes two colours in OKLCH: lightness and chroma change evenly and the
/// hue turns the short way round the wheel. Opposite colours (blue and
/// yellow, pink and green) then pass through other vivid hues instead of
/// the grey or white a straight blend gives.
Color mixOklch(Color a, Color b, double t) {
  if (t <= 0) return a;
  if (t >= 1) return b;
  final x = _toOklch(a);
  final y = _toOklch(b);
  var hx = x.$3;
  var hy = y.$3;
  // A colour with almost no chroma has no real hue: take the other's.
  if (x.$2 < 0.02) hx = hy;
  if (y.$2 < 0.02) hy = hx;
  var dh = hy - hx;
  if (dh > math.pi) dh -= 2 * math.pi;
  if (dh < -math.pi) dh += 2 * math.pi;
  final lightness = x.$1 + (y.$1 - x.$1) * t;
  final chroma = x.$2 + (y.$2 - x.$2) * t;
  final hue = hx + dh * t;
  return _fromOklab(
    lightness,
    chroma * math.cos(hue),
    chroma * math.sin(hue),
    a.a + (b.a - a.a) * t,
  );
}

(double, double, double) _toOklch(Color color) {
  final (l, a, b) = _toOklab(color);
  return (l, math.sqrt(a * a + b * b), math.atan2(b, a));
}

double _toLinear(double c) =>
    c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _toSrgb(double c) {
  final v = c <= 0.0031308
      ? 12.92 * c
      : 1.055 * math.pow(c, 1 / 2.4).toDouble() - 0.055;
  return v.clamp(0.0, 1.0);
}

double _cbrt(double x) =>
    x < 0 ? -math.pow(-x, 1 / 3).toDouble() : math.pow(x, 1 / 3).toDouble();

(double, double, double) _toOklab(Color color) {
  final r = _toLinear(color.r);
  final g = _toLinear(color.g);
  final b = _toLinear(color.b);
  final l = _cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
  final m = _cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
  final s = _cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
  return (
    0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
    1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
    0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s,
  );
}

Color _fromOklab(double lightness, double a, double b, double alpha) {
  final l = math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3);
  final m = math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3);
  final s = math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3);
  final r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
  final g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
  final bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
  return Color.from(
    alpha: alpha.clamp(0.0, 1.0),
    red: _toSrgb(r),
    green: _toSrgb(g),
    blue: _toSrgb(bl),
  );
}
