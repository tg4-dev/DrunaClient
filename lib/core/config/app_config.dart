import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.environment,
    this.demoData = false,
  });

  const AppConfig.fromEnvironment()
    : apiBaseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:22000',
      ),
      environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      ),
      demoData = const bool.fromEnvironment('DEMO_DATA');

  final String apiBaseUrl;
  final String environment;

  /// Screens of the new UI that already have demo data use it instead of the
  /// server. Never set in production.
  final bool demoData;

  bool get isProduction => environment == 'production';
}
