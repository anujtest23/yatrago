import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/constants/api_constants.dart';

/// Emergency contacts CRUD + reorder (max 3, duplicate-prevented server-side).
class EmergencyContactsApi {
  // GET /users/me/emergency-contacts → { contacts, total }
  static Future<List<dynamic>> list() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.emergencyContacts);
      return (res.data['data']['contacts'] as List<dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /users/me/emergency-contacts
  static Future<Map<String, dynamic>> add({
    required String fullName,
    required String phoneNumber,
    String? relationship,
  }) async {
    try {
      final data = <String, dynamic>{
        'fullName': fullName,
        'phoneNumber': phoneNumber,
      };
      if (relationship != null) data['relationship'] = relationship;
      final res = await DioClient.instance.post(
        ApiConstants.emergencyContacts,
        data: data,
      );
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PATCH /users/me/emergency-contacts/:id
  static Future<Map<String, dynamic>> update(
    String id,
    Map<String, dynamic> patch,
  ) async {
    try {
      final res = await DioClient.instance.patch(
        '${ApiConstants.emergencyContacts}/$id',
        data: patch,
      );
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PATCH /users/me/emergency-contacts/reorder
  static Future<void> reorder(List<String> orderedIds) async {
    try {
      await DioClient.instance.patch(
        ApiConstants.emergencyContactsReorder,
        data: {'orderedIds': orderedIds},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // DELETE /users/me/emergency-contacts/:id
  static Future<void> remove(String id) async {
    try {
      await DioClient.instance.delete('${ApiConstants.emergencyContacts}/$id');
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
