import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The shader behind [paintFadingBand] (`shaders/week_band.frag`).
abstract final class BandShader {
  /// Off in widget tests (`test/flutter_test_config.dart`): there the
  /// shader is not compiled, and the slices stand in.
  static bool enabled = true;

  /// The most colours one band can carry through the shader.
  static const maxColors = 8;

  static ui.FragmentProgram? _program;
  static ui.FragmentShader? _shader;

  /// Loads the shader before the month is first drawn.
  static Future<void> precache() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/week_band.frag');
    } catch (_) {
      // No shader (an old renderer): the slices stand in.
    }
  }

  /// One shader for every band: its uniforms are copied at each draw.
  static ui.FragmentShader? get _ready {
    if (!enabled) return null;
    final program = _program;
    if (program == null) return null;
    return _shader ??= program.fragmentShader();
  }
}

/// A busy band in [rect]: [colors] at [stops] run along it in plain RGB,
/// and it fades from its line — the top edge if [fromTop], else the bottom
/// — to nothing [fade] away (100% → 55% → 20% → 0 at 0 / ⅓ / ⅔ / 1).
/// With [middle] (distance from the line, alpha) the fade runs instead
/// straight from 100% to that alpha there, then eases to nothing at
/// [fade]. With [radial] — a centre in [rect]'s own coordinates, a radius
/// and the share of it that is clear and from which it is full — that
/// mask is multiplied in, for an arc instead of a straight fade. Cut clean
/// at the line. One draw, no `saveLayer`.
void paintFadingBand(
  Canvas canvas,
  Rect rect, {
  required List<Color> colors,
  required List<double> stops,
  required bool fromTop,
  required double fade,
  required double opacity,
  (double, double)? middle,
  ({Offset centre, double radius, double clear, double full})? radial,
}) {
  if (rect.isEmpty || opacity <= 0 || colors.isEmpty) return;
  double alphaAt(double d) {
    final mid = middle;
    if (mid == null || mid.$1 <= 0) return bandFade(d / fade);
    if (d <= mid.$1) return 1 + (mid.$2 - 1) * d / mid.$1;
    final f = ((d - mid.$1) / math.max(fade - mid.$1, 1)).clamp(0.0, 1.0);
    return mid.$2 * (1 - f * f * (3 - 2 * f));
  }

  final shader = BandShader._ready;
  if (shader == null || colors.length > BandShader.maxColors) {
    _paintSlices(canvas, rect, colors, stops, fromTop, alphaAt, opacity);
    return;
  }
  var i = 0;
  void put(double value) => shader.setFloat(i++, value);
  put(rect.left);
  put(rect.top);
  put(rect.width);
  put(rect.height);
  put(fromTop ? 1 : 0);
  put(fade);
  put(opacity);
  put(colors.length.toDouble());
  for (var c = 0; c < BandShader.maxColors; c++) {
    final color = colors[c < colors.length ? c : colors.length - 1];
    put(color.r);
    put(color.g);
    put(color.b);
    put(c < colors.length ? stops[c] : 1);
  }
  put(middle?.$1 ?? 0);
  put(middle?.$2 ?? 0);
  put(radial?.centre.dx ?? 0);
  put(radial?.centre.dy ?? 0);
  put(radial?.radius ?? 0);
  put(radial?.clear ?? 0);
  put(radial?.full ?? 1);
  canvas.drawRect(rect, Paint()..shader = shader);
}

/// 100% at the line, about 55% at a third, 20% at two thirds, 0 at the end.
double bandFade(double x) {
  final k = 1 - x.clamp(0.0, 1.0);
  return k * k * (0.45 + 0.55 * k);
}

/// Without the shader: thin slices of falling opacity, each the colours'
/// gradient scaled by a modulate filter. Shows as fine steps.
void _paintSlices(
  Canvas canvas,
  Rect rect,
  List<Color> colors,
  List<double> stops,
  bool fromTop,
  double Function(double distance) alphaAt,
  double opacity,
) {
  const slice = 2.0;
  final paint = Paint()
    ..shader = ui.Gradient.linear(
      rect.centerLeft,
      rect.centerRight,
      colors,
      stops,
    );
  final h = rect.height;
  final slices = (h / slice).ceil();
  for (var i = 0; i < slices; i++) {
    final from = i * h / slices;
    final to = (i + 1) * h / slices;
    final alpha = alphaAt((from + to) / 2) * opacity;
    if (alpha <= 0.004) continue;
    paint.colorFilter = ColorFilter.mode(
      Color.fromRGBO(255, 255, 255, alpha),
      BlendMode.modulate,
    );
    final top = fromTop ? rect.top + from : rect.bottom - to;
    canvas.drawRect(
      Rect.fromLTRB(rect.left, top, rect.right, top + (to - from)),
      paint,
    );
  }
}
