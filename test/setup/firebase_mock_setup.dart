import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Callback = void Function(MethodCall call);

void setupFirebaseCoreMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Create a mock platform channel
  const MethodChannel channel = MethodChannel('plugins.flutter.io/firebase_core');
  
  // Register the mock handler
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'Firebase#initializeCore') {
      return [
        {
          'name': '[DEFAULT]',
          'options': {
            'apiKey': 'test-api-key',
            'appId': 'test-app-id',
            'messagingSenderId': 'test-sender-id',
            'projectId': 'test-project-id',
          },
          'pluginConstants': {},
        }
      ];
    }
    if (call.method == 'Firebase#initializeApp') {
      return {
        'name': call.arguments['appName'],
        'options': call.arguments['options'],
        'pluginConstants': {},
      };
    }
    return null;
  });
}

Future<void> setupFirebaseCoreMockPlatform() async {
  final mockPlatform = MockFirebasePlatform();
  FirebasePlatform.instance = mockPlatform;

  const FirebaseOptions mockOptions = FirebaseOptions(
    apiKey: 'mock-api-key',
    appId: 'mock-app-id',
    messagingSenderId: 'mock-sender-id',
    projectId: 'mock-project-id',
  );

  await Firebase.initializeApp(
    options: mockOptions,
  );
}

class MockFirebasePlatform extends FirebasePlatform {
  final List<FirebaseAppPlatform> _apps = [];

  @override
  FirebaseAppPlatform app([String name = defaultFirebaseAppName]) {
    for (final app in _apps) {
      if (app.name == name) {
        return app;
      }
    }

    throw FirebaseException(
      plugin: 'core',
      message: 'No Firebase App $name has been created - '
          'call Firebase.initializeApp()',
    );
  }

  @override
  List<FirebaseAppPlatform> get apps => _apps;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    name ??= defaultFirebaseAppName;
    options ??= const FirebaseOptions(
      apiKey: 'mock-api-key',
      appId: 'mock-app-id',
      messagingSenderId: 'mock-sender-id',
      projectId: 'mock-project-id',
    );

    final app = TestFirebaseAppPlatform(name, options);
    _apps.add(app);
    return app;
  }
}

class TestFirebaseAppPlatform extends FirebaseAppPlatform {
  TestFirebaseAppPlatform(String name, FirebaseOptions options)
      : super(name, options);
} 