import 'package:flutter/material.dart';
import '../widgets/info_page_scaffold.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const InfoPageScaffold(
      title: 'FAQ',
      subtitle: 'Frequently asked questions',
      children: [
        FaqItem(
          question: 'How do I book a ride?',
          answer:
              'Search your route from the home screen, pick a ride that suits '
              'you, choose your seats, and confirm. The driver is notified '
              'instantly and you can chat once the booking is accepted.',
        ),
        FaqItem(
          question: 'How is the price calculated?',
          answer:
              'Drivers set a fixed price per seat when they publish a ride. '
              'The total you pay is simply the per-seat price multiplied by '
              'the number of seats you book — no surge, no hidden charges.',
        ),
        FaqItem(
          question: 'Can I cancel a booking?',
          answer:
              'Yes. Open the booking in My Rides and tap Cancel. Cancelling '
              'well before departure avoids any charge; cancelling close to '
              'departure may affect your rating.',
        ),
        FaqItem(
          question: 'How do I become a driver?',
          answer:
              'Switch to Driver mode from Settings and complete verification '
              '(license, vehicle, and documents). Once approved, you can '
              'publish rides and start earning.',
        ),
        FaqItem(
          question: 'How does the wallet work?',
          answer:
              'Drivers maintain a wallet balance used for platform commission '
              'when a ride is booked. Top up securely via eSewa from the '
              'Wallet screen.',
        ),
        FaqItem(
          question: 'Is my phone number safe?',
          answer:
              'Your number is used only for verification and ride coordination. '
              'In-app chat means you never have to share personal contact '
              'details until you choose to.',
        ),
      ],
    );
  }
}
