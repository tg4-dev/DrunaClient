import 'package:druna_app/features/onboarding/onboarding_controller.dart';
import 'package:druna_app/features/onboarding/onboarding_steps.dart';
import 'package:druna_app/features/onboarding/onboarding_style.dart';
import 'package:druna_app/shared/ui/person_name.dart';
import 'package:flutter/material.dart';

class DonePage extends StatefulWidget {
  const DonePage({required this.controller, super.key});

  final OnboardingController controller;

  @override
  State<DonePage> createState() => _DonePageState();
}

class _DonePageState extends State<DonePage>
    with SingleTickerProviderStateMixin {
  late final _play = AnimationController(
    vsync: this,
    duration: OnboardingController.doneHold,
  );

  @override
  void initState() {
    super.initState();
    _play.forward();
  }

  @override
  void dispose() {
    _play.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = OnboardingController.doneHold.inMilliseconds;
    final glide = ProfileAvatar.glide.inMilliseconds;
    final appear = CurvedAnimation(
      parent: _play,
      curve: Interval(
        glide / total,
        (glide + 600) / total,
        curve: Curves.easeOutCubic,
      ),
    );
    final leave = CurvedAnimation(
      parent: _play,
      curve: Interval(1 - 450 / total, 1, curve: Curves.easeIn),
    );
    final name = widget.controller.name.text;
    return LayoutBuilder(
      builder: (context, box) {
        final top =
            ProfileAvatar.doneCentre(box.biggest) + ProfileAvatar.done / 2 + 28;
        return Stack(
          children: [
            Positioned(
              top: top,
              left: 24,
              right: 24,
              child: AnimatedBuilder(
                animation: _play,
                builder: (context, child) => Opacity(
                  opacity: (appear.value * (1 - leave.value)).clamp(0, 1),
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - appear.value)),
                    child: child,
                  ),
                ),
                child: Column(
                  children: [
                    NameText(
                      parts: [
                        if (name.trim().isNotEmpty) ...[
                          shownName(name),
                          ', всё готово',
                        ] else
                          'Всё готово',
                      ],
                      names: name.trim().isEmpty ? const {} : const {0},
                      style: OnboardingStyle.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'пора найти время',
                      textAlign: TextAlign.center,
                      style: OnboardingStyle.subtitle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
