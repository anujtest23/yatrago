import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';

class SafetyScreen extends StatelessWidget {
  const SafetyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScaffold(
      title: 'Safety',
      subtitle: 'Your safety comes first',
      children: [
        InfoSection(
          title: 'Before your trip',
          icon: Icons.verified_user_outlined,
          children: [
            InfoBullet('Check the driver\'s rating and vehicle details.'),
            InfoBullet('Confirm the pickup point in the in-app chat.'),
            InfoBullet('Share your trip details with someone you trust.'),
          ],
        ),
        InfoSection(
          title: 'During your trip',
          icon: Icons.directions_car_outlined,
          children: [
            InfoBullet('Always wear your seatbelt.'),
            InfoBullet('Keep the app open to follow the route.'),
            InfoBullet('Trust your instincts — speak up if something feels off.'),
          ],
        ),
        InfoSection(
          title: 'Emergency',
          icon: Icons.emergency_outlined,
          children: [
            InfoParagraph(
              'In an emergency, contact local authorities immediately by '
              'dialing 100 (Police) or 102 (Ambulance). Emergency contacts and '
              'live trip sharing are coming soon.',
            ),
          ],
        ),
      ],
    );
  }
}
