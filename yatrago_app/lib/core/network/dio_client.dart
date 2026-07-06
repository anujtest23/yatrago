import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../constants/api_constants.dart';
import '../services/device_integrity.dart';
import '../storage/secure_storage.dart';

/// Outcome of a token-refresh attempt. Distinguishing a *rejected* session
/// from a transient network failure matters: only a definitive rejection may
/// wipe credentials, otherwise a subway ride would log users out.
enum _RefreshResult { refreshed, rejected, networkError }

class DioClient {
  static Dio? _instance;

  // Shared in-flight refresh so parallel 401s trigger only one refresh call
  static Future<_RefreshResult>? _refreshing;

  // Invoked once when the session is definitively dead (refresh rejected).
  // main.dart wires this to route the user back to the login screen.
  static void Function()? onSessionExpired;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  /// SHA-256 fingerprints (base64) of allowed server certificates, from the
  /// CERT_PINS env value (comma-separated). Empty = standard CA validation.
  static List<String> get _certPins =>
      (dotenv.env['CERT_PINS'] ?? '')
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();

  static Dio _createDio() {
    final baseUrl = ApiConstants.baseUrl;

    // Release builds must never talk to the API in cleartext.
    if (kReleaseMode && !baseUrl.startsWith('https://')) {
      throw StateError('BASE_URL must use HTTPS in release builds');
    }

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _applyCertificatePinning(dio);

    // Request interceptor — attach token + device identity to every request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          // Stable install id (hashed server-side) + runtime environment
          // flags — both feed the backend's fraud/anomaly engine.
          options.headers['X-Device-Id'] =
              await SecureStorage.getOrCreateDeviceId();
          final integrity = await DeviceIntegrity.check();
          if (integrity.isNotEmpty) {
            options.headers['X-Device-Integrity'] = integrity.join(',');
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final alreadyRetried =
              error.requestOptions.extra['__retried'] == true;

          // On 401: try to refresh the access token once, then retry the
          // original request. Never for the refresh call itself (avoid loop).
          if (status == 401 &&
              !alreadyRetried &&
              !path.contains('/auth/refresh')) {
            final result = await _refreshTokens();
            switch (result) {
              case _RefreshResult.refreshed:
                try {
                  final opts = error.requestOptions;
                  opts.extra['__retried'] = true;
                  final newToken = await SecureStorage.getAccessToken();
                  opts.headers['Authorization'] = 'Bearer $newToken';
                  final response = await dio.fetch(opts);
                  return handler.resolve(response);
                } on DioException catch (e) {
                  return handler.next(e);
                }
              case _RefreshResult.rejected:
                // Server explicitly refused the refresh token: the session
                // is dead (rotated away, revoked, or expired). Clear local
                // auth state and route back to login.
                await SecureStorage.clearAll();
                onSessionExpired?.call();
                break;
              case _RefreshResult.networkError:
                // Transient failure — keep credentials, surface the error.
                break;
            }
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  /// Certificate pinning: when CERT_PINS is configured, every TLS handshake
  /// additionally requires the server certificate's SHA-256 fingerprint to
  /// match one of the pins (defense against compromised/rogue CAs — MITM).
  static void _applyCertificatePinning(Dio dio) {
    final pins = _certPins;
    if (pins.isEmpty) return;

    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.validateCertificate = (X509Certificate? cert, host, port) {
        if (cert == null) return false;
        final fingerprint = base64.encode(sha256.convert(cert.der).bytes);
        return pins.contains(fingerprint);
      };
    }
  }

  // Exchange the stored refresh token for a new token pair.
  static Future<_RefreshResult> _refreshTokens() {
    // Reuse an in-flight refresh if one is already running
    _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  static Future<_RefreshResult> _doRefresh() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        return _RefreshResult.rejected;
      }

      // Bare client: no interceptors, so a 401 here can't recurse.
      final bare = Dio(
        BaseOptions(
          baseUrl: ApiConstants.baseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      _applyCertificatePinning(bare);

      final response = await bare.post(
        ApiConstants.refresh,
        data: {'refreshToken': refreshToken},
        options: Options(
          headers: {
            'X-Device-Id': await SecureStorage.getOrCreateDeviceId(),
          },
        ),
      );

      // Response may be wrapped ({ data: {...} }) or flat
      final body = response.data is Map ? response.data as Map : {};
      final data = (body['data'] is Map ? body['data'] : body) as Map;

      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) {
        return _RefreshResult.rejected;
      }

      await SecureStorage.saveAccessToken(newAccess);
      await SecureStorage.saveRefreshToken(newRefresh);
      return _RefreshResult.refreshed;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      // Only an explicit 4xx from the server means the session is dead.
      if (status != null && status >= 400 && status < 500) {
        return _RefreshResult.rejected;
      }
      return _RefreshResult.networkError;
    } catch (_) {
      return _RefreshResult.networkError;
    }
  }
}
