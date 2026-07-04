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
      final data = response.data['data'];

      // Save tokens and user info
      await SecureStorage.saveAccessToken(data['accessToken']);
      await SecureStorage.saveRefreshToken(data['refreshToken']);
      await SecureStorage.saveUserId(data['user']['id']);
      await SecureStorage.saveActiveMode(
        data['user']['activeMode'] ?? 'passenger',
      );

      return data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
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
}
