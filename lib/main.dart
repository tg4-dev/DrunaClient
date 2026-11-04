import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/calendar/band_paint.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:progressive_blur/progressive_blur.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Loaded before the first frame: until then the blurred widgets show
  // their child bare, and switching later would rebuild their subtrees.
  await ProgressiveBlurWidget.precache();
  // The event page's background and the month's bands, so neither starts
  // plain.
  await EventGradient.precache();
  await BandShader.precache();

  const config = AppConfig.fromEnvironment();
  final tokenStore = SecureTokenStore();
  final api = ApiClient(baseUrl: config.apiBaseUrl, tokenStore: tokenStore);
  final repository = DrunaRepository(api);

  runApp(
    DrunaApp(
      repository: repository,
      config: config,
      settingsStorage: PreferencesSettingsStorage(),
      deviceCalendar: platformDeviceCalendar(),
    ),
  );
}
