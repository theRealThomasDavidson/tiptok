import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/video_player_widget.dart';
import '../services/video_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VideoPreviewScreen extends StatefulWidget {
  final String videoPath;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

  VideoPreviewScreen({
    super.key,
    required this.videoPath,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : auth = auth ?? FirebaseAuth.instance,
       storage = storage ?? FirebaseStorage.instance;

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  double _uploadProgress = 0;
  late final VideoStorageService _storageService;

  @override
  void initState() {
    super.initState();
    _storageService = VideoStorageService(storage: widget.storage);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Preview Video')),
      body: Column(
        children: [
          Expanded(
            child: VideoPlayerWidget(videoPath: widget.videoPath),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final userId = widget.auth.currentUser?.uid;
                    if (userId != null) {
                      try {
                        await _storageService.uploadVideo(
                          File(widget.videoPath),
                          userId,
                          (progress) {
                            setState(() {
                              _uploadProgress = progress;
                            });
                          },
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Upload successful!')),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Upload failed: $e')),
                          );
                        }
                      }
                    }
                  },
                  child: const Text('Upload'),
                ),
              ],
            ),
          ),
          if (_uploadProgress > 0 && _uploadProgress < 1)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircularProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
        ],
      ),
    );
  }
} 