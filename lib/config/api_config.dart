import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConfig {
  static String get baseUrl {
    // Check if we're using a custom URL from .env
    final customUrl = dotenv.env['API_BASE_URL'];
    if (customUrl != null && customUrl.isNotEmpty) {
      return customUrl;
    }

    // For physical device, use the computer's local IP
    return 'http://192.168.1.158:8080';  // Your computer's IP address
  }

  // Helper to detect if running in an emulator
  static bool get isEmulator {
    if (Platform.isAndroid) {
      try {
        return Platform.environment['ANDROID_EMULATOR'] == '1' ||
               Platform.environment['ANDROID_SDK_ROOT'] != null;
      } catch (e) {
        return false;
      }
    }
    return false;
  }

  // Specific API endpoints
  static String get generateChaptersEndpoint => '$baseUrl/generate_chapters';
  static String get getChaptersEndpoint => '$baseUrl/get_chapters';
} 