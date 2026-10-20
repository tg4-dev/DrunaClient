import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:druna_app/features/calendar/calendar_event.dart';
import 'package:druna_app/features/calendar/event_repeat_block.dart';
import 'package:druna_app/features/calendar/event_time_block.dart';
import 'package:druna_app/features/calendar/repeat_rule.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Side margin of the sheet's card and blocks.
const _sheetMargin = 16.0;
const _blockGap = 12.0;
const _cardRadius = Radius.circular(20);
const _cardPadding = EdgeInsets.fromLTRB(18, 14, 18, 16);
const _buttonInset = 44.0;
const _buttonHeight = 44.0;
const _buttonWidth = 80.0;
const _iconSize = 24.0;
const _buttonsLift = 19.0;

/// Room under the stack for the ✕/✓ row floating above the keyboard.
const _buttonsRoom = _buttonHeight + _buttonsLift + 12;
const _scrim = Color(0xD9000000);

const _enterDuration = Duration(milliseconds: 460);
const _exitDuration = Duration(milliseconds: 220);

/// The card's place on screen, under the status bar. It never moves with the
/// blocks or the keyboard.
const _cardTop = 48.0;

/// Where each layer starts below its place when the sheet rises. The gaps
/// between them start wide and close as the stack settles.
const _riseCard = 36.0;
const _riseBlocks = [150.0, 270.0];

/// After a swipe the stack is gone within this, never longer.
const _flingDuration = Duration(milliseconds: 140);
const _returnDuration = Duration(milliseconds: 200);

/// Pulling the stack this far down, or flinging it, saves and closes.
const _dismissDistance = 110.0;
const _dismissVelocity = 700.0;

/// Card labels: dark on the event colour. Pure black on `#9A3040` reaches
/// only about 2.9:1, so they stay heavy and near-black.
const _cardLabel = TextStyle(
  color: Color(0xD9000000),
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.1,
);
const _cardTitle = TextStyle(
  color: Colors.white,
  fontSize: 22,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.3,
);
const _cardTime = TextStyle(
  color: Colors.white,
  fontSize: 20,
  fontWeight: FontWeight.w500,
  fontFeatures: [FontFeature.tabularFigures()],
);

/// The event editor: the event's card over its blocks over the keyboard,
/// rising from the bottom. A swipe down saves at once and lets the calendar
/// take touches while the stack finishes leaving.
class EventDurationSheet extends StatefulWidget {
  const EventDurationSheet({
    required this.event,
    required this.onSave,
    required this.onCancel,
    this.onGone,
    this.leaving = false,
    super.key,
  });

  final CalendarEvent event;
  final ValueChanged<CalendarEvent> onSave;
  final VoidCallback onCancel;

  /// Called once the sheet has finished leaving and can be removed.
  final VoidCallback? onGone;

  /// Set by the parent after a swipe: the sheet ignores touches and only
  /// plays out its exit.
  final bool leaving;

  @override
  State<EventDurationSheet> createState() => _EventDurationSheetState();
}

