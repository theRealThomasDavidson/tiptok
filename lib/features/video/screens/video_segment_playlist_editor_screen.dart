import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_segment_model.dart';
import '../services/video_storage_service.dart';
import '../widgets/video_segment_editor.dart';
import '../../playlist/models/playlist_model.dart';
import '../../playlist/services/playlist_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VideoSegmentPlaylistEditorScreen extends StatefulWidget {
  final String videoPath;
  final FirebaseAuth auth;
  
  const VideoSegmentPlaylistEditorScreen({
    super.key,
    required this.videoPath,
    FirebaseAuth? auth,
  }) : auth = auth ?? FirebaseAuth.instance;

  @override
  State<VideoSegmentPlaylistEditorScreen> createState() => _VideoSegmentPlaylistEditorScreenState();
}

class _VideoSegmentPlaylistEditorScreenState extends State<VideoSegmentPlaylistEditorScreen> {
  late VideoPlayerController _controller;
  final List<VideoSegment> _segments = [];
  int _activeSegmentIndex = -1;
  bool _isProcessing = false;
  double _uploadProgress = 0;
  String _playlistTitle = '';
  String _processingStatus = '';
  final TextEditingController _titleController = TextEditingController();
  final VideoStorageService _storageService = VideoStorageService();
  final PlaylistService _playlistService = PlaylistService();
  bool _isFullVideo = true;
  Duration _currentPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _controller.setLooping(false);
    
    _controller.addListener(() {
      if (mounted) {
        setState(() {
          _currentPosition = _controller.value.position;
        });

        if (_activeSegmentIndex >= 0 && _segments.isNotEmpty) {
          var segment = _segments[_activeSegmentIndex];
          var currentSeconds = _controller.value.position.inMilliseconds / 1000;
          
          if (currentSeconds >= segment.endTime) {
            _controller.seekTo(Duration(milliseconds: (segment.startTime * 1000).round()));
            if (!_controller.value.isPlaying) {
              _controller.play();
            }
          } else if (currentSeconds < segment.startTime) {
            _controller.seekTo(Duration(milliseconds: (segment.startTime * 1000).round()));
          }
        } else {
          if (_controller.value.position >= _controller.value.duration) {
            _controller.seekTo(Duration.zero);
            if (!_controller.value.isPlaying) {
              _controller.play();
            }
          }
        }
      }
    });
    
    setState(() {});
  }

  void _addSegment() {
    if (_controller.value.duration == null) return;
    
    final newSegment = VideoSegment(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: 0,
      endTime: _controller.value.duration.inMilliseconds / 1000,
      originalVideoPath: widget.videoPath,
    );
    
    setState(() {
      _segments.add(newSegment);
      _activeSegmentIndex = _segments.length - 1;
    });
  }

  void _updateSegment(int index, VideoSegment newSegment) {
    setState(() {
      _segments[index] = newSegment;
    });
  }

  void _deleteSegment(int index) {
    setState(() {
      _segments.removeAt(index);
      if (_activeSegmentIndex == index) {
        _activeSegmentIndex = -1;
      } else if (_activeSegmentIndex > index) {
        _activeSegmentIndex--;
      }
    });
  }

  void _previewSegment(int index) {
    if (_activeSegmentIndex == index) {
      setState(() {
        _activeSegmentIndex = -1;
      });
      _controller.seekTo(Duration.zero);
    } else {
      final segment = _segments[index];
      setState(() {
        _activeSegmentIndex = index;
      });
      _controller.seekTo(Duration(milliseconds: (segment.startTime * 1000).round()));
    }
    _controller.play();
  }

  Future<String> _processSegment(VideoSegment segment) async {
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/segment_${segment.id}.mp4';

    var startTime = Duration(milliseconds: (segment.startTime * 1000).round())
        .toString()
        .split('.')
        .first;
    final duration = segment.duration.toString().split('.').first;

    final command = '-ss $startTime -i "${segment.originalVideoPath}" -t $duration -c:v copy -c:a copy "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      throw Exception('Failed to process segment');
    }

    return outputPath;
  }

  Future<void> _uploadSegments() async {
    if (_segments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one segment first')),
      );
      return;
    }

    if (_playlistTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a playlist title')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _uploadProgress = 0;
      _processingStatus = 'Creating playlist...';
    });

    try {
      final userId = widget.auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // Create playlist
      final playlist = await _playlistService.createPlaylist(
        userId: userId,
        title: _playlistTitle,
      );

      // Process and upload each segment
      final totalSegments = _segments.length;
      final uploadedVideoIds = <String>[];

      for (var i = 0; i < _segments.length; i++) {
        final segment = _segments[i];
        final segmentNumber = i + 1;
        
        // Process segment
        setState(() {
          _processingStatus = 'Processing segment $segmentNumber of $totalSegments...';
        });
        final processedPath = await _processSegment(segment);
        
        // Upload processed segment
        setState(() {
          _processingStatus = 'Uploading segment $segmentNumber of $totalSegments...';
        });
        final video = await _storageService.uploadVideo(
          File(processedPath),
          userId,
          (progress) {
            setState(() {
              _uploadProgress = (i + progress) / totalSegments;
            });
          },
        );

        uploadedVideoIds.add(video.id);

        // Clean up processed file
        try {
          await File(processedPath).delete();
        } catch (e) {
          debugPrint('Error cleaning up processed file: $e');
        }
      }

      setState(() {
        _processingStatus = 'Finalizing playlist...';
      });

      // Update playlist with video IDs
      await _playlistService.reorderPlaylistVideos(
        playlist.id,
        uploadedVideoIds,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Playlist created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating playlist: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _processingStatus = '';
        });
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    final tenths = (duration.inMilliseconds % 1000 / 100).round();
    return '$minutes:$seconds.$tenths';
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Video Segments'),
      ),
      body: Column(
        children: [
          // Playlist title input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Playlist Title',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => _playlistTitle = value,
            ),
          ),
          
          // Video preview in a card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.4, // 40% of screen height
              alignment: Alignment.center,
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
          ),

          // Playback controls
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      if (_controller.value.isPlaying) {
                        _controller.pause();
                      } else {
                        _controller.play();
                      }
                    });
                  },
                ),
              ],
            ),
          ),

          // Upload progress
          if (_isProcessing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(_processingStatus),
                ],
              ),
            ),
          ],

          // Segment list
          Expanded(
            child: ListView.builder(
              itemCount: _segments.length,
              itemBuilder: (context, index) {
                final segment = _segments[index];
                return VideoSegmentEditor(
                  segment: segment,
                  originalVideoDuration: _controller.value.duration.inMilliseconds / 1000,
                  onSegmentChanged: (newSegment) => _updateSegment(index, newSegment),
                  onDeleteSegment: () => _deleteSegment(index),
                  onSeekTo: (time) => _controller.seekTo(Duration(milliseconds: (time * 1000).round())),
                  onPreviewSegment: () => _previewSegment(index),
                  isActive: index == _activeSegmentIndex,
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: _isProcessing ? null : _addSegment,
                child: const Text('Add Segment'),
              ),
              ElevatedButton(
                onPressed: _isProcessing ? null : _uploadSegments,
                child: const Text('Create Playlist'),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 