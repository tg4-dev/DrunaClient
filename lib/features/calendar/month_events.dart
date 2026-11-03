import 'dart:math' as math;

import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/month_layout.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/calendar/week_bands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'package:druna_app/features/calendar/chip_motion.dart'
    show chipFoldGap, friendsFoldAt, myFoldAt;

/// Month chips are pills at the thin densities. From the title-and-time
/// chip up the corners are only rounded: a pill that tall would round the
/// text away.
double monthChipRadius(EventDensity density) => math.min(
  density.itemHeight / 2,
  density.showTime
      ? (density.titleLines > 1 ? monthChipMaxRadius : monthChipDetailRadius)
      : double.infinity,
);

const monthChipMaxRadius = 14.0;
const monthChipDetailRadius = 8.0;

/// A chip's title in one line.
const monthChipTitleStyle = TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  height: 1.1,
);

/// A chip running on past the week fades out over this much at that end.
const chipContinueFade = 16.0;

/// A one-line title fades into the chip over this much at its end.
const chipTitleFadeWidth = 10.0;

/// Room for the title inside a pill, clear of its round ends.
double monthChipPadding(EventDensity density) =>
    math.max(4, monthChipRadius(density) * 0.6);

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
    this.sharedIndex,
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

  /// Shared events: cells of their days under both layers, still while
  /// the mode changes (design-system §9.8).
  final CalendarEventIndex? sharedIndex;
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
        final visible = _visibleRange(strip.kind, firstOfMonth);
        final columnWidth = size.width / 7;
        final density = _densityWorthIt(
          densityForRowHeight(size.height),
          days: days,
          visible: visible,
          columnWidth: columnWidth,
        );
        final shared = _sharedCells(days, visible, columnWidth, size.height);
        final capacity = monthEventCapacity(size.height, density);
        // Friends' busy time has no titles: it never grows past the middle
        // density, however far the month is zoomed in.
        final friendDensity = friendDensityFor(density);
        final friendCapacity = monthEventCapacity(size.height, friendDensity);
        // On a day with a shared cell, chips stop above its title (or its
        // "+" and faces): they never cross it.
        final chipLimit = <int, double>{};
        for (final cell in shared) {
          final limit =
              cell.rect.bottom - sharedFrontHeight(cell.event, cell.rect);
          for (
            var column = cell.piece.startColumn;
            column <= cell.piece.endColumn;
            column++
          ) {
            chipLimit[column] = math.min(chipLimit[column] ?? limit, limit);
          }
        }
        List<int>? capacitiesFor(EventDensity d, int capacity) {
          if (chipLimit.isEmpty) return null;
          return [
            for (var column = 0; column < 7; column++)
              chipLimit[column] == null
                  ? capacity
                  : ((chipLimit[column]! - monthEventHeader + d.gap) / d.slot)
                        .floor()
                        .clamp(1, capacity),
          ];
        }

        _WeekLayer layerOf(
          CalendarEventIndex source,
          String? hidden,
          int capacity,
          List<int>? columnCapacity,
        ) => _WeekLayer.build(
          index: source,
          strip: strip,
          days: days,
          visible: visible,
          capacity: capacity,
          columnCapacity: columnCapacity,
          hiddenEventId: hidden,
          columnWidth: columnWidth,
        );
        final own = OwnEventColor.of(context);
        final mine = layerOf(
          index,
          hiddenEventId,
          capacity,
          capacitiesFor(density, capacity),
        );
        final friends = friendIndex == null
            ? null
            : layerOf(
                friendIndex!,
                null,
                friendCapacity,
                capacitiesFor(friendDensity, friendCapacity),
              );
        final mineBands = buildSolidBands(mine.bandChips, own);
        final friendBands = friends == null
            ? const <WeekBand>[]
            : buildWeekBands(friends.bandChips, columnWidth: columnWidth);
        final bandHeight = bandHeightFor(size.height);
        final mineChips = _MineChips(
          layer: mine,
          days: days,
          density: density,
          mode: mode,
          rowHeight: size.height,
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
                density: friendDensity,
                mode: mode,
                rowHeight: size.height,
                columnWidth: columnWidth,
                onEventTap: onEventTap,
              );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // Shared cells under everything; their taps go through the
            // day columns ([_column]).
            for (final cell in shared)
              Positioned.fromRect(
                key: ValueKey('shared-back-${cell.key}'),
                rect: cell.rect,
                child: IgnorePointer(
                  child: cell.event == null
                      ? SharedMoreCell(count: cell.piece.more)
                      : SharedCellBack(
                          event: cell.event!,
                          mode: mode,
                          upperBottom: _upperBottom(
                            cell,
                            mine: mine.bottomIn(cell.piece, density),
                            friends: friends?.bottomIn(
                              cell.piece,
                              friendDensity,
                            ),
                          ),
                        ),
                ),
              ),
            // Under the day numbers, so they stay readable over a band.
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  // Repaints on every mode change without rebuilding.
                  child: CustomPaint(
                    painter: _BandPainter(
                      mine: mineBands,
                      friends: friendBands,
                      mode: mode,
                      height: bandHeight,
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
                      shared: [
                        for (final cell in shared)
                          if (cell.piece.covers(column)) cell,
                      ],
                      columnWidth: columnWidth,
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
                      // entrance after a swipe. Folded away, a layer is
                      // not painted; each chip moves on its own
                      // ([ChipMotion]), clipped to the week.
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: friendsShown,
                          child: Opacity(
                            opacity: t >= 1 ? 0 : 1,
                            child: ClipRect(child: mineChips),
                          ),
                        ),
                      ),
                      // Friends' busy time takes no taps; the invites among
                      // it open their page ([_FriendChips]).
                      if (friendChips != null)
                        Positioned.fill(
                          child: IgnorePointer(
                            ignoring: !friendsShown,
                            child: Opacity(
                              opacity: t <= 0 ? 0 : 1,
                              child: ClipRect(child: friendChips),
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
            // Faces, dashed edges and "+" of shared cells: over the chips,
            // across the whole days.
            for (final cell in shared)
              if (cell.event case final event?)
                Positioned.fromRect(
                  key: ValueKey('shared-front-${cell.key}'),
                  rect: sharedDaysRect(cell.piece, columnWidth, cell.rect),
                  child: IgnorePointer(
                    child: SharedCellFront(
                      event: event,
                      mode: mode,
                      onScreenLeft: cell.piece.startColumn == 0,
                      onScreenRight: cell.piece.endColumn == 6,
                      cell: EdgeInsets.only(
                        left:
                            cell.rect.left -
                            cell.piece.startColumn * columnWidth,
                        right:
                            (cell.piece.endColumn + 1) * columnWidth -
                            cell.rect.right,
                      ),
                      upperBottom: _upperBottom(
                        cell,
                        mine: mine.bottomIn(cell.piece, density),
                        friends: friends?.bottomIn(cell.piece, friendDensity),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  /// Where the lowest thing above a cell's faces ends, from the top of the
  /// cell, at each step of the mode: the chips shown then, folding with
  /// their layer, or the day number.
  double Function(double mode) _upperBottom(
    _SharedCell cell, {
    required double? mine,
    required double? friends,
  }) {
    final base = math.max(
      cell.rect.top,
      cell.piece.slot == 0 ? dayNumberTop + dayNumberSize : cell.rect.top,
    );
    double reach(double? bottom, double shown) =>
        bottom == null || bottom <= base
        ? base
        : base + (bottom - base) * shown;
    return (t) =>
        math.max(
          reach(mine, chipShownAt(myFoldAt(t))),
          reach(friends, chipShownAt(friendsFoldAt(t))),
        ) -
        cell.rect.top;
  }

  List<_SharedCell> _sharedCells(
    List<DateTime> days,
    (int, int) visible,
    double columnWidth,
    double rowHeight,
  ) {
    final source = sharedIndex;
    if (source == null || visible.$1 > visible.$2) return const [];
    final events = source.forWeek(strip.weekIndex);
    if (events.isEmpty) return const [];
    final pieces =
        source.memo.putIfAbsent(
              ('shared', strip.weekIndex, strip.kind),
              () => layoutSharedWeek(
                events: events,
                days: days,
                visibleStart: visible.$1,
                visibleEnd: visible.$2,
              ),
            )
            as List<SharedPiece>;
    final byId = {for (final event in events) event.id: event};
    return [
      for (final piece in pieces)
        if (piece.eventId == null || byId[piece.eventId] != null)
          _SharedCell(
            piece: piece,
            event: piece.eventId == null ? null : byId[piece.eventId],
            rect: sharedPieceRect(piece, columnWidth, rowHeight),
          ),
    ];
  }

  /// The density the row's height allows, but no further than shows
  /// something new: the title-and-time chip only with a timed event to
  /// show the time of, the two-line chip only with a title that does not
  /// fit in one line. Otherwise the smaller chips stay, and more of them
  /// fit.
  EventDensity _densityWorthIt(
    EventDensity allowed, {
    required List<DateTime> days,
    required (int, int) visible,
    required double columnWidth,
  }) {
    if (!allowed.showTime) return allowed;
    final events = [
      for (final event in index.forWeek(strip.weekIndex))
        if (event.id != hiddenEventId) event,
    ];
    if (!events.any((event) => !event.allDay)) return titleDensity;
    if (allowed.titleLines < 2) return allowed;
    final padding = monthChipPadding(detailDensity);
    for (final event in events) {
      var columns = 0;
      for (var column = visible.$1; column <= visible.$2; column++) {
        if (eventOccursOn(event, days[column])) columns++;
      }
      if (columns == 0) continue;
      final room = columns * columnWidth - 4 - padding * 2;
      if (_titleWidth(eventDisplayTitle(event)) > room) return allowed;
    }
    return detailDensity;
  }

  static final _titleWidths = <String, double>{};

  /// How wide [title] is in a chip's one line.
  static double _titleWidth(String title) =>
      _titleWidths.putIfAbsent(title, () {
        final painter = TextPainter(
          text: TextSpan(text: title, style: monthChipTitleStyle),
          maxLines: 1,
          textDirection: TextDirection.ltr,
        )..layout();
        final width = painter.width;
        painter.dispose();
        return width;
      });

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
    required List<_SharedCell> shared,
    required double columnWidth,
  }) {
    final showDay = columnVisible(
      kind: strip.kind,
      firstOfMonth: firstOfMonth,
      column: column,
    );
    if (!showDay) return const SizedBox.expand();
    final day = days[column];
    final content = Builder(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Below the number, a shared cell opens its event ("+N" its day).
        onTapUp: (details) {
          final at = details.localPosition;
          final x = at.dx + column * columnWidth;
          for (final cell in shared) {
            if (at.dy < monthEventHeader ||
                !cell.rect.contains(Offset(x, at.dy))) {
              continue;
            }
            final event = cell.event;
            final box = context.findRenderObject() as RenderBox?;
            if (event == null || box == null || onEventTap == null) break;
            final origin = box.localToGlobal(
              Offset(cell.rect.left - column * columnWidth, cell.rect.top),
            );
            onEventTap!(event, origin & cell.rect.size);
            return;
          }
          onDayTap(day);
        },
        onLongPressStart: (details) =>
            onHoldStart?.call(null, details.globalPosition),
        child: _dayNumber(day),
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

  Widget _dayNumber(DateTime day) => Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: const EdgeInsets.only(top: dayNumberTop),
      child: _DayNumber(day: day, today: sameDay(day, today)),
    ),
  );
}

/// A shared event's cell (or "+N") of the week, where it is drawn.
class _SharedCell {
  const _SharedCell({
    required this.piece,
    required this.event,
    required this.rect,
  });

  final SharedPiece piece;
  final CalendarEvent? event;
  final Rect rect;

  String get key => '${piece.eventId ?? 'more'}-${piece.startColumn}';
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

  /// 2 pt inset each side, none where the bar runs on past the week edge.
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
    required this.eventIds,
  });

  factory _WeekLayer.build({
    required CalendarEventIndex index,
    required MonthStrip strip,
    required List<DateTime> days,
    required (int, int) visible,
    required int capacity,
    required String? hiddenEventId,
    required double columnWidth,
    List<int>? columnCapacity,
  }) {
    final shown = [
      for (final event in index.forWeek(strip.weekIndex))
        if (event.id != hiddenEventId) event,
    ];
    final layout =
        index.memo.putIfAbsent(
              (
                'week',
                strip.weekIndex,
                strip.kind,
                capacity,
                columnCapacity?.join(','),
                hiddenEventId,
              ),
              () => layoutWeek(
                events: shown,
                days: days,
                visibleStart: visible.$1,
                visibleEnd: visible.$2,
                capacity: capacity,
                columnCapacity: columnCapacity,
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
          color: event.invite != null
              ? mixedColor(event.invite!.colors)
              : event.color ?? calendarEventColor,
        ),
      );
    }
    return _WeekLayer(
      placed: placed,
      overflow: overflow,
      bandChips: bandChips,
      eventIds: {for (final event in shown) event.id},
    );
  }

  final List<_Placed> placed;

  /// (column, lane, hidden count) for every "+N".
  final List<(int, int, int)> overflow;

  /// Where each event of the week sits along it, for the band.
  final List<BandChip> bandChips;

  /// Every event of the week, also those behind "+N".
  final Set<String> eventIds;

  /// The bottom of the lowest chip or "+N" on the days of [piece], laid
  /// out at [density]; null when there is none.
  double? bottomIn(SharedPiece piece, EventDensity density) {
    var lanes = 0;
    for (final item in placed) {
      if (item.endColumn < piece.startColumn ||
          item.startColumn > piece.endColumn) {
        continue;
      }
      lanes = math.max(lanes, item.lane + 1);
    }
    for (final (column, lane, _) in overflow) {
      if (piece.covers(column)) lanes = math.max(lanes, lane + 1);
    }
    if (lanes == 0) return null;
    return monthEventHeader + lanes * density.slot - density.gap;
  }
}

/// The user's chips: tappable, draggable, with "+N" opening the day. They
/// fold up under the top line of the week while friends are shown.
class _MineChips extends StatelessWidget {
  const _MineChips({
    required this.layer,
    required this.days,
    required this.density,
    required this.mode,
    required this.rowHeight,
    required this.columnWidth,
    required this.onDayTap,
    this.dimmedEventId,
    this.onEventTap,
    this.onHoldStart,
  });

  final _WeekLayer layer;
  final List<DateTime> days;

  final EventDensity density;
  final ValueListenable<double> mode;
  final double rowHeight;
  final double columnWidth;
  final ValueChanged<DateTime> onDayTap;
  final String? dimmedEventId;
  final void Function(CalendarEvent event, Rect rect)? onEventTap;
  final void Function(CalendarEvent? event, Offset global)? onHoldStart;

  @override
  Widget build(BuildContext context) {
    return _AnimatedDensity(
      density: density,
      builder: (context, d) {
        Widget moving(int lane, Widget child) => ChipMotion(
          mode: mode,
          awayAt: myFoldAt,
          homeTop: monthEventHeader + lane * d.slot,
          line: 0,
          child: child,
        );
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final item in layer.placed)
              Positioned(
                key: ValueKey('${item.event.id}-${item.startColumn}'),
                left: item.left(columnWidth),
                width: item.right(columnWidth) - item.left(columnWidth),
                top: monthEventHeader + item.lane * d.slot,
                height: d.itemHeight,
                child: moving(
                  item.lane,
                  _MonthEventBlock(
                    event: item.event,
                    dimmed: item.event.id == dimmedEventId,
                    density: d,
                    continuesBefore: item.continuesBefore,
                    continuesAfter: item.continuesAfter,
                    onTap: onEventTap,
                    onHoldStart: onHoldStart,
                  ),
                ),
              ),
            for (final (column, lane, count) in layer.overflow)
              Positioned(
                key: ValueKey('more-$column'),
                left: column * columnWidth + 4,
                width: columnWidth - 6,
                top: monthEventHeader + lane * d.slot,
                height: d.itemHeight,
                child: moving(
                  lane,
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onDayTap(days[column]),
                    child: _OverflowLabel(count),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Chip sizes glide when the month crosses into another density, instead of
/// jumping. Pinching moves the rows, not the density, so it never lags.
class _AnimatedDensity extends StatelessWidget {
  const _AnimatedDensity({required this.density, required this.builder});

  final EventDensity density;
  final Widget Function(BuildContext context, EventDensity density) builder;

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return TweenAnimationBuilder<EventDensity>(
      tween: _DensityTween(end: density),
      duration: reduce ? Duration.zero : chipResizeDuration,
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

const chipResizeDuration = Duration(milliseconds: 160);

class _DensityTween extends Tween<EventDensity> {
  _DensityTween({super.end});

  @override
  EventDensity lerp(double t) => EventDensity.lerp(begin ?? end!, end!, t);
}

class _OverflowLabel extends StatelessWidget {
  const _OverflowLabel(this.count);

  final int count;

  @override
  Widget build(BuildContext context) => OverflowBox(
    // Taller than the thinnest lane: laid out at its own height, centred
    // on the lane, never cut.
    alignment: Alignment.centerLeft,
    minHeight: 0,
    maxHeight: double.infinity,
    child: Text(
      '+$count',
      style: const TextStyle(
        color: Color(0xFFAEAEB2),
        fontSize: 10,
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
    required this.mode,
    required this.rowHeight,
    required this.columnWidth,
    this.onEventTap,
  });

  final _WeekLayer layer;
  final EventDensity density;
  final ValueListenable<double> mode;
  final double rowHeight;
  final double columnWidth;

  /// For the invites among friends' busy time.
  final void Function(CalendarEvent event, Rect rect)? onEventTap;

  @override
  State<_FriendChips> createState() => _FriendChipsState();
}

class _FriendChipsState extends State<_FriendChips> {
  /// Chips whose friend was let go, playing their exit.
  final _leaving = <String, _Placed>{};

  /// Events of a friend just picked: only they play the entrance. A chip
  /// coming out from behind "+N" as the month is zoomed just shows.
  late Set<String> _fresh = widget.layer.eventIds;

  @override
  void didUpdateWidget(covariant _FriendChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.layer, widget.layer)) return;
    final before = oldWidget.layer.eventIds;
    final now = widget.layer.eventIds;
    _fresh = now.difference(before);
    // Gone from the week, not just hidden behind "+N": that chip would
    // fade out over the count.
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
    return _AnimatedDensity(
      density: widget.density,
      builder: (context, d) => Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in _leaving.values)
            if (!current.contains(item.event.id))
              _chip(item, d, leaving: true, reduce: reduce),
          for (final item in widget.layer.placed)
            _chip(item, d, leaving: false, reduce: reduce),
          for (final (column, lane, count) in widget.layer.overflow)
            Positioned(
              key: ValueKey('more-$column'),
              left: column * widget.columnWidth + 4,
              width: widget.columnWidth - 6,
              top: monthEventHeader + lane * d.slot,
              height: d.itemHeight,
              child: _motion(lane, d, _OverflowLabel(count)),
            ),
        ],
      ),
    );
  }

  /// Friends' chips fold down onto the bottom line of the week.
  Widget _motion(int lane, EventDensity d, Widget child) => ChipMotion(
    mode: widget.mode,
    awayAt: friendsFoldAt,
    homeTop: monthEventHeader + lane * d.slot,
    line: widget.rowHeight,
    child: child,
  );

  Widget _chip(
    _Placed item,
    EventDensity density, {
    required bool leaving,
    required bool reduce,
  }) {
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
        child: _motion(item.lane, density, child!),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(
          begin: leaving || !_fresh.contains(item.event.id) ? 1 : 0,
          end: leaving ? 0 : 1,
        ),
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
        // Busy time is only a colour; an invite has a title and opens.
        child: IgnorePointer(
          ignoring: item.event.invite == null || leaving,
          child: _MonthEventBlock(
            event: item.event,
            density: density,
            continuesBefore: item.continuesBefore,
            continuesAfter: item.continuesAfter,
            showTitle: item.event.invite != null,
            onTap: item.event.invite == null ? null : widget.onEventTap,
          ),
        ),
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
  }) : super(repaint: mode);

  final List<WeekBand> mine;
  final List<WeekBand> friends;
  final ValueListenable<double> mode;
  final double height;

  @override
  void paint(Canvas canvas, Size size) {
    final t = mode.value;
    _paint(canvas, size, mine, away: myFoldAt(t), fromTop: true);
    _paint(canvas, size, friends, away: friendsFoldAt(t), fromTop: false);
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
    for (final band in bands) {
      paintFadingBand(
        canvas,
        Rect.fromLTRB(
          band.left,
          fromTop ? 0 : size.height - h,
          band.right,
          fromTop ? h : size.height,
        ),
        colors: band.colors,
        stops: band.stops,
        fromTop: fromTop,
        fade: h,
        opacity: opacity,
      );
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
      width: dayNumberSize,
      height: dayNumberSize,
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
    final own = OwnEventColor.of(context);
    // Apple Calendar's dark look ([gridTone]): a deep fill with light text
    // of the same hue; a chip with no title is the light tone itself.
    final tone = gridTone(eventColor(event, own));
    final titled = density.showTitle && showTitle;
    final fill = titled ? tone.fill : tone.ink;
    final ink = tone.ink;
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
        child: _InviteRim(
          event: event,
          own: own,
          radius: monthChipRadius(density),
          child: _ChipFill(
            decoration: event.invite == null
                ? BoxDecoration(color: fill, borderRadius: radius)
                : eventFill(event, own, radius: radius),
            fadeBefore: continuesBefore,
            fadeAfter: continuesAfter,
            child: titled
                // The title fades out while the layer folds, so squeezed
                // letters never show.
                ? ChipFoldInk(
                    builder: (context, alpha) => _title(
                      ink.withValues(alpha: ink.a * alpha),
                      // Where the chip itself fades out, the title is
                      // just cut: a fade in the fill's colour would
                      // show there.
                      continuesAfter ? null : fill,
                    ),
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  /// Narrow chips cut the title off rather than spend a third of the room
  /// on an ellipsis: "Бейсб" says more than "Бейс…".
  Widget _title(Color ink, Color? fill) {
    if (density.titleLines > 1) {
      return _TallChipText(event: event, ink: ink, density: density);
    }
    final padding = monthChipPadding(density);
    final title = monthChipTitleStyle.copyWith(color: ink);
    // Laid out at its own height and clipped, like Apple Calendar: while
    // the chip grows or shrinks between densities nothing reflows or jumps.
    if (density.showTime && !event.allDay) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventDisplayTitle(event),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: title,
                ),
                Text(
                  clockLabel(event.start),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: title.copyWith(
                    color: ink.withValues(alpha: ink.a * 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    // One line: cut off and faded into the chip before its round end, as
    // Apple does, rather than an ellipsis eating a third of a narrow chip.
    // The fade stays inside the padding, so it never pokes past the round
    // end.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minHeight: 0,
          maxHeight: double.infinity,
          child: Stack(
            children: [
              Text(
                eventDisplayTitle(event),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: title.copyWith(height: 1),
              ),
              if (fill != null)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: chipTitleFadeWidth,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [fill.withValues(alpha: 0), fill],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A chip's fill. A chip that runs on into the next week or month fades
/// out over [chipContinueFade] at that end instead of being cut square.
class _ChipFill extends StatelessWidget {
  const _ChipFill({
    required this.decoration,
    required this.fadeBefore,
    required this.fadeAfter,
    required this.child,
  });

  final BoxDecoration decoration;
  final bool fadeBefore;
  final bool fadeAfter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = decoration.color;
    if ((!fadeBefore && !fadeAfter) || color == null) {
      return DecoratedBox(decoration: decoration, child: child);
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final edge = width <= 0
            ? 0.5
            : (chipContinueFade / width).clamp(0.0, 0.5).toDouble();
        final clear = color.withValues(alpha: 0);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: decoration.borderRadius,
            gradient: LinearGradient(
              colors: [
                fadeBefore ? clear : color,
                color,
                color,
                fadeAfter ? clear : color,
              ],
              stops: [0, edge, 1 - edge, 1],
            ),
          ),
          child: child,
        );
      },
    );
  }
}

/// The tallest chip: the title on up to two lines, the start time under
/// it. Clipped and laid out at its own height, so it reads cleanly while the
/// chip grows into it.
class _TallChipText extends StatelessWidget {
  const _TallChipText({
    required this.event,
    required this.ink,
    required this.density,
  });

  final CalendarEvent event;
  final Color ink;
  final EventDensity density;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minHeight: 0,
        maxHeight: double.infinity,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            monthChipPadding(density),
            5,
            monthChipPadding(density) - 2,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eventDisplayTitle(event),
                maxLines: density.titleLines,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: ink,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
              ),
              if (!event.allDay)
                Text(
                  clockLabel(event.start),
                  maxLines: 1,
                  style: TextStyle(
                    color: ink.withValues(alpha: 0.8),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.15,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed edge of an invite the user has not answered; other events
/// pass through.
class _InviteRim extends StatelessWidget {
  const _InviteRim({
    required this.event,
    required this.own,
    required this.radius,
    required this.child,
  });

  final CalendarEvent event;
  final Color own;
  final double radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final invite = event.invite;
    if (invite == null || !invite.pending) return child;
    return PendingInviteRim(
      color: eventColor(event, own),
      radius: radius,
      child: child,
    );
  }
}
