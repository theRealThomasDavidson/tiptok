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

class VideoEditScreen extends StatefulWidget {
  final String videoPath;
  final FirebaseAuth auth;
  final FirebaseStorage storage;
  static const int MAX_DURATION_SECONDS = 60;

  VideoEditScreen({
    super.key,
    required this.videoPath,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : auth = auth ?? FirebaseAuth.instance,
       storage = storage ?? FirebaseStorage.instance;

  @override
  State<VideoEditScreen> createState() => _VideoEditScreenState();
}

class _VideoEditScreenState extends State<VideoEditScreen> {
  double _uploadProgress = 0;
  late final VideoStorageService _storageService;
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isTrimming = false;
  bool _isLoading = false;
  bool _isPlaying = false;
  double _startTime = 0.0;
  double _endTime = 0.0;
  String? _editedVideoPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _storageService = VideoStorageService(storage: widget.storage);
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

    // Loop video when it reaches the end
    if (_videoController.value.position >= _videoController.value.duration) {
      _videoController.seekTo(Duration.zero);
      _videoController.play();
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

  Future<void> _togglePlayPause() async {
    if (_videoController.value.isPlaying) {
      await _videoController.pause();
    } else {
      await _videoController.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Video')),
      body: Column(
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayerWidget(videoPath: _editedVideoPath ?? widget.videoPath),
                if (_isLoading || _isTrimming)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                if (_isInitialized && !_isLoading && !_isTrimming)
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: AnimatedOpacity(
                          opacity: _isPlaying ? 0.0 : 0.7,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black45,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isInitialized && !_isLoading) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                RangeSlider(
                  values: RangeValues(_startTime, _endTime),
                  min: 0,
                  max: _videoController.value.duration.inSeconds.toDouble(),
                  onChanged: (RangeValues values) {
                    setState(() {
                      _startTime = values.start;
                      _endTime = values.end;
                    });
                  },
                  labels: RangeLabels(
                    Duration(seconds: _startTime.round()).toString().split('.').first,
                    Duration(seconds: _endTime.round()).toString().split('.').first,
                  ),
                ),
                Text(
                  'Selected duration: ${(_endTime - _startTime).round()} seconds',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
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
                  onPressed: (_isTrimming || _isLoading) ? null : _trimVideo,
                  child: Text(_isTrimming ? 'Trimming...' : 'Trim'),
                ),
                ElevatedButton(
                  onPressed: (_isTrimming || _isLoading) ? null : () async {
                    if (!await _checkDuration()) return;
                    
                    final userId = widget.auth.currentUser?.uid;
                    if (userId != null) {
                      try {
                        final videoToUpload = _editedVideoPath != null 
                          ? File(_editedVideoPath!) 
                          : File(widget.videoPath);
                          
                        await _storageService.uploadVideo(
                          videoToUpload,
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