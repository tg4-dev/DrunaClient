import 'dart:math' as math;

import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/day_events.dart';
import 'package:druna_app/features/calendar/event_layout.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/person_avatar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared events in the month (design-system §9.8) are cells of their days:
/// an answered one fills the day with a gradient of the people in it, left
/// to right; one waiting for the user's answer is only a dashed outline
/// with "+", no colours. Both
/// show the people's faces at the bottom. They belong to both calendars, so
/// they stay put while the swipe folds the user's chips and friends' around
/// them.

/// From an unanswered cell to an answered one, after the user said yes on
/// the event page and closed it.
const sharedMorphDuration = Duration(milliseconds: 620);

/// Gap between stacked cells of a day and on their sides: the same 2 pt
/// the chips keep from the edge of their day.
const sharedCellGap = 2.0;
const sharedPendingRadius = 12.0;
const sharedRimWidth = 2.5;

/// The stroke of an unanswered cell's "+".
const sharedPlusStroke = 2.5;

/// The faces sit this far above the bottom of the cell.
const sharedFacesBottom = 6.0;

/// Chips stay this far above a cell's faces.
const sharedChipClearance = 3.0;

/// Where [piece] sits in a week [rowHeight] tall: the days it covers, from
/// line to line, its share of a stack.
Rect sharedPieceRect(SharedPiece piece, double columnWidth, double rowHeight) {
  final left =
      piece.startColumn * columnWidth +
      (piece.continuesBefore ? 0 : sharedCellGap);
  final right =
      (piece.endColumn + 1) * columnWidth -
      (piece.continuesAfter ? 0 : sharedCellGap);
  final height = (rowHeight - sharedCellGap * (piece.slots - 1)) / piece.slots;
  final y = piece.slot * (height + sharedCellGap);
  return Rect.fromLTWH(left, y, right - left, math.max(0, height));
}

/// The whole days of [piece], edge to edge: an unanswered cell's dashed
/// edge runs on its sides, right in the middle of the gap between the chips
/// of neighbouring days.
Rect sharedDaysRect(SharedPiece piece, double columnWidth, Rect cell) =>
    Rect.fromLTRB(
      piece.startColumn * columnWidth,
      cell.top,
      (piece.endColumn + 1) * columnWidth,
      cell.bottom,
    );

/// Size of the faces on a cell [width] wide.
double sharedFaceSize(double width) =>
    ((width - 8) / 2.2).clamp(12.0, 22.0).toDouble();

/// The "+" of an unanswered cell, against its faces.
const sharedPlusShare = 1.1;

/// How far up from the bottom of [cell] its front reaches: the faces, and
/// on an unanswered cell room for "+" over them; all of a "+N". Chips stay
/// above it.
double sharedFrontHeight(CalendarEvent? event, Rect cell) {
  final invite = event?.invite;
  if (invite == null) return cell.height;
  final face = sharedFaceSize(cell.width);
  final faces = face + sharedFacesBottom + sharedChipClearance;
  if (!invite.pending) return math.min(cell.height, faces);
  return math.min(cell.height, faces + face * sharedPlusShare + 8);
}

/// A cell's colours are fully there at its bottom, at [sharedFillMiddle]
/// on the top of the faces, and gone [sharedFillGap] under what is over the
/// cell — the day number or the lowest chip. Those two anchors follow the
/// chips as the mode folds them. Alpha, not a shade: one draw.
const sharedFillMiddle = 0.45;
const sharedFillGap = 4.0;

/// And a radial mask on top, for the arc: centred on the cell just under
/// what is over it, reaching [sharedArcReach] of the way past the cell's
/// bottom; clear inside [sharedArcClear] of its radius, full from
/// [sharedArcFull]. The sides, farther from the centre, show higher than
/// the middle.
const sharedArcReach = 1.1;
const sharedArcClear = 0.23;
const sharedArcFull = 0.69;

/// Holds the morphs of cells the user just said yes to. Wraps the month in
/// the calendar.
class SharedCells extends StatefulWidget {
  const SharedCells({
    required this.events,
    required this.child,
    this.openInvite,
    super.key,
  });

  /// The shared events as the month shows them.
  final List<CalendarEvent> events;

  /// The invite whose page is open now: a cell answered there morphs once
  /// the page is closed, where the user sees it.
  final ValueListenable<String?>? openInvite;
  final Widget child;

  @override
  State<SharedCells> createState() => _SharedCellsState();
}

