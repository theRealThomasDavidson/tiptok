import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:io';
import '../../home/screens/home_screen.dart';

final FIREBASE_ANDROID_CLIENT_ID = '606703658209-android';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _isLoading = false;

  Future<void> _showLoadingOverlay() async {
    setState(() => _isLoading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _hideLoadingOverlay() {
    setState(() => _isLoading = false);
    if (context.mounted) {
      Navigator.of(context).pop(); // Remove loading dialog
    }
  }

  Future<void> _signUpWithGitHub() async {
    if (_isLoading) {
      debugPrint('Auth operation already in progress');
      return;
    }

    try {
      await _showLoadingOverlay();

      try {
        await FirebaseAuth.instance.signOut();
      } catch (e) {
        debugPrint('Error during cleanup: $e');
      }

      final githubProvider = GithubAuthProvider();
      githubProvider.addScope('read:user');
      githubProvider.addScope('user:email');
      
      UserCredential? userCredential;
      
      if (Platform.isAndroid) {
        try {
          // Use signInWithProvider which handles the activity lifecycle better
          userCredential = await FirebaseAuth.instance.signInWithProvider(githubProvider)
              .timeout(
                const Duration(minutes: 5),  // Increased timeout to 5 minutes
                onTimeout: () {
                  throw TimeoutException('Authentication timed out after 5 minutes');
                },
              );
          
          debugPrint('GitHub auth completed successfully');
        } catch (e) {
          debugPrint('Error during GitHub auth: $e');
          if (e.toString().contains('GenericIdpActivity')) {
            throw FirebaseAuthException(
              code: 'canceled',
              message: 'Authentication was interrupted. Please try again.'
            );
          }
          rethrow;
        }
      } else {
        // Fallback for other platforms
        userCredential = await FirebaseAuth.instance.signInWithPopup(githubProvider);
      }

      // If we got here, we have a successful authentication
      if (userCredential?.user != null) {
        if (userCredential!.user!.displayName == null) {
          await userCredential.user!.updateDisplayName(
            userCredential.user!.email?.split('@')[0] ?? 'GitHub User'
          );
        }

        if (context.mounted) {
          _hideLoadingOverlay();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created successfully')),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        throw FirebaseAuthException(
          code: 'auth-error',
          message: 'Failed to get user credentials'
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
      _hideLoadingOverlay();
      if (context.mounted) {
        String message;
        switch (e.code) {
          case 'account-exists-with-different-credential':
            message = 'An account already exists with a different sign in method. Please sign in with that method.';
            break;
          case 'operation-not-allowed':
            message = 'GitHub sign up is not enabled. Please contact support.';
            break;
          case 'user-disabled':
            message = 'This account has been disabled. Please contact support.';
            break;
          case 'canceled':
            message = 'Sign up was interrupted. Please try again.';
            break;
          default:
            message = 'An error occurred during GitHub sign up: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint('Unexpected error during GitHub sign up: $e');
      _hideLoadingOverlay();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: $e'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (_isLoading) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Check for redirect result when screen initializes
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final credential = await FirebaseAuth.instance.getRedirectResult();
        if (credential.user != null) {
          if (credential.user!.displayName == null) {
            await credential.user!.updateDisplayName(
              credential.user!.email?.split('@')[0] ?? 'GitHub User'
            );
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account created successfully')),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } catch (e) {
        debugPrint('Error checking redirect result: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            TextField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _signUp,
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Sign Up',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Or sign up with',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _signUpWithGitHub,
                  icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.code, color: Colors.white),
                  label: Text(
                    _isLoading ? 'Signing up...' : 'GitHub',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    backgroundColor: Colors.blue,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _signUp() async {
    // Basic validation
    if (_displayNameController.text.isEmpty) {
      debugPrint('Validation failed: Display name empty');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a display name')),
      );
      return;
    }

    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an email')),
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      debugPrint('Creating user with email/password...');
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );

      debugPrint('Updating display name...');
      await userCredential.user?.updateDisplayName(_displayNameController.text);
      debugPrint('User created successfully: ${userCredential.user?.email}');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      String message = 'An error occurred';
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for that email';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address';
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    // Clean up any pending auth operations when disposing the screen
    if (_isLoading) {
      FirebaseAuth.instance.signOut().catchError((e) {
        debugPrint('Error cleaning up auth state: $e');
      });
    }
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }
} 