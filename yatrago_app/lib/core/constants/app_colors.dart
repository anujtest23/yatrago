import 'package:flutter/material.dart';

class AppColors {
  // Primary — Yatri red
  static const Color primary = Color(0xFFE52020);
  static const Color primaryLight = Color(0xFFFFF0F0);
  static const Color primaryDark = Color(0xFFCC1A1A);

  // Brand gradients (Yatri UI)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFE52020), Color(0xFFCC1A1A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Driver mode — dark green, visually distinct from passenger red
  static const Color driver = Color(0xFF1B5E20);
  static const Color driverLight = Color(0xFFE8F5E9);

  // Driver gradient (mirror of primaryGradient, green)
  static const LinearGradient driverGradient = LinearGradient(
    colors: [driver, Color(0xFF0F3D14)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Warm off-white screen background (Yatri UI)
  static const Color bgWarm = Color(0xFFFAF7F4);

  // Success — teal
  static const Color success = Color(0xFF0F6E56);
  static const Color successLight = Color(0xFFE1F5EE);

  // Warning — amber
  static const Color warning = Color(0xFF854F0B);
  static const Color warningLight = Color(0xFFFAEEDA);

  // Error — darker red, distinct from brand red
  static const Color error = Color(0xFFA32D2D);
  static const Color errorLight = Color(0xFFFCEBEB);

  // Neutrals
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF888888);
  static const Color textHint = Color(0xFFBBBBBB);
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderLight = Color(0xFFEEEEEE);
  static const Color background = Color(0xFFF8FAFC);
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF1A1A1A);

  // Star rating
  static const Color star = Color(0xFFF5A623);
}
