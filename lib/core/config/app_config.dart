import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.demoData = false,
    bool offline = false,
  }) : _offline = offline;

  const AppConfig.fromEnvironment()
    : apiBaseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:22000',
      ),
      environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      demoData = const bool.fromEnvironment('DEMO_DATA'),
      _offline = const bool.fromEnvironment('OFFLINE');

  final String apiBaseUrl;
  final String environment;

  /// Screens of the new UI that already have demo data use it instead of the
  /// server. Never set in production.
  final bool demoData;

  final bool _offline;

  /// No server at all (`OFFLINE=true`, `config/offline.json`): accounts and
  /// the session live on the device, everything else on demo data. Never in
  /// production.
  bool get offline => _offline && !isProduction;

  bool get isProduction => environment == 'production';
}
