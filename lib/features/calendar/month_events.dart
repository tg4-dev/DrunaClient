import 'dart:ui' as ui;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/week_bands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Rounder month chips: half the height for thin bars, at most 8.
double monthChipRadius(EventDensity density) =>
    (density.itemHeight / 2).clamp(3.0, 8.0);

/// Days a dragged event would cover if dropped now.
class DropRange {
  const DropRange(this.first, this.last, {required this.moving});

  final DateTime first;
  final DateTime last;

  /// An existing event is being moved, not a new one placed.
  final bool moving;

  bool covers(DateTime day) => !day.isBefore(first) && !day.isAfter(last);

  @override
  bool operator ==(Object other) =>
      other is DropRange &&
      other.first == first &&
      other.last == last &&
      other.moving == moving;

  @override
  int get hashCode => Object.hash(first, last, moving);
}

/// How the month shows events: 0 — the user's in full and friends' as a
/// band at the bottom of each week; 1 — friends' in full and the user's as
/// a band at the top. Values between follow the finger.
const myEventsMode = AlwaysStoppedAnimation<double>(0);

/// Below this mode the user's events take taps; above it friends' are shown.
const calendarModeHalfway = 0.5;

/// The hidden layer's band reaches this share of the week's height from its
/// line, within [bandMinHeight] and [bandMaxHeight].
const bandHeightShare = 0.2;
const bandMinHeight = 16.0;
const bandMaxHeight = 40.0;

/// Only this strip along the line switches to the user's events, so a tap
/// on a day number still opens the day: "tap the red carefully".
const bandTapHeight = 14.0;

double bandHeightFor(double rowHeight) =>
    (rowHeight * bandHeightShare).clamp(bandMinHeight, bandMaxHeight);

