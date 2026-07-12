import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';

/// A signed eSewa top-up intent returned by the backend. The app never
/// computes signatures or amounts itself — it only relays this to eSewa.
class EsewaIntent {
  final String paymentId;
  final String transactionUuid;
  final String gatewayUrl;
  final Map<String, String> fields; // hidden form inputs (incl. signature)
  final String successUrl;
  final String failureUrl;

  EsewaIntent({
    required this.paymentId,
    required this.transactionUuid,
    required this.gatewayUrl,
    required this.fields,
    required this.successUrl,
    required this.failureUrl,
  });

  factory EsewaIntent.fromJson(Map<String, dynamic> json) {
    final rawFields = (json['fields'] as Map?) ?? {};
    return EsewaIntent(
      paymentId: json['paymentId'] as String,
      transactionUuid: json['transactionUuid'] as String? ?? '',
      gatewayUrl: json['gatewayUrl'] as String,
      fields: rawFields.map((k, v) => MapEntry('$k', '${v ?? ''}')),
      successUrl: json['successUrl'] as String? ?? '',
      failureUrl: json['failureUrl'] as String? ?? '',
    );
  }
}

class PaymentApi {
  // GET /wallet/payment-methods
  static Future<Map<String, dynamic>> getPaymentMethods() async {
    try {
      final res = await DioClient.instance.get(ApiConstants.paymentMethods);
      return Map<String, dynamic>.from(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /wallet/payments/esewa/initiate
  static Future<EsewaIntent> initiateEsewa(int amount) async {
    try {
      final res = await DioClient.instance.post(
        ApiConstants.esewaInitiate,
        data: {'amount': amount},
      );
      final data = res.data['data'] ?? res.data;
      return EsewaIntent.fromJson(Map<String, dynamic>.from(data));
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /wallet/payments/esewa/verify — backend re-checks with eSewa and
  /// credits the wallet if genuinely settled. Returns {status, amount, balance}.
  static Future<Map<String, dynamic>> verifyEsewa(String paymentId) async {
    try {
      final res = await DioClient.instance.post(
        ApiConstants.esewaVerify,
        data: {'paymentId': paymentId},
      );
      return Map<String, dynamic>.from(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// POST /wallet/payments/esewa/reconcile — server re-checks ALL of the
  /// caller's pending top-ups and credits any that settled while the app was
  /// closed. Called when the wallet/top-up screen opens or the app resumes.
  /// Idempotent; returns {balance, checked, credited}.
  static Future<Map<String, dynamic>> reconcile() async {
    try {
      final res = await DioClient.instance.post(ApiConstants.esewaReconcile);
      return Map<String, dynamic>.from(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  /// GET /wallet/topups — cursor-paginated top-up attempt history (all
  /// statuses). Returns {topups: [...], nextCursor}.
  static Future<Map<String, dynamic>> getTopupHistory({
    int limit = 20,
    String? cursor,
  }) async {
    try {
      final res = await DioClient.instance.get(
        ApiConstants.walletTopups,
        queryParameters: {
          'limit': limit,
          if (cursor != null) 'cursor': cursor,
        },
      );
      return Map<String, dynamic>.from(res.data['data'] ?? res.data);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
