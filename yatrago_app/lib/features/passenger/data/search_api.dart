import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../models/ride_model.dart';

class SearchApi {
  // Fetch ALL available rides — no filters
  static Future<List<RideModel>> getAllRides({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final response = await DioClient.instance.get(
        ApiConstants.search,
        queryParameters: {'page': page, 'limit': limit},
      );

      final data = response.data['data'];
      final rides = (data['rides'] as List? ?? [])
          .map((r) => RideModel.fromJson(r))
          .toList();

      return rides;
    } on DioException catch (e) {
      // If backend requires origin/dest, return empty gracefully
      return [];
    } catch (_) {
      return [];
    }
  }

  // Search rides with optional text query + proximity/city matching.
  // The backend applies two-tier matching (nearby <=30km first, then
  // same-city fallback) and returns results already ordered and tagged
  // with `matchType`, so no client-side re-filtering is needed here.
  static Future<Map<String, dynamic>> searchRides({
    String? origin,
    String? destination,
    String? date,
    int seats = 1,
    bool? womenOnly,
    String? sortBy,
    int page = 1,
    int limit = 20,
    double? originLat,
    double? originLng,
    double? destLat,
    double? destLng,
    String? originCity,
    String? destCity,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'limit': limit,
        if (seats > 1) 'seats': seats,
        if (womenOnly == true) 'womenOnly': true,
        if (sortBy != null) 'sortBy': sortBy,
        if (date != null && date.isNotEmpty) 'date': date,
        if (origin != null && origin.isNotEmpty) 'origin': origin,
        if (destination != null && destination.isNotEmpty)
          'destination': destination,
        if (originLat != null) 'originLat': originLat,
        if (originLng != null) 'originLng': originLng,
        if (destLat != null) 'destLat': destLat,
        if (destLng != null) 'destLng': destLng,
        if (originCity != null && originCity.isNotEmpty)
          'originCity': originCity,
        if (destCity != null && destCity.isNotEmpty) 'destCity': destCity,
      };

      final response = await DioClient.instance.get(
        ApiConstants.search,
        queryParameters: queryParams,
      );

      final data = response.data['data'];
      final List<RideModel> rides = (data['rides'] as List? ?? [])
          .map((r) => RideModel.fromJson(r))
          .toList();

      return {
        'rides': rides,
        'pagination': data['pagination'] ?? {'total': rides.length},
      };
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
