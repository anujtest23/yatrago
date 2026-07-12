import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/constants/api_constants.dart';

/// Coupon preview. The backend computes the authoritative discount; the app
/// only displays it and passes the raw code to the booking request.
class CouponApi {
  // POST /coupons/validate → { couponId, code, discountAmount, finalAmount }
  static Future<Map<String, dynamic>> validate({
    required String code,
    required num amount,
  }) async {
    try {
      final res = await DioClient.instance.post(
        ApiConstants.couponValidate,
        data: {'code': code, 'amount': amount},
      );
      return Map<String, dynamic>.from(res.data['data']);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
