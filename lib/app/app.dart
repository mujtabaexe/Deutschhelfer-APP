import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../l10n/app_localizations.dart';
import '../ui/core/theme/app_theme.dart';
import 'app_services.dart';
import 'router.dart';
import 'routes.dart';
import 'session_controller.dart';

class DeutschhelferApp extends StatefulWidget {
  const DeutschhelferApp({
    super.key,
    required this.config,
    required this.services,
  });

  final AppConfig config;
  final AppServices services;

  @override
  State<DeutschhelferApp> createState() => _DeutschhelferAppState();
}

class _DeutschhelferAppState extends State<DeutschhelferApp> {
  late final SessionController _session = SessionController(
    authRepository: widget.services.authRepository,
    profileRepository: widget.services.profileRepository,
    pushRepository: widget.services.pushRepository,
  )..start();

  late final GoRouter _router = createRouter(
    services: widget.services,
    session: _session,
    config: widget.config,
  );

  StreamSubscription<Map<String, String>>? _pushTaps;

  /// A notification tap that arrived before the session was known, such as
  /// the one that launched the app.
  String? _pendingPushRoute;

  @override
  void initState() {
    super.initState();
    _session.addListener(_openPendingPushRoute);
    _pushTaps = widget.services.pushRepository.openedMessages.listen(
      _onPushTap,
      onError: (Object _) {},
    );
  }

  void _onPushTap(Map<String, String> data) {
    final route = routeForPush(data);
    if (route == null) return;
    if (_session.status == SessionStatus.initializing) {
      _pendingPushRoute = route;
      return;
    }
    // Route guards still apply: a signed-out user lands on the welcome page.
    _router.go(route);
  }

  void _openPendingPushRoute() {
    final route = _pendingPushRoute;
    if (route == null || _session.status == SessionStatus.initializing) return;
    _pendingPushRoute = null;
    // Only for the session the app opened into; otherwise it is dropped.
    if (_session.status == SessionStatus.active) _router.go(route);
  }

  @override
  void dispose() {
    _session.removeListener(_openPendingPushRoute);
    unawaited(_pushTaps?.cancel());
    _router.dispose();
    _session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: !widget.config.isProduction,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: _router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

/// Shown when startup fails, for example when Firebase cannot initialize.
/// Deliberately avoids localization and routing, which may be what failed.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Deutschhelfer could not start. Check your connection and try again.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