double _smooth(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class MonthWeekGrid extends StatelessWidget {
  const MonthWeekGrid({
    required this.strip,
    required this.rowKey,
    required this.today,
    required this.onDayTap,
    required this.index,
    this.friendIndex,
    this.mode = myEventsMode,
    this.onShowMine,
    this.hiddenEventId,
    this.dimmedEventId,
    this.hoverDay,
    this.onEventTap,
    this.onHoldStart,
    super.key,
  });

  final MonthStrip strip;
  final String rowKey;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;
  final CalendarEventIndex index;

  /// Busy time of the selected friends, drawn in their colours.
  final CalendarEventIndex? friendIndex;
  final ValueListenable<double> mode;

  /// A tap on the band of the user's events while friends are shown.
  final VoidCallback? onShowMine;
  final String? hiddenEventId;

  /// The event being dragged stays in place, faded, until it is dropped.
  final String? dimmedEventId;

  /// The day under a dragged event; only the matching column repaints.
  final ValueListenable<DropRange?>? hoverDay;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    final days = daysOfWeek(strip.weekIndex);
    final firstOfMonth = days.indexWhere((day) => day.day == 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final density = densityForRowHeight(size.height);
        final capacity = monthEventCapacity(size.height, density);
        final visible = _visibleRange(strip.kind, firstOfMonth);
        final columnWidth = size.width / 7;
        _WeekLayer layerOf(CalendarEventIndex source, String? hidden) =>
            _WeekLayer.build(
              index: source,
              strip: strip,
              days: days,
              visible: visible,
              capacity: capacity,
              hiddenEventId: hidden,
              density: density,
              columnWidth: columnWidth,
            );
        final own = OwnEventColor.of(context);
        final mine = layerOf(index, hiddenEventId);
        final friends = friendIndex == null
            ? null
            : layerOf(friendIndex!, null);
        final mineBands = buildSolidBands(mine.bandChips, own);
        final friendBands = friends == null
            ? const <WeekBand>[]
            : buildWeekBands(friends.bandChips, columnWidth: columnWidth);
        final bandHeight = bandHeightFor(size.height);
        final mineChips = _MineChips(
          layer: mine,
          days: days,
          density: density,
          columnWidth: columnWidth,
          dimmedEventId: dimmedEventId,
          onDayTap: onDayTap,
          onEventTap: onEventTap,
          onHoldStart: onHoldStart,
        );
        final friendChips = friends == null
            ? null
            : _FriendChips(
                layer: friends,
                density: density,
                columnWidth: columnWidth,
              );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Under the day numbers, so they stay readable over a band.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: ValueListenableBuilder<double>(
                    valueListenable: mode,
                    builder: (context, t, _) => CustomPaint(
                      painter: _BandPainter(
                        mine: mineBands,
                        friends: friendBands,
                        mode: t,
                        height: bandHeight,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _column(
                      days: days,
                      column: column,
                      firstOfMonth: firstOfMonth,
                      own: own,
                    ),
                  ),
              ],
            ),
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: mode,
                builder: (context, t, _) {
                  final friendsShown = t > calendarModeHalfway;
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Both layers stay mounted at every mode, so friends'
                      // chips keep their state and never replay their
                      // entrance after a swipe.
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: friendsShown,
                          child: _IntoLine(
                            away: t,
                            // Up through the top line, past the lowest chip.
                            distance: -mine.bottom(density),
                            child: mineChips,
                          ),
                        ),
                      ),
                      if (friendChips != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: _IntoLine(
                              away: 1 - t,
                              // Down through the bottom line, past the top
                              // chip.
                              distance: size.height - monthEventHeader,
                              child: friendChips,
                            ),
                          ),
                        ),
                      if (friendsShown && onShowMine != null)
                        for (final band in mineBands)
                          Positioned(
                            left: band.left,
                            width: band.width,
                            top: 0,
                            height: bandTapHeight,
                            child: Semantics(
                              button: true,
                              label: 'Показать мои события',
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onShowMine,
                              ),
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  (int, int) _visibleRange(MonthStripKind kind, int firstOfMonth) {
    var start = 7;
    var end = -1;
    for (var column = 0; column < 7; column++) {
      if (!columnVisible(
        kind: kind,
        firstOfMonth: firstOfMonth,
        column: column,
      )) {
        continue;
      }
      if (column < start) start = column;
      if (column > end) end = column;
    }
    return (start, end);
  }

  /// The day number and the empty space under it: tap opens the day, a long
  /// press creates an event there. Chips are drawn on top by the layers.
  Widget _column({
    required List<DateTime> days,
    required int column,
    required int firstOfMonth,
    required Color own,
  }) {
    final showDay = columnVisible(
      kind: strip.kind,
      firstOfMonth: firstOfMonth,
      column: column,
    );
    if (!showDay) return const SizedBox.expand();
    final day = days[column];
    final content = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onDayTap(day),
      onLongPressStart: (details) =>
          onHoldStart?.call(null, details.globalPosition),
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _DayNumber(day: day, today: sameDay(day, today)),
        ),
      ),
    );
    final hover = hoverDay;
    if (hover == null) {
      return KeyedSubtree(key: ValueKey('$rowKey-$column'), child: content);
    }
    return ValueListenableBuilder<DropRange?>(
      key: ValueKey('$rowKey-$column'),
      valueListenable: hover,
      child: content,
      builder: (context, range, child) => ColoredBox(
        color: range == null || !range.covers(day)
            ? Colors.transparent
            : range.moving
            ? own.withValues(alpha: 0.32)
            : Colors.white.withValues(alpha: 0.12),
        child: child,
      ),
    );
  }
}

/// One chip or bar of a week, in grid columns and lanes.
class _Placed {
  const _Placed({
    required this.event,
    required this.startColumn,
    required this.endColumn,
    required this.lane,
    this.continuesBefore = false,
    this.continuesAfter = false,
  });

  final CalendarEvent event;
  final int startColumn;
  final int endColumn;
  final int lane;
  final bool continuesBefore;
  final bool continuesAfter;

  bool get isSpan => startColumn != endColumn || event.allDay;

  /// Insets match the old column chips (2 pt each side) and bars that run
  /// on past the week edge.
  double left(double columnWidth) =>
      startColumn * columnWidth + (continuesBefore ? 0 : 2);

  double right(double columnWidth) =>
      (endColumn + 1) * columnWidth - (continuesAfter ? 0 : 2);
}

/// Everything one source of events puts into a week: chips, "+N" counts
/// and the busy spans its band is built from.
class _WeekLayer {
  const _WeekLayer({
    required this.placed,
    required this.overflow,
    required this.bandChips,
  });

