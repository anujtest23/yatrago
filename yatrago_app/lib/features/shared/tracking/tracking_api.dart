import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';

class TrackingApi {
  static Future<void> updateMyLocation(double lat, double lng) async {
    try {
      await DioClient.instance.put(
        '/drivers/location',
        data: {'lat': lat, 'lng': lng},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  static Future<Map<String, dynamic>> getDriverLocation(String tripId) async {
    try {
      final response = await DioClient.instance.get('/trips/$tripId/location');
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
