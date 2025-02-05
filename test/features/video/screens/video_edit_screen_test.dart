import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:tiptok/features/video/screens/video_edit_screen.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'dart:io';
import 'video_preview_screen_test.mocks.dart';

class MockVideoPlayerPlatform extends VideoPlayerPlatform {
  final _controllers = <int, StreamController<VideoEvent>>{};
  final _positions = <int, Duration>{};
  final _isPlaying = <int, bool>{};
  var _nextTextureId = 0;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async {
    final textureId = _nextTextureId++;
    _controllers[textureId] = StreamController<VideoEvent>.broadcast();
    _positions[textureId] = Duration.zero;
    _isPlaying[textureId] = false;
    
    // Simulate video loading
    Future.microtask(() {
      _controllers[textureId]?.add(
        VideoEvent(
          eventType: VideoEventType.initialized,
          duration: const Duration(seconds: 1),
          size: const Size(100, 100),
        ),
      );
    });
    
    return textureId;
  }

  @override
  Future<void> dispose(int textureId) async {
    final controller = _controllers[textureId];
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
    _controllers.remove(textureId);
    _positions.remove(textureId);
    _isPlaying.remove(textureId);
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {}

  @override
  Future<void> play(int textureId) async {
    _isPlaying[textureId] = true;
    _controllers[textureId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: true,
      ),
    );
  }

  @override
  Future<void> pause(int textureId) async {
    _isPlaying[textureId] = false;
    _controllers[textureId]?.add(
      VideoEvent(
        eventType: VideoEventType.isPlayingStateUpdate,
        isPlaying: false,
      ),
    );
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {}

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {}

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    _positions[textureId] = position;
    _controllers[textureId]?.add(
      VideoEvent(
        eventType: VideoEventType.completed,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    return _positions[textureId] ?? Duration.zero;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _controllers[textureId]?.stream ?? const Stream.empty();
  }

  void disposeAll() {
    for (final controller in _controllers.values) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _controllers.clear();
    _positions.clear();
    _isPlaying.clear();
  }
}

@GenerateMocks([
  FirebaseAuth,
  User,
  FirebaseStorage,
  Reference,
  UploadTask,
  TaskSnapshot
])
void main() {
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;
  late MockFirebaseStorage mockStorage;
  late MockReference mockReference;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockSnapshot;
  late StreamController<TaskSnapshot> streamController;
  late MockVideoPlayerPlatform mockVideoPlayer;
  const testVideoPath = 'test/video/path';

  setUpAll(() {
    mockVideoPlayer = MockVideoPlayerPlatform();
    VideoPlayerPlatform.instance = mockVideoPlayer;
  });

  setUp(() {
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();
    mockStorage = MockFirebaseStorage();
    mockReference = MockReference();
    mockUploadTask = MockUploadTask();
    mockSnapshot = MockTaskSnapshot();
    streamController = StreamController<TaskSnapshot>();

    when(mockAuth.currentUser).thenAnswer((_) => mockUser);
    when(mockUser.uid).thenAnswer((_) => 'test-user-id');
    when(mockStorage.ref()).thenAnswer((_) => mockReference);
    when(mockReference.child(any)).thenAnswer((_) => mockReference);
    when(mockReference.putFile(any)).thenAnswer((_) => mockUploadTask);
    when(mockUploadTask.snapshotEvents).thenAnswer((_) => streamController.stream);
    when(mockSnapshot.ref).thenAnswer((_) => mockReference);
    when(mockReference.getDownloadURL()).thenAnswer((_) => Future.value('download-url'));
    when(mockSnapshot.bytesTransferred).thenReturn(0);
    when(mockSnapshot.totalBytes).thenReturn(100);
    when(mockSnapshot.state).thenReturn(TaskState.running);
    
    // Mock the Future behavior of UploadTask
    when(mockUploadTask.then(any, onError: anyNamed('onError')))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future.value(mockSnapshot).then(onValue as dynamic Function(TaskSnapshot));
    });
  });

  tearDown(() {
    streamController.close();
    mockVideoPlayer.disposeAll();
  });

  testWidgets('VideoEditScreen shows upload and cancel buttons', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoEditScreen(
          videoPath: testVideoPath,
          auth: mockAuth,
          storage: mockStorage,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.widgetWithText(ElevatedButton, 'Upload'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Cancel'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Trim'), findsOneWidget);
  });

  testWidgets('VideoEditScreen handles successful upload', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VideoEditScreen(
          videoPath: testVideoPath,
          auth: mockAuth,
          storage: mockStorage,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(ElevatedButton, 'Upload'));
    await tester.pump();

    // Simulate 50% progress
    final halfwaySnapshot = MockTaskSnapshot();
    when(halfwaySnapshot.bytesTransferred).thenReturn(50);
    when(halfwaySnapshot.totalBytes).thenReturn(100);
    when(halfwaySnapshot.state).thenReturn(TaskState.running);
    streamController.add(halfwaySnapshot);
    await tester.pump();
    expect(find.text('50.0%'), findsOneWidget);

    // Simulate completion
    final completeSnapshot = MockTaskSnapshot();
    when(completeSnapshot.bytesTransferred).thenReturn(100);
    when(completeSnapshot.totalBytes).thenReturn(100);
    when(completeSnapshot.state).thenReturn(TaskState.success);
    when(completeSnapshot.ref).thenAnswer((_) => mockReference);
    streamController.add(completeSnapshot);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Upload successful!'), findsOneWidget);
  });

  testWidgets('VideoEditScreen handles upload failure', (tester) async {
    // Set up a simple error case
    when(mockReference.putFile(any)).thenThrow(Exception('Upload failed'));

    await tester.pumpWidget(
      MaterialApp(
        home: VideoEditScreen(
          videoPath: testVideoPath,
          auth: mockAuth,
          storage: mockStorage,
        ),
      ),
    );

    // Tap upload button
    await tester.tap(find.widgetWithText(ElevatedButton, 'Upload'));
    await tester.pump(); // Process the tap
    await tester.pump(); // Process the error
    
    // Verify error is shown to user
    expect(find.byType(SnackBar), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(SnackBar),
        matching: find.textContaining('Upload failed'),
      ),
      findsOneWidget,
    );
  });
}