import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final Function(double)? onAspectRatioUpdated;

  const VideoPlayerWidget({
    Key? key,
    required this.videoUrl,
    this.onAspectRatioUpdated,
  }) : super(key: key);

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.videoUrl);
    try {
      await _controller.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        // Notify parent of the actual video aspect ratio
        widget.onAspectRatioUpdated?.call(_controller.value.aspectRatio);
      }
      _controller.addListener(_videoListener);
    } catch (e) {
      print('Error initializing video: $e');
    }
  }

  void _videoListener() {
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying && mounted) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller),
          // Play/Pause button overlay
          if (!_isPlaying)
            Container(
              decoration: BoxDecoration(
                color: Colors.black26,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(
                  Icons.play_arrow,
                  size: 50,
                  color: Colors.white,
                ),
                onPressed: () => _controller.play(),
              ),
            ),
        ],
      ),
    );
  }
} 