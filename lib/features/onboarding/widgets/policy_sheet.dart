import 'package:druna_app/features/event_page/event_style.dart';
import 'package:flutter/material.dart';

Future<void> showPolicySheet(BuildContext context) =>
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, _, _) => const _PolicySheet(),
      ),
    );

class _PolicySheet extends StatefulWidget {
  const _PolicySheet();

  @override
  State<_PolicySheet> createState() => _PolicySheetState();
}

class _PolicySheetState extends State<_PolicySheet>
    with TickerProviderStateMixin {
  static const _placeholder = [
    'Здесь будет политика конфиденциальности Druna. Текст готовится.',
    'Druna хранит имя, ник и почту, чтобы друзья могли тебя найти, и твои '
        'события, чтобы искать общее свободное время. Мы не продаём данные '
        'и не показываем рекламу.',
    'Друзья видят только занятость в те часы, которые ты им открываешь. '
        'Аккаунт и все данные можно удалить в любой момент.',
    'Вопросы о данных — на почту поддержки, она появится здесь вместе с '
        'полным текстом.',
  ];

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
    final reduce = WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;
    if (reduce) {
      _motion.value = 1;
    } else {
      _motion.forward();
    }
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

  void _gone() {
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _close() async {
    if (_closing) return;
    setState(() => _closing = true);
    await _motion.reverse();
    _gone();
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
    setState(() => _closing = true);
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
      _gone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = media.size.height;
    return PopScope(
      canPop: _closing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: IgnorePointer(
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
                    key: const ValueKey('policy-scrim'),
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: Opacity(
                      opacity: (_rise.value * release).clamp(0.0, 1.0),
                      child: const ColoredBox(color: EventPageStyle.scrim),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: media.padding.top + EventPageStyle.top,
                  bottom: 0,
                  child: Transform.translate(
                    offset: Offset(0, height * (1 - _rise.value) + drag),
                    child: sheet,
                  ),
                ),
              ],
            );
          },
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(EventPageStyle.radius),
            ),
            child: ColoredBox(
              color: EventPageStyle.dark,
              child: Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      EventPageStyle.gutter,
                      EventPageStyle.top,
                      EventPageStyle.gutter,
                      24 + media.padding.bottom,
                    ),
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
                      const SizedBox(height: 24),
                      Text(
                        'Политика конфиденциальности',
                        style: onest(28, weight: FontWeight.w700, height: 1.2),
                      ),
                      const SizedBox(height: 16),
                      for (final paragraph in _placeholder) ...[
                        Text(
                          paragraph,
                          style: onest(
                            17,
                            weight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    height: EventPageStyle.handleZone,
                    child: GestureDetector(
                      key: const ValueKey('policy-handle'),
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: _onDragUpdate,
                      onVerticalDragEnd: _onDragEnd,
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
