import 'dart:async';

import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/features/friends/friend_bar.dart';
import 'package:druna_app/features/groups/orbit.dart';
import 'package:druna_app/features/onboarding/widgets/code_boxes.dart';
import 'package:druna_app/features/profile/event_chip.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  EdgeBlur.enabled = false;
  EventGradient.enabled = false;
  Orbit.enabled = false;
  BandShader.enabled = false;
  CodeBoxes.blink = false;
  FitTitle.blink = false;
  EventChip.glows = false;
  FriendBar.arrowDrifts = false;
  await testMain();
}
