import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mainnfc/main.dart'; // Update with your app's actual package name

void main() {
  testWidgets('Login screen loads and has email & password fields', (
    WidgetTester tester,
  ) async {
    // Build the app
    await tester.pumpWidget(const NFCApp());

    // Look for login screen widgets
    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
    expect(find.text('Login'), findsOneWidget);
  });
}
