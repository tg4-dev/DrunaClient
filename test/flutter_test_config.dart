import 'dart:async';

import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/features/event_page/fit_title.dart';
import 'package:druna_app/shared/ui/edge_blur.dart';

/// Runs before every test file: see [EdgeBlur.enabled] and
/// [EventGradient.enabled] and [FitTitle.blink].
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  EdgeBlur.enabled = false;
  EventGradient.enabled = false;
  FitTitle.blink = false;
  await testMain();
}