  factory _WeekLayer.build({
    required CalendarEventIndex index,
    required MonthStrip strip,
    required List<DateTime> days,
    required (int, int) visible,
    required int capacity,
    required String? hiddenEventId,
    required EventDensity density,
    required double columnWidth,
  }) {
    final shown = [
      for (final event in index.forWeek(strip.weekIndex))
        if (event.id != hiddenEventId) event,
    ];
    final layout =
        index.memo.putIfAbsent(
              ('week', strip.weekIndex, strip.kind, capacity, hiddenEventId),
              () => layoutWeek(
                events: shown,
                days: days,
                visibleStart: visible.$1,
                visibleEnd: visible.$2,
                capacity: capacity,
              ),
            )
            as MonthWeekLayout;
    final byId = {for (final event in shown) event.id: event};
    final placed = <_Placed>[
      for (final span in layout.spans)
        if (layout.showsSpan(span) && byId[span.eventId] != null)
          _Placed(
            event: byId[span.eventId]!,
            startColumn: span.startColumn,
            endColumn: span.endColumn,
            lane: span.lane,
            continuesBefore: span.continuesBefore,
            continuesAfter: span.continuesAfter,
          ),
      for (var column = 0; column < 7; column++)
        for (final chip in layout.columns[column].chips)
          if (byId[chip.eventId] != null)
            _Placed(
              event: byId[chip.eventId]!,
              startColumn: column,
              endColumn: column,
              lane: chip.lane,
            ),
    ];
    final overflow = <(int, int, int)>[
      for (var column = 0; column < 7; column++)
        if (layout.columns[column].overflow > 0)
          (
            column,
            layout.columns[column].overflowLane ?? 0,
            layout.columns[column].overflow,
          ),
    ];
    // Every event of the week counts, also those hidden behind "+N": the
    // band shows when someone is busy, not which chips fit.
    final bandChips = <BandChip>[];
    for (final event in shown) {
      int? first;
      int? last;
      for (var column = visible.$1; column <= visible.$2; column++) {
        if (!eventOccursOn(event, days[column])) continue;
        first ??= column;
        last = column;
      }
      if (first == null || last == null) continue;
      final before =
          first == visible.$1 && eventFirstDay(event).isBefore(days[first]);
      final after =
          last == visible.$2 && eventLastDay(event).isAfter(days[last]);
      bandChips.add(
        BandChip(
          left: first * columnWidth + (before ? 0 : 2),
          right: (last + 1) * columnWidth - (after ? 0 : 2),
          color: event.color ?? calendarEventColor,
        ),
      );
    }
    return _WeekLayer(placed: placed, overflow: overflow, bandChips: bandChips);
  }

  final List<_Placed> placed;

  /// (column, lane, hidden count) for every "+N".
  final List<(int, int, int)> overflow;

  /// Where each event of the week sits along it, for the band.
  final List<BandChip> bandChips;

  /// The bottom of the lowest chip or "+N", from the top of the week.
  double bottom(EventDensity density) {
    var lanes = 0;
    for (final item in placed) {
      if (item.lane + 1 > lanes) lanes = item.lane + 1;
    }
    for (final (_, lane, _) in overflow) {
      if (lane + 1 > lanes) lanes = lane + 1;
    }
    return monthEventHeader + lanes * density.slot + 2;
  }
}

/// The user's chips: tappable, draggable, with "+N" opening the day.
class _MineChips extends StatelessWidget {
  const _MineChips({
    required this.layer,
    required this.days,
    required this.density,
    required this.columnWidth,
    required this.onDayTap,
    this.dimmedEventId,
    this.onEventTap,
    this.onHoldStart,
  });

  final _WeekLayer layer;
  final List<DateTime> days;
  final EventDensity density;
  final double columnWidth;
  final ValueChanged<DateTime> onDayTap;
  final String? dimmedEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final item in layer.placed)
          Positioned(
            left: item.left(columnWidth),
            width: item.right(columnWidth) - item.left(columnWidth),
            top: monthEventHeader + item.lane * density.slot,
            height: density.itemHeight,
            child: _MonthEventBlock(
              event: item.event,
              dimmed: item.event.id == dimmedEventId,
              density: density,
              continuesBefore: item.continuesBefore,
              continuesAfter: item.continuesAfter,
              onTap: onEventTap,
              onHoldStart: onHoldStart,
            ),
          ),
        for (final (column, lane, count) in layer.overflow)
          Positioned(
            left: column * columnWidth + 4,
            width: columnWidth - 6,
            top: monthEventHeader + lane * density.slot,
            height: density.itemHeight,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onDayTap(days[column]),
              child: _OverflowLabel(count),
            ),
          ),
      ],
    );
  }
}

class _OverflowLabel extends StatelessWidget {
  const _OverflowLabel(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      '+$count',
      style: const TextStyle(
        color: Color(0xFF8E8E93),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    ),
  );
}

