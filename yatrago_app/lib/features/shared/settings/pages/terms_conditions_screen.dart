import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// Terms & Conditions hub — a card of tappable topics, each opening a leaf
/// detail page of bullet points. Visual pattern ported from the Yatri
/// reference. Informational only, no backend.
class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  static const _detailSubtitle =
      'By using our app, you agree to the following terms and conditions.';

  static const _sections = <_TermsSection>[
    _TermsSection(
      icon: Icons.article_outlined,
      title: 'Using the App',
      subtitle: 'Rules for using our platform.',
      bullets: [
        'You must be at least 18 years old to use our services.',
        'You agree to provide accurate and up-to-date information.',
        'You are responsible for maintaining the confidentiality of your '
            'account.',
        'We reserve the right to update or modify these terms at any time.',
        'Continued use of the app means you accept the updated terms.',
      ],
    ),
    _TermsSection(
      icon: Icons.directions_car_outlined,
      title: 'Ride Booking',
      subtitle: 'Terms related to ride bookings.',
      bullets: [
        'You agree to book rides only when you intend to travel.',
        'You must provide correct pickup and drop-off destinations.',
        'You must respect the driver and their vehicle at all times.',
        'Fares are set per seat by the driver for the published route.',
        'You agree to pay the fare shown at the time of booking.',
      ],
    ),
    _TermsSection(
      icon: Icons.payment_outlined,
      title: 'Payments & Wallet',
      subtitle: 'Payment methods, charges and refunds.',
      bullets: [
        'Wallet top-ups are processed securely through eSewa.',
        'Drivers maintain a wallet balance for platform commission.',
        'Refunds are processed in accordance with our cancellation policy.',
        'Any payment disputes must be reported within 7 days of the ride.',
        'Promo codes are subject to specific terms and expiration dates.',
      ],
    ),
    _TermsSection(
      icon: Icons.cancel_outlined,
      title: 'Cancellation Policy',
      subtitle: 'Rules for cancelling a booking.',
      bullets: [
        'You can cancel a booking before a driver accepts it without a fee.',
        'A cancellation fee may apply if you cancel after a driver accepts.',
        'If a driver cancels after accepting, you will not be charged.',
        'Frequent cancellations may lead to account suspension.',
        'Cancellation fees are credited to the driver for their time.',
      ],
    ),
    _TermsSection(
      icon: Icons.person_outlined,
      title: 'User Responsibilities',
      subtitle: 'Your responsibilities while using the app.',
      bullets: [
        'You must follow all local traffic laws and safety regulations.',
        "You are responsible for any damage caused to the driver's vehicle.",
        'Do not engage in abusive, threatening, or illegal behaviour.',
        'Report any safety concerns or incidents immediately.',
        'Keep your account credentials secure and do not share them.',
      ],
    ),
    _TermsSection(
      icon: Icons.gavel_outlined,
      title: 'Full Terms & Conditions',
      subtitle: 'Read the complete terms.',
      bullets: [
        'These terms represent the entire agreement between you and YatraGo.',
        'We reserve the right to suspend accounts that violate these terms.',
        'All content, logos, and software are the property of YatraGo.',
        'We are not liable for indirect or consequential damages.',
        "These terms are governed by the local jurisdiction's laws.",
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Terms & Conditions',
      subtitle: 'Please read our terms and conditions carefully.',
      footer: const InfoFooterButton(label: 'I Understand'),
      children: [
        SettingsCard(
          children: [
            for (var i = 0; i < _sections.length; i++) ...[
              SettingsTile(
                icon: _sections[i].icon,
                title: _sections[i].title,
                subtitle: _sections[i].subtitle,
                onTap: () => context.push(
                  RouteNames.termsDetail,
                  extra: {
                    'title': _sections[i].title,
                    'subtitle': _detailSubtitle,
                    'bullets': _sections[i].bullets,
                  },
                ),
              ),
              if (i < _sections.length - 1) const SettingsDivider(),
            ],
          ],
        ),
      ],
    );
  }
}

class _TermsSection {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> bullets;

  const _TermsSection({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });
}