class _EventDurationSheetState extends State<EventDurationSheet>
    with TickerProviderStateMixin {
  late final AnimationController _motion;
  late final AnimationController _settle;
  late final CurvedAnimation _rise;
  late final CurvedAnimation _fade;
  final _cardKey = GlobalKey();

  /// Measured after layout; the blocks start just under the card.
  double _cardHeight = 92;
  final _drag = ValueNotifier<double>(0);
  final _titleFocus = FocusNode();
  late final TextEditingController _title;
  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  RepeatRule? _repeat;
  var _closing = false;
  double _settleFrom = 0;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _allDay = event.allDay;
    _repeat = event.repeat;
    if (event.allDay) {
      final span = defaultEventSpan(eventFirstDay(event), DateTime.now());
      _start = span.start;
      _end = span.end;
    } else {
      _start = nearestQuarter(event.start);
      final end = nearestQuarter(event.end);
      _end = end.isAfter(_start) ? end : _start.add(minimumEventLength);
    }
    _title = TextEditingController(text: event.title);
    _motion = AnimationController(
      vsync: this,
      duration: _enterDuration,
      reverseDuration: _exitDuration,
    );
    _settle = AnimationController(vsync: this, duration: _returnDuration)
      ..addListener(() {
        final t = Curves.easeOutCubic.transform(_settle.value);
        _drag.value = _settleFrom * (1 - t);
      });
    _rise = CurvedAnimation(
      parent: _motion,
      curve: Curves.easeOutQuart,
      reverseCurve: Curves.easeInCubic,
    );
    _fade = CurvedAnimation(
      parent: _motion,
      curve: const Interval(0, 0.55, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );
    // The keyboard rises with the sheet instead of after it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _titleFocus.requestFocus();
      _measureCard();
      _motion.forward();
    });
  }

  @override
  void dispose() {
    _rise.dispose();
    _fade.dispose();
    _motion.dispose();
    _settle.dispose();
    _drag.dispose();
    _titleFocus.dispose();
    _title.dispose();
    super.dispose();
  }

  void _setStart(int hour, int minute) {
    final next = withStartClock(_start, _end, hour, minute);
    setState(() {
      _start = next.start;
      _end = next.end;
    });
  }

  void _setEnd(int hour, int minute) {
    final next = withEndClock(_start, _end, hour, minute);
    setState(() => _end = next.end);
  }

  CalendarEvent _draft() => applyEventDraft(
    event: widget.event,
    title: _title.text,
    allDay: _allDay,
    start: _start,
    end: _end,
    repeat: _repeat,
  );

  /// Button exits play first, then report; the sheet still owns the screen.
  Future<void> _close(VoidCallback action) async {
    if (_closing) return;
    _closing = true;
    _titleFocus.unfocus();
    await _motion.reverse();
    if (!mounted) return;
    action();
    widget.onGone?.call();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _settle.stop();
    final next = _drag.value + (details.primaryDelta ?? 0);
    // Upward pulls resist; the stack only leaves downward.
    _drag.value = next < 0 ? next * 0.25 : next;
  }

  void _onDragEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_drag.value > _dismissDistance || velocity > _dismissVelocity) {
      _swipeAway(velocity);
      return;
    }
    _settleFrom = _drag.value;
    _settle.forward(from: 0);
  }

  /// Saves the moment the finger lifts, then finishes the slide out within
  /// [_flingDuration] while the calendar already takes touches.
  void _swipeAway(double velocity) {
    _closing = true;
    _titleFocus.unfocus();
    widget.onSave(_draft());
    final height = MediaQuery.sizeOf(context).height;
    final from = _drag.value;
    final exit = AnimationController(vsync: this, duration: _flingDuration);
    final curve = CurvedAnimation(parent: exit, curve: Curves.easeOutCubic);
    exit.addListener(() {
      _drag.value = from + (height - from) * curve.value;
    });
    exit.forward().whenComplete(() {
      curve.dispose();
      exit.dispose();
      if (mounted) widget.onGone?.call();
    });
  }

  void _measureCard() {
    final box = _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.height == _cardHeight) return;
    setState(() => _cardHeight = box.size.height);
  }

  /// [child] fading in and rising from [distance] below its place.
  Widget _rising(double distance, Widget child) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: _rise,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, distance * (1 - _rise.value)),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final bottomInset = keyboard > 0 ? keyboard : media.padding.bottom;
    final top = media.padding.top + _cardTop;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _measureCard();
    });
    // The blocks scroll under the card; only the card can be pulled down.
    final blocks = ListView(
      padding: EdgeInsets.fromLTRB(
        _sheetMargin,
        _cardHeight + _blockGap,
        _sheetMargin,
        _buttonsRoom,
      ),
      children: [
        _rising(
          _riseBlocks[0],
          EventTimeBlock(
            start: _start,
            end: _end,
            allDay: _allDay,
            onAllDay: (value) => setState(() => _allDay = value),
            onStart: _setStart,
            onEnd: _setEnd,
          ),
        ),
        const SizedBox(height: _blockGap),
        _rising(
          _riseBlocks[1],
          EventRepeatBlock(
            rule: _repeat,
            day: eventFirstDay(widget.event),
            onChanged: (rule) => setState(() => _repeat = rule),
          ),
        ),
      ],
    );
    final card = Positioned(
      top: top,
      left: _sheetMargin,
      right: _sheetMargin,
      child: _rising(_riseCard, KeyedSubtree(key: _cardKey, child: _card())),
    );
    return IgnorePointer(
      ignoring: widget.leaving,
      child: Material(
        type: MaterialType.transparency,
        child: ValueListenableBuilder<double>(
          valueListenable: _drag,
          builder: (context, drag, _) {
            // Pulling down fades the sheet towards the calendar behind it.
            final release = (1 - drag.clamp(0, 400) / 400).toDouble();
            return Stack(
              children: [
                FadeTransition(
                  opacity: _motion,
                  child: Opacity(
                    opacity: release,
                    child: const ColoredBox(
                      color: _scrim,
                      child: SizedBox.expand(),
                    ),
                  ),
                ),
                Positioned(
                  top: top,
                  left: 0,
                  right: 0,
                  bottom: bottomInset,
                  child: Transform.translate(
                    offset: Offset(0, drag),
                    child: Opacity(
                      opacity: release,
                      child: ClipRect(child: blocks),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: bottomInset,
                  height: 120,
                  child: IgnorePointer(
                    child: FadeTransition(
                      opacity: _fade,
                      child: Opacity(
                        opacity: release,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xCC000000)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Transform.translate(
                  offset: Offset(0, drag),
                  child: Stack(children: [card]),
                ),
                Positioned(
                  left: _buttonInset,
                  right: _buttonInset,
                  bottom: bottomInset + _buttonsLift,
                  child: Opacity(
                    opacity: release,
                    child: FadeTransition(opacity: _fade, child: _buttons()),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Color get _color => eventColor(widget.event, OwnEventColor.of(context));

  /// White on dark event colours, black on light ones.
  Color get _ink => eventInk(_color);

  Widget _card() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _color,
          borderRadius: const BorderRadius.all(_cardRadius),
        ),
        child: Padding(
          padding: _cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Text('Мои события', style: _cardLabel),
                  const Spacer(),
                  Text(eventDateLabel(_start), style: _cardLabel),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: _title,
                      focusNode: _titleFocus,
                      padding: EdgeInsets.zero,
                      decoration: const BoxDecoration(),
                      cursorColor: SheetStyle.accent,
                      textCapitalization: TextCapitalization.sentences,
                      style: _cardTitle.copyWith(color: _ink),
                      placeholder: 'Название',
                      placeholderStyle: _cardTitle.copyWith(color: _ink),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: SheetStyle.fade,
                    child: _allDay
                        ? const SizedBox.shrink()
                        : Padding(
                            key: const ValueKey('card-time'),
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              clockRangeLabel(_start, _end),
                              style: _cardTime.copyWith(color: _ink),
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buttons() {
    // Fixed padding around the icon gives the pill its width; the native
    // button centres its child only when the child spans the pill.
    const padding = EdgeInsets.symmetric(
      horizontal: (_buttonWidth - _iconSize) / 2,
    );
    final radius = BorderRadius.circular(_buttonHeight / 2);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Semantics(
          label: 'Отмена',
          button: true,
          child: AdaptiveButton.icon(
            key: const ValueKey('sheet-cancel'),
            onPressed: () => _close(widget.onCancel),
            icon: Icons.close_rounded,
            iconColor: Colors.white,
            color: SheetStyle.muted,
            style: AdaptiveButtonStyle.glass,
            size: AdaptiveButtonSize.large,
            padding: padding,
            borderRadius: radius,
            useSmoothRectangleBorder: false,
          ),
        ),
        Semantics(
          label: 'Сохранить',
          button: true,
          child: AdaptiveButton.icon(
            key: const ValueKey('sheet-save'),
            onPressed: () {
              final draft = _draft();
              _close(() => widget.onSave(draft));
            },
            icon: Icons.check_rounded,
            iconColor: Colors.white,
            color: SheetStyle.accent,
            style: AdaptiveButtonStyle.prominentGlass,
            size: AdaptiveButtonSize.large,
            padding: padding,
            borderRadius: radius,
            useSmoothRectangleBorder: false,
          ),
        ),
      ],
    );
  }
}