class _SharedCellsState extends State<SharedCells>
    with TickerProviderStateMixin {
  final _morphs = _Morphs();

  /// Answered while their page was open; they play when it closes.
  final _queued = <String>{};

  @override
  void initState() {
    super.initState();
    widget.openInvite?.addListener(_playQueued);
  }

  @override
  void didUpdateWidget(covariant SharedCells oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.openInvite != widget.openInvite) {
      oldWidget.openInvite?.removeListener(_playQueued);
      widget.openInvite?.addListener(_playQueued);
    }
    if (identical(oldWidget.events, widget.events)) return;
    final wasPending = {
      for (final event in oldWidget.events)
        if (event.invite case final invite?) invite.id: invite.pending,
    };
    for (final event in widget.events) {
      final invite = event.invite;
      if (invite == null || invite.pending) continue;
      if (wasPending[invite.id] == true) _queued.add(invite.id);
    }
    _playQueued();
  }

  void _playQueued() {
    if (_queued.isEmpty || widget.openInvite?.value != null) return;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduce) {
      for (final id in _queued) {
        _morphs.start(id, this);
      }
    }
    _queued.clear();
  }

  @override
  void dispose() {
    widget.openInvite?.removeListener(_playQueued);
    _morphs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SharedScope(morphs: _morphs, child: widget.child);
}

/// Morphs in flight, by invite id.
class _Morphs extends ChangeNotifier {
  final _running = <String, AnimationController>{};

  Animation<double>? of(String id) => _running[id];

  void start(String id, TickerProvider vsync) {
    _running.remove(id)?.dispose();
    final controller = AnimationController(
      vsync: vsync,
      duration: sharedMorphDuration,
    );
    _running[id] = controller;
    controller.forward().whenComplete(() {
      if (!identical(_running[id], controller)) return;
      _running.remove(id);
      controller.dispose();
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    for (final controller in _running.values) {
      controller.dispose();
    }
    _running.clear();
    super.dispose();
  }
}

class _SharedScope extends InheritedNotifier<_Morphs> {
  const _SharedScope({required _Morphs morphs, required super.child})
    : super(notifier: morphs);

  static Animation<double>? morphOf(BuildContext context, String id) => context
      .dependOnInheritedWidgetOfExactType<_SharedScope>()
      ?.notifier
      ?.of(id);
}

double _span(double from, double to, double x) =>
    ((x - from) / (to - from)).clamp(0.0, 1.0);

/// Builds [builder] with where the cell of [invite] stands between
/// unanswered (0) and answered (1), following its morph if one plays.
Widget _withAnswer(
  BuildContext context,
  EventInvite invite,
  Widget Function(double answered) builder,
) {
  final morph = _SharedScope.morphOf(context, invite.id);
  if (morph == null) return builder(invite.pending ? 0 : 1);
  return AnimatedBuilder(
    animation: morph,
    builder: (context, _) => builder(morph.value),
  );
}

/// The back of a cell: under the day numbers, the bands and the chips.
/// Its colours fade out upwards to nothing just under what is over it
/// ([upperBottom], as for [SharedCellFront]): the day number, or the chips
/// crossing it, following them as the mode folds and unfolds them.
class SharedCellBack extends StatelessWidget {
  const SharedCellBack({
    required this.event,
    required this.mode,
    required this.upperBottom,
    this.facesTop,
    super.key,
  });

  final CalendarEvent event;
  final ValueListenable<double> mode;
  final double Function(double mode) upperBottom;

  /// How far up from the bottom the faces reach; by default the month's
  /// ([sharedFacesBottom] and [sharedFaceSize]).
  final double? facesTop;

  @override
  Widget build(BuildContext context) {
    final invite = event.invite!;
    return _withAnswer(context, invite, (answered) {
      final grow = Curves.easeOutCubic.transform(_span(0.2, 1, answered));
      CustomPaint fill(double opacity) => CustomPaint(
        painter: _CellFill(
          colors: invite.colors,
          opacity: opacity,
          mode: mode,
          upperBottom: upperBottom,
          facesTop: facesTop,
        ),
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          if (grow >= 1)
            fill(1)
          else if (grow > 0)
            ClipRect(clipper: _RisingEdge(grow), child: fill(1)),
        ],
      );
    });
  }
}

/// The front of a cell, over the chips: the faces, and on an unanswered
/// cell the dashed edge and "+". It spans the whole days
/// ([sharedDaysRect]); [cell] is where the cell itself sits inside them.
///
/// "+" stands halfway between the faces and what is above them: the
/// lowest chip of the day, or the day number. [upperBottom] says where that
/// is, from the top of this box, at each step of the mode.
class SharedCellFront extends StatelessWidget {
  const SharedCellFront({
    required this.event,
    required this.cell,
    required this.mode,
    required this.upperBottom,
    this.onScreenLeft = false,
    this.onScreenRight = false,
    this.faces,
    super.key,
  });

