import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/timeline_scale.dart';
import 'package:flutter/material.dart';

final dayTimelineOrigin = DateTime(1970, 1, 1);
const dayTimelineDayCount = 365 * 130;

class DayScrollMetrics extends ChangeNotifier {
  double offset = 0;
  double pixelsPerHour = defaultPixelsPerHour;

  var _disposed = false;

  void update(double offset, double pixelsPerHour) {
    if (_disposed) return;
    if (this.offset == offset && this.pixelsPerHour == pixelsPerHour) return;
    this.offset = offset;
    this.pixelsPerHour = pixelsPerHour;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class DayTimeline extends StatefulWidget {
  const DayTimeline({
    required this.day,
    required this.onVisibleDay,
    this.metrics,
    this.hourLabelOpacity = 1,
    super.key,
  });

  final DateTime day;
  final ValueChanged<DateTime> onVisibleDay;
  final DayScrollMetrics? metrics;
  final double hourLabelOpacity;

  @override
  State<DayTimeline> createState() => DayTimelineState();
}

class DayTimelineState extends State<DayTimeline>
    with SingleTickerProviderStateMixin {
  static const _dayCount = dayTimelineDayCount;

  final _listKey = GlobalKey();
  late final ScrollController _scroll;
  late final AnimationController _snap;
  double _pixels = defaultPixelsPerHour;
  double _pinchStartPixels = defaultPixelsPerHour;
  double _pinchStartOffset = 0;
  double _pinchStartFocal = 0;
  double _lastFocal = 0;
  double _snapFrom = defaultPixelsPerHour;
  double _snapTo = defaultPixelsPerHour;
  double _snapOffset = 0;
  double _snapFocal = 0;
  final _pointers = <int, Offset>{};
  double? _pinchStartDistance;
  DateTime? _reportedDay;
  var _snapping = false;

  @override
  void initState() {
    super.initState();
    final index = calendarDaysBetween(dayTimelineOrigin, dateOnly(widget.day));
    final origin = index * 24 * _pixels - dayMidnightInset;
    _scroll = ScrollController(initialScrollOffset: origin < 0 ? 0 : origin)
      ..addListener(_publish);
    _reportedDay = dateOnly(widget.day);
    _snap = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    )..addListener(_onSnapTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _publish();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _snap.dispose();
    super.dispose();
  }

  int _visibleIndex() {
    final hours = (_scroll.offset + dayMidnightInset) / _pixels;
    return (hours / 24).floor().clamp(0, _dayCount - 1);
  }

  Future<void> alignToInset() async {
    if (!mounted || !_scroll.hasClients) return;
    final target = (_visibleIndex() * 24 * _pixels - dayMidnightInset)
        .clamp(0, _scroll.position.maxScrollExtent)
        .toDouble();
    if ((_scroll.offset - target).abs() < 1) return;
    await _scroll.animateTo(
      target,
      duration: expandAlignDuration,
      curve: Curves.easeOutCubic,
    );
  }

  void _publish() {
    if (!_scroll.hasClients) return;
    widget.metrics?.update(_scroll.offset, _pixels);
    final day = addCalendarDays(dayTimelineOrigin, _visibleIndex());
    if (_reportedDay == day) return;
    _reportedDay = day;
    widget.onVisibleDay(day);
  }

  void _jump(double offset) {
    if (!_scroll.hasClients) return;
    final max = _scroll.position.maxScrollExtent;
    if (offset <= max) {
      _scroll.jumpTo(offset.clamp(0, max).toDouble());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final grown = _scroll.position.maxScrollExtent;
      _scroll.jumpTo(offset.clamp(0, grown).toDouble());
    });
  }

  double? _focalInList() {
    final box = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || _pointers.length < 2) return null;
    final points = _pointers.values.toList();
    final mid = Offset(
      (points[0].dx + points[1].dx) / 2,
      (points[0].dy + points[1].dy) / 2,
    );
    return box.globalToLocal(mid).dx;
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.position;
    if (_pointers.length != 2) return;
    _snap.stop();
    _snapping = false;
    _pinchStartDistance = _pointerDistance();
    _pinchStartPixels = _pixels;
    _pinchStartOffset = _scroll.hasClients ? _scroll.offset : 0;
    _pinchStartFocal = _focalInList() ?? 0;
    _lastFocal = _pinchStartFocal;
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;
    final start = _pinchStartDistance;
    if (_pointers.length < 2 || start == null || start == 0) return;
    final scale = _pointerDistance() / start;
    final next = (_pinchStartPixels * scale)
        .clamp(timelineMinPixelsPerHour, timelineMaxPixelsPerHour)
        .toDouble();
    final focal = _focalInList() ?? _pinchStartFocal;
    _lastFocal = focal;
    final anchored = zoomedOffset(
      offset: _pinchStartOffset,
      focal: _pinchStartFocal,
      oldExtent: _pinchStartPixels,
      newExtent: next,
    );
    setState(() => _pixels = next);
    _jump(anchored + _pinchStartFocal - focal);
    _publish();
  }

