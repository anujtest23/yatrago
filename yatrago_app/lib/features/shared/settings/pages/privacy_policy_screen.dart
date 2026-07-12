import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScaffold(
      title: 'Privacy Policy',
      subtitle: 'Last updated: July 2026',
      children: [
        InfoSection(
          title: 'Information we collect',
          children: [
            InfoBullet('Your name and phone number for account verification.'),
            InfoBullet('Trip details — routes, dates, and bookings you make.'),
            InfoBullet('Approximate location to power search and the map.'),
            InfoBullet('Device information used to keep your account secure.'),
          ],
        ),
        InfoSection(
          title: 'How we use it',
          children: [
            InfoParagraph(
              'We use your information to operate the ride-sharing service, '
              'match you with rides, process wallet transactions, and keep the '
              'platform safe. We never sell your personal data.',
            ),
          ],
        ),
        InfoSection(
          title: 'Data sharing',
          children: [
            InfoParagraph(
              'Limited details (such as your first name and rating) are shared '
              'with the driver or passenger you are travelling with, only after '
              'a booking is confirmed.',
            ),
          ],
        ),
        InfoSection(
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
