import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/event_page/event_gradient.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:progressive_blur/progressive_blur.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');
  // Loaded before the first frame: until then the blurred widgets show
  // their child bare, and switching later would rebuild their subtrees.
  await ProgressiveBlurWidget.precache();
  // The event page's background shader, so it never starts plain.
  await EventGradient.precache();

  const config = AppConfig.fromEnvironment();
  final tokenStore = SecureTokenStore();
  final api = ApiClient(baseUrl: config.apiBaseUrl, tokenStore: tokenStore);
  final repository = DrunaRepository(api);

  runApp(
    DrunaApp(
      repository: repository,
      tokenStore: tokenStore,
      config: config,
      settingsStorage: PreferencesSettingsStorage(),
    ),
  );
}
