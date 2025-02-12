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
import 'package:cloud_firestore/cloud_firestore.dart';

class VideoEditScreen extends StatefulWidget {
  final String videoPath;
  final FirebaseAuth auth;
  final FirebaseStorage storage;

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
  bool _isGeneratingChapters = false;
  String? _chaptersStatus;
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

  Future<void> _generateChapters() async {
    if (!_isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please wait for video to initialize'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingChapters = true;
      _chaptersStatus = 'Uploading video for processing...';
    });

    try {
      final user = widget.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload to videos directory (not processing)
      final videoFile = File(_editedVideoPath ?? widget.videoPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoId = '${timestamp}_${user.uid}';
      final videoRef = widget.storage.ref()
          .child('videos/${user.uid}/$videoId.mp4');

      // Upload the video
      final uploadTask = videoRef.putFile(videoFile);
      
      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
          _chaptersStatus = 'Uploading: ${(progress * 100).toStringAsFixed(1)}%';
        });
      });

      // Wait for upload to complete
      await uploadTask;
      
      setState(() {
        _chaptersStatus = 'Processing video (this may take 5-10 minutes). Please keep this screen open.';
      });

      // Listen for status updates in videoprocessing collection
      FirebaseFirestore.instance
          .collection('videoprocessing')
          .doc(videoId)
          .snapshots()
          .listen((snapshot) {
        final status = snapshot.data()?['status'];
        setState(() {
          switch (status) {
            case 'processing':
              _chaptersStatus = 'Generating chapters... (this may take 5-10 minutes)';
              break;
            case 'completed':
              _chaptersStatus = 'Chapters generated successfully!';
              _isGeneratingChapters = false;
              Navigator.pop(context); // Return to previous screen
              break;
            case 'error':
              _chaptersStatus = 'Error: ${snapshot.data()?['error']}';
              _isGeneratingChapters = false;
              break;
          }
        });
      });

    } catch (e) {
      setState(() {
        _chaptersStatus = 'Error: $e';
        _isGeneratingChapters = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating chapters: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Video'),
        actions: [
          if (_isInitialized && !_isLoading && !_isTrimming)
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _uploadVideo,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isInitialized) ...[
            AspectRatio(
              aspectRatio: _videoController.value.aspectRatio,
              child: VideoPlayer(_videoController),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                ),
              ],
            ),
            if (_uploadProgress > 0 && _uploadProgress < 1) ...[
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            Row(
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
                ElevatedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else if (_error != null) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ] else ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
          
          if (_isGeneratingChapters || _chaptersStatus != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (_isGeneratingChapters)
                    LinearProgressIndicator(value: _uploadProgress),
                  if (_chaptersStatus != null)
                    Text(_chaptersStatus!),
                ],
              ),
            ),
            
          ElevatedButton.icon(
            onPressed: !_isGeneratingChapters ? _generateChapters : null,
            icon: const Icon(Icons.auto_stories),
            label: const Text('Generate Chapters'),
          ),
        ],
      ),
    );
  }
} 