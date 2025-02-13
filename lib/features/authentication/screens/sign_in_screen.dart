import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'sign_up_screen.dart';
import '../../home/screens/home_screen.dart';
import 'package:file_picker/file_picker.dart';

class SignInScreen extends StatefulWidget {
  final FirebaseAuth auth;

  SignInScreen({
    super.key,
    FirebaseAuth? auth,
  }) : auth = auth ?? FirebaseAuth.instance;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPhoneMode = false;
  bool _isVerificationSent = false;
  String? _verificationId;

  void _showLoadingOverlay({String message = 'Loading...'}) {
    setState(() {
      _isLoading = true;
    });
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(message),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _hideLoadingOverlay() {
    if (_isLoading) {
      Navigator.of(context).pop(); // Remove the loading overlay
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isPhoneMode ? 'Please enter a phone number' : 'Please enter an email')),
      );
      return;
    }

    if (!_isPhoneMode && _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a password')),
      );
      return;
    }

    if (_isPhoneMode) {
      await _signInWithPhone();
    } else {
      await _signInWithEmail();
    }
  }

  Future<void> _signInWithEmail() async {
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

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found for that email';
          break;
        case 'wrong-password':
          message = 'Wrong password provided';
          break;
        case 'invalid-email':
          message = 'The email address is badly formatted';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithPhone() async {
    if (!_isVerificationSent) {
      if (_emailController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a phone number')),
        );
        return;
      }

      _showLoadingOverlay(message: 'Verifying phone number...');

      try {
        await widget.auth.verifyPhoneNumber(
          phoneNumber: _emailController.text,
          verificationCompleted: (PhoneAuthCredential credential) async {
            _hideLoadingOverlay();
            _showLoadingOverlay(message: 'Signing in...');
            try {
              await widget.auth.signInWithCredential(credential);
              if (context.mounted) {
                _hideLoadingOverlay();
                Navigator.pushReplacementNamed(context, '/home');
              }
            } catch (e) {
              if (context.mounted) {
                _hideLoadingOverlay();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            }
          },
          verificationFailed: (FirebaseAuthException e) {
            _hideLoadingOverlay();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.message ?? 'Invalid phone number')),
            );
          },
          codeSent: (String verificationId, int? resendToken) {
            _hideLoadingOverlay();
            setState(() {
              _verificationId = verificationId;
              _isVerificationSent = true;
            });
          },
          codeAutoRetrievalTimeout: (String verificationId) {
            _hideLoadingOverlay();
          },
        );
      } catch (e) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } else {
      if (_passwordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter the verification code')),
        );
        return;
      }

      _showLoadingOverlay(message: 'Verifying code...');

      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: _passwordController.text,
        );
        await widget.auth.signInWithCredential(credential);
        
        if (context.mounted) {
          _hideLoadingOverlay();
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on FirebaseAuthException catch (e) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Invalid verification code')),
        );
      } catch (e) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _signInWithGitHub() async {
    _showLoadingOverlay(message: 'Signing in...');

    try {
      final githubProvider = GithubAuthProvider();
      githubProvider.addScope('read:user');
      githubProvider.addScope('user:email');

      // First attempt sign in
      try {
        await widget.auth.signInWithProvider(githubProvider)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => throw TimeoutException('Sign in timed out'),
            );
        
        if (context.mounted) {
          _hideLoadingOverlay();
          Navigator.pushReplacementNamed(context, '/home');
        }
        return;
      } on FirebaseAuthException catch (e) {
        // If user doesn't exist, proceed with sign up
        if (e.code == 'user-not-found') {
          if (context.mounted) {
            _showLoadingOverlay(message: 'Creating account...');
          }
          
          // Try sign up
          final userCredential = await widget.auth.signInWithProvider(githubProvider);
          
          // Update display name if not set
          if (userCredential.user?.displayName == null) {
            await userCredential.user?.updateDisplayName(
              userCredential.user?.email?.split('@')[0] ?? 'GitHub User'
            );
          }

          if (context.mounted) {
            _hideLoadingOverlay();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully'),
                duration: Duration(seconds: 3),
              ),
            );
            Navigator.pushReplacementNamed(context, '/home');
          }
          return;
        }
        rethrow;
      }
    } on TimeoutException {
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in timed out. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'operation-not-allowed':
          message = 'GitHub sign in is not enabled';
          break;
        case 'account-exists-with-different-credential':
          message = 'An account already exists with this email';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    _showLoadingOverlay(message: 'Signing in with Google...');

    try {
      final googleProvider = GoogleAuthProvider();
      await widget.auth.signInWithProvider(googleProvider)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Sign in timed out'),
          );
      
      if (context.mounted) {
        _hideLoadingOverlay();
        Navigator.pushReplacementNamed(context, '/home');
      }
    } on TimeoutException {
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign in timed out. Please try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'operation-not-allowed':
          message = 'Google sign in is not enabled';
          break;
        case 'account-exists-with-different-credential':
          message = 'An account already exists with this email';
          break;
        default:
          message = e.message ?? 'An error occurred';
      }
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _hideLoadingOverlay();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('An unexpected error occurred: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'assets/images/Icon_start.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'TipTok',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                key: ValueKey(_isPhoneMode ? 'phone' : 'email'),
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: _isPhoneMode ? 'Phone Number' : 'Email',
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.blue),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                    borderSide: BorderSide(color: Colors.blue, width: 2),
                  ),
                ),
                keyboardType: _isPhoneMode ? TextInputType.phone : TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              if (!_isPhoneMode || _isVerificationSent)
                TextField(
                  key: ValueKey(_isPhoneMode ? 'verification-code' : 'password'),
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: _isPhoneMode ? 'Verification Code' : 'Password',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide(color: Colors.blue, width: 2),
                    ),
                  ),
                  obscureText: !_isPhoneMode,
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_isPhoneMode
                      ? (_isVerificationSent ? 'Verify' : 'Send Code')
                      : 'Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _signInWithGitHub,
                    icon: const Icon(Icons.code),
                    label: const Text('GitHub'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    key: const Key('google-signin'),
                    onPressed: _signInWithGoogle,
                    icon: const Icon(Icons.g_translate),
                    label: const Text('Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isPhoneMode = !_isPhoneMode;
                    _isVerificationSent = false;
                    _verificationId = null;
                    _emailController.clear();
                    _passwordController.clear();
                  });
                },
                child: Text(_isPhoneMode
                    ? 'Use Email Instead'
                    : 'Use Phone Number Instead'),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Don't have an account? "),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SignUpScreen(
                            auth: widget.auth,
                          ),
                        ),
                      );
                    },
                    child: const Text('Sign Up'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
} 