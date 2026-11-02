import 'dart:async';

import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/done_page.dart';
import 'package:druna_app/features/onboarding/onboarding_controller.dart';
import 'package:druna_app/features/onboarding/onboarding_steps.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/features/onboarding/welcome_page.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/shared/ui/avatar_style.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The onboarding from the settings, played without the server
/// ([RehearsalAuthFlowSource]): no account is made, and the end — or ✕ on
/// the welcome screen — brings the user back where they were. [signIn]:
/// every email has an account, so the flow goes to the password.
/// [colorSlot] and [font] — the user's own, for «Всё готово» after it.
Future<void> showOnboardingRehearsal(
  BuildContext context, {
  bool signIn = false,
  int? colorSlot,
  AvatarFont? font,
}) {
  final navigator = Navigator.of(context);
  return navigator.push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 600),
      reverseTransitionDuration: const Duration(milliseconds: 600),
      pageBuilder: (context, _, _) => OnboardingFlow(
        source: RehearsalAuthFlowSource(signInOnly: signIn),
        onFinished: () async => navigator.pop(),
        onClose: navigator.pop,
        knownColorSlot: colorSlot,
        knownFont: font,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// Sign-in and registration (design-system §9.9): one screen over the
/// moving background, its steps sliding in and out. The arrows stay put
/// under the field; system back, the Android back button and a swipe from
/// the left edge go a step back.
class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    required this.source,
    required this.onFinished,
    this.onClose,
    this.onProfile,
    this.knownColorSlot,
    this.knownFont,
    super.key,
  });

  final AuthFlowSource source;

  /// Tokens are saved: let the app in ([SessionController.adopt]).
  final Future<void> Function() onFinished;

  /// The rehearsal from the settings: ✕ on the welcome screen, and back
  /// from it leaves.
  final VoidCallback? onClose;

  /// The account is made: keep the picked colour and font.
  final void Function(int colorSlot, AvatarFont font)? onProfile;

  /// This device's colour and font for its user, shown after a sign-in.
  final int? knownColorSlot;
  final AvatarFont? knownFont;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with WidgetsBindingObserver {
  late final _flow = OnboardingController(
    source: widget.source,
    onFinished: widget.onFinished,
    onProfile: widget.onProfile,
    knownColorSlot: widget.knownColorSlot,
    knownFont: widget.knownFont,
  );
  var _step = OnboardingStep.welcome;
  Timer? _keyboardCheck;

  @override
  void initState() {
    super.initState();
    _flow.addListener(_stepChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  /// A new step takes the keyboard into its field once it is built; the
  /// old field hands it over, so the keyboard stays up. Welcome and the end
  /// have no field: there it goes down.
  void _stepChanged() {
    if (_flow.step == _step) return;
    _step = _flow.step;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final focus = _flow.focus;
      if (focus == null) {
        FocusManager.instance.primaryFocus?.unfocus();
      } else {
        focus.requestFocus();
      }
    });
  }

  /// The keyboard cannot be put away on a step with a field: if it went
  /// down (Android's back, a system sheet closed), it comes back.
  @override
  void didChangeMetrics() {
    _keyboardCheck?.cancel();
    _keyboardCheck = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final focus = _flow.focus;
      if (focus == null) return;
      // The user may be in another field of the step (the repeat of the
      // password): leave the focus there.
      if (!_flow.stepFocus.any((node) => node.hasFocus)) {
        return focus.requestFocus();
      }
      final view = View.of(context);
      if (view.viewInsets.bottom == 0) {
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      }
    });
  }

  /// How far a swipe from the left edge has gone.
  var _edgeDrag = 0.0;

  static const _edge = 20.0;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardCheck?.cancel();
    _flow.removeListener(_stepChanged);
    _flow.dispose();
    super.dispose();
  }

  bool _hasField(OnboardingStep step) =>
      step != OnboardingStep.welcome && step != OnboardingStep.done;

  Widget _page(OnboardingStep step) => switch (step) {
    OnboardingStep.welcome => WelcomePage(onEmail: _flow.start),
    OnboardingStep.done => DonePage(controller: _flow),
    _ => FormStepPage(controller: _flow, step: step),
  };

  /// In from the side the user moves to, out to the other. The old page is
  /// gone by the middle and the new one comes in after it starts to leave,
  /// so the two never blur into each other; the slide is short and eased
  /// both ways.
  Widget _transition(Widget child, Animation<double> animation) =>
      AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final leaving = animation.status == AnimationStatus.reverse;
          final dir = _flow.back ? -1 : 1;
          final v = animation.value;
          // Leaving runs 1 → 0: it fades over the first 55% of the time.
          final opacity = leaving
              ? const Interval(0.45, 1, curve: Curves.easeIn).transform(v)
              : const Interval(0.3, 1, curve: Curves.easeOut).transform(v);
          final rest = 1 - Curves.easeInOutCubic.transform(v);
          final dx = (leaving ? -dir : dir) * OnboardingStyle.slide * rest;
          return Opacity(
            opacity: opacity,
            child: Transform.translate(offset: Offset(dx, 0), child: child),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ListenableBuilder(
      listenable: _flow,
      builder: (context, _) {
        final step = _flow.step;
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            final close = widget.onClose;
            if (step == OnboardingStep.welcome && close != null) {
              close();
            } else {
              _flow.goBack();
            }
          },
          child: Scaffold(
            backgroundColor: OnboardingStyle.black,
            resizeToAvoidBottomInset: false,
            // One autofill context for the whole flow. A group per step
            // would end its context on every step change, and iOS drops
            // the keyboard when that happens; the password is committed
            // for saving by the controller instead.
            body: AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  OnboardingBackground(
                    surge: _flow.moves + _flow.colorTurns,
                    accent: _flow.backgroundColor,
                    dark: step == OnboardingStep.done,
                  ),
                  AnimatedSwitcher(
                    duration: reduce ? Duration.zero : OnboardingStyle.move,
                    switchInCurve: Curves.linear,
                    switchOutCurve: Curves.linear,
                    transitionBuilder: _transition,
                    layoutBuilder: (current, previous) => Stack(
                      fit: StackFit.expand,
                      children: [...previous, ?current],
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(step),
                      child: _page(step),
                    ),
                  ),
                  _arrows(step, reduce),
                  LayoutBuilder(
                    builder: (context, box) => Stack(
                      children: [
                        ProfileAvatar(controller: _flow, size: box.biggest),
                      ],
                    ),
                  ),
                  if (widget.onClose != null && step == OnboardingStep.welcome)
                    Positioned(
                      top: MediaQuery.paddingOf(context).top + 8,
                      right: 16,
                      child: PillButton(
                        key: const ValueKey('onboarding-close'),
                        icon: CupertinoIcons.xmark,
                        label: 'Закрыть',
                        onPressed: widget.onClose,
                      ),
                    ),
                  if (_flow.canGoBack)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _edge,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragStart: (_) => _edgeDrag = 0,
                        onHorizontalDragUpdate: (details) =>
                            _edgeDrag += details.delta.dx,
                        onHorizontalDragEnd: (details) {
                          final fling = (details.primaryVelocity ?? 0) > 400;
                          if (fling || _edgeDrag > 80) _flow.goBack();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The arrows follow the field. A new step glides them to its place;
  /// the keyboard, meanwhile and at any other time, moves that place and
  /// they keep up at once ([_FollowTop]).
  Widget _arrows(OnboardingStep step, bool reduce) {
    final shown = _hasField(step);
    return LayoutBuilder(
      builder: (context, constraints) {
        final at = StepGeometry.of(
          context,
          constraints.biggest,
          fieldHeight: fieldHeightOf(step),
          tall: step == OnboardingStep.profile,
        );
        return _FollowTop(
          step: step,
          target: at.navTop,
          duration: reduce ? Duration.zero : ProfileAvatar.glide,
          child: IgnorePointer(
            ignoring: !shown,
            child: AnimatedOpacity(
              opacity: shown ? 1 : 0,
              duration: reduce ? Duration.zero : OnboardingStyle.move,
              child: StepArrows(
                lit: _flow.canSubmit,
                busy: _flow.busy,
                onBack: _flow.canGoBack ? _flow.goBack : null,
                onForward: _flow.submit,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// [child] at [target] from the top. When [step] changes it glides there
/// from where it stood; while gliding, and always otherwise, a moving
/// [target] (the keyboard) is followed at once — the glide is towards the
/// live target, not a stale one.
class _FollowTop extends StatefulWidget {
  const _FollowTop({
    required this.step,
    required this.target,
    required this.duration,
    required this.child,
  });

  final Object step;
  final double target;
  final Duration duration;
  final Widget child;

  @override
  State<_FollowTop> createState() => _FollowTopState();
}

class _FollowTopState extends State<_FollowTop>
    with SingleTickerProviderStateMixin {
  late final _glide = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late double _from = widget.target;
  late double _shown = widget.target;

  @override
  void didUpdateWidget(covariant _FollowTop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _glide.duration = widget.duration;
    if (widget.step != oldWidget.step) {
      _from = _shown;
      _glide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _glide,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeInOutCubic.transform(_glide.value);
      _shown = _from + (widget.target - _from) * t;
      return Stack(
        children: [
          Positioned(
            top: _shown,
            left: 0,
            right: 0,
            child: Center(child: child),
          ),
        ],
      );
    },
  );
}
