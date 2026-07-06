import 'package:go_router/go_router.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/onboarding_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/otp_screen.dart';
import '../../features/auth/screens/complete_profile_screen.dart';
import '../../features/auth/screens/mode_selection_screen.dart';
import '../../features/passenger/home/passenger_home_screen.dart';
import '../../features/passenger/home/passenger_shell.dart';
import '../../features/passenger/search/search_screen.dart';
import '../../features/passenger/search/search_results_screen.dart';
import '../../features/passenger/search/ride_detail_screen.dart';
import '../../features/passenger/search/driver_profile_screen.dart';
import '../../features/passenger/booking/select_seats_screen.dart';
import '../../features/passenger/booking/booking_summary_screen.dart';
import '../../features/passenger/booking/booking_confirmation_screen.dart';
import '../../features/passenger/my_rides/my_rides_screen.dart';
import '../../features/passenger/my_rides/passenger_ride_detail_screen.dart';
import '../../features/passenger/my_rides/cancel_booking_screen.dart';
import '../../features/passenger/review/rate_driver_screen.dart';
import '../../features/driver/dashboard/driver_shell.dart';
import '../../features/driver/dashboard/driver_dashboard_screen.dart';
import '../../features/driver/onboarding/become_driver_screen.dart';
import '../../features/driver/onboarding/driver_onboarding_wizard.dart';
import '../../features/driver/onboarding/under_review_screen.dart';
import '../../features/driver/onboarding/approved_screen.dart';
import '../../features/driver/onboarding/rejected_screen.dart';
import '../../features/driver/post_ride/post_ride_wizard.dart';
import '../../features/driver/post_ride/ride_published_screen.dart';
import '../../features/driver/bookings/incoming_bookings_screen.dart';
import '../../features/driver/bookings/passenger_details_screen.dart';
import '../../features/driver/my_rides/driver_my_rides_screen.dart';
import '../../features/driver/my_rides/driver_ride_detail_screen.dart';
import '../../features/driver/my_rides/edit_ride_screen.dart';
import '../../features/driver/my_rides/contact_passenger_screen.dart';
import '../../features/driver/trip_summary/trip_summary_screen.dart';
import '../../features/driver/trip_summary/rate_passenger_screen.dart';
import '../../features/driver/wallet/driver_wallet_screen.dart';
import '../../features/shared/notifications/notifications_screen.dart';
import '../../features/shared/settings/settings_screen.dart';
import '../../features/shared/settings/device_sessions_screen.dart';
import '../../features/shared/settings/edit_profile_screen.dart';
import '../../features/shared/tracking/trip_tracking_screen.dart';
import 'route_names.dart';

