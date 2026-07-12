import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/constants/api_constants.dart';

/// Channel×category notification preferences and privacy settings.
class PreferencesApi {
  // GET /users/me/notification-preferences
  static Future<Map<String, dynamic>> getNotificationPreferences() async {
    try {
      final res =
          await DioClient.instance.get(ApiConstants.notificationPreferences);
      return Map<String, dynamic>.from(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PATCH /users/me/notification-preferences
  // patch shape: { category: { push?: bool, email?: bool, sms?: bool } }
  static Future<Map<String, dynamic>> updateNotificationPreferences(
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await DioClient.instance.patch(
        ApiConstants.notificationPreferences,
        data: patch,
      );
      return Map<String, dynamic>.from(res.data['data']['preferences']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /users/me/privacy-settings
  static Future<Map<String, dynamic>> getPrivacySettings() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.privacySettings);
      return Map<String, dynamic>.from(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PATCH /users/me/privacy-settings
  static Future<Map<String, dynamic>> updatePrivacySettings(
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await DioClient.instance.patch(
        ApiConstants.privacySettings,
        data: patch,
      );
      return Map<String, dynamic>.from(res.data['data']['settings']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
