import 'dart:math';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';
import '../models/booking_model.dart';

class BookingApi {
  // Unique key so the backend can safely dedupe retried booking requests
  static String _newIdempotencyKey() {
    final rand = Random().nextInt(0xFFFFFF).toRadixString(16);
    return 'bk-${DateTime.now().microsecondsSinceEpoch}-$rand';
  }

  // POST /bookings — submit a booking request (driver must accept).
  static Future<Map<String, dynamic>> createBooking({
    required String rideId,
    required int seatsBooked,
    double? pickupLat,
    double? pickupLng,
    String? pickupName,
    double? dropLat,
    double? dropLng,
    String? dropName,
    String? couponCode,
  }) async {
    final idempotencyKey = _newIdempotencyKey();
    try {
      final response = await DioClient.instance.post(
        ApiConstants.bookings,
        data: {
          'rideId': rideId,
          'seatsBooked': seatsBooked,
          if (pickupLat != null) 'pickupLat': pickupLat,
          if (pickupLng != null) 'pickupLng': pickupLng,
          if (pickupName != null) 'pickupName': pickupName,
          if (dropLat != null) 'dropLat': dropLat,
          if (dropLng != null) 'dropLng': dropLng,
          if (dropName != null) 'dropName': dropName,
          if (couponCode != null) 'couponCode': couponCode,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /bookings?role=passenger
  static Future<List<BookingModel>> getMyBookings({
    String role = 'passenger',
    String? status,
  }) async {
    try {
      final response = await DioClient.instance.get(
        ApiConstants.bookings,
        queryParameters: {'role': role, if (status != null) 'status': status},
      );
      final bookings = (response.data['data']['bookings'] as List)
          .map((b) => BookingModel.fromJson(b))
          .toList();
      return bookings;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /bookings/:id
  static Future<Map<String, dynamic>> getBookingById(String id) async {
    try {
      final response = await DioClient.instance.get(
        '${ApiConstants.bookings}/$id',
      );
      return response.data['data'];
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // PATCH /bookings/:id/cancel
  static Future<void> cancelBooking(String id, {String? reason}) async {
    try {
      await DioClient.instance.patch(
        '${ApiConstants.bookings}/$id/cancel',
        data: {'reason': reason ?? 'Cancelled by passenger'},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
