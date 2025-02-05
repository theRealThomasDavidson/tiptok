import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import '../screens/video_preview_screen.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
  static const int MAX_DURATION_SECONDS = 60;
  
  Future<File?> _pickVideoWithFilters() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp4', 'mov', 'avi'],
      dialogTitle: 'Select a video to edit',
      withData: false,  // Don't load into memory
      allowCompression: false,  // Preserve quality
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      debugPrint('Selected file: ${result.files.single.path}');
      debugPrint('File exists: ${await file.exists()}');
      return file;
    }
    return null;
  }

  Future<void> _checkDurationAndPreview(File videoFile) async {
    // Create a temporary controller to check duration
    final controller = VideoPlayerController.file(videoFile);
    try {
      await controller.initialize();
      final duration = controller.value.duration;
      
      if (duration.inSeconds > MAX_DURATION_SECONDS) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Video is too long (${duration.inSeconds} seconds). Maximum allowed duration is $MAX_DURATION_SECONDS seconds.'
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VideoPreviewScreen(
                videoPath: videoFile.path,
              ),
            ),
          );
        }
      }
    } finally {
      await controller.dispose();
    }
  }

  Future<void> _pickAndPreviewVideo() async {
    if (!mounted) return;
    
    final file = await _pickVideoWithFilters();
    if (file != null) {
      await _checkDurationAndPreview(file);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Video'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Maximum video duration: 60 seconds',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickAndPreviewVideo,
              child: const Text('Select Video'),
            ),
          ],
        ),
      ),
    );
  }
} 