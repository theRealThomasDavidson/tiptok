import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:tiptok/features/video/services/video_storage_service.dart';
import 'dart:async';
import 'video_storage_service_test.mocks.dart';

@GenerateMocks([FirebaseStorage, Reference, UploadTask, TaskSnapshot])
void main() {
  late VideoStorageService storageService;
  late MockFirebaseStorage mockStorage;
  late MockReference mockRef;
  late MockUploadTask mockUploadTask;
  late MockTaskSnapshot mockSnapshot;
  late StreamController<TaskSnapshot> streamController;
  late File testFile;

  setUp(() {
    // Create instances
    mockStorage = MockFirebaseStorage();
    mockRef = MockReference();
    mockUploadTask = MockUploadTask();
    mockSnapshot = MockTaskSnapshot();
    streamController = StreamController<TaskSnapshot>();
    testFile = File('test_path');

    // Set up the mock behaviors
    when(mockStorage.ref()).thenAnswer((_) => mockRef);
    when(mockRef.child(any)).thenAnswer((_) => mockRef);
    when(mockRef.putFile(any)).thenAnswer((_) => mockUploadTask);
    when(mockUploadTask.snapshotEvents).thenAnswer((_) => streamController.stream);
    when(mockUploadTask.snapshot).thenAnswer((_) => mockSnapshot);
    when(mockSnapshot.ref).thenAnswer((_) => mockRef);
    when(mockRef.getDownloadURL())
        .thenAnswer((_) => Future.value('https://mock-url.com/video.mp4'));
    when(mockSnapshot.bytesTransferred).thenAnswer((_) => 100);
    when(mockSnapshot.totalBytes).thenAnswer((_) => 100);

    // Mock the Future behavior of UploadTask
    when(mockUploadTask.then(any, onError: anyNamed('onError')))
        .thenAnswer((invocation) {
      final onValue = invocation.positionalArguments[0] as Function;
      return Future.value(mockSnapshot).then(onValue as dynamic Function(TaskSnapshot));
    });

    storageService = VideoStorageService(storage: mockStorage);
  });

  tearDown(() {
    streamController.close();
  });

  test('uploadVideo should upload file and return download URL', () async {
    final downloadUrl = storageService.uploadVideo(
      testFile,
      'test-user-id',
      (progress) {},
    );

    streamController.add(mockSnapshot);
    await streamController.close();

    expect(await downloadUrl, 'https://mock-url.com/video.mp4');
  });

  test('uploadVideo should handle upload progress', () async {
    double? lastProgress;

    final downloadUrl = storageService.uploadVideo(
      testFile,
      'test-user-id',
      (progress) {
        lastProgress = progress;
      },
    );

    streamController.add(mockSnapshot);
    await streamController.close();
    await downloadUrl;

    expect(lastProgress, 1.0); // 100/100 = 1.0
  });

  test('uploadVideo should throw exception on failure', () async {
    reset(mockRef);
    when(mockRef.putFile(any)).thenThrow(Exception('Upload failed'));

    expect(
      () => storageService.uploadVideo(
        testFile,
        'test-user-id',
        (progress) {},
      ),
      throwsA(isA<Exception>()),
    );
  });
} 