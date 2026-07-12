import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';

/// Reusable 6-box OTP entry field (Yatri visuals). Shared by any OTP flow so
/// the input UI is defined once. It is intentionally free of business logic —
/// callers own verification. Reports the full code via [onChanged] and fires
/// [onCompleted] when all six digits are entered.
class OtpBoxesField extends StatefulWidget {
  final Color accent;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpBoxesField({
    super.key,
    this.accent = AppColors.primary,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpBoxesField> createState() => OtpBoxesFieldState();
}

class OtpBoxesFieldState extends State<OtpBoxesField> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void initState() {
    super.initState();
    for (final f in _focusNodes) {
      f.addListener(() {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  /// Clears every box and refocuses the first — for callers to reset on error.
  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    if (mounted) _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) {
          final filled = _controllers[i].text.isNotEmpty;
          final current = _focusNodes[i].hasFocus;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 56,
            decoration: BoxDecoration(
              color: filled
                  ? widget.accent.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: current
                    ? widget.accent
                    : filled
                        ? widget.accent.withValues(alpha: 0.5)
                        : AppColors.border,
                width: current ? 2 : 1.5,
              ),
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
                  color: widget.accent,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (val) {
                  if (val.isNotEmpty && i < 5) {
                    _focusNodes[i + 1].requestFocus();
                  }
                  if (val.isEmpty && i > 0) {
                    _focusNodes[i - 1].requestFocus();
                  }
                  setState(() {});
                  widget.onChanged?.call(_code);
                  if (_code.length == 6) {
                    widget.onCompleted?.call(_code);
                  }
                },
              ),
            ),
          );
        }),
      ),
    );
  }
}
