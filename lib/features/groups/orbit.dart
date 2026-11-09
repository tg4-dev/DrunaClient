import 'dart:math' as math;

import 'package:druna_app/models/models.dart';
import 'package:flutter/foundation.dart';
import 'package:druna_app/shared/ui/motion.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

abstract final class OrbitStyle {
  static const widthShare = 0.75;
  static const height = 170.0;
  static const tilt = -15 * math.pi / 180;
  static const avatar = 56.0;
  static const period = Duration(seconds: 40);
  static const depth = 0.15;

  static const box = height + avatar;
}

Offset orbitPoint({
  required Size box,
  required double angle,
  double tilt = OrbitStyle.tilt,
}) {
  final a = box.width * OrbitStyle.widthShare / 2;
  const b = OrbitStyle.height / 2;
  final x = a * math.cos(angle);
  final y = b * math.sin(angle);
  return Offset(
    box.width / 2 + x * math.cos(tilt) - y * math.sin(tilt),
    box.height / 2 + x * math.sin(tilt) + y * math.cos(tilt),
  );
}

double orbitDepth(double angle) => 1 + OrbitStyle.depth * math.sin(angle);

double orbitSlot(int index, int count) =>
    count <= 0 ? 0 : 2 * math.pi * index / count;

class _Rider {
  _Rider(this.person, this.angle) : grow = 0;

  FriendInfo person;
  double angle;
  double fromAngle = 0;
  double toAngle = 0;
  double moved = 1;

  double grow;
  double growFrom = 0;
  double growTo = 1;
  double grown = 0;

  bool get gone => growTo == 0 && grown >= 1;
}

class Orbit extends StatefulWidget {
  const Orbit({
    required this.people,
    required this.meId,
    this.center,
    super.key,
  });

  final List<FriendInfo> people;
  final int meId;
  final Widget? center;

  static bool enabled = true;

  @override
  State<Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<Orbit> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _phase = ValueNotifier<double>(0);
  final _riders = <_Rider>[];
  Duration _last = Duration.zero;

  bool get _still =>
      !Orbit.enabled || (MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void initState() {
    super.initState();
    final count = widget.people.length;
    for (var i = 0; i < count; i++) {
      _riders.add(
        _Rider(widget.people[i], orbitSlot(i, count))
          ..grow = 1
          ..grown = 1,
      );
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    didChangeDependencies();
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
  void didUpdateWidget(covariant Orbit oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = [for (final person in widget.people) person.id];
    for (final rider in _riders) {
      if (!ids.contains(rider.person.id) && rider.growTo != 0) {
        rider
          ..growFrom = rider.grow
          ..growTo = 0
          ..grown = 0;
      }
    }
    final count = widget.people.length;
    for (var i = 0; i < count; i++) {
      final person = widget.people[i];
      final target = orbitSlot(i, count);
      final existing = _riders.where(
        (rider) => rider.person.id == person.id && rider.growTo != 0,
      );
      if (existing.isEmpty) {
        _riders.add(
          _Rider(person, target)
            ..growFrom = 0
            ..growTo = 1
            ..grown = _still ? 1 : 0
            ..grow = _still ? 1 : 0,
        );
        continue;
      }
      final rider = existing.first..person = person;
      if (rider.angle != target) {
        rider
          ..fromAngle = rider.angle
          ..toAngle = target
          ..moved = _still ? 1 : 0;
        if (_still) rider.angle = target;
      }
    }
    if (_still) _riders.removeWhere((rider) => rider.growTo == 0);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _phase.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    final turn = OrbitStyle.period.inMicroseconds / 1e6;
    final step = dt * 1e6 / Motion.medium.inMicroseconds;
    final growStep = dt * 1e6 / Motion.long.inMicroseconds;
    for (final rider in _riders) {
      if (rider.moved < 1) {
        rider.moved = (rider.moved + step).clamp(0.0, 1.0);
        final t = Motion.settle.transform(rider.moved);
        rider.angle = rider.fromAngle + (rider.toAngle - rider.fromAngle) * t;
      }
      if (rider.grown < 1) {
        rider.grown = (rider.grown + growStep).clamp(0.0, 1.0);
        final curve = rider.growTo > rider.growFrom
            ? Motion.enter
            : Motion.exit;
        rider.grow =
            rider.growFrom +
            (rider.growTo - rider.growFrom) * curve.transform(rider.grown);
      }
    }
    final before = _riders.length;
    _riders.removeWhere((rider) => rider.gone);
    if (_riders.length != before) setState(() {});
    _phase.value = (_phase.value + dt * 2 * math.pi / turn) % (2 * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final riders = List.of(_riders);
    final center = widget.center;
    return LayoutBuilder(
      builder: (context, constraints) => SizedBox(
        width: constraints.maxWidth,
        height: OrbitStyle.box,
        child: RepaintBoundary(
          child: Flow(
            clipBehavior: Clip.none,
            delegate: _OrbitFlow(
              phase: _phase,
              riders: riders,
              center: center != null,
            ),
            children: [
              for (final rider in riders)
                KeyedSubtree(
                  key: ValueKey('orbit-slot-${rider.person.id}'),
                  child: IgnorePointer(
                    child: PersonAvatar(
                      key: ValueKey('orbit-${rider.person.id}'),
                      id: rider.person.id,
                      name: rider.person.name,
                      username: rider.person.username,
                      size: OrbitStyle.avatar,
                    ),
                  ),
                ),
              if (center != null)
                Center(key: const ValueKey('orbit-center'), child: center),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbitFlow extends FlowDelegate {
  _OrbitFlow({required this.phase, required this.riders, required this.center})
    : super(repaint: phase);

  final ValueListenable<double> phase;
  final List<_Rider> riders;
  final bool center;

  @override
  BoxConstraints getConstraintsForChild(int i, BoxConstraints constraints) =>
      i < riders.length
      ? BoxConstraints.tight(const Size.square(OrbitStyle.avatar))
      : BoxConstraints.tight(constraints.biggest);

  @override
  void paintChildren(FlowPaintingContext context) {
    final at = phase.value;
    final order = [for (var i = 0; i < riders.length; i++) i]
      ..sort(
        (a, b) => math
            .sin(at + riders[a].angle)
            .compareTo(math.sin(at + riders[b].angle)),
      );
    void paintRider(int i) {
      final rider = riders[i];
      final scale = rider.grow * orbitDepth(at + rider.angle);
      if (scale <= 0) return;
      final point = orbitPoint(box: context.size, angle: at + rider.angle);
      const half = OrbitStyle.avatar / 2;
      context.paintChild(
        i,
        transform: Matrix4.translationValues(point.dx, point.dy, 0)
          ..scaleByDouble(scale, scale, 1, 1)
          ..translateByDouble(-half, -half, 0, 1),
      );
    }

    for (final i in order) {
      if (math.sin(at + riders[i].angle) < 0) paintRider(i);
    }
    if (center) context.paintChild(riders.length);
    for (final i in order) {
      if (math.sin(at + riders[i].angle) >= 0) paintRider(i);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitFlow old) =>
      old.phase != phase || old.riders != riders || old.center != center;

  @override
  bool shouldRelayout(covariant _OrbitFlow old) =>
      old.riders.length != riders.length || old.center != center;
}
