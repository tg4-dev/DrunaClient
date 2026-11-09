import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/shared_cell.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/profile/chip_time.dart';
import 'package:druna_app/models/models.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/material.dart';

abstract final class EventChipStyle {
  static const radius = 32.0;
  static const padding = 16.0;
  static const gap = 12.0;

  static const titleSize = 24.0;
  static const titleLines = 2;

  static const column = 88.0;

  static const avatar = 28.0;
  static const avatarStep = 20.0;
  static const avatarsShown = 5;

  static const angle = 20 * math.pi / 180;
  static const center = Color(0xD9000000);

  static const emptyFill = Color(0xFF141414);
  static const pendingRim = Color(0x99FFFFFF);
  static const pendingRimWidth = 2.5;
  static const pendingDash = 8.0;
  static const pendingGap = 5.0;

  static const dim = 0.45;

  static const glow = Color(0x14FFFFFF);
  static const glowBand = 0.4;
  static const glowSweep = Duration(milliseconds: 1600);
  static const glowPause = Duration(milliseconds: 1200);

  static final time = onest(
    17,
    weight: FontWeight.w600,
    color: const Color(0xB3FFFFFF),
  );
  static final spanTime = onest(
    15,
    weight: FontWeight.w500,
    color: const Color(0xB3FFFFFF),
  );
  static final caption = onest(
    13,
    weight: FontWeight.w600,
    color: const Color(0x99FFFFFF),
  );

  static final title = EventPageStyle.title.copyWith(fontSize: titleSize);
}

class EventChip extends StatefulWidget {
  const EventChip({
    required this.title,
    required this.start,
    required this.end,
    required this.allDay,
    required this.people,
    required this.colors,
    required this.onTap,
    this.pending = false,
    this.dimmed = false,
    super.key,
  });

  final String title;
  final DateTime start;
  final DateTime end;
  final bool allDay;
  final List<FriendInfo> people;
  final List<Color> colors;
  final VoidCallback onTap;

  final bool pending;

  final bool dimmed;

  static var glows = true;

  @override
  State<EventChip> createState() => _EventChipState();
}

class _EventChipState extends State<EventChip>
    with SingleTickerProviderStateMixin {
  var _pressed = false;
  AnimationController? _glow;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncGlow();
  }

  @override
  void reassemble() {
    super.reassemble();
    _syncGlow();
  }

  @override
  void didUpdateWidget(covariant EventChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncGlow();
  }

  @override
  void dispose() {
    _glow?.dispose();
    super.dispose();
  }

  void _syncGlow() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final on = widget.pending && !reduce && EventChip.glows;
    if (!on) {
      _glow?.dispose();
      _glow = null;
      return;
    }
    _glow ??= AnimationController(
      vsync: this,
      duration: EventChipStyle.glowSweep + EventChipStyle.glowPause,
    )..repeat();
  }

  void _press(bool down) {
    if (_pressed != down) setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final time = chipTime(widget.start, widget.end, allDay: widget.allDay);
    final title = widget.title.trim().isEmpty ? 'Без названия' : widget.title;
    var colors = widget.colors;
    if (widget.dimmed) {
      colors = [
        for (final color in colors)
          Color.lerp(color, Colors.black, EventChipStyle.dim)!,
      ];
    }
    return Semantics(
      button: true,
      label: [
        title,
        ?time.caption,
        time.left,
        time.middle,
        time.right,
        if (widget.pending) 'ждёт ответа',
      ].join(', '),
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed && !reduce ? PillStyle.pressedScale : 1,
          duration: PillStyle.press,
          curve: Curves.easeOutCubic,
          child: CustomPaint(
            painter: ChipFill(colors: colors, pending: widget.pending),
            foregroundPainter: _glow == null ? null : GlowPainter(_glow!),
            child: Padding(
              padding: const EdgeInsets.all(EventChipStyle.padding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Time(time: time),
                  const SizedBox(height: 6),
                  FitTitle(
                    text: title,
                    style: EventChipStyle.title,
                    maxLines: EventChipStyle.titleLines,
                  ),
                  if (widget.people.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    FaceStack(
                      people: widget.people,
                      size: EventChipStyle.avatar,
                      max: EventChipStyle.avatarsShown,
                      step: EventChipStyle.avatarStep,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time({required this.time});

  final ChipTime time;

  @override
  Widget build(BuildContext context) {
    final style = time.span ? EventChipStyle.spanTime : EventChipStyle.time;
    Widget cell(String text) => SizedBox(
      width: EventChipStyle.column,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.fade,
        softWrap: false,
        style: style,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (time.caption case final caption?) ...[
          Text(caption, style: EventChipStyle.caption),
          const SizedBox(height: 4),
        ],
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [cell(time.left), cell(time.middle), cell(time.right)],
          ),
        ),
      ],
    );
  }
}

class ChipFill extends CustomPainter {
  const ChipFill({
    required this.colors,
    this.pending = false,
    this.radius = EventChipStyle.radius,
  });

  final List<Color> colors;
  final bool pending;

  final double? radius;

  static const _rim = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [PillStyle.rimTop, PillStyle.rimBottom],
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final corner = radius ?? size.height / 2;
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(corner));
    if (pending || colors.isEmpty) {
      if (!pending) {
        canvas.drawRRect(shape, Paint()..color = EventChipStyle.emptyFill);
      }
      DashedRimPainter(
        color: EventChipStyle.pendingRim,
        radius: corner,
        dash: EventChipStyle.pendingDash,
        gap: EventChipStyle.pendingGap,
        width: EventChipStyle.pendingRimWidth,
      ).paint(canvas, size);
      return;
    }
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = LinearGradient(
          colors: colors.length > 1 ? colors : [colors.first, colors.first],
          transform: const GradientRotation(EventChipStyle.angle),
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = RadialGradient(
          radius: 0.5 * size.width / size.shortestSide,
          colors: const [EventChipStyle.center, Color(0x00000000)],
        ).createShader(rect),
    );
    canvas.drawRRect(
      shape.deflate(PillStyle.rimWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PillStyle.rimWidth
        ..shader = _rim.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant ChipFill old) =>
      old.pending != pending ||
      old.radius != radius ||
      !_sameColors(old.colors, colors);
}

bool _sameColors(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

class GlowPainter extends CustomPainter {
  GlowPainter(this.progress, {this.radius = EventChipStyle.radius})
    : super(repaint: progress);

  final Animation<double> progress;
  final double radius;

  static final double sweepShare =
      EventChipStyle.glowSweep.inMicroseconds /
      (EventChipStyle.glowSweep + EventChipStyle.glowPause).inMicroseconds;

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value / sweepShare;
    if (t >= 1 || size.isEmpty) return;
    final band = size.width * EventChipStyle.glowBand;
    final reach = size.width + size.height;
    final center = -band + (reach + 2 * band) * t;
    Offset at(double s) => Offset(s / 2, s / 2);
    final rect = Offset.zero & size;
    canvas
      ..save()
      ..clipRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)))
      ..drawRect(
        rect,
        Paint()
          ..shader = ui.Gradient.linear(
            at(center - band / 2),
            at(center + band / 2),
            const [Color(0x00FFFFFF), EventChipStyle.glow, Color(0x00FFFFFF)],
            const [0, 0.5, 1],
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(covariant GlowPainter old) =>
      old.progress != progress || old.radius != radius;
}
