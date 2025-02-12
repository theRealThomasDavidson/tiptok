import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'video_segment_playlist_editor_screen.dart';
import '../screens/video_edit_screen.dart';

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
    if (file != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Choose Edit Mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Create Playlist'),
                subtitle: const Text('Split video into segments'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoSegmentPlaylistEditorScreen(
                        videoPath: file.path,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Simple Edit'),
                subtitle: const Text('Trim and upload'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => VideoEditScreen(
                        videoPath: file.path,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
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
            const Icon(
              Icons.video_library,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'Create Video Content',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Maximum video duration: 60 seconds\nCreate a simple video or split into segments',
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