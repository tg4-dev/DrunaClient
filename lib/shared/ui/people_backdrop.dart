import 'dart:ui' as ui;

import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract final class PeopleBackdropStyle {
  static const black = Color(0xFF000000);
  static const clear = Color(0x00000000);

  static const darkWidth = 1.25;
}

class PeopleBackdrop extends StatelessWidget {
  const PeopleBackdrop({required this.colors, required this.anchor, super.key});

  final List<Color> colors;

  final ValueListenable<double> anchor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        EventGradient(colors: [PeopleBackdropStyle.black, ...colors]),
        RepaintBoundary(child: CustomPaint(painter: DarkLayerPainter(anchor))),
      ],
    );
  }
}

double darkSolidShare(double anchor, double height) =>
    height <= 0 ? 0 : (1 - anchor / height).clamp(0.0, 0.999);

class DarkLayerPainter extends CustomPainter {
  DarkLayerPainter(this.anchor) : super(repaint: anchor);

  final ValueListenable<double> anchor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = size.height;
    final solid = darkSolidShare(anchor.value, size.height);
    canvas
      ..save()
      ..translate(size.width / 2, size.height)
      ..scale(PeopleBackdropStyle.darkWidth, 1);
    final reach = size.width / 2 / PeopleBackdropStyle.darkWidth;
    canvas.drawRect(
      Rect.fromLTRB(-reach, -radius, reach, 0),
      Paint()
        ..shader = ui.Gradient.radial(
          Offset.zero,
          radius,
          const [
            PeopleBackdropStyle.black,
            PeopleBackdropStyle.black,
            PeopleBackdropStyle.clear,
          ],
          [0, solid, 1],
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DarkLayerPainter old) => old.anchor != anchor;
}

class BackdropScene extends ChangeNotifier {
  BackdropScene(this.position) {
    position.addListener(_onPosition);
  }

  final ValueListenable<double> position;

  final _entries = <Object, ({int index, List<Color> colors})>{};
  final _anchors = <Object, ValueListenable<double>>{};
  late final anchor = _SceneAnchor(this);
  int _current = 0;
  var _notifyScheduled = false;
  var _disposed = false;

  List<Color> get colors => _colorsAt(_current);

  List<Color> _colorsAt(int index) {
    for (final entry in _entries.values) {
      if (entry.index == index) return entry.colors;
    }
    return const [];
  }

  ValueListenable<double>? _anchorAt(int index) {
    for (final MapEntry(:key, :value) in _entries.entries) {
      if (value.index == index) return _anchors[key];
    }
    return null;
  }

  void report(
    Object owner, {
    required int index,
    required List<Color> colors,
    required ValueListenable<double> anchor,
  }) {
    final before = _entries[owner];
    final old = _anchors[owner];
    if (old != anchor) {
      old?.removeListener(this.anchor.changed);
      anchor.addListener(this.anchor.changed);
      _anchors[owner] = anchor;
    }
    _entries[owner] = (index: index, colors: colors);
    final visible = index == _current || before?.index == _current;
    if (before == null ||
        before.index != index ||
        (visible && !listEquals(before.colors, colors))) {
      _later();
    }
  }

  void forget(Object owner) {
    _anchors.remove(owner)?.removeListener(anchor.changed);
    if (_entries.remove(owner) != null) _later();
  }

  void _onPosition() {
    anchor.changed();
    final current = position.value.round();
    if (current == _current) return;
    _current = current;
    notifyListeners();
  }

  void _later() {
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (_disposed) return;
      anchor.changed();
      notifyListeners();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    _disposed = true;
    position.removeListener(_onPosition);
    for (final listenable in _anchors.values) {
      listenable.removeListener(anchor.changed);
    }
    anchor.dispose();
    super.dispose();
  }
}

class _SceneAnchor extends ChangeNotifier implements ValueListenable<double> {
  _SceneAnchor(this.scene);

  final BackdropScene scene;

  void changed() => notifyListeners();

  @override
  double get value {
    final at = scene.position.value;
    final low = at.floor();
    final from = scene._anchorAt(low)?.value;
    final to = scene._anchorAt(low + 1)?.value;
    if (from == null) return to ?? 0;
    if (to == null) return from;
    return from + (to - from) * (at - low);
  }
}
