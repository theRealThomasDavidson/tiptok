import 'package:firebase_app_check/firebase_app_check.dart';

class CustomAppCheckProvider implements AndroidProvider {
  @override
  Future<String> getToken() async {
    // Return a dummy token that will be accepted during development
    return 'development_dummy_token_${DateTime.now().millisecondsSinceEpoch}';
  }

  @override
  String get providerId => 'custom';
} 