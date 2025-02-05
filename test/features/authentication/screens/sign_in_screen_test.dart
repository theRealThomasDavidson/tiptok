import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tiptok/features/authentication/screens/sign_in_screen.dart';
import 'package:tiptok/features/home/screens/home_screen.dart';
import '../../../setup/firebase_mock_setup.dart';

// Generate the mocks
class MockFirebaseAuth extends Mock implements FirebaseAuth {
  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return super.noSuchMethod(
      Invocation.method(
        #signInWithEmailAndPassword,
        [],
        {#email: email, #password: password},
      ),
      returnValue: Future.value(MockUserCredential()),
    );
  }
}

class MockUserCredential extends Mock implements UserCredential {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  
  late MockFirebaseAuth mockFirebaseAuth;
  late MockUserCredential mockCredential;

  setUp(() async {
    mockFirebaseAuth = MockFirebaseAuth();
    mockCredential = MockUserCredential();
  });

  testWidgets('SignInScreen shows all required elements', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: SignInScreen(auth: mockFirebaseAuth)));

    // Verify all the important widgets are present
    expect(find.text('TipTok'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
    expect(find.text('Don\'t have an account? Sign Up'), findsOneWidget);
  });

  testWidgets('SignInScreen handles successful login', (WidgetTester tester) async {
    // Mock successful sign in
    when(mockFirebaseAuth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'password123',
    )).thenAnswer((_) async => mockCredential);

    await tester.pumpWidget(MaterialApp(home: SignInScreen(auth: mockFirebaseAuth)));

    // Enter credentials
    await tester.enterText(
      find.byType(TextField).first, 
      'test@example.com'
    );
    await tester.enterText(
      find.byType(TextField).last, 
      'password123'
    );

    // Tap the sign in button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Verify navigation to home screen
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('SignInScreen handles login failure', (WidgetTester tester) async {
    // Mock failed sign in
    when(mockFirebaseAuth.signInWithEmailAndPassword(
      email: 'test@example.com',
      password: 'wrongpassword',
    )).thenThrow(
      FirebaseAuthException(code: 'wrong-password')
    );

    await tester.pumpWidget(MaterialApp(home: SignInScreen(auth: mockFirebaseAuth)));

    // Enter credentials
    await tester.enterText(
      find.byType(TextField).first, 
      'test@example.com'
    );
    await tester.enterText(
      find.byType(TextField).last, 
      'wrongpassword'
    );

    // Tap the sign in button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
    await tester.pumpAndSettle();

    // Verify error message
    expect(find.text('Wrong password provided'), findsOneWidget);
  });
} 