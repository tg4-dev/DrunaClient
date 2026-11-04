import 'dart:ui' as ui;

import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/shared/ui/oklab.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class EventGradient extends StatefulWidget {
  const EventGradient({
    required this.colors,
    this.dark = EventPageStyle.dark,
    this.surge = 0,
    super.key,
  });

  final List<Color> colors;

  final Color dark;

  final int surge;

  static const maxColors = 6;

  static bool enabled = true;

  static ui.FragmentProgram? _program;

  static Future<void> precache() async {
    try {
      _program ??= await ui.FragmentProgram.fromAsset(
        'shaders/event_gradient.frag',
      );
    } catch (_) {}
  }

  @override
  State<EventGradient> createState() => _EventGradientState();
}

class _Slot {
  _Slot(this.color, {this.weight = 0}) : lab = oklab(color);

  Color color;

  (double, double, double) lab;

  (double, double, double)? _from;
  (double, double, double)? _to;
  var _turned = 0.0;

  void recolor(Color next, {required bool still}) {
    color = next;
    if (still) {
      lab = oklab(next);
      _from = null;
      return;
    }
    _from = lab;
    _to = oklab(next);
    _turned = 0;
  }

  void turn(double dt, double seconds) {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    _turned = (_turned + dt / seconds).clamp(0.0, 1.0);
    final t = Curves.easeInOutCubic.transform(_turned);
    lab = (
      from.$1 + (to.$1 - from.$1) * t,
      from.$2 + (to.$2 - from.$2) * t,
      from.$3 + (to.$3 - from.$3) * t,
    );
    if (_turned >= 1) _from = null;
  }

  double weight;
  double velocity = 0;
  double target = 1;
}

class _EventGradientState extends State<EventGradient>
    with SingleTickerProviderStateMixin {
  static const _speed = 0.35;

  static const _loop = 4.0;

  static const _recolor = 0.6;

  static const _stiffness = 40.0;
  static const _damping = 8.0;

  final _slots = <_Slot>[];
  final _repaint = _Repaint();
  late final Ticker _ticker = createTicker(_tick);
  ui.FragmentShader? _shader;
  var _phase = 0.0;
  Duration _last = Duration.zero;

  double? _runFrom;
  double? _runTo;
  var _runFor = 0.0;
  Duration _runAt = Duration.zero;
  final _waiting = <Color>[];

  bool get _still =>
      !EventGradient.enabled ||
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void initState() {
    super.initState();
    final program = EventGradient._program;
    if (EventGradient.enabled && program != null) {
      _shader = program.fragmentShader();
    }
    for (final color in widget.colors.take(EventGradient.maxColors)) {
      _slots.add(_Slot(color, weight: 1));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) {
      _ticker.stop();
    } else if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant EventGradient oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.surge != oldWidget.surge && !_still && _runTo == null) {
      _startRun();
    }
    final next = widget.colors.take(EventGradient.maxColors).toList();
    final old = oldWidget.colors.take(EventGradient.maxColors).toList();
    if (old.length == next.length &&
        _slots.length == old.length &&
        _waiting.isEmpty &&
        !_listEquals(old, next)) {
      for (var i = 0; i < old.length; i++) {
        if (old[i] == next[i]) continue;
        for (final slot in _slots) {
          if (slot.color == old[i]) {
            slot.recolor(next[i], still: _still);
            break;
          }
        }
      }
      if (_still) _repaint.ping();
      return;
    }
    for (final slot in _slots) {
      final stays = next.contains(slot.color);
      if (!stays) slot.target = 0;
      if (stays && slot.target == 0) slot.target = 1;
    }
    _waiting.removeWhere((color) => !next.contains(color));
    final joining = [
      for (final color in next)
        if (!_slots.any((slot) => slot.color == color) &&
            !_waiting.contains(color))
          color,
    ];
    if (_still) {
      _slots.removeWhere((slot) => slot.target == 0);
      _slots.insertAll(0, [for (final color in joining) _Slot(color)]);
      for (final slot in _slots) {
        slot.weight = slot.target;
      }
      _repaint.ping();
      return;
    }
    if (joining.isEmpty) return;
    _waiting.addAll(joining);
    if (_runTo == null) _startRun();
  }

  void _startRun() {
    final to = ((_phase / _loop).floor() + 1) * _loop;
    _runFrom = _phase;
    _runTo = to;
    _runFor = 0.4 + 0.15 * (to - _phase);
    _runAt = _last;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shader?.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final from = _runFrom;
    final to = _runTo;
    if (from != null && to != null) {
      final t = ((elapsed - _runAt).inMicroseconds / 1e6 / _runFor).clamp(
        0.0,
        1.0,
      );
      _phase = from + (to - from) * Curves.easeInOutCubic.transform(t);
      if (t >= 1) {
        _runFrom = null;
        _runTo = null;
        _slots.insertAll(0, [for (final color in _waiting) _Slot(color)]);
        _waiting.clear();
      }
    } else {
      _phase += dt * _speed;
    }
    for (final slot in _slots) {
      slot.turn(dt, _recolor);
      final pull =
          _stiffness * (slot.target - slot.weight) - _damping * slot.velocity;
      slot.velocity += pull * dt;
      slot.weight = (slot.weight + slot.velocity * dt).clamp(0.0, 1.4);
    }
    _slots.removeWhere(
      (slot) =>
          slot.target == 0 && slot.weight < 0.005 && slot.velocity.abs() < 0.01,
    );
    _repaint.ping();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _shader == null
            ? _PlainPainter(widget.colors, widget.dark, _repaint)
            : _ShaderPainter(
                shader: _shader!,
                slots: _slots,
                dark: oklab(widget.dark),
                phase: () => _phase,
                repaint: _repaint,
              ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}

class _ShaderPainter extends CustomPainter {
  _ShaderPainter({
    required this.shader,
    required this.slots,
    required this.phase,
    required this.dark,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ui.FragmentShader shader;
  final List<_Slot> slots;
  final double Function() phase;

  final (double, double, double) dark;

  @override
  void paint(Canvas canvas, Size size) {
    var i = 0;
    void put(double value) => shader.setFloat(i++, value);
    put(size.width);
    put(size.height);
    put(phase());
    for (var k = 0; k < EventGradient.maxColors; k++) {
      final slot = k < slots.length ? slots[k] : null;
      final lab = slot?.lab ?? (0.0, 0.0, 0.0);
      put(lab.$1);
      put(lab.$2);
      put(lab.$3);
      put(slot?.weight ?? 0);
    }
    put(dark.$1);
    put(dark.$2);
    put(dark.$3);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _ShaderPainter old) =>
      old.shader != shader || old.dark != dark;
}

class _PlainPainter extends CustomPainter {
  _PlainPainter(this.colors, this.dark, Listenable repaint)
    : super(repaint: repaint);

  final List<Color> colors;
  final Color dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final stops = colors.isEmpty ? [dark] : colors;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.6, -0.8),
          radius: 1.4,
          colors: [...stops, dark],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _PlainPainter old) =>
      old.colors != colors || old.dark != dark;
}

bool _listEquals(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
