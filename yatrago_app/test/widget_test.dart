// Smoke test: verifies the app boots and renders its first route
// without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yatrago_app/main.dart';

void main() {
  testWidgets('YatraGoApp builds and shows the splash screen', (
    WidgetTester tester,
  ) async {
    dotenv.loadFromString(
      envString: 'BASE_URL=http://localhost:3000/api/v1',
    );

    await tester.pumpWidget(const ProviderScope(child: YatraGoApp()));
    expect(find.byType(MaterialApp), findsOneWidget);

    // Let the splash screen's delayed navigation timer fire and settle
    // so no pending timer leaks past the test.
    await tester.pump(const Duration(seconds: 3));
  });
}
