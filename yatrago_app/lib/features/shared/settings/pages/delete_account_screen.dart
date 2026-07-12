import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/route_names.dart';
import '../../../auth/data/auth_api.dart';
import '../../verification/sensitive_action_otp_screen.dart';
import '../../verification/verification_success_screen.dart';
import '../widgets/settings_ui.dart';

/// Delete Account — confirmation step. Explains the consequences and, on
/// confirm, routes into the sensitive-action OTP flow wired to the real
/// deletion endpoints: request-otp on open, confirm on verify. Confirming
/// puts the account into a 30-day pending-deletion grace period (login+browse
/// stay allowed; bookings/rides/top-ups/payouts are blocked until cancelled).
class DeleteAccountScreen extends StatelessWidget {
  /// Where to return the user after the flow completes (settings hub for the
  /// active mode).
  final String returnRoute;

  const DeleteAccountScreen({super.key, this.returnRoute = RouteNames.settings});

  void _confirm(BuildContext context) {
    context.push(
      RouteNames.sensitiveOtp,
      extra: SensitiveOtpArgs(
        title: 'Verify Your Identity',
        actionLabel: 'delete your account',
        onRequestOtp: AuthApi.requestDeletionOtp,
        onVerify: AuthApi.confirmDeletion,
        success: VerificationSuccessArgs(
          title: 'Deletion Scheduled',
          message:
              'Your account is scheduled for deletion in 30 days. You can still '
              'browse, but bookings, rides, top-ups and payouts are disabled. '
              'Cancel anytime from Settings to keep your account.',
          buttonLabel: 'Back to Settings',
          returnRoute: returnRoute,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                child: Column(
                  children: [
                    const SettingsPageHeader(
                      title: 'Delete Account',
                      subtitle: 'This action cannot be undone.',
                    ),
                    const SizedBox(height: 48),
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 54,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Your profile, ride history, wallet, and account '
                        'information will be scheduled for permanent deletion. '
                        'Are you sure you want to continue?',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () => _confirm(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Yes, Delete Account',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: AppColors.primary,
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
