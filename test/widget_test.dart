// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tiptok/main.dart';
import 'package:tiptok/features/authentication/screens/sign_in_screen.dart';
import 'setup/firebase_mock_setup.dart';

void main() {
  setupFirebaseCoreMocks();
  setupFirebaseCoreMockPlatform();

  testWidgets('App loads and shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Verify that the login screen is shown
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.text('TipTok'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
  });
}
