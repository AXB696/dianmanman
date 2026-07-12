import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_charge/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SmartChargeV2App());
    await tester.pumpAndSettle();

    // Verify that MaterialApp is loaded
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}



