import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'video_segment_playlist_editor_screen.dart';

class VideoUploadScreen extends StatefulWidget {
  const VideoUploadScreen({super.key});

  @override
  State<VideoUploadScreen> createState() => _VideoUploadScreenState();
}

class _VideoUploadScreenState extends State<VideoUploadScreen> {
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

  Future<void> _pickAndEditVideo() async {
    if (!mounted) return;
    
    final file = await _pickVideoWithFilters();
    if (file != null) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoSegmentPlaylistEditorScreen(
              videoPath: file.path,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Video Playlist'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Create a new video playlist',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select a video to split into segments\nand create a playlist',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _pickAndEditVideo,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Select Video'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 