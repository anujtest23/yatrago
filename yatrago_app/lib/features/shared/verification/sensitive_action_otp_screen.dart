import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../../auth/data/auth_api.dart';
import '../settings/widgets/settings_ui.dart';
import 'otp_boxes_field.dart';
import 'verification_success_screen.dart';

/// Arguments for the sensitive-action OTP flow (Flow B). Distinct from the
/// login OTP (Flow A) — this flow gates high-risk actions like account
/// deletion and shares only presentation, never authentication logic.
class SensitiveOtpArgs {
  final String title;
  final String actionLabel;
  final VerificationSuccessArgs success;

  /// Sends (or resends) the OTP. Called on screen open and on "Resend code".
  /// When null the screen is purely presentational (legacy demo behaviour).
  final Future<void> Function()? onRequestOtp;

  /// Verifies the entered [code] against the backend. Throwing surfaces the
  /// error to the user and keeps them on the screen. When null, entering six
  /// digits advances straight to the success screen (demo behaviour).
  final Future<void> Function(String code)? onVerify;

  const SensitiveOtpArgs({
    required this.title,
    required this.actionLabel,
    required this.success,
    this.onRequestOtp,
    this.onVerify,
  });
}

/// UI-only sensitive-action OTP screen. It renders the Yatri verification
/// chrome and the shared [OtpBoxesField]; verification against the backend is
/// intentionally NOT implemented yet (Delete Account backend is a separate
/// task). Entering six digits advances to the success screen so the flow can
/// be demonstrated and later wired to a real verify endpoint.
class SensitiveActionOtpScreen extends StatefulWidget {
  final SensitiveOtpArgs args;
  const SensitiveActionOtpScreen({super.key, required this.args});

  @override
  State<SensitiveActionOtpScreen> createState() =>
      _SensitiveActionOtpScreenState();
}

class _SensitiveActionOtpScreenState extends State<SensitiveActionOtpScreen> {
  final _otpKey = GlobalKey<OtpBoxesFieldState>();
  String _phone = '';
  int _resendSeconds = 30;
  Timer? _timer;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _loadPhone();
    _sendOtp();
    _startTimer();
  }

  Future<void> _sendOtp() async {
    final send = widget.args.onRequestOtp;
    if (send == null) return;
    try {
      await send();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPhone() async {
    try {
      final user = await AuthApi.getMe();
      if (!mounted) return;
      setState(() => _phone = (user['phoneNumber'] as String?) ?? '');
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _resendSeconds = 30;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_resendSeconds > 0) {
          _resendSeconds--;
        } else {
          t.cancel();
        }
      });
    });
  }

  Future<void> _onCompleted(String code) async {
    if (_verifying) return;
    FocusScope.of(context).unfocus();
    final verify = widget.args.onVerify;
    if (verify == null) {
      // No backend hook — advance the UI (demo behaviour).
      context.pushReplacement(RouteNames.verificationSuccess,
          extra: widget.args.success);
      return;
    }

    setState(() => _verifying = true);
    try {
      await verify(code);
      if (!mounted) return;
      context.pushReplacement(RouteNames.verificationSuccess,
          extra: widget.args.success);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _otpKey.currentState?.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final masked = _phone.length >= 4
        ? '••••••${_phone.substring(_phone.length - 4)}'
        : _phone;

    return Scaffold(
      backgroundColor: const Color(0xFFFEFEFE),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            children: [
              SettingsPageHeader(
                title: widget.args.title,
                subtitle: 'Confirm it\'s you before we ${widget.args.actionLabel}.',
              ),
              const SizedBox(height: 40),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary, size: 46),
              ),
              const SizedBox(height: 20),
              Text(
                'Enter verification code',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                masked.isEmpty
                    ? 'We\'ve sent a 6-digit code to your phone.'
                    : 'We\'ve sent a 6-digit code to $masked',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),
              OtpBoxesField(key: _otpKey, onCompleted: _onCompleted),
              const SizedBox(height: 24),
              if (_verifying)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              _resendSeconds > 0
                  ? Text(
                      'Resend code in 00:${_resendSeconds.toString().padLeft(2, '0')}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    )
                  : GestureDetector(
                      onTap: () {
                        _sendOtp();
                        _startTimer();
                      },
                      child: Text(
                        'Resend code',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