  void _onPointerUp(PointerEvent event) {
    final wasPinch = _pointers.length >= 2;
    _pointers.remove(event.pointer);
    if (!wasPinch || _pointers.length >= 2) return;
    _pinchStartDistance = null;
    _snapFrom = _pixels;
    _snapTo = nearestTimelinePixels(_pixels);
    _snapOffset = _scroll.hasClients ? _scroll.offset : 0;
    _snapFocal = _lastFocal;
    _snapping = true;
    _snap.forward(from: 0);
    setState(() {});
  }

  void _onSnapTick() {
    if (!_snapping) return;
    final t = Curves.easeOutCubic.transform(_snap.value);
    final next = _snapFrom + (_snapTo - _snapFrom) * t;
    final offset = zoomedOffset(
      offset: _snapOffset,
      focal: _snapFocal,
      oldExtent: _snapFrom,
      newExtent: next,
    );
    setState(() => _pixels = next);
    _jump(offset);
    _publish();
    if (_snap.isCompleted) _snapping = false;
  }

  double _pointerDistance() {
    final points = _pointers.values.toList();
    return (points[0] - points[1]).distance;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerUp,
        child: ListView.builder(
          key: _listKey,
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          physics: _pointers.length >= 2
              ? const NeverScrollableScrollPhysics()
              : const BouncingScrollPhysics(),
          itemCount: _dayCount,
          itemExtent: 24 * _pixels,
          itemBuilder: (context, index) => CustomPaint(
            painter: _HourGridPainter(
              pixelsPerHour: _pixels,
              hourLabelOpacity: widget.hourLabelOpacity,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _HourGridPainter extends CustomPainter {
  const _HourGridPainter({
    required this.pixelsPerHour,
    required this.hourLabelOpacity,
  });

  final double pixelsPerHour;
  final double hourLabelOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final half = halfHourOpacity(pixelsPerHour);
    for (var hour = 0; hour < 24; hour++) {
      final opacity = hourLineOpacity(hour, pixelsPerHour);
      final x = hour * pixelsPerHour;
      if (opacity > 0.02) {
        if (hourLabelOpacity > 0.02) _label(canvas, hour, x, opacity);
        canvas.drawLine(
          Offset(x, hour == 0 ? 0 : 28),
          Offset(x, size.height),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.34 * opacity)
            ..strokeWidth = 1,
        );
      }
      if (half > 0.02) {
        final mid = x + pixelsPerHour / 2;
        canvas.drawLine(
          Offset(mid, 36),
          Offset(mid, size.height),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.22 * half)
            ..strokeWidth = 0.6,
        );
      }
    }
  }

  void _label(Canvas canvas, int hour, double x, double opacity) {
    final painter = TextPainter(
      text: TextSpan(
        text: hour.toString().padLeft(2, '0'),
        style: TextStyle(
          color: const Color(
            0xFF8E8E93,
          ).withValues(alpha: opacity * hourLabelOpacity),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x + 4, 6));
  }

  @override
  bool shouldRepaint(covariant _HourGridPainter oldDelegate) =>
      oldDelegate.pixelsPerHour != pixelsPerHour ||
      oldDelegate.hourLabelOpacity != hourLabelOpacity;
}