final appRouter = GoRouter(
  initialLocation: RouteNames.splash,
  routes: [
    // ── Splash ──────────────────────────────────────────────────
    GoRoute(path: RouteNames.splash, builder: (_, __) => const SplashScreen()),

    // ── Auth ────────────────────────────────────────────────────
    GoRoute(
      path: RouteNames.onboarding,
      builder: (_, __) => const OnboardingScreen(),
    ),
    GoRoute(path: RouteNames.login, builder: (_, __) => const LoginScreen()),
    GoRoute(
      path: RouteNames.otp,
      builder: (context, state) {
        final phone = state.extra as String;
        return OtpScreen(phoneNumber: phone);
      },
    ),
    GoRoute(
      path: RouteNames.completeProfile,
      builder: (_, __) => const CompleteProfileScreen(),
    ),
    GoRoute(
      path: RouteNames.modeSelection,
      builder: (_, __) => const ModeSelectionScreen(),
    ),

    // ── Driver Onboarding (outside shell — no nav bar needed) ───
    GoRoute(
      path: RouteNames.becomeDriver,
      builder: (_, __) => const BecomeDriverScreen(),
    ),
    GoRoute(
      path: RouteNames.driverOnboarding,
      builder: (_, __) => const DriverOnboardingWizard(),
    ),
    GoRoute(
      path: RouteNames.driverUnderReview,
      builder: (_, __) => const UnderReviewScreen(),
    ),
    GoRoute(
      path: RouteNames.driverApproved,
      builder: (_, __) => const ApprovedScreen(),
    ),
    GoRoute(
      path: RouteNames.driverRejected,
      builder: (_, __) => const RejectedScreen(),
    ),

    // ── Passenger Shell ─────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => PassengerShell(child: child),
      routes: [
        GoRoute(
          path: RouteNames.passengerHome,
          builder: (_, __) => const PassengerHomeScreen(),
        ),
        GoRoute(
          path: RouteNames.search,
          builder: (context, state) {
            final params = state.extra as Map<String, dynamic>?;
            return SearchScreen(initialParams: params);
          },
        ),
        GoRoute(
          path: RouteNames.passengerMyRides,
          builder: (_, __) => const MyRidesScreen(),
        ),
        GoRoute(
          path: RouteNames.notifications,
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: RouteNames.settings,
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.deviceSessions,
          builder: (_, __) => const DeviceSessionsScreen(),
        ),
      ],
    ),

    // ── Driver Shell ────────────────────────────────────────────
    ShellRoute(
      builder: (context, state, child) => DriverShell(child: child),
      routes: [
        GoRoute(
          path: RouteNames.driverDashboard,
          builder: (_, __) => const DriverDashboardScreen(),
        ),
        GoRoute(
          path: RouteNames.postRide,
          builder: (_, __) => const PostRideWizard(),
        ),
        GoRoute(
          path: RouteNames.driverMyRides,
          builder: (_, __) => const DriverMyRidesScreen(),
        ),
        GoRoute(
          path: RouteNames.incomingBookings,
          builder: (_, __) => const IncomingBookingsScreen(),
        ),
        GoRoute(
          path: RouteNames.driverSettings,
          builder: (_, __) => const SettingsScreen(),
        ),
        GoRoute(
          path: RouteNames.driverNotifications,
          builder: (_, __) => const NotificationsScreen(),
        ),
        GoRoute(
          path: RouteNames.driverWallet,
          builder: (_, __) => const DriverWalletScreen(),
        ),
      ],
    ),

    // ── Passenger detail screens (outside shell — full screen) ──
    GoRoute(
      path: RouteNames.searchResults,
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return SearchResultsScreen(searchParams: params);
      },
    ),
    GoRoute(
      path: RouteNames.rideDetail,
      builder: (context, state) {
        final ride = state.extra as Map<String, dynamic>;
        return RideDetailScreen(ride: ride);
      },
    ),
    GoRoute(
      path: RouteNames.driverProfile,
      builder: (context, state) {
        final userId = state.extra as String;
        return DriverProfileScreen(driverUserId: userId);
      },
    ),
    GoRoute(
      path: RouteNames.selectSeats,
      builder: (context, state) {
        final ride = state.extra as Map<String, dynamic>;
        return SelectSeatsScreen(ride: ride);
      },
    ),
    GoRoute(
      path: RouteNames.bookingSummary,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return BookingSummaryScreen(data: data);
      },
    ),
    GoRoute(
      path: RouteNames.bookingConfirmation,
      builder: (context, state) {
        final booking = state.extra as Map<String, dynamic>;
        return BookingConfirmationScreen(booking: booking);
      },
    ),
    GoRoute(
      path: RouteNames.passengerRideDetail,
      builder: (context, state) {
        final id = state.extra as String;
        return PassengerRideDetailScreen(bookingId: id);
      },
    ),
    GoRoute(
      path: RouteNames.cancelBooking,
      builder: (context, state) {
        final id = state.extra as String;
        return CancelBookingScreen(bookingId: id);
      },
    ),
    GoRoute(
      path: RouteNames.rateDriver,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return RateDriverScreen(data: data);
      },
    ),

    // ── Driver detail screens (outside shell — full screen) ─────
    GoRoute(
      path: RouteNames.ridePublished,
      builder: (context, state) {
        final trip = state.extra as Map<String, dynamic>;
        return RidePublishedScreen(trip: trip);
      },
    ),
    GoRoute(
      path: RouteNames.passengerDetails,
      builder: (context, state) {
        final id = state.extra as String;
        return PassengerDetailsScreen(bookingId: id);
      },
    ),
    GoRoute(
      path: RouteNames.driverRideDetail,
      builder: (context, state) {
        final id = state.extra as String;
        return DriverRideDetailScreen(tripId: id);
      },
    ),
    GoRoute(
      path: RouteNames.editRide,
      builder: (context, state) {
        final id = state.extra as String;
        return EditRideScreen(tripId: id);
      },
    ),
    GoRoute(
      path: RouteNames.contactPassenger,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return ContactPassengerScreen(
          bookingId: data['bookingId'] as String,
          passengerName: data['passengerName'] as String,
        );
      },
    ),
    GoRoute(
      path: RouteNames.tripSummary,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripSummaryScreen(data: data);
      },
    ),
    GoRoute(
      path: RouteNames.ratePassenger,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return RatePassengerScreen(data: data);
      },
    ),

    // ── Shared screens ───────────────────────────────────────────
    GoRoute(
      path: RouteNames.editProfile,
      builder: (_, __) => const EditProfileScreen(),
    ),
    GoRoute(
      path: RouteNames.tripTracking,
      builder: (context, state) {
        final data = state.extra as Map<String, dynamic>;
        return TripTrackingScreen(
          tripId: data['tripId'] as String,
          isDriver: data['isDriver'] as bool,
          originLat: data['originLat'] as double,
          originLng: data['originLng'] as double,
          originName: data['originName'] as String,
          destLat: data['destLat'] as double,
          destLng: data['destLng'] as double,
          destName: data['destName'] as String,
        );
      },
    ),
  ],
);
