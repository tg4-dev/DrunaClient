import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

abstract final class BandShader {
  static bool enabled = true;

  static const maxColors = 8;

  static ui.FragmentProgram? _program;
  static ui.FragmentShader? _shader;

  static Future<void> precache() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset('shaders/week_band.frag');
    } catch (_) {}
  }

  static ui.FragmentShader? get _ready {
    if (!enabled) return null;
    final program = _program;
    if (program == null) return null;
    return _shader ??= program.fragmentShader();
  }
}

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
    final mask = radial;
    if (mask == null || mask.radius <= 0) {
      _paintSlices(canvas, rect, colors, stops, fromTop, alphaAt, opacity);
      return;
    }
    canvas.saveLayer(rect, Paint());
    _paintSlices(canvas, rect, colors, stops, fromTop, alphaAt, opacity);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = ui.Gradient.radial(
          rect.topLeft + mask.centre,
          mask.radius,
          const [Color(0x00000000), Color(0xFF000000)],
          [mask.clear.clamp(0.0, 1.0), mask.full.clamp(0.0, 1.0)],
        ),
    );
    canvas.restore();
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

const bandFadeAt = [0.0, 0.35, 0.7, 1.0];
const bandFadeLevels = [1.0, 0.55, 0.2, 0.0];

const _bandFadeSlopes = [-9 / 7, -8 / 7, -5 / 6, 0.0];

double bandFade(double x) {
  final clamped = x.clamp(0.0, 1.0);
  final i = clamped < bandFadeAt[1]
      ? 0
      : clamped < bandFadeAt[2]
      ? 1
      : 2;
  final h = bandFadeAt[i + 1] - bandFadeAt[i];
  final t = (clamped - bandFadeAt[i]) / h;
  final t2 = t * t;
  final t3 = t2 * t;
  return (2 * t3 - 3 * t2 + 1) * bandFadeLevels[i] +
      (t3 - 2 * t2 + t) * h * _bandFadeSlopes[i] +
      (-2 * t3 + 3 * t2) * bandFadeLevels[i + 1] +
      (t3 - t2) * h * _bandFadeSlopes[i + 1];
}

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
