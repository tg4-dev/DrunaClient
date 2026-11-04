import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({required this.apiBaseUrl, this.demoData = false});

  const AppConfig.fromEnvironment()
    : apiBaseUrl = const String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'https://druna.tg4.dev',
      ),
      demoData = const bool.fromEnvironment('DEMO_DATA');

  final String apiBaseUrl;

  final bool demoData;
}
