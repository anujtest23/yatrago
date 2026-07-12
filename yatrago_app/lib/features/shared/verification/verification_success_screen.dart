import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Arguments for the shared verification success screen.
class VerificationSuccessArgs {
  final String title;
  final String message;
  final String buttonLabel;

  /// Route to `go` to when the user taps the button (returns them to the
  /// originating settings hub).
  final String returnRoute;

  const VerificationSuccessArgs({
    required this.title,
    required this.message,
    this.buttonLabel = 'Done',
    required this.returnRoute,
  });
}

/// Green "Verified!" success screen (Yatri design). Purely presentational — it
/// performs no account-state change. The backend Delete Account flow will hook
/// in later to actually schedule the deletion.
class VerificationSuccessScreen extends StatelessWidget {
  final VerificationSuccessArgs args;
  const VerificationSuccessScreen({super.key, required this.args});

  static const Color _green = Color(0xFF10B981);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              _graphic(),
              const SizedBox(height: 36),
              Text(
                args.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _green,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                args.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF475569),
                  height: 1.5,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => context.go(args.returnRoute),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    args.buttonLabel,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _graphic() {
    return Container(
      width: 160,
      height: 160,
      decoration: const BoxDecoration(
        color: Color(0xFFEAFDF2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFFD1FADF),
          shape: BoxShape.circle,
          border: Border.all(
            color: const Color(0xFF12B76A).withValues(alpha: 0.1),
            width: 3,
          ),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _green.withValues(alpha: 0.08),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.verified_user_rounded,
              color: _green, size: 52),
        ),
      ),
    );
  }
}
