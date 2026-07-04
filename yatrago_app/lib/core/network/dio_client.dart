import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class DioClient {
  static Dio? _instance;

  // Shared in-flight refresh so parallel 401s trigger only one refresh call
  static Future<bool>? _refreshing;

  // Invoked once when the session is definitively dead (refresh failed).
  // main.dart wires this to route the user back to the login screen.
  static void Function()? onSessionExpired;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Request interceptor — attach token to every request
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          return handler.next(response);
        },
        onError: (DioException error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final alreadyRetried =
              error.requestOptions.extra['__retried'] == true;

          // On 401: try to refresh the access token once, then retry the
          // original request. Never for the refresh call itself (avoid loop).
          if (status == 401 && !alreadyRetried && !path.contains('/auth/refresh')) {
            final refreshed = await _refreshTokens(dio);
            if (refreshed) {
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
            }
            // Refresh failed — session truly dead. Clear local auth state
            // and kick the user back to login instead of leaving them on a
            // broken screen with a futile "Retry".
            await SecureStorage.clearAll();
            onSessionExpired?.call();
          }
          return handler.next(error);
        },
      ),
    );

    return dio;
  }

  // Exchange the stored refresh token for a new token pair.
  // Returns true if new tokens were saved.
  static Future<bool> _refreshTokens(Dio dio) {
    // Reuse an in-flight refresh if one is already running
    _refreshing ??= _doRefresh(dio).whenComplete(() => _refreshing = null);
    return _refreshing!;
  }

  static Future<bool> _doRefresh(Dio dio) async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;

      // Bare client: no interceptors, so a 401 here can't recurse
      final bare = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
      final response = await bare.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      // Response may be wrapped ({ data: {...} }) or flat
      final body = response.data is Map ? response.data as Map : {};
      final data = (body['data'] is Map ? body['data'] : body) as Map;

      final newAccess = data['accessToken'] as String?;
      final newRefresh = data['refreshToken'] as String?;
      if (newAccess == null || newRefresh == null) return false;

      await SecureStorage.saveAccessToken(newAccess);
      await SecureStorage.saveRefreshToken(newRefresh);
      return true;
    } catch (_) {
      return false;
    }
  }
}
