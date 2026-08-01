import 'package:chargenet_mobile/data/constants.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores the bearer token in the platform keystore.
///
/// Keystore failures return an empty result so the app can request a new login.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static Future<T?> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (_) {
      return null;
    }
  }

  Future<String?> read() =>
      _guard<String?>(() => _storage.read(key: KConstants.authTokenKey));

  Future<void> write(String token) async {
    await _guard(
      () => _storage.write(key: KConstants.authTokenKey, value: token),
    );
  }

  Future<void> delete() async {
    await _guard(() => _storage.delete(key: KConstants.authTokenKey));
  }

  Future<bool> hasToken() async =>
      await _guard(() => _storage.containsKey(key: KConstants.authTokenKey)) ??
      false;
}