/// How fast friends' chips react to the selection changing.
abstract final class FriendChipMotion {
  static const appear = Duration(milliseconds: 160);
  static const leave = Duration(milliseconds: 140);
  static const move = Duration(milliseconds: 180);
}

/// Friends' busy time. Picking a friend fades their chips in, letting one go
/// fades them out, and the chips around slide to their new lanes. Lanes are
/// animated rather than pixels, so pinching the month never lags.
class _FriendChips extends StatefulWidget {
  const _FriendChips({
    required this.layer,
    required this.density,
    required this.columnWidth,
  });

  final _WeekLayer layer;
  final EventDensity density;
  final double columnWidth;

  @override
  State<_FriendChips> createState() => _FriendChipsState();
}

class _FriendChipsState extends State<_FriendChips> {
  /// Chips whose friend was let go, playing their exit.
  final _leaving = <String, _Placed>{};

  @override
  void didUpdateWidget(covariant _FriendChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.layer, widget.layer)) return;
    final now = {for (final item in widget.layer.placed) item.event.id};
    final gone = [
      for (final item in oldWidget.layer.placed)
        if (!now.contains(item.event.id)) item,
    ];
    if (gone.isEmpty) return;
    for (final item in gone) {
      _leaving[item.event.id] = item;
    }
    Future<void>.delayed(FriendChipMotion.leave, () {
      if (!mounted) return;
      setState(() {
        for (final item in gone) {
          if (identical(_leaving[item.event.id], item)) {
            _leaving.remove(item.event.id);
          }
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final current = {for (final item in widget.layer.placed) item.event.id};
    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        for (final item in _leaving.values)
          if (!current.contains(item.event.id))
            _chip(item, leaving: true, reduce: reduce),
        for (final item in widget.layer.placed)
          _chip(item, leaving: false, reduce: reduce),
        for (final (column, lane, count) in widget.layer.overflow)
          Positioned(
            left: column * widget.columnWidth + 4,
            width: widget.columnWidth - 6,
            top: monthEventHeader + lane * widget.density.slot,
            height: widget.density.itemHeight,
            child: _OverflowLabel(count),
          ),
      ],
    );
  }

  Widget _chip(_Placed item, {required bool leaving, required bool reduce}) {
    final density = widget.density;
    final left = item.left(widget.columnWidth);
    final width = item.right(widget.columnWidth) - left;
    return TweenAnimationBuilder<double>(
      key: ValueKey('${leaving ? 'out' : 'in'}-${item.event.id}'),
      tween: Tween(end: item.lane.toDouble()),
      duration: reduce ? Duration.zero : FriendChipMotion.move,
      curve: Curves.easeOutCubic,
      builder: (context, lane, child) => Positioned(
        left: left,
        width: width,
        top: monthEventHeader + lane * density.slot,
        height: density.itemHeight,
        child: child!,
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: leaving ? 1 : 0, end: leaving ? 0 : 1),
        duration: reduce
            ? Duration.zero
            : leaving
            ? FriendChipMotion.leave
            : FriendChipMotion.appear,
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(
            scaleY: 0.6 + 0.4 * value,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
        child: _MonthEventBlock(
          event: item.event,
          density: density,
          continuesBefore: item.continuesBefore,
          continuesAfter: item.continuesAfter,
          showTitle: false,
        ),
      ),
    );
  }
}

/// A layer on its way out flies through its week line and is cut off by
/// it, the way it came back: chips leave across the line, never fade or
/// squash. Follows the finger; one transform per week. The tree is the same
/// at every [away], so stateful chips below keep their state.
class _IntoLine extends StatelessWidget {
  const _IntoLine({
    required this.away,
    required this.distance,
    required this.child,
  });

  /// 0 — in place, 1 — fully past the line.
  final double away;

  /// How far the layer travels to clear the line; negative is up.
  final double distance;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final travel = Curves.easeInCubic.transform(away.clamp(0.0, 1.0));
    return Opacity(
      // Fully past the line: skip painting, keep the state.
      opacity: away >= 1 ? 0 : 1,
      child: Transform.translate(
        offset: Offset(0, distance * travel),
        child: child,
      ),
    );
  }
}

