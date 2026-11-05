import 'dart:math' as math;

import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/week_bands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';

class DayFriendsGeometry {
  const DayFriendsGeometry({
    required this.height,
    required this.bottomInset,
    required this.rows,
    required this.stackSlots,
  });

  final double height;

  final double bottomInset;

  final int rows;

  final int stackSlots;

  static const avatar = 48.0;
  static const gutter = 14.0;
  static const columnWidth = gutter * 2 + avatar;

  static const rowHeight = avatar;
  static const rowStep = rowHeight + timelineEventGap;
  static const myRowTop = timelineEventTop;
  static const dividerY = myRowTop + rowHeight + 8;
  static const friendsTop = dividerY + 9;

  static const stackStep = 29.0;
  static const stackMax = 3;

  static const avatarInset = (rowHeight - avatar) / 2;

  double rowTop(int row) => friendsTop + row * rowStep;

  double get bandBottom => height - bottomInset;

  double get bandHeight =>
      stackSlots == 0 ? 0 : avatar + (stackSlots - 1) * stackStep;

  double get bandTop => bandBottom - bandHeight;

  double stackTop(int slot) => bandTop + slot * stackStep;

  double stackTarget(int stack) =>
      stackTop(stack < stackMax ? stack : stackMax);

  static const _settle = 10.0;

  double _openTop(double row, double offset) =>
      rowTop(0) + row * rowStep + avatarInset - offset;

  double _groupShift(double offset) =>
      stackTop(0) - _openTop(0, offset) + 6 * _settle;

  double avatarTop({
    required double row,
    required int stack,
    required double offset,
    required double fold,
  }) {
    final open = _openTop(row, offset);
    final target = stackTarget(stack);
    if (fold <= 0) return open;
    if (fold >= 1) return target;
    if (open >= target) return open + (target - open) * fold;
    final free = open + fold * _groupShift(offset);
    final x = (target - free) / _settle;
    if (x > 30) return free;
    return target - _settle * math.log(1 + math.exp(x));
  }

  double hiddenTop({
    required double row,
    required double offset,
    required double fold,
  }) {
    final open = _openTop(row, offset);
    final away = height + avatar + row * 12 - open;
    return open + fold * math.max(_groupShift(offset), away);
  }

  double get maxOffset => math.max(0, rowTop(rows) - bandBottom);

  @override
  bool operator ==(Object other) =>
      other is DayFriendsGeometry &&
      other.height == height &&
      other.bottomInset == bottomInset &&
      other.rows == rows &&
      other.stackSlots == stackSlots;

  @override
  int get hashCode => Object.hash(height, bottomInset, rows, stackSlots);
}

class DayFriendsView {
  const DayFriendsView({
    required this.events,
    required this.rows,
    required this.geometry,
    required this.offset,
  });

  final CalendarEventIndex events;

  final Map<int, int> rows;
  final DayFriendsGeometry geometry;

  final ValueListenable<double> offset;
}

@immutable
class BusySpan {
  const BusySpan(
    this.start,
    this.end, {
    this.continuesBefore = false,
    this.continuesAfter = false,
  });

  final double start;
  final double end;
  final bool continuesBefore;
  final bool continuesAfter;

  @override
  bool operator ==(Object other) =>
      other is BusySpan &&
      other.start == start &&
      other.end == end &&
      other.continuesBefore == continuesBefore &&
      other.continuesAfter == continuesAfter;

  @override
  int get hashCode => Object.hash(start, end, continuesBefore, continuesAfter);

  @override
  String toString() => 'BusySpan($start–$end)';
}

List<BusySpan> busySpansOnDay(Iterable<CalendarEvent> events, DateTime day) {
  final slices = [for (final event in events) ?sliceOnDay(event, day)]
    ..sort((a, b) => a.startHour.compareTo(b.startHour));
  final spans = <BusySpan>[];
  for (final slice in slices) {
    final last = spans.isEmpty ? null : spans.last;
    if (last != null && slice.startHour <= last.end) {
      if (slice.endHour > last.end || slice.continuesAfter) {
        spans[spans.length - 1] = BusySpan(
          last.start,
          math.max(last.end, slice.endHour),
          continuesBefore: last.continuesBefore,
          continuesAfter: last.continuesAfter || slice.continuesAfter,
        );
      }
      continue;
    }
    spans.add(
      BusySpan(
        slice.startHour,
        slice.endHour,
        continuesBefore: slice.continuesBefore,
        continuesAfter: slice.continuesAfter,
      ),
    );
  }
  return spans;
}

class DayFriendLayer extends StatelessWidget {
  const DayFriendLayer({
    required this.day,
    required this.pixelsPerHour,
    required this.view,
    required this.mode,
    super.key,
  });

  final DateTime day;
  final double pixelsPerHour;
  final DayFriendsView view;
  final ValueListenable<double> mode;

