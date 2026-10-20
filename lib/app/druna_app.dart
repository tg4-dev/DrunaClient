import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/features/auth/auth_screen.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DrunaApp extends StatefulWidget {
  const DrunaApp({
    required this.repository,
    required this.tokenStore,
    required this.config,
    this.settingsStorage,
    super.key,
  });
  final DrunaRepository repository;
  final TokenStore tokenStore;
  final AppConfig config;

  /// Defaults to memory, so tests start from clean settings.
  final SettingsStorage? settingsStorage;

  @override
  State<DrunaApp> createState() => _DrunaAppState();
}

class _DrunaAppState extends State<DrunaApp> {
  late final SessionController session;
  late final AppSettings settings;

  @override
  void initState() {
    super.initState();
    session = SessionController(widget.repository)..restore();
    // Outside production demo friends are on until switched off in settings.
    settings = AppSettings(
      storage: widget.settingsStorage ?? MemorySettingsStorage(),
      demoByDefault: widget.config.demoData || !widget.config.isProduction,
      allowDemo: !widget.config.isProduction,
    )..load();
  }

  @override
  void dispose() {
    session.dispose();
    settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Druna',
    debugShowCheckedModeBanner: false,
    theme: buildDrunaTheme(),
    locale: const Locale('ru'),
    supportedLocales: const [Locale('ru')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: .9, maxScaleFactor: 1.35),
      ),
      child: child!,
    ),
    home: AnimatedBuilder(
      animation: session,
      builder: (context, _) => switch (session.state) {
        SessionState.restoring => const _SplashScreen(),
        SessionState.signedOut => AuthScreen(session: session),
        SessionState.signedIn => HomePager(
          session: session,
          settings: settings,
          config: widget.config,
        ),
      },
    ),
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => const GradientScaffold(
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BrandMark(size: 72),
          SizedBox(height: 28),
          CircularProgressIndicator(strokeWidth: 2),
        ],
      ),
    ),
  );
}
