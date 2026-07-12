import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/info_page_scaffold.dart';

/// "Full Privacy Policy" — leaf page reached from the Privacy Policy hub. Shows
/// a document/shield illustration (ported from the Yatri reference) above the
/// complete privacy text. Informational only, no backend.
class FullPrivacyPolicyScreen extends StatelessWidget {
  const FullPrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Full Privacy Policy',
      subtitle: 'View our complete Privacy Policy document.',
      children: [
        const SizedBox(height: 8),
        const Center(child: _PolicyIllustration()),
        const SizedBox(height: 24),
        const InfoSection(
          title: 'Information we collect',
          children: [
            InfoBullet('Your name and phone number for account verification.'),
            InfoBullet('Trip details — routes, dates, and bookings you make.'),
            InfoBullet('Approximate location to power search and the map.'),
            InfoBullet('Device information used to keep your account secure.'),
          ],
        ),
        const InfoSection(
          title: 'How we use it',
          children: [
            InfoParagraph(
              'We use your information to operate the ride-sharing service, '
              'match you with rides, process wallet transactions, and keep the '
              'platform safe. We never sell your personal data.',
            ),
          ],
        ),
        const InfoSection(
          title: 'Data sharing',
          children: [
            InfoParagraph(
              'Limited details (such as your first name and rating) are shared '
              'with the driver or passenger you are travelling with, only after '
              'a booking is confirmed.',
            ),
          ],
        ),
        const InfoSection(
          title: 'Your rights',
          children: [
            InfoBullet('Access and edit your profile at any time.'),
            InfoBullet('Request account deletion from Settings.'),
            InfoBullet('Contact support with any privacy questions.'),
          ],
        ),
      ],
    );
  }
}

/// Document + shield illustration ported from the Yatri Full Privacy Policy
/// reference, retinted to the YatraGo brand palette.
class _PolicyIllustration extends StatelessWidget {
  const _PolicyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight.withValues(alpha: 0.6),
            ),
          ),
          Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryLight,
            ),
          ),
          // Policy document card
          Positioned(
            top: 24,
            child: Container(
              width: 84,
              height: 112,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  _DocLine(48),
                  SizedBox(height: 8),
                  _DocLine(60),
                  SizedBox(height: 8),
                  _DocLine(40),
                  SizedBox(height: 8),
                  _DocLine(52),
                  SizedBox(height: 8),
                  _DocLine(32),
                ],
              ),
            ),
          ),
          // Shield overlay
          Positioned(
            bottom: 24,
            right: 28,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.security_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocLine extends StatelessWidget {
  final double width;
  const _DocLine(this.width);

  @override
  Widget build(BuildContext context) {
    return Container(width: width, height: 4, color: const Color(0xFFE2E8F0));
  }
}
