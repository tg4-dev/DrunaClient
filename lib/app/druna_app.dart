import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/app_theme.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/core/storage/token_store.dart';
import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/features/onboarding/welcome_page.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DrunaApp extends StatefulWidget {
  const DrunaApp({
    required this.repository,
    required this.tokenStore,
    required this.config,
    this.settingsStorage,
    this.authFlowSource,
    super.key,
  });
  final DrunaRepository repository;
  final TokenStore tokenStore;
  final AppConfig config;

  /// Defaults to memory, so tests start from clean settings.
  final SettingsStorage? settingsStorage;

  /// Replaces the onboarding's source (tests); otherwise the demo switch
  /// picks [DemoAuthFlowSource] or [ServerAuthFlowSource].
  final AuthFlowSource? authFlowSource;

  @override
  State<DrunaApp> createState() => _DrunaAppState();
}

class _DrunaAppState extends State<DrunaApp> {
  late final SessionController session;
  late final AppSettings settings;

  /// Without a server (`config/offline.json`): accounts on the device.
  OfflineAccounts? _offline;

  @override
  void initState() {
    super.initState();
    // Outside production demo friends are on until switched off in settings.
    settings = AppSettings(
      storage: widget.settingsStorage ?? MemorySettingsStorage(),
      demoByDefault: widget.config.demoData || !widget.config.isProduction,
      allowDemo: !widget.config.isProduction,
    )..load();
    if (widget.config.offline) _offline = OfflineAccounts(settings.storage);
    session = SessionController(widget.repository, offline: _offline)
      ..restore();
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
    theme: buildAppTheme(),
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
    // The onboarding dissolves into the app, and back on sign-out.
    home: AnimatedBuilder(
      animation: session,
      builder: (context, _) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        child: KeyedSubtree(
          key: ValueKey(session.state),
          child: switch (session.state) {
            SessionState.restoring => const _SplashScreen(),
            SessionState.signedOut => OnboardingFlow(
              source: _authFlowSource(),
              onFinished: session.adopt,
              onProfile: (slot, font) {
                settings
                  ..ownColorSlot = slot
                  ..ownFontId = font.id;
              },
            ),
            SessionState.signedIn => HomePager(
              session: session,
              settings: settings,
              config: widget.config,
            ),
          },
        ),
      ),
    ),
  );

  AuthFlowSource _authFlowSource() =>
      widget.authFlowSource ??
      switch (_offline) {
        final offline? => OfflineAuthFlowSource(offline),
        null => null,
      } ??
      (settings.demoFriends
          ? DemoAuthFlowSource(
              repository: widget.repository,
              storage: settings.storage,
            )
          : ServerAuthFlowSource(widget.repository));
}

/// The onboarding's background with the logo where the welcome screen
/// has it, so the welcome screen grows out of it.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const OnboardingBackground(),
        LayoutBuilder(
          builder: (context, constraints) => Stack(
            children: [
              Positioned(
                top:
                    constraints.maxHeight * logoCentre -
                    217 / Brand.logoAspect / 2,
                left: 0,
                right: 0,
                child: const Center(child: DrunaLogo()),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