  final CalendarEvent event;
  final EdgeInsets cell;
  final ValueListenable<double> mode;
  final double Function(double mode) upperBottom;

  /// The faces drawn elsewhere (the day's sticky ones): their size and
  /// distance from the bottom, for the "+" to sit over them. Null — the
  /// month's faces, drawn here.
  final ({double size, double bottom})? faces;

  /// The days start or end at the edge of the screen: the dashed edge stays
  /// inside it there.
  final bool onScreenLeft;
  final bool onScreenRight;

  @override
  Widget build(BuildContext context) {
    final invite = event.invite!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - cell.horizontal;
        final elsewhere = faces;
        final face = elsewhere?.size ?? sharedFaceSize(width);
        final facesBottom = elsewhere?.bottom ?? sharedFacesBottom;
        return _withAnswer(context, invite, (answered) {
          final pending = 1 - _span(0, 0.3, answered);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (elsewhere == null)
                Positioned(
                  left: cell.left,
                  right: cell.right,
                  bottom: sharedFacesBottom,
                  height: face,
                  child: Center(
                    child: FaceStack(people: invite.people, size: face),
                  ),
                ),
              if (pending > 0) ...[
                // On the edges of the days: the middle of the gap between
                // the chips of neighbouring days, never over them.
                CustomPaint(
                  painter: DashedRimPainter(
                    color: Colors.white.withValues(alpha: 0.6 * pending),
                    radius: sharedPendingRadius,
                    dash: 8,
                    gap: 5,
                    width: sharedRimWidth,
                    inset: EdgeInsets.fromLTRB(
                      onScreenLeft ? sharedRimWidth / 2 : 0,
                      sharedRimWidth / 2,
                      onScreenRight ? sharedRimWidth / 2 : 0,
                      sharedRimWidth / 2,
                    ),
                  ),
                ),
                ValueListenableBuilder<double>(
                  valueListenable: mode,
                  builder: (context, t, _) {
                    final size = face * sharedPlusShare;
                    final facesTop = constraints.maxHeight - facesBottom - face;
                    final middle = (upperBottom(t) + facesTop) / 2;
                    return Positioned(
                      left: cell.left,
                      right: cell.right,
                      top: middle - size / 2,
                      height: size,
                      child: Transform.scale(
                        scale: Curves.easeOut.transform(pending),
                        child: const CustomPaint(
                          key: ValueKey('shared-plus'),
                          painter: _Plus(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          );
        });
      },
    );
  }
}

/// A "+N" cell: more shared events on this day than fit.
class SharedMoreCell extends StatelessWidget {
  const SharedMoreCell({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF1C1C1E),
    child: Center(
      child: Text(
        '+$count',
        style: const TextStyle(
          color: Color(0xFFAEAEB2),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

/// The people's colours left to right, the organizer's on the left; fully
/// there at the bottom, [sharedFillMiddle] on the top of the faces, gone
/// just under what is over the cell, and shaped into an arc by a radial
/// mask. Repaints with the mode, never
/// rebuilds.
class _CellFill extends CustomPainter {
  _CellFill({
    required this.colors,
    required this.opacity,
    required this.mode,
    required this.upperBottom,
    this.facesTop,
  }) : super(repaint: mode);

  final List<Color> colors;
  final double opacity;
  final ValueListenable<double> mode;
  final double Function(double mode) upperBottom;
  final double? facesTop;

  @override
  void paint(Canvas canvas, Size size) {
    if (colors.isEmpty || size.isEmpty) return;
    final spread = colors.length == 1 ? [colors.first, colors.first] : colors;
    // Distances up from the bottom of the cell.
    final middle = facesTop ?? sharedFacesBottom + sharedFaceSize(size.width);
    final upper = upperBottom(mode.value);
    final gone = math.max(middle + 8, size.height - upper - sharedFillGap);
    final top = math.max(0.0, upper);
    paintFadingBand(
      canvas,
      Offset.zero & size,
      colors: spread,
      stops: [for (var i = 0; i < spread.length; i++) i / (spread.length - 1)],
      fromTop: false,
      fade: gone,
      opacity: opacity,
      middle: (middle, sharedFillMiddle),
      radial: (
        centre: Offset(size.width / 2, top),
        radius: math.max(1.0, (size.height - top) * sharedArcReach),
        clear: sharedArcClear,
        full: sharedArcFull,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _CellFill old) =>
      old.opacity != opacity ||
      old.mode != mode ||
      old.upperBottom != upperBottom ||
      old.facesTop != facesTop ||
      !listEquals(old.colors, colors);
}

/// The "+" of an unanswered cell: two rounded strokes, bolder than the
/// icon font's, centred in a square of the box's height.
class _Plus extends CustomPainter {
  const _Plus();

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.height / 2 - sharedPlusStroke / 2;
    final centre = size.center(Offset.zero);
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = sharedPlusStroke
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(centre - Offset(half, 0), centre + Offset(half, 0), paint)
      ..drawLine(centre - Offset(0, half), centre + Offset(0, half), paint);
  }

  @override
  bool shouldRepaint(covariant _Plus old) => false;
}

/// The bottom [grow] of the box: an answered cell's colours rise into it
/// from below.
class _RisingEdge extends CustomClipper<Rect> {
  const _RisingEdge(this.grow);

  final double grow;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, size.height * (1 - grow), size.width, size.height);

  @override
  bool shouldReclip(covariant _RisingEdge old) => old.grow != grow;
}

/// Up to three faces overlapping, the rightmost on top; with more people
/// the third is "+N".
class FaceStack extends StatelessWidget {
  const FaceStack({required this.people, required this.size, super.key});

  final List<FriendInfo> people;
  final double size;

  static const _max = 3;

  @override
  Widget build(BuildContext context) {
    final crowded = people.length > _max;
    final shown = people.take(crowded ? _max - 1 : _max).toList();
    final count = shown.length + (crowded ? 1 : 0);
    if (count == 0) return const SizedBox.shrink();
    final step = size * 0.6;
    return SizedBox(
      width: size + step * (count - 1),
      height: size,
      child: Stack(
        children: [
          // Painted left to right: the rightmost ends up on top.
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: step * i,
              child: PersonAvatar(
                id: shown[i].id,
                name: shown[i].name,
                username: shown[i].username,
                size: size,
              ),
            ),
          if (crowded)
            Positioned(
              left: step * (count - 1),
              child: AvatarOverflow(
                count: people.length - shown.length,
                size: size,
              ),
            ),
        ],
      ),
    );
  }
}

/// In the open day the shared cells stand behind everything for the time
/// of their event, across every row, the way the month's stand behind a
/// day: the colours rise from the bottom (gone by [sharedDayFade] of the
/// height), the faces at the bottom, an unanswered one dashed with "+".
/// They do not fold with the mode. Overlapping ones stack top to bottom,
/// at most [sharedMaxSlots]; a tap opens the event.
const sharedDayFade = 0.12;

/// The day's faces: bigger than the month's and higher off the bottom,
/// drawn by [DaySharedFaces], sticky at the left.
const sharedDayFaceSize = 30.0;
const sharedDayFacesBottom = 28.0;

/// Lanes for cells in time ([spans] sorted by start), and how many share
/// each run of overlapping ones, at most [sharedMaxSlots].
({List<int> lanes, List<int> slots}) sharedTimeLanes(
  List<(double, double)> spans,
) {
  final lanes = <int>[];
  final ends = <double>[];
  for (final (start, end) in spans) {
    var lane = ends.indexWhere((e) => e <= start);
    if (lane < 0) {
      lane = ends.length;
      ends.add(end);
    } else {
      ends[lane] = end;
    }
    lanes.add(lane);
  }
  final slots = List.filled(spans.length, 1);
  var runStart = 0;
  var runEnd = double.negativeInfinity;
  for (var i = 0; i <= spans.length; i++) {
    if (i == spans.length || spans[i].$1 >= runEnd) {
      var most = 0;
      for (var j = runStart; j < i; j++) {
        most = math.max(most, lanes[j] + 1);
      }
      for (var j = runStart; j < i; j++) {
        slots[j] = math.min(most, sharedMaxSlots);
      }
      if (i == spans.length) break;
      runStart = i;
      runEnd = spans[i].$2;
    } else {
      runEnd = math.max(runEnd, spans[i].$2);
    }
  }
  return (lanes: lanes, slots: slots);
}

class DaySharedLayer extends StatelessWidget {
  const DaySharedLayer({
    required this.day,
    required this.pixelsPerHour,
    required this.events,
    this.front = false,
    this.onTap,
    super.key,
  });

  final DateTime day;
  final double pixelsPerHour;
  final List<CalendarEvent> events;

  /// The faces, dashed edges and "+", over the bars; otherwise the colours,
  /// under them.
  final bool front;
  final void Function(CalendarEvent event, Rect rect)? onTap;

  static const _still = AlwaysStoppedAnimation<double>(0);

  @override
  Widget build(BuildContext context) {
    final slices = [
      for (final event in events)
        if (event.invite != null)
          if (sliceOnDay(event, day) case final slice?) (event, slice),
    ]..sort((a, b) => a.$2.startHour.compareTo(b.$2.startHour));
    if (slices.isEmpty) return const SizedBox.shrink();
    final (:lanes, :slots) = sharedTimeLanes([
      for (final (_, slice) in slices) (slice.startHour, slice.endHour),
    ]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final children = <Widget>[];
        for (var i = 0; i < slices.length; i++) {
          final (event, slice) = slices[i];
          if (lanes[i] >= sharedMaxSlots) continue;
          final share = (height - sharedCellGap * (slots[i] - 1)) / slots[i];
          final top = lanes[i] * (share + sharedCellGap);
          final days = Rect.fromLTRB(
            slice.startHour * pixelsPerHour,
            top,
            slice.endHour * pixelsPerHour,
            top + share,
          );
          final cell = EdgeInsets.only(
            left: slice.continuesBefore ? 0 : sharedCellGap,
            right: slice.continuesAfter ? 0 : sharedCellGap,
          );
          double upper(double _) => share * sharedDayFade;
          if (!front) {
            children.add(
              Positioned.fromRect(
                key: ValueKey('day-shared-${event.id}'),
                rect: cell.deflateRect(days),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap == null
                      ? null
                      : () {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box == null) return;
                          final rect = cell.deflateRect(days);
                          onTap!(
                            event,
                            box.localToGlobal(rect.topLeft) & rect.size,
                          );
                        },
                  child: SharedCellBack(
                    event: event,
                    mode: _still,
                    upperBottom: upper,
                    facesTop: sharedDayFacesBottom + sharedDayFaceSize,
                  ),
                ),
              ),
            );
            continue;
          }
          children.add(
            Positioned.fromRect(
              key: ValueKey('day-shared-front-${event.id}'),
              rect: days,
              child: IgnorePointer(
                child: SharedCellFront(
                  event: event,
                  cell: cell,
                  mode: _still,
                  upperBottom: upper,
                  faces: (
                    size: sharedDayFaceSize,
                    bottom: sharedDayFacesBottom,
                  ),
                ),
              ),
            ),
          );
        }
        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

/// The faces of the shared events in view of the open day, at the bottom
/// of their cells, sticky at the left: they stay in view (clear of the
/// friends' column, [leftInset]) while the event runs on past the left
/// edge, like the bars' titles.
class DaySharedFaces extends StatelessWidget {
  const DaySharedFaces({
    required this.events,
    required this.scrollOffset,
    required this.pixelsPerHour,
    required this.viewportWidth,
    this.leftInset = 0,
    super.key,
  });

  final List<CalendarEvent> events;
  final double scrollOffset;
  final double pixelsPerHour;
  final double viewportWidth;
  final double leftInset;

  static const _padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final shared = [
      for (final event in events)
        if (event.invite?.people.isNotEmpty ?? false) event,
    ]..sort((a, b) => a.start.compareTo(b.start));
    final (:lanes, :slots) = sharedTimeLanes([
      for (final event in shared)
        (
          timelineX(event.start, pixelsPerHour),
          timelineX(event.end, pixelsPerHour),
        ),
    ]);
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final children = <Widget>[];
          for (var i = 0; i < shared.length; i++) {
            if (lanes[i] >= sharedMaxSlots) continue;
            final event = shared[i];
            final people = event.invite!.people;
            final left = timelineX(event.start, pixelsPerHour) - scrollOffset;
            final right = timelineX(event.end, pixelsPerHour) - scrollOffset;
            if (right <= leftInset || left >= viewportWidth) continue;
            final shown = math.min(people.length, 3);
            final width = sharedDayFaceSize * (1 + 0.6 * (shown - 1));
            final x = math.min(
              math.max(left, leftInset) + _padding,
              right - _padding - width,
            );
            if (x < left) continue;
            // The bottom of this cell's share of the height.
            final share = (height - sharedCellGap * (slots[i] - 1)) / slots[i];
            final cellBottom = lanes[i] * (share + sharedCellGap) + share;
            children.add(
              Positioned(
                key: ValueKey('day-shared-faces-${event.id}'),
                left: x,
                bottom: height - cellBottom + sharedDayFacesBottom,
                child: FaceStack(people: people, size: sharedDayFaceSize),
              ),
            );
          }
          return Stack(children: children);
        },
      ),
    );
  }
}
