import 'dart:async';

import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/onboarding/widgets/code_boxes.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  EdgeBlur.enabled = false;
  EventGradient.enabled = false;
  BandShader.enabled = false;
  CodeBoxes.blink = false;
  FitTitle.blink = false;
  await testMain();
}
