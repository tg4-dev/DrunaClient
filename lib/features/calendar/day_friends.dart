import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/chip_motion.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/features/calendar/week_bands.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Where things sit in the open day once friends are in it.
///
/// Friends' calendar (`t = 1`): the top row is the user's — their avatar
/// and a band of their busy time — then a divider, then one row per friend,
/// level with the friend's avatar in the column on the left. Rows scroll
/// together with the column.
///
/// The user's calendar (`t = 0`): the user's events take their lanes from
/// the top, and the selected friends fold into a stack at the bottom left
/// next to a band of their busy time.
class DayFriendsGeometry {
  const DayFriendsGeometry({
    required this.height,
    required this.bottomInset,
    required this.rows,
    required this.stackSlots,
  });

  /// Height of the timeline.
  final double height;

  /// Room left free at the bottom: the home indicator and a margin.
  final double bottomInset;

  /// Friends in the column; the timeline has rows for the selected ones.
  final int rows;

  /// Avatars in the folded stack, "+N" included.
  final int stackSlots;

  static const avatar = 48.0;
  static const gutter = 14.0;
  static const columnWidth = gutter * 2 + avatar;

  /// A row's bar is as tall as the avatar beside it, the user's row too.
  static const rowHeight = avatar;
  static const rowStep = rowHeight + timelineEventGap;
  static const myRowTop = timelineEventTop;
  static const dividerY = myRowTop + rowHeight + 8;
  static const friendsTop = dividerY + 9;

  /// The folded stack: full-size avatars overlapping by this step.
  static const stackStep = 29.0;
  static const stackMax = 3;

  /// From the top of a row's bar to its avatar.
  static const avatarInset = (rowHeight - avatar) / 2;

  double rowTop(int row) => friendsTop + row * rowStep;

  double get bandBottom => height - bottomInset;

  double get bandHeight =>
      stackSlots == 0 ? 0 : avatar + (stackSlots - 1) * stackStep;

  double get bandTop => bandBottom - bandHeight;

  double stackTop(int slot) => bandTop + slot * stackStep;

  /// Where the avatar of the friend picked [stack]-th lands in the folded
  /// stack; those past [stackMax] go under "+N".
  double stackTarget(int stack) =>
      stackTop(stack < stackMax ? stack : stackMax);

  /// Top of the avatar on row [row] scrolled by [offset], folded by [fold]
  /// (0 on its row, 1 in the stack at [stack]). The column and friends'
  /// bars both move by it, so a bar never leaves its avatar's level.
  double avatarTop({
    required double row,
    required int stack,
    required double offset,
    required double fold,
  }) {
    final open = rowTop(0) + row * rowStep + avatarInset - offset;
    return open + (stackTarget(stack) - open) * fold;
  }

  /// How far the rows scroll: until the last one is above [bandBottom].
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

/// Friends' busy time as the open day needs it.
class DayFriendsView {
  const DayFriendsView({
    required this.events,
    required this.rows,
    required this.geometry,
    required this.offset,
  });

  /// Busy time of the selected friends, each event with its owner.
  final CalendarEventIndex events;

  /// Row of each selected friend, by id.
  final Map<int, int> rows;
  final DayFriendsGeometry geometry;

