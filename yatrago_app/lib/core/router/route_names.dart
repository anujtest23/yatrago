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

  // Driver-scoped copies of shared screens (registered inside DriverShell so
  // the driver bottom nav bar stays visible instead of falling back to the
  // passenger shell, which is where the shared /settings and /notifications
  // routes live).
  static const String driverSettings = '/driver/settings';
  static const String driverNotifications = '/driver/notifications';
  static const String driverWallet = '/driver/wallet';
}
