import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// Privacy Policy hub — a card of tappable topics, each opening a leaf detail
/// page. Visual pattern ported from the Yatri reference. All rows are static
/// except "Delete Account & Data", which routes into YatraGo's existing
/// production account-deletion flow (not a mock).
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Privacy Policy',
      subtitle: 'We are committed to protecting your privacy and data.',
      footer: const InfoFooterButton(label: 'Got It'),
      children: [
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.assignment_ind_outlined,
              title: 'Information We Collect',
              subtitle: 'The data we collect from you.',
              onTap: () => context.push(RouteNames.infoCollect),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.verified_user_outlined,
              title: 'How We Protect Your Data',
              subtitle: 'Security measures we follow.',
              onTap: () => context.push(
                RouteNames.privacyDetail,
                extra: const {
                  'title': 'How We Protect Your Data',
                  'subtitle': 'Security measures we follow.',
                  'bullets': [
                    'All personal information is encrypted during transit and '
                        'at rest.',
                    'We run regular vulnerability scans and safety assessments.',
                    'Access to user details is restricted to authorized '
                        'personnel only.',
                    'We comply with recognised data security standards.',
                  ],
                },
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.share_outlined,
              title: 'When We Share Information',
              subtitle: 'When and why we share data.',
              onTap: () => context.push(
                RouteNames.privacyDetail,
                extra: const {
                  'title': 'When We Share Information',
                  'subtitle': 'When and why we share data.',
                  'bullets': [
                    'We share pickup locations and contact info with your '
                        'driver or passenger to facilitate the ride.',
                    'We may share data with legal authorities if required by '
                        'law.',
                    'Aggregated, non-personal data is used to analyse usage '
                        'patterns.',
                    'We do not sell your personal data to advertisers or third '
                        'parties.',
                  ],
                },
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.no_accounts_outlined,
              title: 'Delete Account & Data',
              subtitle: 'How you can delete your data.',
              onTap: () => context.push(
                RouteNames.deleteAccount,
                extra: RouteNames.privacyPolicy,
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.privacy_tip_outlined,
              title: 'Full Privacy Policy',
              subtitle: 'Read the complete policy.',
              onTap: () => context.push(RouteNames.fullPrivacyPolicy),
            ),
          ],
        ),
      ],
    );
  }
}
