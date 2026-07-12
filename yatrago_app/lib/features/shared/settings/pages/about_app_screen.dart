import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/info_page_scaffold.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'About App',
      subtitle: 'Learn more about YatraGo',
      children: [
        Center(
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.primary,
                  size: 44,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'YatraGo',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Version 1.0.0',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const InfoSection(
          title: 'Our Mission',
          icon: Icons.flag_rounded,
          children: [
            InfoParagraph(
              'YatraGo connects drivers with empty seats to passengers heading '
              'the same way — making intercity travel across Nepal more '
              'affordable, social, and sustainable.',
            ),
          ],
        ),
        const InfoSection(
          title: 'What we offer',
          icon: Icons.star_rounded,
          children: [
            InfoBullet('Verified drivers and secure phone-based sign-in.'),
            InfoBullet('Transparent per-seat pricing with no hidden fees.'),
            InfoBullet('In-app chat between drivers and passengers.'),
            InfoBullet('Wallet top-ups and trip history at your fingertips.'),
          ],
        ),
        const InfoSection(
          title: 'Get in touch',
          icon: Icons.mail_outline_rounded,
          children: [
            InfoParagraph('support@yatrago.com'),
            InfoParagraph('Kathmandu, Nepal'),
          ],
        ),
      ],
    );
  }
}