  @override
  Widget build(BuildContext context) {
    final geometry = view.geometry;
    final byOwner = <int, List<CalendarEvent>>{};
    for (final event in view.events.onDay(day)) {
      final owner = event.ownerId;
      if (owner == null || !view.rows.containsKey(owner)) continue;
      byOwner.putIfAbsent(owner, () => []).add(event);
    }
    final motion = Listenable.merge([mode, view.offset]);
    final children = <Widget>[];
    for (final MapEntry(key: owner, value: events) in byOwner.entries) {
      final row = view.rows[owner]!;
      final color = events.first.color ?? defaultOwnColor;
      final homeTop = geometry.rowTop(row);
      for (final span in busySpansOnDay(events, day)) {
        children.add(
          Positioned(
            key: ValueKey('friend-$owner-${span.start}'),
            left: span.start * pixelsPerHour,
            width: (span.end - span.start) * pixelsPerHour,
            top: homeTop,
            height: DayFriendsGeometry.rowHeight,
            child: AnimatedBuilder(
              animation: motion,
              builder: (context, _) {
                final fold = dayFriendsFold(mode.value);
                final top =
                    geometry.avatarTop(
                      row: row.toDouble(),
                      stack: row,
                      offset: view.offset.value,
                      fold: fold,
                    ) -
                    DayFriendsGeometry.avatarInset;
                final alpha = 1 - _smoothStep(0.8, 1, fold);
                if (alpha <= 0) return const SizedBox.shrink();
                return Transform.translate(
                  offset: Offset(0, top - homeTop),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: gridTone(color).ink.withValues(alpha: alpha),
                      borderRadius: BorderRadius.horizontal(
                        left: span.continuesBefore
                            ? Radius.zero
                            : timelineEventRadius,
                        right: span.continuesAfter
                            ? Radius.zero
                            : timelineEventRadius,
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    return ClipRect(
      clipper: const _BelowClipper(DayFriendsGeometry.friendsTop),
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

double dayFriendsFold(double mode) => (1 - mode).clamp(0.0, 1.0);

class _BelowClipper extends CustomClipper<Rect> {
  const _BelowClipper(this.top);

  final double top;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top, size.width, size.height);

  @override
  bool shouldReclip(covariant _BelowClipper oldClipper) =>
      oldClipper.top != top;
}

class DayBandsPainter extends CustomPainter {
  DayBandsPainter({
    required this.mine,
    required this.friends,
    required this.ownColor,
    required this.geometry,
    required this.dayWidth,
    required this.mode,
  }) : super(repaint: mode);

  final List<WeekBand> mine;
  final List<WeekBand> friends;
  final Color ownColor;
  final DayFriendsGeometry geometry;

  final double dayWidth;
  final ValueListenable<double> mode;

  static double _smooth(double edge0, double edge1, double x) =>
      _smoothStep(edge0, edge1, x);

  @override
  void paint(Canvas canvas, Size size) {
    final t = mode.value;
    _paintMine(canvas, myFoldAt(t));
    _paintFriends(canvas, dayFriendsFold(t));
  }

  void _paintMine(Canvas canvas, double away) {
    if (away <= 0 || mine.isEmpty) return;
    final h =
        DayFriendsGeometry.rowHeight *
        Curves.easeOutCubic.transform(_smooth(0.3, 1, away));
    final opacity = _smooth(0.2, 0.7, away);
    if (h < 0.5 || opacity <= 0) return;
    const top = DayFriendsGeometry.myRowTop;
    for (final band in mine) {
      paintFadingBand(
        canvas,
        Rect.fromLTRB(band.left, top, band.right, top + h),
        colors: [ownColor, ownColor],
        stops: const [0, 1],
        fromTop: true,
        fade: DayFriendsGeometry.rowHeight,
        opacity: opacity,
      );
    }
  }

  void _paintFriends(Canvas canvas, double away) {
    if (away <= 0 || friends.isEmpty || geometry.bandHeight <= 0) return;
    final grow = Curves.easeOutCubic.transform(_smooth(0.6, 1, away));
    final opacity = _smooth(0.6, 0.9, away);
    final h = geometry.bandHeight * grow;
    if (h < 0.5 || opacity <= 0) return;
    final bottom = geometry.bandBottom;
    for (final band in friends) {
      final left = band.left <= 0 ? Radius.zero : timelineEventRadius;
      final right = band.right >= dayWidth ? Radius.zero : timelineEventRadius;
      final rect = Rect.fromLTRB(band.left, bottom - h, band.right, bottom);
      canvas
        ..save()
        ..clipRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: left,
            bottomLeft: left,
            topRight: right,
            bottomRight: right,
          ),
        );
      paintFadingBand(
        canvas,
        rect,
        colors: band.colors,
        stops: band.stops,
        fromTop: false,
        fade: h,
        opacity: opacity,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant DayBandsPainter old) =>
      old.mode != mode ||
      old.ownColor != ownColor ||
      old.geometry != geometry ||
      old.dayWidth != dayWidth ||
      !identical(old.mine, mine) ||
      !identical(old.friends, friends);
}

class DayBands extends StatelessWidget {
  const DayBands({
    required this.day,
    required this.pixelsPerHour,
    required this.mine,
    required this.view,
    required this.mode,
    super.key,
  });

  final DateTime day;
  final double pixelsPerHour;
  final List<CalendarEvent> mine;
  final DayFriendsView view;
  final ValueListenable<double> mode;

  @override
  Widget build(BuildContext context) {
    final own = OwnEventColor.of(context);
    final dayWidth = 24 * pixelsPerHour;
    BandChip chipOf(BusySpan span, Color color) => BandChip(
      left: span.start * pixelsPerHour,
      right: span.end * pixelsPerHour,
      color: color,
    );
    final mineBands = buildSolidBands([
      for (final span in busySpansOnDay(mine, day)) chipOf(span, own),
    ], own);
    final friendChips = <BandChip>[];
    for (final event in view.events.onDay(day)) {
      if (!view.rows.containsKey(event.ownerId)) continue;
      final slice = sliceOnDay(event, day);
      if (slice == null) continue;
      friendChips.add(
        chipOf(
          BusySpan(slice.startHour, slice.endHour),
          event.color ?? defaultOwnColor,
        ),
      );
    }
    final friendBands = buildWeekBands(friendChips, columnWidth: dayWidth);
    return CustomPaint(
      painter: DayBandsPainter(
        mine: mineBands,
        friends: friendBands,
        ownColor: own,
        geometry: view.geometry,
        dayWidth: dayWidth,
        mode: mode,
      ),
    );
  }
}

class MyBandTitles extends StatelessWidget {
  const MyBandTitles({
    required this.events,
    required this.scrollOffset,
    required this.pixelsPerHour,
    required this.viewportWidth,
    required this.leftInset,
    required this.mode,
    super.key,
  });

  final List<CalendarEvent> events;
  final double scrollOffset;
  final double pixelsPerHour;
  final double viewportWidth;

  final double leftInset;
  final ValueListenable<double> mode;

  @override
  Widget build(BuildContext context) {
    final own = OwnEventColor.of(context);
    final ink = gridTone(own).ink;
    final runs = myBandRuns(events);
    final children = <Widget>[];
    for (final run in runs) {
      final left = timelineX(run.start, pixelsPerHour) - scrollOffset;
      final right = timelineX(run.end, pixelsPerHour) - scrollOffset;
      if (right <= leftInset || left >= viewportWidth) continue;
      final x = math.max(left, leftInset) + timelineTitlePadding;
      final width = right - timelineTitlePadding - x;
      if (width <= 24) continue;
      children.add(
        Positioned(
          left: x,
          width: width,
          top: DayFriendsGeometry.myRowTop,
          height: DayFriendsGeometry.rowHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                text: eventDisplayTitle(run.first),
                children: [
                  if (run.more > 0)
                    TextSpan(
                      text: ' +${run.more}',
                      style: TextStyle(
                        fontFamily: 'Onest',
                        color: ink.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: timelineTitleStyle.copyWith(
                color: ink,
                fontWeight: FontWeight.w500,
                fontVariations: const [FontVariation('wght', 500)],
              ),
            ),
          ),
        ),
      );
    }
    return IgnorePointer(
      child: ValueListenableBuilder<double>(
        valueListenable: mode,
        child: Stack(children: children),
        builder: (context, t, child) {
          final shown = _smoothStep(0.6, 1, myFoldAt(t));
          if (shown <= 0) return const SizedBox.shrink();
          return Opacity(opacity: shown, child: child);
        },
      ),
    );
  }
}

typedef MyBandRun = ({
  DateTime start,
  DateTime end,
  CalendarEvent first,
  int more,
});

List<MyBandRun> myBandRuns(List<CalendarEvent> events) {
  final sorted = [...events]
    ..sort((a, b) => timelineSpan(a).start.compareTo(timelineSpan(b).start));
  final runs = <MyBandRun>[];
  for (final event in sorted) {
    final span = timelineSpan(event);
    final last = runs.isEmpty ? null : runs.last;
    if (last != null && !span.start.isAfter(last.end)) {
      runs[runs.length - 1] = (
        start: last.start,
        end: span.end.isAfter(last.end) ? span.end : last.end,
        first: last.first,
        more: last.more + 1,
      );
      continue;
    }
    runs.add((start: span.start, end: span.end, first: event, more: 0));
  }
  return runs;
}

double _smoothStep(double edge0, double edge1, double x) {
  final t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
