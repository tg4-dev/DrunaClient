import 'dart:math' as math;

import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The onboarding's background: the event page's gradient in black and
/// the brand colour, turning slowly, faster for a moment on every step
/// ([surge]). [dark] fades it all to black (the last screen).
class OnboardingBackground extends StatelessWidget {
  const OnboardingBackground({
    this.surge = 0,
    this.dark = false,
    this.accent = Brand.accent,
    super.key,
  });

  final int surge;
  final bool dark;

  /// The colour with the black: the brand's, from the profile step the
  /// user's own. A change flows in.
  final Color accent;

  /// The last screen: the gradient runs once more (the step's surge) for
  /// the first third, then goes dark.
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

/// ← and → under the field (screen 9). Back is white with a dark arrow.
/// Forward is white when the step is ready ([lit]) and translucent
/// otherwise, but still pressable: a press checks the field and says what
/// is wrong. While a request is out it spins.
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

/// The red line over the field; it fades in and, with the field under it,
/// shakes on every new error ([count]). The field stays the same widget,
/// so it keeps its focus and the keyboard.
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
    duration: const Duration(milliseconds: 420),
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
        // Three swings that die away.
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

/// The title of a step and the line under it.
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
