import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScaffold(
      title: 'Terms & Conditions',
      subtitle: 'Last updated: July 2026',
      children: [
        InfoSection(
          title: '1. Acceptance',
          children: [
            InfoParagraph(
              'By creating an account and using YatraGo, you agree to these '
              'terms. If you do not agree, please discontinue use of the app.',
            ),
          ],
        ),
        InfoSection(
          title: '2. Ride-sharing service',
          children: [
            InfoParagraph(
              'YatraGo is a platform that connects drivers and passengers. '
              'YatraGo is not a transport carrier; drivers are independent and '
              'responsible for their vehicles and conduct.',
            ),
          ],
        ),
        InfoSection(
          title: '3. Payments & wallet',
          children: [
            InfoBullet('Passengers pay the per-seat fare set by the driver.'),
            InfoBullet(
                'Drivers maintain a wallet balance for platform commission.'),
            InfoBullet('Top-ups are processed through eSewa and are final.'),
          ],
        ),
        InfoSection(
          title: '4. User conduct',
          children: [
            InfoParagraph(
              'You agree to provide accurate information, treat other users '
              'respectfully, and comply with all applicable laws. Accounts may '
              'be suspended for misuse or fraudulent activity.',
            ),
          ],
        ),
        InfoSection(
          title: '5. Liability',
          children: [
            InfoParagraph(
              'YatraGo provides the platform "as is" and is not liable for '
              'disputes, delays, or incidents arising between users during a '
              'trip, to the extent permitted by law.',
            ),
          ],
        ),
      ],
    );
  }
}
