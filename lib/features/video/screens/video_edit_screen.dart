import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/video_player_widget.dart';
import '../services/video_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_segment_model.dart';
import '../widgets/video_segment_editor.dart';

class VideoEditScreen extends StatefulWidget {
  final String videoPath;
  final FirebaseAuth auth;
  final FirebaseStorage storage;
  final VideoStorageService storageService;
  static const int MAX_DURATION_SECONDS = 60;

  VideoEditScreen({
    super.key,
    required this.videoPath,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
    VideoStorageService? storageService,
  })  : auth = auth ?? FirebaseAuth.instance,
        storage = storage ?? FirebaseStorage.instance,
        storageService = storageService ?? VideoStorageService();

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  double _uploadProgress = 0;
  late final VideoStorageService _storageService;
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isTrimming = false;
  bool _isLoading = true;
  bool _isPlaying = false;
  double _startTime = 0.0;
  double _endTime = 0.0;
  String? _editedVideoPath;
  String? _error;
  List<VideoSegment> _segments = [];
  int _activeSegmentIndex = -1;

  @override
  void initState() {
    super.initState();
    _storageService = widget.storageService;
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    setState(() {
      _isLoading = true;
      _isInitialized = false;
      _error = null;
    });

    try {
      _videoController = VideoPlayerController.file(File(_editedVideoPath ?? widget.videoPath));
      await _videoController.initialize();
      
      // Start playing the video
      await _videoController.play();
      
      if (mounted) {
        setState(() {
          _startTime = 0.0;
          _endTime = _videoController.value.duration.inSeconds.toDouble();
          _isInitialized = true;
          _isLoading = false;
          _isPlaying = true;
          
          // Create initial segment
          if (_segments.isEmpty) {
            _segments.add(VideoSegment(
              id: DateTime.now().toString(),
              startTime: 0,
              endTime: _videoController.value.duration.inSeconds.toDouble(),
              originalVideoPath: widget.videoPath,
            ));
            _activeSegmentIndex = 0;
          }
        });
      }

      // Add listener for playback state
      _videoController.addListener(_videoListener);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error initializing video: $e';
          _isInitialized = false;
          _isLoading = false;
          _isPlaying = false;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController.value.hasError) {
      setState(() {
        _error = 'Video playback error: ${_videoController.value.errorDescription}';
      });
    }
    
    // Update playing state
    final isPlaying = _videoController.value.isPlaying;
    if (_isPlaying != isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }

    // Check if we need to loop within segment boundaries
    if (_activeSegmentIndex >= 0 && _activeSegmentIndex < _segments.length) {
      final selectedSegment = _segments[_activeSegmentIndex];
      final position = _videoController.value.position.inSeconds.toDouble();
      
      // If position is outside segment bounds, seek back to start
      if (position < selectedSegment.startTime || position > selectedSegment.endTime) {
        _videoController.seekTo(Duration(seconds: selectedSegment.startTime.toInt()));
      }
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    // Clean up temporary edited video file
    if (_editedVideoPath != null) {
      File(_editedVideoPath!).delete().catchError((e) => 
        debugPrint('Error deleting temporary file: $e')
      );
    }
    super.dispose();
  }

  Future<bool> _checkDuration() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for video to initialize'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    final duration = _videoController.value.duration;
    if (duration.inSeconds > VideoEditScreen.MAX_DURATION_SECONDS) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Video is too long (${duration.inSeconds} seconds). Maximum allowed duration is ${VideoEditScreen.MAX_DURATION_SECONDS} seconds.'
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _trimVideo() async {
    if (_isTrimming || !_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for video to initialize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTrimming = true;
    });

    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final startTime = Duration(seconds: _startTime.round()).toString().split('.').first;
      final duration = Duration(seconds: (_endTime - _startTime).round()).toString().split('.').first;

      debugPrint('Trimming video from $startTime for duration $duration');
      debugPrint('Input path: ${widget.videoPath}');
      debugPrint('Output path: $outputPath');

      final command = '-ss $startTime -i "${widget.videoPath}" -t $duration -c:v copy -c:a copy -avoid_negative_ts make_zero "$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      final logs = await session.getLogs();
      
      debugPrint('FFmpeg logs: ${logs.join('\n')}');

      if (ReturnCode.isSuccess(returnCode)) {
        final outputFile = File(outputPath);
        if (!await outputFile.exists()) {
          throw Exception('Output file was not created');
        }
        
        final fileSize = await outputFile.length();
        if (fileSize == 0) {
          throw Exception('Output file is empty');
        }

        // Clean up old video controller
        await _videoController.dispose();
        
        setState(() {
          _editedVideoPath = outputPath;
        });

        // Initialize new video controller
        await _initializeVideo();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Video trimmed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final failureLogs = await session.getFailStackTrace();
        throw Exception('FFmpeg failed: ${failureLogs ?? 'Unknown error'}');
      }
    } catch (e) {
      debugPrint('Error during trimming: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error trimming video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isTrimming = false;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
    } else {
      _videoController.play();
    }
  }

  void _addSegment() {
    if (_segments.isEmpty) return;
    
    final lastSegment = _segments.last;
    final midPoint = (lastSegment.startTime + lastSegment.endTime) / 2;
    
    setState(() {
      // Split the last segment in half
      _segments.last = lastSegment.copyWith(endTime: midPoint);
      _segments.add(VideoSegment(
        id: DateTime.now().toString(),
        startTime: midPoint,
        endTime: lastSegment.endTime,
        originalVideoPath: widget.videoPath,
      ));
      _activeSegmentIndex = _segments.length - 1;
    });
  }

  void _onSegmentChanged(VideoSegment updatedSegment) {
    setState(() {
      _segments[_activeSegmentIndex] = updatedSegment;
    });
  }

  void _deleteSegment(int index) {
    setState(() {
      _segments.removeAt(index);
      if (_activeSegmentIndex >= _segments.length) {
        _activeSegmentIndex = _segments.length - 1;
      }
    });
  }

  void _previewSegment(int index) {
    setState(() {
      _activeSegmentIndex = index;
    });
    final segment = _segments[index];
    _videoController.seekTo(Duration(seconds: segment.startTime.toInt()));
    _videoController.play();
  }

  Future<void> _uploadVideo() async {
    if (!await _checkDuration()) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0;
    });

    try {
      final videoFile = File(_editedVideoPath ?? widget.videoPath);
      final userId = widget.auth.currentUser?.uid;
      if (userId == null) throw Exception('User not logged in');

      // TODO: Process segments if needed before upload
      
      await _storageService.uploadVideo(
        videoFile,
        userId,
        (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload successful!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Video')),
        body: Center(
          child: _error != null
              ? Text(_error!, style: const TextStyle(color: Colors.red))
              : const CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Video')),
      body: Column(
        children: [
          // Playlist name input
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Video Title',
                border: OutlineInputBorder(),
              ),
            ),
          ),

          // Video preview in a card
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            elevation: 4,
            clipBehavior: Clip.antiAlias,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5, // 50% of screen height
              alignment: Alignment.center,
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
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
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
          ),

          // Upload progress
          if (_uploadProgress > 0 && _uploadProgress < 1) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('${(_uploadProgress * 100).toStringAsFixed(1)}%'),
                ],
              ),
            ),
          ],

          const Spacer(),

          // Bottom controls
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _trimVideo,
                  child: const Text('Trim'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _uploadVideo,
                  child: const Text('Upload'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 