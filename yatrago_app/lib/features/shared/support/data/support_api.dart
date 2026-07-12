import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/constants/api_constants.dart';

/// Contact Us (tickets) and Report an Issue (ride-specific) API.
class SupportApi {
  // POST /support/attachments (multipart) → returns the stored /uploads path.
  // Server re-validates MIME, magic bytes and size (5 MB); this is the only
  // way to obtain a path accepted by createTicket/reportIssue.
  static Future<String> uploadAttachment(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: 'screenshot'),
      });
      final res = await DioClient.instance.post(
        ApiConstants.supportAttachments,
        data: form,
        options: Options(contentType: 'multipart/form-data'),
      );
      return res.data['data']['url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /support/tickets
  static Future<Map<String, dynamic>> createTicket({
    required String category,
    required String subject,
    required String description,
    List<String>? attachments,
  }) async {
    try {
      final res = await DioClient.instance.post(
        ApiConstants.supportTickets,
        data: {
          'category': category,
          'subject': subject,
          'description': description,
          if (attachments != null && attachments.isNotEmpty)
            'attachments': attachments,
        },
      );
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /support/tickets
  static Future<List<dynamic>> myTickets() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.supportTickets);
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /support/issues
  static Future<Map<String, dynamic>> reportIssue({
    required String category,
    required String description,
    String? bookingId,
    String? rideId,
    List<String>? attachments,
  }) async {
    try {
      final data = <String, dynamic>{
        'category': category,
        'description': description,
      };
      if (bookingId != null) data['bookingId'] = bookingId;
      if (rideId != null) data['rideId'] = rideId;
      if (attachments != null && attachments.isNotEmpty) {
        data['attachments'] = attachments;
      }
      final res = await DioClient.instance.post(
        ApiConstants.supportIssues,
        data: data,
      );
      return res.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /support/issues
  static Future<List<dynamic>> myIssues() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.supportIssues);
      return res.data['data'] as List<dynamic>;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
