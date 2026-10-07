import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/core/theme/druna_theme.dart';
import 'package:druna_app/features/auth/auth_screen.dart';
import 'package:druna_app/features/calendar/calendar_screen.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/druna_widgets.dart';
import 'package:flutter/material.dart';

class DrunaApp extends StatefulWidget {
  const DrunaApp({
    required this.repository,
    required this.tokenStore,
    required this.config,
    super.key,
  });
  final DrunaRepository repository;
  final TokenStore tokenStore;
  final AppConfig config;

  @override
  State<DrunaApp> createState() => _DrunaAppState();
}

class _DrunaAppState extends State<DrunaApp> {
  late final SessionController session;

  @override
  void initState() {
    super.initState();
    session = SessionController(widget.repository)..restore();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Druna',
    debugShowCheckedModeBanner: false,
    theme: buildDrunaTheme(),
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
        SessionState.signedIn => const CalendarScreen(),
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
