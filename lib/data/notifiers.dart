import 'package:flutter/material.dart';
import 'package:chargenet_mobile/data/models.dart';

/// Where the app sits in the authentication flow.
enum AuthState { unknown, signedOut, signedIn }

/// The tabs of the dashboard shell.
///
/// Shared so a screen can deep-link into one.
enum DashboardTab { home, activity, profile }

ValueNotifier<bool> isUserOnboardedNotifier = ValueNotifier(false);

/// The tab [DashboardNavigationScreen] is showing.
ValueNotifier<DashboardTab> dashboardTabNotifier = ValueNotifier(
  DashboardTab.home,
);

/// Stays 0.00 until `AppStateService.refreshAll()` runs after sign-in.
final walletCurrencyNotifier = ValueNotifier<String>('MYR');
final walletReservedNotifier = ValueNotifier<double>(0);
ValueNotifier<double> walletBalanceNotifier = ValueNotifier(0.0);
ValueNotifier<ChargingSession?> activeSessionNotifier = ValueNotifier(null);

/// Null while transport is healthy; retained readings must be labelled on loss.
final sessionConnectionNotifier = ValueNotifier<String?>(null);
ValueNotifier<List<Vehicle>> vehiclesNotifier = ValueNotifier([]);
ValueNotifier<List<Station>> stationsNotifier = ValueNotifier([]);

ValueNotifier<AuthState> authStateNotifier = ValueNotifier(AuthState.unknown);
ValueNotifier<AppUser?> currentUserNotifier = ValueNotifier(null);
ValueNotifier<List<ChargingSession>> sessionHistoryNotifier = ValueNotifier([]);
ValueNotifier<List<WalletTransaction>> transactionsNotifier = ValueNotifier([]);
ValueNotifier<List<CpoPartner>> cposNotifier = ValueNotifier([]);
