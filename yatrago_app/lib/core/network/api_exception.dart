import 'package:dio/dio.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException({required this.message, this.statusCode});

  factory ApiException.fromDioError(DioException error) {
    String message = 'Something went wrong. Please try again.';
    int? statusCode = error.response?.statusCode;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      message = 'Connection timed out. Check your internet connection.';
    } else if (error.type == DioExceptionType.connectionError) {
      message = 'Cannot connect to server. Check your WiFi connection.';
    } else if (error.response != null) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        final msg = data['message'];
        message = msg is List ? msg.first.toString() : msg.toString();
      }
    }

    return ApiException(message: message, statusCode: statusCode);
  }

  @override
  String toString() => message;
}
