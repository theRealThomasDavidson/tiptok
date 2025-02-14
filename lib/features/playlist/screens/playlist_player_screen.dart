import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../../../features/video/models/video_model.dart';

class PlaylistPlayerScreen extends StatefulWidget {
  final List<VideoModel> videos;
  final String title;
  final int initialVideoIndex;

  const PlaylistPlayerScreen({
    super.key,
    required this.videos,
    required this.title,
    this.initialVideoIndex = 0,
  });

  @override
  State<PlaylistPlayerScreen> createState() => _PlaylistPlayerScreenState();
}

class _PlaylistPlayerScreenState extends State<PlaylistPlayerScreen> {
  VideoPlayerController? _controller;
  late int _currentVideoIndex;
  bool _isInitialized = false;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentVideoIndex = widget.initialVideoIndex;
    _initializeVideo();
  }

  Future<void> _cleanupCurrentVideo() async {
    if (_controller != null) {
      await _controller!.pause();
      await _controller!.dispose();
      _controller = null;
    }
    if (mounted) {
      setState(() {
        _isInitialized = false;
      });
    }
  }

  Future<void> _initializeVideo() async {
    if (widget.videos.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Cleanup previous video first
    await _cleanupCurrentVideo();

    try {
      // Create new controller with lower quality settings
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videos[_currentVideoIndex].url),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true, // Allows mixing with other audio
        ),
        formatHint: VideoFormat.hls, // Use HLS if available for adaptive streaming
      );

      // Initialize with error handling
      await _controller!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timed out');
        },
      );

      _controller!.addListener(_videoListener);
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
        _controller!.play();
      }
    } catch (e) {
      // Cleanup on error
      await _cleanupCurrentVideo();
      
      if (mounted) {
        setState(() {
          _error = 'Error playing video: $e';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_error!),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _initializeVideo,
            ),
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (_controller?.value.hasError ?? false) {
      setState(() {
        _error = _controller?.value.errorDescription;
      });
      return;
    }
    
    if (_controller?.value.position != null && 
        _controller?.value.duration != null &&
        _controller!.value.position >= _controller!.value.duration) {
      _playNextVideo();
    }
  }

  Future<void> _playNextVideo() async {
    if (_currentVideoIndex < widget.videos.length - 1) {
      _currentVideoIndex++;
      await _initializeVideo();
    }
  }

  Future<void> _playPreviousVideo() async {
    if (_currentVideoIndex > 0) {
      _currentVideoIndex--;
      await _initializeVideo();
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _cleanupCurrentVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentVideo = widget.videos[_currentVideoIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          // Video player
          AspectRatio(
            aspectRatio: _isInitialized && _controller != null 
                ? _controller!.value.aspectRatio 
                : 16 / 9,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isInitialized && _controller != null)
                  VideoPlayer(_controller!)
                else if (_isLoading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red[300], size: 48),
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red[300]),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _initializeVideo,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                
                // Play/Pause overlay
                if (_isInitialized && _controller != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller!.value.isPlaying) {
                          _controller!.pause();
                        } else {
                          _controller!.play();
                        }
                      });
                    },
                    child: Container(
                      color: Colors.transparent,
                      child: Center(
                        child: Icon(
                          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 64.0,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Video controls
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and progress
                Text(
                  currentVideo.suggestedTitle ?? 'Untitled Video',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isInitialized && _controller != null) ...[
                  const SizedBox(height: 8),
                  // Progress bar
                  VideoProgressIndicator(
                    _controller!,
                    allowScrubbing: true,
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 4),
                  // Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_controller!.value.position)),
                      Text(_formatDuration(_controller!.value.duration)),
                    ],
                  ),
                ],
                
                // Playlist controls
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: _currentVideoIndex > 0 ? _playPreviousVideo : null,
                    ),
                    const SizedBox(width: 16),
                    if (_isInitialized && _controller != null)
                      IconButton(
                        icon: Icon(
                          _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        onPressed: () {
                          setState(() {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          });
                        },
                      ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      onPressed: _currentVideoIndex < widget.videos.length - 1 
                          ? _playNextVideo 
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Playlist
          Expanded(
            child: ListView.builder(
              itemCount: widget.videos.length,
              itemBuilder: (context, index) {
                final video = widget.videos[index];
                final isCurrentVideo = index == _currentVideoIndex;

                return ListTile(
                  leading: Container(
                    width: 80,
                    height: 45,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: video.thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              video.thumbnailUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.error),
                            ),
                          )
                        : const Icon(Icons.video_library),
                  ),
                  title: Text(
                    video.suggestedTitle ?? 'Untitled Video',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: isCurrentVideo ? FontWeight.bold : null,
                    ),
                  ),
                  tileColor: isCurrentVideo ? Colors.blue.withOpacity(0.1) : null,
                  onTap: () {
                    if (index != _currentVideoIndex) {
                      setState(() {
                        _currentVideoIndex = index;
                      });
                      _initializeVideo();
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 