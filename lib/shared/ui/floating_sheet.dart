import 'package:druna_app/features/calendar/sheet_style.dart';
import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/cupertino.dart';

abstract final class FloatingSheetStyle {
  static const inset = 8.0;
  static const radius = EventPageStyle.radius;

  static const maxHeight = 0.75;
}

class FloatingSheet extends StatefulWidget {
  const FloatingSheet({
    required this.icon,
    required this.title,
    required this.child,
    required this.onClosing,
    required this.onGone,
    this.scrimKey,
    super.key,
  });

  final IconData icon;
  final String title;
  final Widget child;

  final VoidCallback onClosing;

  final VoidCallback onGone;

  final Key? scrimKey;

  @override
  State<FloatingSheet> createState() => _FloatingSheetState();
}

class _FloatingSheetState extends State<FloatingSheet>
    with TickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: EventPageStyle.enter,
    reverseDuration: EventPageStyle.leave,
  );
  late final _rise = CurvedAnimation(
    parent: _motion,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );
  late final _settle = AnimationController(
    vsync: this,
    duration: EventPageStyle.settle,
  )..addListener(_onSettle);
  final _drag = ValueNotifier<double>(0);
  double _settleFrom = 0;
  var _closing = false;

  @override
  void initState() {
    super.initState();
    _motion.forward();
  }

  @override
  void dispose() {
    _rise.dispose();
    _motion.dispose();
    _settle.dispose();
    _drag.dispose();
    super.dispose();
  }

  void _onSettle() {
    final t = Curves.easeOutCubic.transform(_settle.value);
    _drag.value = _settleFrom * (1 - t);
  }

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    widget.onClosing();
    await _motion.reverse();
    if (mounted) widget.onGone();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    final next = _drag.value + (details.primaryDelta ?? 0);
    _drag.value = next < 0 ? next * 0.25 : next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value > EventPageStyle.dismissDistance ||
        velocity > EventPageStyle.dismissVelocity) {
      _swipeAway();
      return;
    }
    _settleFrom = _drag.value;
    _settle.forward(from: 0);
  }

  void _swipeAway() {
    _closing = true;
    widget.onClosing();
    final height = MediaQuery.sizeOf(context).height;
    final from = _drag.value;
    final exit = AnimationController(
      vsync: this,
      duration: EventPageStyle.fling,
    );
    exit.addListener(() {
      _drag.value =
          from + (height - from) * Curves.easeInCubic.transform(exit.value);
    });
    exit.forward().whenComplete(() {
      exit.dispose();
      if (mounted) widget.onGone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    return IgnorePointer(
      ignoring: _closing,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rise, _drag]),
        builder: (context, sheet) {
          final drag = _drag.value;
          final release = (1 - drag.clamp(0, 400) / 400).toDouble();
          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  key: widget.scrimKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Opacity(
                    opacity: (_rise.value * release).clamp(0.0, 1.0),
                    child: const ColoredBox(color: EventPageStyle.scrim),
                  ),
                ),
              ),
              Positioned(
                left: FloatingSheetStyle.inset,
                right: FloatingSheetStyle.inset,
                bottom: FloatingSheetStyle.inset,
                child: Transform.translate(
                  offset: Offset(0, height * (1 - _rise.value) + drag),
                  child: sheet,
                ),
              ),
            ],
          );
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: height * FloatingSheetStyle.maxHeight,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(FloatingSheetStyle.radius),
            ),
            child: ColoredBox(
              color: SheetStyle.block,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 12, 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              width: EventPageStyle.grabber.width,
                              height: EventPageStyle.grabber.height,
                              decoration: BoxDecoration(
                                color: EventPageStyle.grabberColor,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                widget.icon,
                                color: SheetStyle.muted,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  style: SheetStyle.title,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        12,
                        12 + media.padding.bottom,
                      ),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
