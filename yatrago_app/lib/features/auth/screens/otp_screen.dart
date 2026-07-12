import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_names.dart';
import '../data/auth_api.dart';
import '../../shared/chat/chat_unread.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  String? _error;
  int _resendSeconds = 60;

  // Entrance animations (Yatri design)
  bool _visible = false;
  late AnimationController _shieldAnimController;
  late Animation<double> _shieldScaleAnim;

  @override
  void initState() {
    super.initState();
    _startResendTimer();

    _shieldAnimController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _shieldScaleAnim = CurvedAnimation(
      parent: _shieldAnimController,
      curve: Curves.elasticOut,
    );

    // Repaint boxes when focus moves so the active box highlights.
    for (final f in _focusNodes) {
      f.addListener(() {
        if (mounted) setState(() {});
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _visible = true);
        _shieldAnimController.forward();
      }
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    _shieldAnimController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        if (_resendSeconds > 0) _resendSeconds--;
      });
      return _resendSeconds > 0;
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _clearOtpBoxes() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit OTP');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var data = await AuthApi.verifyOtp(widget.phoneNumber, _otp);
      if (!mounted) return;

      // MFA-enrolled accounts must pass a second factor before any tokens
      // are issued. Collect the authenticator code and complete the login.
      if (data['mfaRequired'] == true) {
        final completed = await _promptMfa(data['mfaToken'] as String);
        if (completed == null) {
          setState(() => _isLoading = false);
          return;
        }
        data = completed;
      }
      if (!mounted) return;

      final isNewUser = data['isNewUser'] == true;

      // Session established — bring chat online and seed the unread badge.
      unawaited(ChatUnread.instance.start());

      if (isNewUser) {
        context.go(RouteNames.completeProfile);
      } else {
        final mode = data['user']['activeMode'];
        if (mode == 'driver') {
          context.go(RouteNames.driverDashboard);
        } else {
          context.go(RouteNames.passengerHome);
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
      _clearOtpBoxes();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Prompt for a TOTP code and complete the MFA login. Returns the login
  /// payload on success, or null if the user cancelled.
  Future<Map<String, dynamic>?> _promptMfa(String mfaToken) async {
    final controller = TextEditingController();
    String? dialogError;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> submit() async {
            final code = controller.text.trim();
            if (code.length != 6) {
              setDialogState(() => dialogError = 'Enter the 6-digit code');
              return;
            }
            try {
              final result = await AuthApi.verifyMfa(mfaToken, code);
              if (ctx.mounted) Navigator.pop(ctx, result);
            } catch (e) {
              setDialogState(() => dialogError = e.toString());
            }
          }

          return AlertDialog(
            title: const Text('Two-factor authentication'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Enter the code from your authenticator app.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    errorText: dialogError,
                    hintText: '123456',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(onPressed: submit, child: const Text('Verify')),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    setState(() => _isResending = true);
    try {
      await AuthApi.sendOtp(widget.phoneNumber);
      setState(() => _resendSeconds = 60);
      _startResendTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('OTP sent again')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedOpacity(
        opacity: _visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOut,
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // Back button
                _buildBackButton(),

                const SizedBox(height: 8),

                // Shield icon with circular rings
                _buildShieldIcon(),

                const SizedBox(height: 4),

                // "Verify your number"
                _buildTitle(),

                const SizedBox(height: 6),

                // Subtitle with phone number
                _buildSubtitle(),

                const SizedBox(height: 12),

                // OTP input boxes (real TextFields — system keyboard)
                _buildOtpBoxes(),

                // Error message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 12, 28, 0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppColors.error,
                      ),
                    ),
                  ),

                // Loading indicator while verifying
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),

                const SizedBox(height: 28),

                // Dashed divider with mandala icon
                _buildDashedDivider(),

                const SizedBox(height: 8),

                // Resend OTP timer
                _buildResendTimer(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // BACK BUTTON
  // ════════════════════════════════════════════════════════════
  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 16, top: 12),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // SHIELD ICON — Red shield with checkmark + animated rings
  // ════════════════════════════════════════════════════════════
  Widget _buildShieldIcon() {
    return ScaleTransition(
      scale: _shieldScaleAnim,
      child: SizedBox(
        width: 130,
        height: 130,
        child: CustomPaint(
          painter: _ShieldRingsPainter(),
          child: Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified_user,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // TITLE — "Verify your number"
  // ════════════════════════════════════════════════════════════
  Widget _buildTitle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Verify your ',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          'number',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // SUBTITLE — "We've sent a 6-digit OTP to <phone>"
  // ════════════════════════════════════════════════════════════
  Widget _buildSubtitle() {
    return Column(
      children: [
        Text(
          "We've sent a 6-digit OTP to",
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.phoneNumber,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════
  // OTP INPUT BOXES — Yatri visuals, real TextFields underneath
  // ════════════════════════════════════════════════════════════
  Widget _buildOtpBoxes() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final bool isFilled = _controllers[i].text.isNotEmpty;
          final bool isCurrent = _focusNodes[i].hasFocus;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: isFilled
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrent
                    ? AppColors.primary
                    : isFilled
                        ? AppColors.primary.withValues(alpha: 0.5)
                        : AppColors.border,
                width: isCurrent ? 2.0 : 1.5,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        blurRadius: 8,
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: TextField(
                controller: _controllers[i],
                focusNode: _focusNodes[i],
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  setState(() => _error = null);
                  if (val.isNotEmpty && i < 5) {
                    _focusNodes[i + 1].requestFocus();
                  }
                  if (val.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                  if (i == 5 && val.isNotEmpty) {
                    // Auto-submit when last digit entered
                    _verifyOtp();
                  }
                },
              ),
            ),
          );
        }),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // DASHED DIVIDER — Dashed red line with mandala icon
  // ════════════════════════════════════════════════════════════
  Widget _buildDashedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              size: const Size(double.infinity, 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Image.asset(
              'assets/images/login_mandala.png',
              width: 30,
              height: 30,
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: CustomPaint(
              painter: _DashedLinePainter(),
              size: const Size(double.infinity, 1),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════
  // RESEND TIMER — Clock icon + "Resend OTP in 01:00"
  // ════════════════════════════════════════════════════════════
  Widget _buildResendTimer() {
    final String timeStr =
        '${(_resendSeconds ~/ 60).toString().padLeft(2, '0')}:${(_resendSeconds % 60).toString().padLeft(2, '0')}';
    final bool canResend = _resendSeconds == 0;

    if (_isResending) {
      return Text(
        'Sending...',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      );
    }

    return GestureDetector(
      onTap: canResend ? _resendOtp : null,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time_rounded,
            color: canResend ? AppColors.primary : AppColors.textSecondary,
            size: 18,
          ),
          const SizedBox(width: 6),
          if (canResend)
            Text(
              'Resend OTP',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            )
          else ...[
            Text(
              'Resend OTP in ',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              timeStr,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// SHIELD RINGS PAINTER — Concentric rings around shield icon
// ════════════════════════════════════════════════════════════
class _ShieldRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer ring (faint)
    final outerPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width / 2, outerPaint);

    // Middle ring
    final middlePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width / 2 - 10, middlePaint);

    // Inner ring
    final innerPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, size.width / 2 - 22, innerPaint);

    // Decorative ring stroke
    final ringStrokePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, size.width / 2 - 5, ringStrokePaint);

    // Small dot decorations around the ring
    final dotPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (pi / 180);
      final radius = size.width / 2 - 5;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      canvas.drawCircle(Offset(x, y), 2.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ════════════════════════════════════════════════════════════
// DASHED LINE PAINTER — Red dashed horizontal line
// ════════════════════════════════════════════════════════════
class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.35)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height / 2),
        Offset(startX + dashWidth, size.height / 2),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
