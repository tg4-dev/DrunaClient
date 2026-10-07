import 'package:druna_app/features/calendar/day_timeline.dart';
import 'package:druna_app/features/calendar/day_title_layout.dart';
import 'package:druna_app/features/calendar/expand_geometry.dart';
import 'package:druna_app/features/calendar/month_calendar.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:flutter/material.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  final _monthKey = GlobalKey<MonthCalendarState>();
  final _timelineKey = GlobalKey<DayTimelineState>();
  final _dayMetrics = DayScrollMetrics();
  late final AnimationController _expand;
  DateTime? _day;
  Rect? _from;
  double? _monthOffset;
  int? _openedStrip;
  var _pulling = false;

  @override
  void initState() {
    super.initState();
    _expand = AnimationController(vsync: this, duration: expandOpenDuration);
  }

  @override
  void dispose() {
    _expand.dispose();
    _dayMetrics.dispose();
    super.dispose();
  }

  Future<void> _open(DateTime day, Rect weekRect) async {
    final date = DateTime(day.year, day.month, day.day);
    setState(() {
      _day = date;
      _from = weekRect;
      _monthOffset = _monthKey.currentState?.scrollOffset;
      _openedStrip = stripIndexOfDay(date);
    });
    await _expand.animateTo(1, curve: Curves.easeOutCubic);
  }

  double _pullRange() {
    final travel = _from?.top ?? 280;
    return travel.clamp(1.0, 1200.0);
  }

  void _onPullStart(DragStartDetails details) {
    if (_day == null || _expand.value < 0.98) return;
    _expand.stop();
    setState(() => _pulling = true);
  }

  void _onPullUpdate(DragUpdateDetails details) {
    if (!_pulling) return;
    final delta = details.primaryDelta ?? 0;
    _expand.value = (_expand.value - delta / _pullRange()).clamp(0.0, 1.0);
  }

  void _onPullEnd(DragEndDetails details) {
    _finishPull(details.primaryVelocity ?? 0);
  }

  void _onPullCancel() {
    _finishPull(0);
  }

  void _finishPull(double velocity) {
    if (!_pulling) return;
    setState(() => _pulling = false);
    if (velocity > 500 || _expand.value < 0.7) {
      _close();
      return;
    }
    final remaining = 1 - _expand.value;
    _expand.animateTo(
      1,
      duration: _scrubDuration(remaining),
      curve: Curves.easeOutCubic,
    );
  }

  Duration _scrubDuration(double span) {
    final milliseconds = (expandOpenDuration.inMilliseconds * span).round();
    return Duration(milliseconds: milliseconds.clamp(1, 360));
  }

  Future<void> _close() async {
    if (!mounted) return;
    final day = _day;
    if (day != null) {
      final same = _openedStrip != null && stripIndexOfDay(day) == _openedStrip;
      final Rect? rect;
      if (same && _monthOffset != null) {
        _monthKey.currentState?.restoreOffset(_monthOffset!);
        rect = _monthKey.currentState?.rectForStrip(stripIndexOfDay(day));
      } else {
        rect = _monthKey.currentState?.revealDay(day);
      }
      if (rect != null) setState(() => _from = rect);
    }
    await _expand.animateTo(
      0,
      duration: _scrubDuration(_expand.value),
      curve: Curves.easeOutCubic,
    );
    if (!mounted) return;
    setState(() {
      _day = null;
      _from = null;
      _monthOffset = null;
      _openedStrip = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final day = _day;
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: _expand,
        builder: (context, _) {
          final t = _expand.value;
          final layout = day != null && _from != null
              ? expandLayout(
                  t: t,
                  week: _from!,
                  screenHeight: MediaQuery.sizeOf(context).height,
                )
              : null;
          return Stack(
            children: [
              IgnorePointer(
                ignoring: t > 0.04,
                child: MonthCalendar(
                  key: _monthKey,
                  focus: DateTime.now(),
                  onDayTap: _open,
                ),
              ),
              if (day != null && _from != null)
                _ExpandedDay(
                  layout: layout!,
                  day: day,
                  timelineKey: _timelineKey,
                  metrics: _dayMetrics,
                  onVisibleDay: (next) {
                    if (_day == next) return;
                    setState(() => _day = next);
                  },
                  onClose: _close,
                  pulling: _pulling,
                  onPullStart: _onPullStart,
                  onPullUpdate: _onPullUpdate,
                  onPullEnd: _onPullEnd,
                  onPullCancel: _onPullCancel,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ExpandedDay extends StatelessWidget {
  const _ExpandedDay({
    required this.layout,
    required this.day,
    required this.timelineKey,
    required this.metrics,
    required this.onVisibleDay,
    required this.onClose,
    required this.pulling,
    required this.onPullStart,
    required this.onPullUpdate,
    required this.onPullEnd,
    required this.onPullCancel,
  });

  final ExpandLayout layout;
  final DateTime day;
  final GlobalKey<DayTimelineState> timelineKey;
  final DayScrollMetrics metrics;
  final ValueChanged<DateTime> onVisibleDay;
  final VoidCallback onClose;
  final bool pulling;
  final GestureDragStartCallback onPullStart;
  final GestureDragUpdateCallback onPullUpdate;
  final GestureDragEndCallback onPullEnd;
  final VoidCallback onPullCancel;

  @override
  Widget build(BuildContext context) {
    final sheetHeight = (layout.bottom - layout.top).clamp(
      0.0,
      double.infinity,
    );
    final headerHeight = MediaQuery.paddingOf(context).top + monthTitleHeight;
    final gridHeight = (sheetHeight - headerHeight).clamp(0.0, double.infinity);
    return Stack(
      children: [
        Positioned(
          top: layout.top,
          left: 0,
          right: 0,
          height: sheetHeight,
          child: IgnorePointer(
            ignoring: !pulling && layout.motion < 0.02,
            child: Opacity(
              opacity: layout.veil.clamp(0, 1),
              child: ColoredBox(
                color: Colors.black,
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned(
                        top: headerHeight,
                        left: 0,
                        right: 0,
                        height: gridHeight,
                        child: IgnorePointer(
                          ignoring: pulling || layout.motion < 0.98,
                          child: DayTimeline(
                            key: timelineKey,
                            day: day,
                            metrics: metrics,
                            onVisibleDay: onVisibleDay,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: headerHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onVerticalDragStart: onPullStart,
                          onVerticalDragUpdate: onPullUpdate,
                          onVerticalDragEnd: onPullEnd,
                          onVerticalDragCancel: onPullCancel,
                          child: SafeArea(
                            bottom: false,
                            child: SizedBox(
                              height: monthTitleHeight,
                              child: Stack(
                                clipBehavior: Clip.hardEdge,
                                children: [
                                  Positioned.fill(
                                    child: AnimatedBuilder(
                                      animation: metrics,
                                      builder: (context, _) =>
                                          _DayTitleTrack(metrics: metrics),
                                    ),
                                  ),
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    child: IconButton(
                                      onPressed: onClose,
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.bottomLeft,
                                      constraints: const BoxConstraints(
                                        minWidth: 44,
                                        minHeight: 36,
                                      ),
                                      icon: const Icon(
                                        Icons.chevron_left,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

const _dayTitleMinX = 40.0;

String _dayTitle(DateTime day) => '${day.day} ${weekdayShort(day)}';

TextStyle _dayTitleStyle(
  double size,
  double opacity, [
  FontWeight weight = FontWeight.w700,
  double letterSpacing = -0.6,
]) => TextStyle(
  color: Colors.white.withValues(alpha: opacity.clamp(0, 1)),
  fontSize: size,
  fontWeight: weight,
  letterSpacing: letterSpacing,
  height: 1,
);

double _titleWidth(
  String text,
  double size,
  FontWeight weight, [
  double letterSpacing = -0.6,
]) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: _dayTitleStyle(size, 1, weight, letterSpacing),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

double _fitOpacity(double x, double width) {
  if (width <= 0 || x >= _dayTitleMinX) return 1;
  return ((x + width - _dayTitleMinX) / width).clamp(0.0, 1.0);
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

class _MidnightLine {
  const _MidnightLine(this.x, this.span);

  final double x;
  final double span;
}

class _MidnightRulesPainter extends CustomPainter {
  const _MidnightRulesPainter(this.lines);

  final List<_MidnightLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.34)
      ..strokeWidth = 1;
    for (final line in lines) {
      final top = size.height - line.span;
      canvas.drawLine(Offset(line.x, top), Offset(line.x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MidnightRulesPainter oldDelegate) => true;
}

class _DayTitleTrack extends StatelessWidget {
  const _DayTitleTrack({required this.metrics});

  final DayScrollMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final probe = dayTitleLayout(
      offset: metrics.offset,
      pixelsPerHour: metrics.pixelsPerHour,
      bigWidth: 1,
    );
    final titles = dayTitleLayout(
      offset: metrics.offset,
      pixelsPerHour: metrics.pixelsPerHour,
      bigWidth: _titleWidth(
        _dayTitle(_dayAt(probe.index)),
        dayTitleBig,
        FontWeight.w700,
      ),
    );
    final currentWeight =
        FontWeight.lerp(FontWeight.w700, FontWeight.w400, titles.travel) ??
        FontWeight.w700;
    final currentWidth = _titleWidth(
      _dayTitle(_dayAt(titles.index)),
      titles.currentSize,
      currentWeight,
    );
    final currentX = titles.currentX(currentWidth);
    final nextWeight =
        FontWeight.lerp(FontWeight.w400, FontWeight.w700, titles.travel) ??
        FontWeight.w400;
    final nextX = titles.nextX();
    final lines = <_MidnightLine>[
      _MidnightLine(titles.currentMidnight, titles.currentSize),
      if (titles.nextMidnight != null)
        _MidnightLine(titles.nextMidnight!, titles.nextSize),
    ];
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _MidnightRulesPainter(lines)),
        ),
        if (titles.index > 0) _previous(titles),
        _placed(
          titles.index,
          currentX,
          titles.currentSize,
          currentWeight,
          _fitOpacity(currentX, currentWidth),
        ),
        if (nextX != null)
          _placed(
            titles.index + 1,
            nextX,
            titles.nextSize,
            nextWeight,
            _lerp(0.8, 1, titles.travel),
          ),
      ],
    );
  }

  Widget _previous(DayTitleLayout titles) {
    final width = _titleWidth(
      _dayTitle(_dayAt(titles.index - 1)),
      dayTitleSmall,
      FontWeight.w400,
    );
    final x = titles.previousX(width);
    return _placed(
      titles.index - 1,
      x,
      dayTitleSmall,
      FontWeight.w400,
      _fitOpacity(x, width),
    );
  }

  DateTime _dayAt(int dayIndex) => addCalendarDays(dayTimelineOrigin, dayIndex);

  Widget _placed(
    int dayIndex,
    double x,
    double size,
    FontWeight weight,
    double opacity,
  ) {
    if (opacity < 0.02) return const SizedBox.shrink();
    return Positioned(
      left: x,
      bottom: 0,
      child: Text(
        _dayTitle(_dayAt(dayIndex)),
        style: _dayTitleStyle(size, opacity, weight),
      ),
    );
  }
}
