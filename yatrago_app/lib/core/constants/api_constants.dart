import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  static String get baseUrl =>
      dotenv.env['BASE_URL'] ?? 'http://192.168.1.105:3000/api/v1';

  // WebSocket origin (no /api/v1 prefix — gateways bypass the global prefix).
  // Derived from baseUrl so a single BASE_URL env drives both transports.
  static String get socketUrl {
    final b = baseUrl;
    final i = b.indexOf('/api/');
    return i >= 0 ? b.substring(0, i) : b;
  }

  // Auth
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String refresh = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String sessions = '/auth/sessions';
  static const String me = '/auth/me';

  // Users
  static const String usersMe = '/users/me';
  static const String usersMeMode = '/users/me/mode';
  static const String usersProfilePhoto = '/users/profile-photo';
  // Account deletion (OTP-gated, 30-day grace period)
  static const String deletionRequestOtp = '/users/me/deletion/request-otp';
  static const String deletionConfirm = '/users/me/deletion/confirm';
  static const String deletionCancel = '/users/me/deletion/cancel';
  // Notification preferences (channel × category) + privacy settings
  static const String notificationPreferences =
      '/users/me/notification-preferences';
  static const String privacySettings = '/users/me/privacy-settings';

  // Coupons
  static const String couponValidate = '/coupons/validate';

  // Emergency contacts
  static const String emergencyContacts = '/users/me/emergency-contacts';
  static const String emergencyContactsReorder =
      '/users/me/emergency-contacts/reorder';

  // Support — Contact Us & Report an Issue
  static const String supportTickets = '/support/tickets';
  static const String supportIssues = '/support/issues';
  static const String supportAttachments = '/support/attachments';

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

  // Chat
  static const String chatConversations = '/chat/conversations';
  static const String chatUnreadCount = '/chat/unread-count';
  static String chatMessages(String bookingId) => '/chat/$bookingId/messages';
  static String chatRead(String bookingId) => '/chat/$bookingId/read';

  // Wallet
  static const String wallet = '/wallet';
  static const String walletCommissions = '/wallet/commissions';

  // Payments (self-service wallet top-up via gateway)
  static const String paymentMethods = '/wallet/payment-methods';
  static const String esewaInitiate = '/wallet/payments/esewa/initiate';
  static const String esewaVerify = '/wallet/payments/esewa/verify';
  static const String esewaReconcile = '/wallet/payments/esewa/reconcile';
  static const String walletTopups = '/wallet/topups';

  // Reviews
  static const String reviews = '/reviews';

  // Notifications
  static const String notifications = '/notifications';
}