/// The layer not shown in full lives on as bands on its week line: the
/// user's from the top line down, friends' from the bottom line up. Each
/// band is cut clean at the line and fades towards the middle of the week;
/// along it run the colours of the events (see [buildWeekBands]). A band
/// grows out of the line as its chips fold into it.
class _BandPainter extends CustomPainter {
  _BandPainter({
    required this.mine,
    required this.friends,
    required this.mode,
    required this.height,
  });

  final List<WeekBand> mine;
  final List<WeekBand> friends;
  final double mode;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    _paint(canvas, size, mine, away: mode, fromTop: true);
    _paint(canvas, size, friends, away: 1 - mode, fromTop: false);
  }

  void _paint(
    Canvas canvas,
    Size size,
    List<WeekBand> bands, {
    required double away,
    required bool fromTop,
  }) {
    if (away <= 0 || bands.isEmpty) return;
    final grow = Curves.easeOutCubic.transform(_smooth(0.3, 1, away));
    final opacity = _smooth(0.2, 0.7, away);
    final h = height * grow;
    if (h < 0.5 || opacity <= 0) return;
    final top = fromTop ? 0.0 : size.height - h;
    final line = fromTop ? top : top + h;
    final middle = fromTop ? top + h : top;
    final mask = Paint()
      ..blendMode = BlendMode.dstIn
      ..shader = ui.Gradient.linear(
        Offset(0, line),
        Offset(0, middle),
        const [
          Color(0xFF000000),
          Color(0x8C000000),
          Color(0x33000000),
          Color(0x00000000),
        ],
        const [0, 0.35, 0.7, 1],
      );
    final layer = Paint()..color = Color.fromRGBO(0, 0, 0, opacity);
    for (final band in bands) {
      final rect = Rect.fromLTRB(band.left, top, band.right, top + h);
      canvas.saveLayer(rect, layer);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(band.left, 0),
            Offset(band.right, 0),
            band.colors,
            band.stops,
          ),
      );
      canvas.drawRect(rect, mask);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _BandPainter old) =>
      old.mode != mode ||
      old.height != height ||
      !identical(old.mine, mine) ||
      !identical(old.friends, friends);
}

class _DayNumber extends StatelessWidget {
  const _DayNumber({required this.day, required this.today});

  final DateTime day;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final weekend = day.weekday >= DateTime.saturday;
    // Today: a white disc with the number cut out of it in black.
    final color = today
        ? Colors.black
        : weekend
        ? const Color(0xFFD1D1D6)
        : Colors.white;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: today
          ? const BoxDecoration(color: Colors.white, shape: BoxShape.circle)
          : null,
      child: Text(
        '${day.day}',
        key: ValueKey('day-${day.year}-${day.month}-${day.day}'),
        style: TextStyle(
          color: color,
          fontSize: 17,
          fontWeight: today ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}

class _MonthEventBlock extends StatelessWidget {
  const _MonthEventBlock({
    required this.event,
    required this.density,
    this.dimmed = false,
    this.continuesBefore = false,
    this.continuesAfter = false,
    this.onTap,
    this.onHoldStart,
    this.showTitle = true,
  });

  final CalendarEvent event;
  final EventDensity density;

  /// Friends' busy time has no title to show.
  final bool showTitle;
  final bool dimmed;
  final bool continuesBefore;
  final bool continuesAfter;
  final void Function(CalendarEvent event, Rect rect)? onTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    final color = eventColor(event, OwnEventColor.of(context));
    final ink = eventInk(color);
    final corner = Radius.circular(monthChipRadius(density));
    final radius = BorderRadius.horizontal(
      left: continuesBefore ? Radius.zero : corner,
      right: continuesAfter ? Radius.zero : corner,
    );
    return AnimatedOpacity(
      opacity: dimmed ? 0.35 : 1,
      duration: const Duration(milliseconds: 160),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null || !box.hasSize) return;
                onTap!(event, box.localToGlobal(Offset.zero) & box.size);
              },
        onLongPressStart: onHoldStart == null
            ? null
            : (details) => onHoldStart!(event, details.globalPosition),
        child: DecoratedBox(
          decoration: BoxDecoration(color: color, borderRadius: radius),
          child: density.showTitle && showTitle
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: density.showTime && !event.allDay
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              eventDisplayTitle(event),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: ink,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              clockLabel(event.start),
                              maxLines: 1,
                              style: TextStyle(
                                color: ink,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                          ],
                        )
                      : Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            eventDisplayTitle(event),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: ink,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              height: 1,
                            ),
                          ),
                        ),
                )
              : const SizedBox.expand(),
        ),
      ),
    );
  }
}
