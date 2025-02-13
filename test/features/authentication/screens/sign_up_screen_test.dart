import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:tiptok/features/authentication/screens/sign_up_screen.dart';
import '../../../setup/firebase_mock_setup.dart';
import '../../../setup/firebase_auth_mock_setup.mocks.dart';

// Mock HomeScreen for testing
class MockHomeScreen extends StatelessWidget {
  const MockHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('Mock Home Screen'),
      ),
    );
  }
}

@GenerateMocks([
  FirebaseAuth,
  UserCredential,
  User,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  
  late GeneratedMockFirebaseAuth mockAuth;
  late GeneratedMockUser mockUser;
  late GeneratedMockUserCredential mockCredential;

  setUp(() async {
    // Initialize Firebase before each test
    await setupFirebaseCoreMockPlatform();
    
    mockUser = GeneratedMockUser();
    mockCredential = GeneratedMockUserCredential();
    mockAuth = GeneratedMockFirebaseAuth();

    // Setup basic mock behavior
    when(mockCredential.user).thenReturn(mockUser);
    when(mockUser.email).thenReturn('test@example.com');
    when(mockUser.displayName).thenReturn(null);
    when(mockUser.updateDisplayName(any)).thenAnswer((_) => Future.value());

    when(mockAuth.createUserWithEmailAndPassword(
      email: anyNamed('email'),
      password: anyNamed('password'),
    )).thenAnswer((_) => Future.value(mockCredential));
    
    when(mockAuth.signInWithProvider(any)).thenAnswer((_) => Future.value(mockCredential));
    when(mockAuth.signOut()).thenAnswer((_) => Future.value());
    when(mockAuth.getRedirectResult()).thenAnswer((_) => Future.value(mockCredential));

    // Mock FirebaseAuth.instance
    when(FirebaseAuth.instance.getRedirectResult()).thenAnswer((_) => Future.value(mockCredential));
  });

  group('SignUpScreen UI Tests', () {
    testWidgets('shows all required form fields', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: SignUpScreen(auth: mockAuth),
      ));

      expect(find.widgetWithText(AppBar, 'Sign Up'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Display Name'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Confirm Password'), findsOneWidget);
      
      // Verify exactly which buttons are present
      expect(find.widgetWithText(ElevatedButton, 'Sign Up'), findsOneWidget); // Main sign up button
      expect(find.text('GitHub'), findsOneWidget); // GitHub button text
      expect(find.byIcon(Icons.code), findsOneWidget); // GitHub button icon
      
      // Verify that Google and Phone sign up are NOT present
      expect(find.text('Google'), findsNothing);
      expect(find.byIcon(Icons.g_translate), findsNothing);
      expect(find.text('Phone'), findsNothing);
      expect(find.text('Use Phone Number Instead'), findsNothing);
    });

    testWidgets('validates empty display name', (tester) async {
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Leave display name empty but fill other fields
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle(); // Wait for all animations

      expect(find.text('Please enter a display name'), findsOneWidget);
    });

    testWidgets('validates password matching', (tester) async {
      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Fill form with mismatched passwords
      await tester.enterText(find.widgetWithText(TextField, 'Display Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'password456');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle(); // Wait for all animations

      expect(find.text('Passwords do not match'), findsOneWidget);
    });
  });

  group('SignUpScreen Email/Password Tests', () {
    testWidgets('handles successful signup', (tester) async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockCredential);

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
        routes: {
          '/home': (context) => const MockHomeScreen(),
        },
      ));

      // Fill form with valid data
      await tester.enterText(find.widgetWithText(TextField, 'Display Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pumpAndSettle(); // Wait for all animations

      verify(mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
      
      expect(find.byType(MockHomeScreen), findsOneWidget);
    });

    testWidgets('handles weak password error', (tester) async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'test@example.com',
        password: 'weak',
      )).thenThrow(
        FirebaseAuthException(code: 'weak-password', message: 'The password provided is too weak'),
      );

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Fill form with weak password
      await tester.enterText(find.widgetWithText(TextField, 'Display Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'test@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'weak');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'weak');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump(); // Start the frame
      await tester.pump(const Duration(milliseconds: 50)); // Wait for error state

      expect(find.text('The password provided is too weak'), findsOneWidget);
    });

    testWidgets('handles email already in use error', (tester) async {
      when(mockAuth.createUserWithEmailAndPassword(
        email: 'existing@example.com',
        password: 'password123',
      )).thenThrow(
        FirebaseAuthException(code: 'email-already-in-use', message: 'An account already exists for that email'),
      );

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Fill form with existing email
      await tester.enterText(find.widgetWithText(TextField, 'Display Name'), 'Test User');
      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'existing@example.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'password123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Up'));
      await tester.pump(); // Start the frame
      await tester.pump(const Duration(milliseconds: 50)); // Wait for error state

      expect(find.text('An account already exists for that email'), findsOneWidget);
    });
  });

  group('SignUpScreen GitHub Tests', () {
    testWidgets('shows loading state during GitHub signup', (tester) async {
      final completer = Completer<UserCredential>();
      when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Find and tap the GitHub button
      final githubButton = find.byIcon(Icons.code);
      expect(githubButton, findsOneWidget);
      
      await tester.tap(githubButton);
      await tester.pump(); // Start the frame
      await tester.pump(const Duration(milliseconds: 50)); // Wait for loading state

      // Verify loading state
      expect(find.text('Signing up...'), findsOneWidget);
      
      // Find the loading indicator with specific properties
      final loadingIndicator = find.byWidgetPredicate(
        (widget) => widget is CircularProgressIndicator && 
                    widget.valueColor is AlwaysStoppedAnimation<Color> &&
                    (widget.valueColor as AlwaysStoppedAnimation<Color>).value == Colors.white
      );
      expect(loadingIndicator, findsOneWidget);

      completer.complete(mockCredential);
      await tester.pump(); // Process the completion
      await tester.pump(); // Process the overlay dismissal
      await tester.pump(const Duration(seconds: 2)); // Wait for SnackBar and navigation
    });

    testWidgets('handles successful GitHub signup', (tester) async {
      final completer = Completer<UserCredential>();
      when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
        routes: {
          '/home': (context) => const MockHomeScreen(),
        },
      ));

      // Find and tap the GitHub button
      final githubButton = find.byIcon(Icons.code);
      expect(githubButton, findsOneWidget);
      
      await tester.tap(githubButton);
      await tester.pump(); // Start the frame
      await tester.pump(const Duration(milliseconds: 50)); // Wait for loading state

      // Verify loading state
      expect(find.text('Signing up...'), findsOneWidget);

      completer.complete(mockCredential);
      await tester.pump(); // Process the completion
      await tester.pump(); // Process the overlay dismissal
      await tester.pump(const Duration(seconds: 2)); // Wait for dialog dismissal
      await tester.pump(); // Process dialog dismissal
      await tester.pump(); // Process any pending frames

      // Wait for SnackBar
      await tester.pump(const Duration(seconds: 1));

      // Verify success message in SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('Account created successfully'),
      ), findsOneWidget);

      // Wait for navigation
      await tester.pump(const Duration(seconds: 1));

      // Verify we're on the home screen
      expect(find.byType(MockHomeScreen), findsOneWidget);
    });

    testWidgets('handles GitHub signup error - not enabled', (tester) async {
      when(mockAuth.signInWithProvider(any)).thenThrow(
        FirebaseAuthException(code: 'operation-not-allowed', message: 'GitHub sign up is not enabled'),
      );

      await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: GlobalKey<ScaffoldMessengerState>(),
        home: SignUpScreen(auth: mockAuth),
      ));

      // Find and tap the GitHub button
      final githubButton = find.byIcon(Icons.code);
      expect(githubButton, findsOneWidget);
      
      await tester.tap(githubButton);
      await tester.pump(); // Start the frame
      await tester.pump(); // Process the error
      await tester.pump(const Duration(seconds: 2)); // Wait for dialog dismissal
      await tester.pump(); // Process dialog dismissal
      await tester.pump(); // Process any pending frames

      // Wait for SnackBar
      await tester.pump(const Duration(seconds: 1));

      // Verify error message in SnackBar
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.descendant(
        of: find.byType(SnackBar),
        matching: find.text('GitHub sign up is not enabled. Please contact support.'),
      ), findsOneWidget);
      
      // Verify we're still on the signup screen
      expect(find.byType(SignUpScreen), findsOneWidget);
    });
  });
} 