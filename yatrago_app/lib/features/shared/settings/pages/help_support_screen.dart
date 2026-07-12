import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/route_names.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Help & Support',
      subtitle: 'We\'re here to help',
      children: [
        SettingsCard(
          children: [
            SettingsTile(
              icon: Icons.help_outline_rounded,
              title: 'FAQ',
              subtitle: 'Answers to common questions',
              onTap: () => context.push(RouteNames.faq),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.shield_outlined,
              title: 'Safety',
              subtitle: 'Safety tips and emergency info',
              onTap: () => context.push(RouteNames.safety),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.mail_outline_rounded,
              title: 'Contact Us',
              subtitle: 'Reach our support team',
              comingSoon: true,
              onTap: () => context.push(
                RouteNames.comingSoon,
                extra: 'Contact Us',
              ),
            ),
            const SettingsDivider(),
            SettingsTile(
              icon: Icons.report_gmailerrorred_rounded,
              title: 'Report an Issue',
              subtitle: 'Tell us what went wrong',
              comingSoon: true,
              onTap: () => context.push(
                RouteNames.comingSoon,
                extra: 'Report an Issue',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const InfoSection(
          title: 'Reach us directly',
          icon: Icons.support_agent_rounded,
          children: [
            InfoParagraph('Email: support@yatrago.com'),
            InfoParagraph('Hours: Sun–Fri, 9:00 AM – 6:00 PM'),
          ],
        ),
      ],
    );
  }
}
