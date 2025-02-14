import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_segment_model.dart';
import '../models/video_model.dart';
import '../services/video_storage_service.dart';
import '../widgets/video_segment_editor.dart';
import '../../playlist/models/playlist_model.dart';
import '../../playlist/services/playlist_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../video_processing/services/video_processing_service.dart';

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
  late double _uploadProgress;
  String _playlistTitle = '';
  String _processingStatus = '';
  final TextEditingController _titleController = TextEditingController();
  final VideoStorageService _storageService = VideoStorageService();
  final PlaylistService _playlistService = PlaylistService();
  bool _isFullVideo = true;
  Duration _currentPosition = Duration.zero;
  bool _isInitialized = false;
  final VideoProcessingService _processingService = VideoProcessingService();

  @override
  void initState() {
    super.initState();
    _uploadProgress = 0.0;
    _controller = VideoPlayerController.file(File(widget.videoPath));
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
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
          
          // Add a small buffer (0.1 seconds) to prevent exact matches
          if (currentSeconds >= segment.endTime + 0.1) {
            _controller.seekTo(Duration(milliseconds: (segment.startTime * 1000).round()));
            if (!_controller.value.isPlaying) {
              _controller.play();
            }
          } else if (currentSeconds < segment.startTime - 0.1) {
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
    
    setState(() {
      _isInitialized = true;
    });
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

  void _toggleFullVideo() {
    setState(() {
      _isFullVideo = !_isFullVideo;
      if (_isFullVideo) {
        _controller.seekTo(Duration.zero);
      } else if (_activeSegmentIndex >= 0) {
        var segment = _segments[_activeSegmentIndex];
        _controller.seekTo(Duration(milliseconds: (segment.startTime * 1000).round()));
      }
    });
  }

  void _previewSegment(int index) {
    if (_activeSegmentIndex == index) {
      // If clicking the same segment, deactivate it
      setState(() {
        _activeSegmentIndex = -1;
      });
      _controller.seekTo(Duration.zero);
    } else {
      // Activate the new segment
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

    // Validate segment data
    if (segment.startTime < 0 || segment.endTime <= segment.startTime) {
      throw Exception('Invalid segment times: start=${segment.startTime}, end=${segment.endTime}');
    }

    // Verify original video exists
    final videoFile = File(segment.originalVideoPath);
    if (!await videoFile.exists()) {
      throw Exception('Original video file not found: ${segment.originalVideoPath}');
    }

    var startTime = Duration(milliseconds: (segment.startTime * 1000).round())
        .toString()
        .split('.')
        .first;
    final duration = segment.duration.toString().split('.').first;

    debugPrint('Processing segment:');
    debugPrint('- ID: ${segment.id}');
    debugPrint('- Start time: $startTime');
    debugPrint('- Duration: $duration');
    debugPrint('- Input path: ${segment.originalVideoPath}');
    debugPrint('- Output path: $outputPath');

    final command = '-ss $startTime -i "${segment.originalVideoPath}" -t $duration -c:v copy -c:a copy "$outputPath"';

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final logs = await session.getLogsAsString();
      debugPrint('FFmpeg failed with logs:');
      debugPrint(logs);
      throw Exception('Failed to process segment. FFmpeg logs: $logs');
    }

    // Verify output file exists and has size > 0
    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw Exception('Output file not created: $outputPath');
    }
    final size = await outputFile.length();
    if (size == 0) {
      throw Exception('Output file is empty: $outputPath');
    }

    debugPrint('Successfully processed segment to: $outputPath (${size} bytes)');
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
          _processingStatus = 'Preparing segment $segmentNumber of $totalSegments...';
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

    final screenHeight = MediaQuery.of(context).size.height;
    final maxVideoHeight = screenHeight * 0.4; // 40% of screen height
    final videoWidth = MediaQuery.of(context).size.width;
    final maxContentWidth = videoWidth * 0.85; // 85% of screen width
    
    // Calculate dimensions to fit video within frame while maintaining aspect ratio
    final frameAspectRatio = maxContentWidth / maxVideoHeight;
    final videoAspectRatio = _controller.value.aspectRatio;
    
    late final double effectiveVideoWidth;
    late final double effectiveVideoHeight;
    
    if (videoAspectRatio > frameAspectRatio) {
      // Video is wider than frame, fit to width
      effectiveVideoWidth = maxContentWidth;
      effectiveVideoHeight = maxContentWidth / videoAspectRatio;
    } else {
      // Video is taller than frame, fit to height
      effectiveVideoHeight = maxVideoHeight;
      effectiveVideoWidth = maxVideoHeight * videoAspectRatio;
    }

    final isSimpleVideo = _segments.length <= 1;
    final buttonText = isSimpleVideo ? 'Create Video' : 'Create Playlist';
    final titleText = isSimpleVideo ? 'Edit Video' : 'Create Video Playlist';

    // Calculate current position for time indicator (mutable values)
    var currentPosition = _controller.value.position.inMilliseconds;
    var totalDuration = _controller.value.duration.inMilliseconds;
    var positionFraction = totalDuration > 0 ? currentPosition / totalDuration : 0.0;
    var indicatorPosition = effectiveVideoWidth * positionFraction;

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
      ),
      body: Column(
        children: [
          // Playlist title input
          if (!isSimpleVideo)
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
          
          // Video preview with constrained height
          Container(
            color: Colors.black,
            width: maxContentWidth,
            height: maxVideoHeight,
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(
              horizontal: (videoWidth - maxContentWidth) / 2,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: effectiveVideoWidth,
                  height: effectiveVideoHeight,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: VideoPlayer(_controller),
                ),
                // Center play/pause button
                Opacity(
                  opacity: 0.3,
                  child: IconButton(
                    icon: Icon(
                      _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
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
                ),
                // Video controls overlay
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Time indicator
                      Container(
                        height: 20,
                        padding: EdgeInsets.zero,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.5),
                            ],
                          ),
                        ),
                        child: ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (context, VideoPlayerValue value, child) {
                            return Column(
                              children: [
                                // Time display
                                Container(
                                  height: 16,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    _formatDuration(value.position),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                                // Progress bar
                                GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  excludeFromSemantics: true,
                                  onHorizontalDragUpdate: (details) {
                                    final box = context.findRenderObject() as RenderBox;
                                    final dx = details.localPosition.dx;
                                    final width = box.size.width;
                                    final position = dx / width;
                                    final duration = value.duration;
                                    _controller.seekTo(duration * position);
                                  },
                                  child: VideoProgressIndicator(
                                    _controller,
                                    allowScrubbing: true,
                                    padding: EdgeInsets.zero,
                                    colors: VideoProgressColors(
                                      playedColor: Colors.amber,
                                      backgroundColor: Colors.black45,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Upload progress
          if (_isProcessing) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text(
                    _processingStatus,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Segments or Generate Chapters button
          Expanded(
            child: _segments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'No segments added yet',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _generateChapters,
                        icon: const Icon(Icons.auto_stories),
                        label: const Text('Generate Chapters'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      if (_isProcessing) ...[
                        const SizedBox(height: 16),
                        const CircularProgressIndicator(),
                        const SizedBox(height: 8),
                        Text(
                          _processingStatus,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _segments.length,
                  itemBuilder: (context, index) {
                    final segment = _segments[index];
                    return VideoSegmentEditor(
                      key: ValueKey(segment.hashCode),
                      segment: segment,
                      originalVideoDuration: _controller.value.duration.inMilliseconds / 1000,
                      onSegmentChanged: (updatedSegment) {
                        setState(() {
                          _segments[index] = updatedSegment;
                        });
                      },
                      onDeleteSegment: () {
                        setState(() {
                          _segments.removeAt(index);
                        });
                      },
                      onSeekTo: (position) {
                        _controller.seekTo(Duration(milliseconds: (position * 1000).round()));
                      },
                      onPreviewSegment: () => _previewSegment(index),
                      isActive: _activeSegmentIndex == index,
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
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _addSegment,
                icon: const Icon(Icons.add),
                label: const Text('Add Segment'),
              ),
              ElevatedButton.icon(
                onPressed: _isProcessing 
                  ? null 
                  : () {
                      if (isSimpleVideo) {
                        // For single video or segment, no playlist title needed
                        _uploadSegments();
                      } else if (_playlistTitle.isNotEmpty) {
                        _uploadSegments();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a playlist title')),
                        );
                      }
                    },
                icon: const Icon(Icons.upload),
                label: Text(buttonText),
              ),
            ],
          ),
        ),
      ),
    );
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
      _isProcessing = true;
      _processingStatus = 'Uploading video for processing...';
    });

    String? storagePath;
    try {
      final user = widget.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Upload to videos directory
      final videoFile = File(widget.videoPath);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoId = '${timestamp}_${user.uid}';
      storagePath = 'videos/${user.uid}/$videoId.mp4';
      final videoRef = FirebaseStorage.instance.ref().child(storagePath);

      // Upload the video
      final uploadTask = videoRef.putFile(videoFile);
      
      // Track upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        setState(() {
          _uploadProgress = progress;
          _processingStatus = 'Uploading: ${(progress * 100).toStringAsFixed(1)}%';
        });
      });

      await uploadTask;
      
      setState(() {
        _processingStatus = 'Generating chapters...';
      });

      // Generate chapters using our VideoProcessingService
      final chapters = await _processingService.generateChapters(storagePath);
      
      // Convert chapters to segments
      final newSegments = chapters.chapters.map((chapter) {
        return VideoSegment(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          startTime: chapter.start,
          endTime: chapter.end,
          originalVideoPath: widget.videoPath,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _segments.clear();
          _segments.addAll(newSegments);
          _isProcessing = false;
          _processingStatus = '';
          
          // Set the suggested title
          _titleController.text = chapters.suggestedTitle.replaceAll('"', '');
          _playlistTitle = _titleController.text;
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chapters generated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          _processingStatus = 'Error: $e';
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating chapters: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Clean up the uploaded video
      if (storagePath != null) {
        try {
          final videoRef = FirebaseStorage.instance.ref().child(storagePath);
          await videoRef.delete();
          debugPrint('Cleaned up temporary video upload: $storagePath');
        } catch (e) {
          debugPrint('Error cleaning up video upload: $e');
        }
      }
    }
  }
} 