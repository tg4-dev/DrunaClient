import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/druna_app.dart';
import 'package:druna_app/core/api/api_client.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU');

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
