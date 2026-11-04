import 'package:druna_app/app/app_settings.dart';
import 'package:druna_app/app/app_theme.dart';
import 'package:druna_app/app/home_pager.dart';
import 'package:druna_app/app/offline_accounts.dart';
import 'package:druna_app/app/session_controller.dart';
import 'package:druna_app/core/config/app_config.dart';
import 'package:druna_app/features/calendar_sync/calendar_sync.dart';
import 'package:druna_app/features/calendar_sync/device_calendar.dart';
import 'package:druna_app/features/onboarding/auth_flow_source.dart';
import 'package:druna_app/features/onboarding/onboarding_flow.dart';
import 'package:druna_app/features/onboarding/welcome_page.dart';
import 'package:druna_app/features/onboarding/widgets/onboarding_parts.dart';
import 'package:druna_app/repositories/druna_repository.dart';
import 'package:druna_app/shared/ui/brand.dart';
import 'package:druna_app/shared/ui/top_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class DrunaApp extends StatefulWidget {
  const DrunaApp({
    required this.repository,
    required this.config,
    this.settingsStorage,
    this.authFlowSource,
    this.deviceCalendar,
    super.key,
  });
  final DrunaRepository repository;
  final AppConfig config;

  final SettingsStorage? settingsStorage;

  final AuthFlowSource? authFlowSource;

  final DeviceCalendar? deviceCalendar;

  @override
  State<DrunaApp> createState() => _DrunaAppState();
}

class _DrunaAppState extends State<DrunaApp> {
  late final SessionController session;
  late final AppSettings settings;
  late final CalendarSync calendarSync;

  late final OfflineAccounts _accounts;
  late bool _demo;

  @override
  void initState() {
    super.initState();
    settings = AppSettings(
      storage: widget.settingsStorage ?? MemorySettingsStorage(),
      demoByDefault: widget.config.demoData,
    );
    _demo = settings.demo;
    _accounts = OfflineAccounts(settings.storage);
    calendarSync = CalendarSync(
      device: widget.deviceCalendar ?? const NoDeviceCalendar(),
      storage: settings.storage,
    )..load();
    session = SessionController(widget.repository);
    _start();
  }

  Future<void> _start() async {
    await settings.load();
    if (!mounted) return;
    _demo = settings.demo;
    calendarSync.exportEnabled = !_demo;
    session.offline = _demo ? _accounts : null;
    settings.addListener(_onSettings);
    await session.restore();
  }

  void _onSettings() {
    if (settings.demo == _demo) return;
    _demo = settings.demo;
    calendarSync.exportEnabled = !_demo;
    session.switchTo(_demo ? _accounts : null);
  }

  @override
  void dispose() {
    settings.removeListener(_onSettings);
    session.dispose();
    calendarSync.dispose();
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
    home: AnimatedBuilder(
      animation: session,
      builder: (context, _) {
        if (session.state == SessionState.signedOut &&
            session.takeExpiredSignOut()) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              showToast(context, 'Сессия истекла, войди снова', error: true);
            }
          });
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: KeyedSubtree(
            key: ValueKey(session.state),
            child: switch (session.state) {
              SessionState.restoring => const _SplashScreen(),
              SessionState.signedOut => OnboardingFlow(
                source: _authFlowSource(),
                onFinished: session.adopt,
                knownColorSlot: settings.ownColorSlot,
                knownFont: ownFontFor(settings),
                calendarSync: calendarSync,
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
                sync: calendarSync,
              ),
            },
          ),
        );
      },
    ),
  );

  AuthFlowSource _authFlowSource() =>
      widget.authFlowSource ??
      (settings.demo
          ? OfflineAuthFlowSource(_accounts)
          : ServerAuthFlowSource(widget.repository));
}

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
