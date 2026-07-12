import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';

/// Leaf detail page for a single terms topic (e.g. "Ride Booking"). Reached
/// from the Terms & Conditions hub; content is passed in via the router `extra`
/// so one screen serves every terms sub-topic. Informational only — no backend.
class TermsDetailScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<String> bulletPoints;

  const TermsDetailScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bulletPoints,
  });

  @override
  Widget build(BuildContext context) {
    return InfoPageScaffold(
      title: title,
      subtitle: subtitle,
      children: [
        InfoSection(
          children: [
            for (final point in bulletPoints) InfoBullet(point),
          ],
        ),
      ],
    );
  }
}
