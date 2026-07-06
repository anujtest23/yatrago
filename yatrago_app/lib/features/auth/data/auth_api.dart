import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';

class AuthApi {
  // POST /auth/send-otp
  static Future<Map<String, dynamic>> sendOtp(String phoneNumber) async {
    try {
      final response = await DioClient.instance.post(
        ApiConstants.sendOtp,
        data: {'phoneNumber': phoneNumber},
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /auth/verify-otp
  static Future<Map<String, dynamic>> verifyOtp(
    String phoneNumber,
    String otp,
  ) async {
    try {
      final response = await DioClient.instance.post(
        ApiConstants.verifyOtp,
        data: {'phoneNumber': phoneNumber, 'otp': otp},
      );
      final data = response.data['data'] as Map<String, dynamic>;

      // MFA-enrolled accounts (admins) get no tokens here — a second factor
      // is required. Caller must route to the MFA step; nothing is stored.
      if (data['mfaRequired'] == true) {
        return data;
      }

      await _persistSession(data);
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /auth/totp/verify — completes an MFA login and stores the session
  static Future<Map<String, dynamic>> verifyMfa(
    String mfaToken,
    String code,
  ) async {
    try {
      final response = await DioClient.instance.post(
        '/auth/totp/verify',
        data: {'mfaToken': mfaToken, 'code': code},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      await _persistSession(data);
      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  static Future<void> _persistSession(Map<String, dynamic> data) async {
    await SecureStorage.saveAccessToken(data['accessToken']);
    await SecureStorage.saveRefreshToken(data['refreshToken']);
    await SecureStorage.saveUserId(data['user']['id']);
    await SecureStorage.saveActiveMode(
      data['user']['activeMode'] ?? 'passenger',
    );
  }

  // POST /auth/logout
  static Future<void> logout() async {
    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      await DioClient.instance.post(
        ApiConstants.logout,
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Even if API fails, clear local storage
    } finally {
      await SecureStorage.clearAll();
    }
  }

  // GET /auth/me
  static Future<Map<String, dynamic>> getMe() async {
    try {
      final response = await DioClient.instance.get(ApiConstants.me);
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /auth/logout-all — revoke every session on every device
  static Future<void> logoutAll() async {
    try {
      await DioClient.instance.post(ApiConstants.logoutAll);
    } catch (_) {
      // Even if API fails, clear local storage
    } finally {
      await SecureStorage.clearAll();
    }
  }

  // GET /auth/sessions — active device sessions for this account
  static Future<List<Map<String, dynamic>>> getSessions() async {
    try {
      final response = await DioClient.instance.get(ApiConstants.sessions);
      final data = response.data['data'];
      return (data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // DELETE /auth/sessions/:id — revoke one device session
  static Future<void> revokeSession(String sessionId) async {
    try {
      await DioClient.instance.delete(
        '${ApiConstants.sessions}/$sessionId',
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
