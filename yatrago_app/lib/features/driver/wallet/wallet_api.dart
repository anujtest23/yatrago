import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/constants/api_constants.dart';

class WalletApi {
  // GET /wallet — balance + recent transactions
  static Future<Map<String, dynamic>> getWallet() async {
    try {
      final response = await DioClient.instance.get(ApiConstants.wallet);
      return response.data['data'] ?? response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // POST /wallet/topup
  static Future<Map<String, dynamic>> topUp(double amount) async {
    try {
      final response = await DioClient.instance.post(
        ApiConstants.walletTopup,
        data: {'amount': amount},
      );
      return response.data['data'] ?? response.data;
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }

  // GET /wallet/commissions — driver commission deduction history
  static Future<List<Map<String, dynamic>>> getCommissions() async {
    try {
      final response = await DioClient.instance.get(
        ApiConstants.walletCommissions,
      );
      final data = response.data['data'] ?? response.data;
      return List<Map<String, dynamic>>.from(data['commissions'] ?? []);
    } on DioException catch (e) {
      throw ApiException.fromDioError(e);
    }
  }
}
