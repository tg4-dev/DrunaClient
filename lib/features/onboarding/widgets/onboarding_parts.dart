import 'package:druna_app/shared/ui/motion.dart';
import 'dart:math' as math;

import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({
    this.surge = 0,
    this.dark = false,
    this.accent = Brand.accent,
    super.key,
  });

  final int surge;
  final bool dark;

  final Color accent;

  static const darken = Duration(milliseconds: 3000);

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      EventGradient(
        colors: [OnboardingStyle.black, accent],
        dark: OnboardingStyle.black,
        surge: surge,
      ),
      IgnorePointer(
        child: AnimatedOpacity(
          opacity: dark ? 1 : 0,
          duration: darken,
          curve: const Interval(0.3, 1, curve: Curves.easeInOut),
          child: const ColoredBox(color: OnboardingStyle.black),
        ),
      ),
    ],
  );
}

class StepArrows extends StatelessWidget {
  const StepArrows({
    required this.onBack,
    required this.onForward,
    required this.lit,
    required this.busy,
    super.key,
  });

  final VoidCallback? onBack;
  final VoidCallback onForward;
  final bool lit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final white = lit || busy;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PillButton(
          key: const ValueKey('onboarding-back'),
          label: 'Назад',
          width: OnboardingStyle.arrowWidth,
          height: OnboardingStyle.height,
          fill: Colors.white,
          onPressed: onBack,
          child: const ArrowIcon(color: OnboardingStyle.ink, back: true),
        ),
        const SizedBox(width: OnboardingStyle.arrowGap),
        PillButton(
          key: const ValueKey('onboarding-next'),
          label: 'Дальше',
          width: OnboardingStyle.arrowWidth,
          height: OnboardingStyle.height,
          fill: white ? Colors.white : PillStyle.fill,
          onPressed: busy ? null : onForward,
          child: AnimatedSwitcher(
            duration: OnboardingStyle.fade,
            child: busy
                ? const CupertinoActivityIndicator(
                    key: ValueKey('busy'),
                    color: OnboardingStyle.ink,
                  )
                : ArrowIcon(
                    key: ValueKey(white),
                    color: white
                        ? OnboardingStyle.ink
                        : Colors.white.withValues(alpha: 0.7),
                  ),
          ),
        ),
      ],
    );
  }
}

class ErrorShake extends StatefulWidget {
  const ErrorShake({
    required this.error,
    required this.count,
    required this.child,
    super.key,
  });

  final String? error;
  final int count;
  final Widget child;

  @override
  State<ErrorShake> createState() => _ErrorShakeState();
}

class _ErrorShakeState extends State<ErrorShake>
    with SingleTickerProviderStateMixin {
  late final _shake = AnimationController(
    vsync: this,
    duration: Motion.long,
    value: 1,
  );

  @override
  void didUpdateWidget(covariant ErrorShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.count != oldWidget.count && widget.error != null && !reduce) {
      _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _shake,
    builder: (context, child) {
      final t = _shake.value;
      return Transform.translate(
        offset: Offset(8 * math.sin(t * 3 * 2 * math.pi) * (1 - t), 0),
        child: child,
      );
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: OnboardingStyle.errorSlot,
          child: Center(
            child: AnimatedSwitcher(
              duration: OnboardingStyle.fade,
              child: widget.error == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      liveRegion: true,
                      child: Text(
                        widget.error!,
                        key: ValueKey(widget.error),
                        textAlign: TextAlign.center,
                        style: OnboardingStyle.error,
                      ),
                    ),
            ),
          ),
        ),
        widget.child,
      ],
    ),
  );
}

class StepTitle extends StatelessWidget {
  const StepTitle({required this.title, this.subtitle, super.key});

  final String title;
  final Widget? subtitle;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        title,
        textAlign: TextAlign.center,
        style: OnboardingStyle.title,
        maxLines: 2,
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 4),
        DefaultTextStyle(
          style: OnboardingStyle.subtitle,
          textAlign: TextAlign.center,
          child: subtitle!,
        ),
      ],
    ],
  );
}
