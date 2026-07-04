import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://192.168.1.105:3000/api/v1';

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';

  // Users
  static const String usersMe = '/users/me';
  static const String usersMeMode = '/users/me/mode';
  static const String usersProfilePhoto = '/users/profile-photo';

  // Drivers
  static const String driversApply = '/drivers/apply';
  static const String driversCitizenship = '/drivers/citizenship';
  static const String driversLicense = '/drivers/license';
  static const String driversSelfie = '/drivers/selfie';
  static const String driversStatus = '/drivers/status';
  static const String driversDashboard = '/drivers/dashboard';

  // Vehicles
  static const String vehicles = '/vehicles';

  // Trips
  static const String trips = '/trips';

  // Search
  static const String search = '/search';

  // Bookings
  static const String bookings = '/bookings';
  static const String messages = '/bookings/messages';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletTopup = '/wallet/topup';
  static const String walletCommissions = '/wallet/commissions';

  // Reviews
  static const String reviews = '/reviews';

  // Notifications
  static const String notifications = '/notifications';
}
