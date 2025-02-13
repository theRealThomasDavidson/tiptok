import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      _controller = controller;

      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'This video is no longer available';
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage ?? 'Error playing video',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    // Get the screen size
    final size = MediaQuery.of(context).size;
    final videoSize = _controller!.value.size;
    
    // Calculate the aspect ratio
    final aspectRatio = videoSize.width / videoSize.height;
    
    // Calculate the video dimensions to fit the screen while maintaining aspect ratio
    double width = size.width;
    double height = size.width / aspectRatio;
    
    // If the height would be greater than the screen height, scale it down
    if (height > size.height) {
      height = size.height;
      width = height * aspectRatio;
    }

    return SizedBox(
      width: width,
      height: height,
      child: VideoPlayer(_controller!),
    );
  }
} 