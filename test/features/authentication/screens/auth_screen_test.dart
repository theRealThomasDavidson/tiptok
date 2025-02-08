import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tiptok/features/authentication/screens/sign_in_screen.dart';
import '../../../setup/firebase_mock_setup.dart';
import 'dart:async';
import 'auth_screen_test.mocks.dart';
import 'package:firebase_core/firebase_core.dart';

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
  ConfirmationResult,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  
  late MockFirebaseAuth mockAuth;
  late MockUserCredential mockCredential;
  late MockUser mockUser;
  late MockConfirmationResult mockConfirmationResult;

  setUpAll(() async {
    await setupFirebaseCoreMockPlatform();
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockCredential = MockUserCredential();
    mockUser = MockUser();
    mockConfirmationResult = MockConfirmationResult();

    when(mockCredential.user).thenReturn(mockUser);
    when(mockUser.email).thenReturn('test@example.com');
    when(mockConfirmationResult.confirm(any)).thenAnswer((_) async => mockCredential);
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
        final completer = Completer<UserCredential>();
        when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );
        await tester.pumpAndSettle();

        final githubButton = find.byIcon(Icons.code);
        expect(githubButton, findsOneWidget);

        await tester.tap(githubButton);
        await tester.pump(); // Start the loading animation

        // Verify loading overlay is shown
        expect(find.text('Signing in...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Complete the sign-in process
        completer.complete(mockCredential);
        await tester.pumpAndSettle();
      });

      testWidgets('handles successful GitHub signin', (tester) async {
        final completer = Completer<UserCredential>();
        when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );
        await tester.pumpAndSettle();

        final githubButton = find.byIcon(Icons.code);
        expect(githubButton, findsOneWidget);

        await tester.tap(githubButton);
        await tester.pump(); // Start the loading animation

        // Complete the sign-in process immediately
        completer.complete(mockCredential);
        await tester.pumpAndSettle();

        verify(mockAuth.signInWithProvider(any)).called(1);
        expect(find.byType(MockHomeScreen), findsOneWidget);
      });

      testWidgets('handles GitHub signin error - not enabled', (tester) async {
        when(mockAuth.signInWithProvider(any)).thenThrow(
          FirebaseAuthException(code: 'operation-not-allowed', message: 'GitHub sign in is not enabled'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );
        await tester.pumpAndSettle();

        final githubButton = find.byIcon(Icons.code);
        expect(githubButton, findsOneWidget);

        await tester.tap(githubButton);
        await tester.pumpAndSettle(); // Wait for error handling

        expect(find.text('GitHub sign in is not enabled'), findsOneWidget);
      });

      testWidgets('handles GitHub signin error - account exists', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
          ),
        );
        await tester.pumpAndSettle();

        when(mockAuth.signInWithProvider(any))
            .thenThrow(FirebaseAuthException(
              code: 'account-exists-with-different-credential',
              message: 'An account already exists with this email'
            ));

        final githubButton = find.byIcon(Icons.code);
        expect(githubButton, findsOneWidget);

        await tester.tap(githubButton);
        await tester.pumpAndSettle(); // Wait for error handling

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('An account already exists with this email'), findsOneWidget);
      });
    });

    group('SignInScreen Google Authentication', () {
      testWidgets('shows loading state during Google signin', (tester) async {
        final completer = Completer<UserCredential>();
        when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

        await tester.pumpWidget(MaterialApp(
          home: SignInScreen(
            auth: mockAuth,
          ),
        ));

        await tester.tap(find.byKey(const Key('google-signin')));
        await tester.pump();

        expect(find.text('Signing in with Google...'), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        completer.complete(mockCredential);
        await tester.pumpAndSettle();
      });

      testWidgets('handles successful Google signin', (tester) async {
        final completer = Completer<UserCredential>();
        when(mockAuth.signInWithProvider(any)).thenAnswer((_) => completer.future);

        await tester.pumpWidget(MaterialApp(
          home: SignInScreen(
            auth: mockAuth,
          ),
          routes: {
            '/home': (context) => const Scaffold(body: Text('Home Screen')),
          },
        ));

        await tester.tap(find.byKey(const Key('google-signin')));
        await tester.pump();

        completer.complete(mockCredential);
        await tester.pumpAndSettle();

        verify(mockAuth.signInWithProvider(any)).called(1);
        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('handles Google signin error - not enabled', (tester) async {
        when(mockAuth.signInWithProvider(any)).thenThrow(
          FirebaseAuthException(code: 'operation-not-allowed', message: 'Google sign in is not enabled'),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
            routes: {
              '/home': (context) => const MockHomeScreen(),
            },
          ),
        );
        await tester.pumpAndSettle();

        final googleButton = find.byIcon(Icons.g_translate);
        expect(googleButton, findsOneWidget);

        await tester.tap(googleButton);
        await tester.pumpAndSettle();

        expect(find.text('Google sign in is not enabled'), findsOneWidget);
      });
    });

    group('Phone Authentication', () {
      testWidgets('accepts phone number input', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(auth: mockAuth),
          ),
        );

        // Enter a phone number in the email field
        await tester.enterText(find.byKey(const Key('email')), '+1234567890');
        expect(find.text('+1234567890'), findsOneWidget);
      });

      testWidgets('shows loading state during phone verification',
          (tester) async {
        final completer = Completer<void>();
        
        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          codeAutoRetrievalTimeout: anyNamed('codeAutoRetrievalTimeout'),
        )).thenAnswer((_) => completer.future);

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(
              auth: mockAuth,
            ),
          ),
        );

        // Ensure the toggle button is visible
        await tester.ensureVisible(find.text('Use Phone Number Instead'));
        await tester.pump();
        
        // Switch to phone mode
        await tester.tap(find.text('Use Phone Number Instead'));
        await tester.pump();

        // Ensure the phone field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('phone')));
        await tester.pump();
        
        await tester.enterText(
            find.byKey(const ValueKey('phone')), '+1234567890');
        await tester.pump();
        
        // Ensure the send code button is visible
        await tester.ensureVisible(find.text('Send Code'));
        await tester.pump();
        
        await tester.tap(find.text('Send Code'));
        await tester.pumpAndSettle();

        expect(find.text('Verifying phone number...'), findsOneWidget);
        verifyCompleter.complete();
        await tester.pumpAndSettle();

        // Ensure the verification code field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('verification-code')));
        await tester.pump();
        
        // Enter verification code
        await tester.enterText(
            find.byKey(const ValueKey('verification-code')), '123456');
        await tester.pump();
        
        // Ensure the verify button is visible
        await tester.ensureVisible(find.text('Verify'));
        await tester.pump();
        
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(find.text('Verifying code...'), findsOneWidget);
        signInCompleter.complete(mockCredential);
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('handles successful phone verification', (tester) async {
        String? verificationId;
        final verifyCompleter = Completer<void>();
        final signInCompleter = Completer<UserCredential>();

        // Setup verifyPhoneNumber mock
        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          codeAutoRetrievalTimeout: anyNamed('codeAutoRetrievalTimeout'),
        )).thenAnswer((invocation) {
          final codeSent = invocation.namedArguments[const Symbol('codeSent')] as PhoneCodeSent;
          verificationId = 'test-verification-id';
          codeSent(verificationId!, null);
          return verifyCompleter.future;
        });

        // Setup signInWithCredential mock
        when(mockAuth.signInWithCredential(any))
            .thenAnswer((_) => signInCompleter.future);

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(
              auth: mockAuth,
            ),
            routes: {
              '/home': (context) => const Scaffold(body: Text('Home Screen')),
            },
          ),
        );

        // Ensure the toggle button is visible
        await tester.ensureVisible(find.text('Use Phone Number Instead'));
        await tester.pump();
        
        // Switch to phone mode
        await tester.tap(find.text('Use Phone Number Instead'));
        await tester.pump();

        // Ensure the phone field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('phone')));
        await tester.pump();
        
        // Enter phone number
        await tester.enterText(
            find.byKey(const ValueKey('phone')), '+1234567890');
        await tester.pump();
        
        // Ensure the send code button is visible
        await tester.ensureVisible(find.text('Send Code'));
        await tester.pump();
        
        await tester.tap(find.text('Send Code'));
        await tester.pumpAndSettle();

        expect(find.text('Verifying phone number...'), findsOneWidget);
        verifyCompleter.complete();
        await tester.pumpAndSettle();

        // Ensure the verification code field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('verification-code')));
        await tester.pump();
        
        // Enter verification code
        await tester.enterText(
            find.byKey(const ValueKey('verification-code')), '123456');
        await tester.pump();
        
        // Ensure the verify button is visible
        await tester.ensureVisible(find.text('Verify'));
        await tester.pump();
        
        await tester.tap(find.text('Verify'));
        await tester.pumpAndSettle();

        expect(find.text('Verifying code...'), findsOneWidget);
        signInCompleter.complete(mockCredential);
        await tester.pumpAndSettle();

        expect(find.text('Home Screen'), findsOneWidget);
      });

      testWidgets('handles invalid phone number error', (tester) async {
        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          codeAutoRetrievalTimeout: anyNamed('codeAutoRetrievalTimeout'),
        )).thenAnswer((invocation) async {
          final verificationFailed = invocation.namedArguments[const Symbol('verificationFailed')] 
              as PhoneVerificationFailed;
          verificationFailed(FirebaseAuthException(
            code: 'invalid-phone-number',
            message: 'Invalid phone number',
          ));
        });

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(
              auth: mockAuth,
            ),
          ),
        );

        // Ensure the toggle button is visible
        await tester.ensureVisible(find.text('Use Phone Number Instead'));
        await tester.pump();
        
        // Switch to phone mode
        await tester.tap(find.text('Use Phone Number Instead'));
        await tester.pump();

        // Ensure the phone field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('phone')));
        await tester.pump();
        
        await tester.enterText(
            find.byKey(const ValueKey('phone')), 'not-a-phone-number');
        await tester.pump();
        
        // Ensure the send code button is visible
        await tester.ensureVisible(find.text('Send Code'));
        await tester.pump();
        
        await tester.tap(find.text('Send Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); // Wait for dialog animation

        expect(find.text('Invalid phone number'), findsOneWidget);
      });

      testWidgets('handles invalid verification code error', (tester) async {
        String? verificationId;
        final verifyCompleter = Completer<void>();

        when(mockAuth.verifyPhoneNumber(
          phoneNumber: anyNamed('phoneNumber'),
          verificationCompleted: anyNamed('verificationCompleted'),
          verificationFailed: anyNamed('verificationFailed'),
          codeSent: anyNamed('codeSent'),
          codeAutoRetrievalTimeout: anyNamed('codeAutoRetrievalTimeout'),
        )).thenAnswer((invocation) {
          final codeSent = invocation.namedArguments[const Symbol('codeSent')] as PhoneCodeSent;
          verificationId = 'test-verification-id';
          codeSent(verificationId!, null);
          return verifyCompleter.future;
        });

        when(mockAuth.signInWithCredential(any))
            .thenThrow(FirebaseAuthException(
              code: 'invalid-verification-code',
              message: 'Invalid verification code',
            ));

        await tester.pumpWidget(
          MaterialApp(
            home: SignInScreen(
              auth: mockAuth,
            ),
          ),
        );

        // Ensure the toggle button is visible
        await tester.ensureVisible(find.text('Use Phone Number Instead'));
        await tester.pump();
        
        // Switch to phone mode
        await tester.tap(find.text('Use Phone Number Instead'));
        await tester.pump();

        // Ensure the phone field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('phone')));
        await tester.pump();
        
        await tester.enterText(
            find.byKey(const ValueKey('phone')), '+1234567890');
        await tester.pump();
        
        // Ensure the send code button is visible
        await tester.ensureVisible(find.text('Send Code'));
        await tester.pump();
        
        await tester.tap(find.text('Send Code'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); // Wait for dialog animation

        verifyCompleter.complete();
        await tester.pump();

        // Ensure the verification code field is visible
        await tester.ensureVisible(find.byKey(const ValueKey('verification-code')));
        await tester.pump();
        
        // Enter invalid verification code
        await tester.enterText(
            find.byKey(const ValueKey('verification-code')), 'wrong-code');
        await tester.pump();
        
        // Ensure the verify button is visible
        await tester.ensureVisible(find.text('Verify'));
        await tester.pump();
        
        await tester.tap(find.text('Verify'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100)); // Wait for dialog animation

        expect(find.text('Invalid verification code'), findsOneWidget);
      });
    });
  });
} 