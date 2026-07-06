import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _activeModeKey = 'active_mode';
  static const _deviceIdKey = 'device_id';

  // Access token
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  static Future<String?> getAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  // Refresh token
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return _storage.read(key: _refreshTokenKey);
  }

  // User ID
  static Future<void> saveUserId(String id) async {
    await _storage.write(key: _userIdKey, value: id);
  }

  static Future<String?> getUserId() async {
    return _storage.read(key: _userIdKey);
  }

  // Active mode
  static Future<void> saveActiveMode(String mode) async {
    await _storage.write(key: _activeModeKey, value: mode);
  }

  static Future<String?> getActiveMode() async {
    return _storage.read(key: _activeModeKey);
  }

  /// Stable, random install identifier sent as X-Device-Id. Generated once
  /// (CSPRNG) and hashed server-side; used for account-farming detection.
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final rng = Random.secure();
    final id = List.generate(
      32,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  // Clear all on logout — but keep the device identifier: it identifies the
  // INSTALL, not the user, and losing it on every logout would blind the
  // multi-account (farming) detection on the server.
  static Future<void> clearAll() async {
    final deviceId = await _storage.read(key: _deviceIdKey);
    await _storage.deleteAll();
    if (deviceId != null) {
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // First time launch
  static Future<bool> isFirstTime() async {
    final val = await _storage.read(key: 'is_first_time');
    if (val == null) {
      // First time — mark it
      await _storage.write(key: 'is_first_time', value: 'done');
      return true;
    }
    return false;
  }
}
