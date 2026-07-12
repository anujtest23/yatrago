import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';

/// Shared Settings UI kit — the single source of truth for the Yatri settings
/// design language (red dash-diamond header, white rounded cards, icon tiles).
/// Every settings/info sub-page composes these instead of duplicating markup.

// ════════════════════════════════════════════════════════════════
// HEADER — back button + centered title + red dash-diamond divider
// ════════════════════════════════════════════════════════════════
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Accent for the title/divider. Defaults to the passenger red; pass
  /// [AppColors.driver] to render the driver (green) variant.
  final Color accent;
  final VoidCallback? onBack;

  const SettingsPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.accent = AppColors.primary,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            onTap: onBack ?? () => context.pop(),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: accent,
                size: 18,
              ),
            ),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            _DashDiamond(accent: accent),
            if (subtitle != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _DashDiamond extends StatelessWidget {
  final Color accent;
  const _DashDiamond({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(width: 32, height: 1.5, color: accent),
        const SizedBox(width: 8),
        Transform.rotate(
          angle: 45 * math.pi / 180,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              border: Border.all(color: accent, width: 1.5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(width: 32, height: 1.5, color: accent),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════
// CARD — white rounded container with soft shadow
// ════════════════════════════════════════════════════════════════
class SettingsCard extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  const SettingsCard({super.key, required this.children, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// Thin inset divider between tiles.
class SettingsDivider extends StatelessWidget {
  const SettingsDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      color: Color(0xFFF1F5F9),
      indent: 16,
      endIndent: 16,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TILE — icon square + title + subtitle + trailing/chevron
// ════════════════════════════════════════════════════════════════
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color accent;

  /// Renders the title in the accent colour (used for destructive actions).
  final bool isDestructive;

  /// Shows a "Coming Soon" pill and dims the row. Tap is still allowed so the
  /// destination can explain the disabled state.
  final bool comingSoon;

  /// Optional trailing widget (e.g. a version string) replacing the chevron.
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.accent = AppColors.primary,
    this.isDestructive = false,
    this.comingSoon = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: comingSoon ? 0.6 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accent, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDestructive
                                  ? accent
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (comingSoon) ...[
                          const SizedBox(width: 8),
                          _ComingSoonPill(accent: accent),
                        ],
                      ],
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(Icons.chevron_right_rounded, color: accent, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComingSoonPill extends StatelessWidget {
  final Color accent;
  const _ComingSoonPill({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Soon',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: accent,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Small caption above a group of cards (e.g. "ACCOUNT").
class SettingsSectionLabel extends StatelessWidget {
  final String label;
  const SettingsSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8, top: 4),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF94A3B8),
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
