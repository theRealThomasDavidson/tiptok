import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return android;
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAmO0rbiGHEuPfafaWi_W_FtpjL0wEy_oM',
    appId: '1:606703658209:android:a572a2b421ff68002b03a0',
    messagingSenderId: '606703658209',
    projectId: 'tiptok-f2819',
    storageBucket: 'tiptok-f2819.firebasestorage.app',
  );
} 