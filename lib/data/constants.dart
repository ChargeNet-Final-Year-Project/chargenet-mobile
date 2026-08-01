import 'package:flutter/foundation.dart';

class KConstants {
  static const String isUserOnboarded = 'isUserOnboarded';

  static const double defaultMapZoom = 14.5;
  static const double mapMinZoom = 3;
  static const double mapMaxZoom = 19;

  static const String osmTileUrl = String.fromEnvironment(
    'MAP_TILE_URL',
    defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
  );

  static const double circularBorderRadius = 15;

  // API

  /// Build-time override for real devices:
  /// `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080`.
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Host serving the backend, chosen for the current platform.
  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    if (kIsWeb) return 'http://localhost:8080';
    // The Android emulator reaches the host machine through 10.0.2.2; the iOS
    // simulator and desktop builds share the host's localhost.
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static const String apiPrefix = '/api/v1';

  static const Duration requestTimeout = Duration(seconds: 15);

  /// Minimum wallet balance (RM) needed to start a session.
  static const double minStartBalance = 10.0;

  /// Secure-storage key holding the bearer token.
  static const String authTokenKey = 'authToken';

  // Wallet 

  /// Top-up bounds enforced by the simulated gateway.
  static const double minTopUpAmount = 5.0;
  static const double maxTopUpAmount = 2000.0;

  /// Simulated payment gateways, in the order the sheet offers them.
  /// These strings are sent verbatim as `paymentMethod`, so they must match
  /// `store.PaymentMethods` on the backend.
  static const String paymentMaybankFpx = 'Maybank FPX';
  static const String paymentTouchNGo = "Touch 'n Go eWallet";
  static const String paymentCreditCard = 'Credit Card';

  static const List<String> paymentMethods = [
    paymentMaybankFpx,
    paymentTouchNGo,
    paymentCreditCard,
  ];

  /// SharedPreferences key remembering whether the balance is visible.
  static const String walletBalanceVisible = 'walletBalanceVisible';

  // Vehicles 

  /// Accepted battery capacity range, in kWh.
  static const double minVehicleBatteryKwh = 10.0;
  static const double maxVehicleBatteryKwh = 250.0;

  // Charger activation 

  /// Target state of charge offered by the activation slider.
  static const double minTargetSoc = 50.0;
  static const double maxTargetSoc = 100.0;
  static const double defaultTargetSoc = 80.0;

  /// 5 %-per-notch slider between [minTargetSoc] and [maxTargetSoc].
  static const int targetSocDivisions = 10;

  /// State of charge assumed for the pre-charge estimate. The server picks a
  /// random 15–35 % on start, which the app cannot know yet.
  static const double assumedStartSoc = 20.0;

  /// Efficiency factor used to turn a connector's rated power into a realistic
  /// average *battery / (0.8 * kW)`).
  static const double chargingEfficiency = 0.8;

  /// Deep link carried by a ChargeNet EVSE QR code: `chargenet://evse/<uid>`.
  static const String evseCodeScheme = 'chargenet';
  static const String evseCodeHost = 'evse';

  /// EVSE shipped with the demo seed. Offered while debugging on a desktop or
  /// simulator build, where the camera scanner cannot run.
  static const String sampleEvseUid = 'VLT-SGB-01';

  // Brand Colors
  static const String cpoColorVoltGo = '#0D9488';
  static const String cpoColorChargeSync = '#2563EB';
  static const String cpoColorEcoWatt = '#16A34A';
}