  /// How far the rows are scrolled up.
  final ValueListenable<double> offset;
}

/// One stretch of busy time within a day, in hours from its midnight.
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

/// The busy time of [events] on [day]: overlapping or touching events make
/// one span. A friend is either busy or not; how many things they do at
/// once is not shown.
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

/// Friends' bars of one day, each on its friend's row. Picking the user's
/// calendar folds them down into the band at the bottom; only a transform
/// changes per frame, as in the month.
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
      final color = events.first.color ?? calendarEventColor;
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
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.horizontal(
                    left: span.continuesBefore
                        ? Radius.zero
                        : timelineEventRadius,
                    right: span.continuesAfter
                        ? Radius.zero
                        : timelineEventRadius,
                  ),
                ),
              ),
              builder: (context, child) {
                final fold = dayColumnFold(mode.value);
                final top =
                    geometry.avatarTop(
                      row: row.toDouble(),
                      stack: row,
                      offset: view.offset.value,
                      fold: fold,
                    ) -
                    DayFriendsGeometry.avatarInset;
                return Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.translationValues(0, top - homeTop, 0)
                    ..scaleByDouble(1, _barScale(fold), 1, 1),
                  child: child,
                );
              },
            ),
          ),
        );
      }
    }
    // Rows scroll under the user's row: nothing shows above the divider.
    return ClipRect(
      clipper: const _BelowClipper(DayFriendsGeometry.friendsTop),
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

/// How far the open day's column and friends' bars are folded into the
/// stack: 0 on their rows, 1 in the stack. It moves over the same half of
/// the swipe as the month's friend chips ([friendsFoldAt]).
double dayColumnFold(double mode) =>
    Curves.easeInOutCubic.transform(friendsFoldAt(mode));

/// Near the stack a friend's bar sinks into the band of busy time, which
/// grows there at the same time ([DayBandsPainter]).
double _barScale(double fold) =>
    1 - Curves.easeIn.transform(_smoothStep(0.7, 1, fold));

class _BelowClipper extends CustomClipper<Rect> {
  const _BelowClipper(this.top);

  final double top;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(0, top, size.width, size.height);

  @override
  bool shouldReclip(covariant _BelowClipper oldClipper) =>
      oldClipper.top != top;
}

/// The two bands of one day for the layer that is folded away: the user's
/// busy time along the top row while friends are shown, friends' busy time
/// at the bottom while the user's events are. Each grows out of its line
/// as its chips fold into it (see the month's band, design-system §9.4).
class DayBandsPainter extends CustomPainter {
  DayBandsPainter({
    required this.mine,
    required this.friends,
    required this.ownColor,
    required this.geometry,
    required this.dayWidth,
    required this.mode,
  }) : super(repaint: mode);

  /// The user's busy time, in pixels from the day's midnight.
  final List<WeekBand> mine;
  final List<WeekBand> friends;
  final Color ownColor;
  final DayFriendsGeometry geometry;

  /// A band reaching an end of the day goes on into the next one: that end
  /// stays square.
  final double dayWidth;
  final ValueListenable<double> mode;

  static const _slice = 2.0;

  /// 100% at the line, fading to nothing at the bottom of the row.
  static double _fade(double x) {
    final k = 1 - x.clamp(0.0, 1.0);
    return k * k * (0.45 + 0.55 * k);
  }

  static double _smooth(double edge0, double edge1, double x) =>
      _smoothStep(edge0, edge1, x);

  @override
  void paint(Canvas canvas, Size size) {
    final t = mode.value;
    _paintMine(canvas, myFoldAt(t));
    _paintFriends(canvas, friendsFoldAt(t));
  }

  /// From the top line of the user's row down, fading towards its bottom.
  void _paintMine(Canvas canvas, double away) {
    if (away <= 0 || mine.isEmpty) return;
    final h =
        DayFriendsGeometry.rowHeight *
        Curves.easeOutCubic.transform(_smooth(0.3, 1, away));
    final opacity = _smooth(0.2, 0.7, away);
    if (h < 0.5 || opacity <= 0) return;
    final paint = Paint();
    final slices = (h / _slice).ceil();
    const top = DayFriendsGeometry.myRowTop;
    for (var i = 0; i < slices; i++) {
      final from = i * h / slices;
      final to = (i + 1) * h / slices;
      final alpha =
          _fade((from + to) / 2 / DayFriendsGeometry.rowHeight) * opacity;
      if (alpha <= 0.004) continue;
      paint.color = ownColor.withValues(alpha: alpha);
      for (final band in mine) {
        canvas.drawRect(
          Rect.fromLTRB(band.left, top + from, band.right, top + to),
          paint,
        );
      }
    }
  }

  /// The colours of the friends along it, growing up from the bottom line
  /// next to the stack: cut clean at the line and fading upwards, like the
  /// month's band. The rounded ends are a clip, not a layer.
  void _paintFriends(Canvas canvas, double away) {
    if (away <= 0 || friends.isEmpty || geometry.bandHeight <= 0) return;
    final grow = Curves.easeOutCubic.transform(_smooth(0.3, 1, away));
    final opacity = _smooth(0.2, 0.7, away);
    final h = geometry.bandHeight * grow;
    if (h < 0.5 || opacity <= 0) return;
    final bottom = geometry.bandBottom;
    final slices = (h / _slice).ceil();
    for (final band in friends) {
      final paint = Paint()
        ..shader = ui.Gradient.linear(
          Offset(band.left, 0),
          Offset(band.right, 0),
          band.colors,
          band.stops,
        );
      final left = band.left <= 0 ? Radius.zero : timelineEventRadius;
      final right = band.right >= dayWidth ? Radius.zero : timelineEventRadius;
      canvas
        ..save()
        ..clipRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTRB(band.left, bottom - h, band.right, bottom),
            topLeft: left,
            bottomLeft: left,
            topRight: right,
            bottomRight: right,
          ),
        );
      for (var i = 0; i < slices; i++) {
        final from = i * h / slices;
        final to = (i + 1) * h / slices;
        final alpha = _fade((from + to) / 2 / h) * opacity;
        if (alpha <= 0.004) continue;
        // Modulate scales the shader's colour, alpha included, per draw.
        paint.colorFilter = ColorFilter.mode(
          Color.fromRGBO(255, 255, 255, alpha),
          BlendMode.modulate,
        );
        canvas.drawRect(
          Rect.fromLTRB(band.left, bottom - to, band.right, bottom - from),
          paint,
        );
      }
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

/// The bands of one day, built from its events and painted under them.
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
          event.color ?? calendarEventColor,
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

/// Titles on the user's band while friends are shown: the first event of
/// each stretch and how many more it holds ("druna +1"), sticking to the
/// left edge like the titles of the bars. In the list's viewport.
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

  /// The friends column covers this much of the left edge.
  final double leftInset;
  final ValueListenable<double> mode;

  @override
  Widget build(BuildContext context) {
    final own = OwnEventColor.of(context);
    final ink = eventInk(own);
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
                      style: TextStyle(color: ink.withValues(alpha: 0.7)),
                    ),
                ],
              ),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: timelineTitleStyle.copyWith(
                color: ink,
                fontWeight: FontWeight.w500,
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

/// A stretch of the user's busy time: events that overlap or touch.
typedef MyBandRun = ({
  DateTime start,
  DateTime end,
  CalendarEvent first,
  int more,
});

/// The user's [events] joined into stretches of busy time, the way the band
/// draws them.
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
