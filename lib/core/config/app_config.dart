import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({required this.apiBaseUrl, required this.environment});

  const AppConfig.fromEnvironment()
    : apiBaseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://localhost:22000',
      ),
      environment = const String.fromEnvironment(
        'APP_ENV',
        defaultValue: 'development',
      );

  final String apiBaseUrl;
  final String environment;

  bool get isProduction => environment == 'production';
}
