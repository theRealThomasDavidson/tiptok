import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tiptok/features/authentication/screens/sign_in_screen.dart';
import 'auth_screen_test.mocks.dart';
import 'dart:async';

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
  GithubAuthProvider,
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockCredential;
  late MockUser mockUser;
  late MockGithubAuthProvider mockGithubProvider;

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockCredential = MockUserCredential();
    mockUser = MockUser();
    mockGithubProvider = MockGithubAuthProvider();

    when(mockCredential.user).thenReturn(mockUser);
    when(mockUser.email).thenReturn('test@example.com');
  });

  group('SignInScreen', () {
    testWidgets('shows form fields and signin buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(auth: mockAuth),
        ),
      );

      expect(find.byType(TextField), findsNWidgets(2)); // Email and password
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text('GitHub'), findsOneWidget);
    });

    testWidgets('validates empty fields', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(auth: mockAuth),
        ),
      );

      // Enter empty values
      await tester.enterText(find.byKey(const Key('email')), '');
      await tester.enterText(find.byKey(const Key('password')), '');
      
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for SnackBar

      expect(find.text('Please enter an email'), findsOneWidget);
    });

    testWidgets('handles successful email signin', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(auth: mockAuth),
          routes: {
            '/home': (context) => const MockHomeScreen(),
          },
        ),
      );

      when(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenAnswer((_) async => mockCredential);

      await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      verify(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).called(1);
      expect(find.byType(MockHomeScreen), findsOneWidget);
    });

    testWidgets('handles signin error', (tester) async {
      when(mockAuth.signInWithEmailAndPassword(
        email: 'test@example.com',
        password: 'password123',
      )).thenThrow(FirebaseAuthException(code: 'wrong-password'));

      await tester.pumpWidget(
        MaterialApp(
          home: SignInScreen(auth: mockAuth),
        ),
      );

      await tester.enterText(find.byKey(const Key('email')), 'test@example.com');
      await tester.enterText(find.byKey(const Key('password')), 'password123');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1)); // Wait for SnackBar

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Wrong password provided'), findsOneWidget);
    });

    group('GitHub Authentication', () {
      testWidgets('shows loading state during GitHub signin', (tester) async {
        // Create a completer to control when the sign-in completes
        final signInCompleter = Completer<UserCredential>();
        
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );

        when(mockAuth.signInWithProvider(any))
            .thenAnswer((_) => signInCompleter.future);

        // Initial state - button should be enabled
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Tap the GitHub button
        await tester.tap(find.text('GitHub'));
        await tester.pump(); // Process the tap

        // Verify loading state
        expect(find.text('Signing in...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the sign-in
        signInCompleter.complete(mockCredential);
        await tester.pumpAndSettle();

        // Verify navigation
        expect(find.byType(MockHomeScreen), findsOneWidget);
      });

      testWidgets('handles successful GitHub signin', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );

        when(mockAuth.signInWithProvider(any))
            .thenAnswer((_) async {
              await Future.delayed(const Duration(milliseconds: 100));
              return mockCredential;
            });

        // Initial state
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // Tap the button
        await tester.tap(find.text('GitHub'));
        await tester.pump(); // Process the tap
        
        // Verify loading state appears
        expect(find.text('Signing in...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        verify(mockAuth.signInWithProvider(any)).called(1);
        expect(find.byType(MockHomeScreen), findsOneWidget);
      });

      testWidgets('handles GitHub signin error - not enabled', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
          ),
        );

        when(mockAuth.signInWithProvider(any))
            .thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));

        // Initial state
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        await tester.tap(find.text('GitHub'));
        await tester.pump(); // Process the tap
        
        // Should show loading state briefly
        expect(find.text('Signing in...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pump(); // Process the error
        await tester.pump(const Duration(seconds: 1)); // Wait for SnackBar

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('GitHub sign in is not enabled'), findsOneWidget);

        // Should return to initial state
        expect(find.text('GitHub'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('handles GitHub signin error - account exists', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
          ),
        );

        when(mockAuth.signInWithProvider(any))
            .thenThrow(FirebaseAuthException(
              code: 'account-exists-with-different-credential'
            ));

        await tester.tap(find.text('GitHub'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1)); // Wait for SnackBar

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('An account already exists with this email'), findsOneWidget);
      });
    });
  });
} 