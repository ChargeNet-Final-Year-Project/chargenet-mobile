import 'dart:async';

import 'package:chargenet_mobile/services/session_coordinator.dart';
import 'package:chargenet_mobile/features/charging/widgets/charging_receipt_dialog.dart';
import 'package:chargenet_mobile/core/app_theme.dart';
import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/auth/login_screen.dart';
import 'package:chargenet_mobile/features/dashboard/dashboard_navigation_screen.dart';
import 'package:chargenet_mobile/features/onboarding/onboarding_screen.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  void _authChanged() {
    if (authStateNotifier.value != AuthState.signedOut) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void initState() {
    authStateNotifier.addListener(_authChanged);
    initIsUserOnboarded();
    // Resolves a previously stored session (token → `/auth/me`) so a warm start
    // can skip the login screen. Any failure leaves the gate on `signedOut`.
    AppStateService.instance.bootstrap();
    isUserOnboardedNotifier.addListener(_persistOnboarded);
    super.initState();
  }

  @override
  void dispose() {
    authStateNotifier.removeListener(_authChanged);
    isUserOnboardedNotifier.removeListener(_persistOnboarded);
    super.dispose();
  }

  void initIsUserOnboarded() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    isUserOnboardedNotifier.value =
        prefs.getBool(KConstants.isUserOnboarded) ?? false;
  }

  /// The onboarding flag only lived in the notifier, so it has to be written
  /// back or the app shows onboarding again after a restart.
  Future<void> _persistOnboarded() async {
    if (!isUserOnboardedNotifier.value) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KConstants.isUserOnboarded, true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'ChargeNet',
      themeMode: ThemeMode.light,
      theme: AppTheme.light,
      builder: (context, child) =>
          AnnotatedRegion(value: AppTheme.systemOverlayStyle, child: child!),

      home: ValueListenableBuilder<bool>(
        valueListenable: isUserOnboardedNotifier,
        builder: (context, isUserOnboarded, child) {
          if (!isUserOnboarded) return const OnboardingScreen();

          return ValueListenableBuilder<AuthState>(
            valueListenable: authStateNotifier,
            builder: (context, authState, child) {
              switch (authState) {
                case AuthState.unknown:
                  return const _SplashView();

                case AuthState.signedOut:
                  return const LoginScreen();

                case AuthState.signedIn:
                  return const _SignedInRoot();
              }
            },
          );
        },
      ),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.electric_bolt,
              size: 46,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 10),
            const Text(
              'ChargeNet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              height: 26,
              width: 26,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gate builds a fresh state object every time it enters `signedIn`, so
/// `refreshAll()` runs exactly once per sign-in — including after the next user
/// logs in on the same device.
class _SignedInRoot extends StatefulWidget {
  const _SignedInRoot();

  @override
  State<_SignedInRoot> createState() => _SignedInRootState();
}

class _SignedInRootState extends State<_SignedInRoot>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    activeSessionNotifier.addListener(_watchSession);
    SessionCoordinator.instance.addListener(_receiptReady);
    _watchSession();
    AppStateService.instance.refreshAll();
  }

  @override
  void dispose() {
    activeSessionNotifier.removeListener(_watchSession);
    SessionCoordinator.instance.removeListener(_receiptReady);
    SessionCoordinator.instance.reset();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A session can advance or end while the app is in the background, so the
  /// mini-bar re-reads it every time we come back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    SessionCoordinator.instance.retry();
    AppStateService.instance.refreshAfterResume();
  }

  void _watchSession() {
    final active = activeSessionNotifier.value;
    if (active != null) SessionCoordinator.instance.watch(active);
  }

  void _receiptReady() {
    if (!SessionCoordinator.instance.hasReceipt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || authStateNotifier.value != AuthState.signedIn) return;
      final receipt = SessionCoordinator.instance.takeReceipt();
      if (receipt == null) return;
      dashboardTabNotifier.value = DashboardTab.activity;
      unawaited(showChargingReceipt(context, receipt));
    });
  }

  @override
  Widget build(BuildContext context) => const DashboardNavigationScreen();
}
