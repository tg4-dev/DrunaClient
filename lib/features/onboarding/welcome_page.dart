import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/features/onboarding/widgets/policy_sheet.dart';
import 'package:druna_app/features/onboarding/widgets/social_button.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/pill_button.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

const logoCentre = 0.29;

class WelcomePage extends StatefulWidget {
  const WelcomePage({required this.onEmail, super.key});

  final VoidCallback onEmail;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      reduce ? _enter.value = 1 : _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  Widget _rise(double begin, double end, Widget child) {
    final t = CurvedAnimation(
      parent: _enter,
      curve: Interval(begin, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: t,
      child: AnimatedBuilder(
        animation: t,
        child: child,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 16 * (1 - t.value)),
          child: child,
        ),
      ),
    );
  }

  void _soon(String provider) {
    showToast(context, 'Вход через $provider скоро появится');
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxHeight;
        final logoHeight = 217 / Brand.logoAspect;
        return Stack(
          children: [
            Positioned(
              top: height * logoCentre - logoHeight / 2,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const DrunaLogo(),
                  const SizedBox(height: 22),
                  _rise(
                    0,
                    0.45,
                    Text('Найдем время', style: OnboardingStyle.tagline),
                  ),
                ],
              ),
            ),
            Positioned(
              top: height * 0.557,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  _rise(
                    0.15,
                    0.6,
                    SocialButton(
                      provider: SocialProvider.apple,
                      onPressed: () => _soon('Apple'),
                    ),
                  ),
                  const SizedBox(height: OnboardingStyle.buttonGap),
                  _rise(
                    0.22,
                    0.67,
                    SocialButton(
                      provider: SocialProvider.google,
                      onPressed: () => _soon('Google'),
                    ),
                  ),
                  const SizedBox(height: OnboardingStyle.buttonGap),
                  _rise(
                    0.29,
                    0.74,
                    PillButton(
                      key: const ValueKey('email-sign-in'),
                      text: 'Вход по нику',
                      width: OnboardingStyle.fieldWidth,
                      height: OnboardingStyle.height,
                      textStyle: OnboardingStyle.social,
                      onPressed: widget.onEmail,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: padding.bottom + 24,
              child: _rise(0.45, 0.9, const _Policy()),
            ),
          ],
        );
      },
    );
  }
}

class _Policy extends StatefulWidget {
  const _Policy();

  @override
  State<_Policy> createState() => _PolicyState();
}

class _PolicyState extends State<_Policy> {
  late final _tap = TapGestureRecognizer()
    ..onTap = () => showPolicySheet(context);

  @override
  void dispose() {
    _tap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      text: 'регистрируясь в Druna, вы\nсоглашаетесь с нашей ',
      children: [
        TextSpan(
          text: 'политикой',
          recognizer: _tap,
          style: OnboardingStyle.footnote.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: OnboardingStyle.footnote.color,
          ),
        ),
      ],
    ),
    textAlign: TextAlign.center,
    style: OnboardingStyle.footnote,
  );
}
