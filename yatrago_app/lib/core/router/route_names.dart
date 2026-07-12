class RouteNames {
  // Auth
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String otp = '/otp';
  static const String completeProfile = '/complete-profile';
  static const String modeSelection = '/mode-selection';

  // Passenger
  static const String passengerHome = '/passenger/home';
  static const String search = '/passenger/search';
  static const String searchResults = '/passenger/search-results';
  static const String rideDetail = '/passenger/ride-detail';
  static const String driverProfile = '/passenger/driver-profile';
  static const String selectSeats = '/passenger/select-seats';
  static const String bookingSummary = '/passenger/booking-summary';
  static const String bookingConfirmation = '/passenger/booking-confirmation';
  static const String passengerMyRides = '/passenger/my-rides';
  static const String passengerRideDetail = '/passenger/my-rides/detail';
  static const String cancelBooking = '/passenger/cancel-booking';
  static const String rateDriver = '/passenger/rate-driver';

  // Driver
  static const String becomeDriver = '/driver/become';
  static const String driverOnboarding = '/driver/onboarding';
  static const String driverUnderReview = '/driver/under-review';
  static const String driverApproved = '/driver/approved';
  static const String driverRejected = '/driver/rejected';
  static const String driverDashboard = '/driver/dashboard';
  static const String postRide = '/driver/post-ride';
  static const String ridePublished = '/driver/ride-published';
  static const String incomingBookings = '/driver/incoming-bookings';
  static const String passengerDetails = '/driver/passenger-details';
  static const String driverMyRides = '/driver/my-rides';
  static const String driverRideDetail = '/driver/my-rides/detail';
  static const String contactPassenger = '/driver/contact-passenger';
  static const String editRide = '/driver/edit-ride';
  static const String tripSummary = '/driver/trip-summary';
  static const String ratePassenger = '/driver/rate-passenger';

  // Shared
  static const String settings = '/settings';
  static const String editProfile = '/settings/edit-profile';
  static const String deviceSessions = '/settings/devices';
  static const String notifications = '/notifications';
  static const String tripTracking = '/trip-tracking';

  // Settings sub-pages (full-screen; reachable from both passenger and driver
  // settings hubs).
  static const String profile = '/settings/profile';
  static const String notificationSettings = '/settings/notification-settings';
  static const String aboutApp = '/settings/about';
  static const String helpSupport = '/settings/help';
  static const String faq = '/settings/faq';
  static const String privacyPolicy = '/settings/privacy-policy';
  static const String termsConditions = '/settings/terms';

  // Privacy / Terms static sub-pages (leaf detail screens reached from the
  // Privacy Policy and Terms & Conditions hubs). All informational — no backend.
  static const String infoCollect = '/settings/privacy-policy/info-collect';
  static const String locationPermission =
      '/settings/privacy-policy/location-permission';
  static const String privacyDetail = '/settings/privacy-policy/detail';
  static const String fullPrivacyPolicy = '/settings/privacy-policy/full';
  static const String termsDetail = '/settings/terms/detail';
  static const String safety = '/settings/safety';
  static const String appVersion = '/settings/app-version';
  static const String comingSoon = '/settings/coming-soon';
  static const String privacySettings = '/settings/privacy';
  static const String emergencyContacts = '/settings/emergency-contacts';
  static const String contactUs = '/settings/contact-us';
  static const String reportIssue = '/settings/report-issue';

  // Delete Account (UI flow only; backend deletion is a separate task).
  static const String deleteAccount = '/settings/delete-account';
  static const String sensitiveOtp = '/verify-action';
  static const String verificationSuccess = '/verify-action/success';

  // Chat / Messages. The Messages tab lives inside each shell (so the nav bar
  // stays visible); the thread itself is full-screen (outside the shells).
  static const String passengerMessages = '/passenger/messages';
  static const String driverMessages = '/driver/messages';
  static const String chat = '/chat';

  // Driver-scoped copies of shared screens (registered inside DriverShell so
  // the driver bottom nav bar stays visible instead of falling back to the
  // passenger shell, which is where the shared /settings and /notifications
  // routes live).
  static const String driverSettings = '/driver/settings';
  static const String driverNotifications = '/driver/notifications';
  static const String driverWallet = '/driver/wallet';

  // Wallet top-up (full-screen; reachable from the wallet screen and from the
  // insufficient-balance dialog when posting a ride).
  static const String topUp = '/driver/top-up';
  static const String topupHistory = '/driver/top-up/history';
}
