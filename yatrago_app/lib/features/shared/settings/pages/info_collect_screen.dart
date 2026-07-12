import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';
import '../widgets/settings_ui.dart';

/// "Information We Collect" — leaf page reached from the Privacy Policy hub.
/// Lists the categories of data the app collects. Informational only, no
/// backend; rows are non-interactive (no chevron/tap).
class InfoCollectScreen extends StatelessWidget {
  const InfoCollectScreen({super.key});

  static const _items = <_CollectItem>[
    _CollectItem(
      icon: Icons.person_outline_rounded,
      title: 'Personal Information',
      description: 'Name, phone number and profile details.',
    ),
    _CollectItem(
      icon: Icons.location_on_outlined,
      title: 'Location Information',
      description: 'Your location is used to match rides and ensure safety.',
    ),
    _CollectItem(
      icon: Icons.phone_android_outlined,
      title: 'Device Information',
      description: 'Device type, OS, unique IDs and app activity.',
    ),
    _CollectItem(
      icon: Icons.trending_up_rounded,
      title: 'Usage Information',
      description: 'How you use the app to help us improve your experience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: 'Information We Collect',
      subtitle:
          'We collect the following information to provide and improve our '
          'services.',
      children: [
        SettingsCard(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              SettingsTile(
                icon: _items[i].icon,
                title: _items[i].title,
                subtitle: _items[i].description,
                trailing: const SizedBox.shrink(),
              ),
              if (i < _items.length - 1) const SettingsDivider(),
            ],
          ],
        ),
      ],
    );
  }
}

class _CollectItem {
  final IconData icon;
  final String title;
  final String description;

  const _CollectItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
