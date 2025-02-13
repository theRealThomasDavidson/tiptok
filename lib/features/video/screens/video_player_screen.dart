import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../models/video_model.dart';
import '../models/video_chapter_model.dart';
import '../services/chapter_generation_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final VideoModel video;

  const VideoPlayerScreen({
    Key? key,
    required this.video,
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  List<VideoChapter>? _chapters;
  bool _isLoadingChapters = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _loadChapters();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.network(widget.video.url);
    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.addListener(_videoListener);
    } catch (e) {
      setState(() {
        _error = 'Error loading video: $e';
      });
    }
  }

  void _videoListener() {
    final isPlaying = _controller.value.isPlaying;
    if (isPlaying != _isPlaying) {
      setState(() {
        _isPlaying = isPlaying;
      });
    }
  }

  Future<void> _loadChapters() async {
    if (_chapters != null) return;

    setState(() {
      _isLoadingChapters = true;
      _error = null;
    });

    try {
      final service = ChapterGenerationService();
      final chapters = await service.getExistingChapters(widget.video.id);
      
      if (mounted) {
        setState(() {
          _chapters = chapters;
          _isLoadingChapters = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading chapters: $e';
          _isLoadingChapters = false;
        });
      }
    }
  }

  void _seekToChapter(VideoChapter chapter) {
    _controller.seekTo(Duration(milliseconds: (chapter.startTime * 1000).round()));
    if (!_controller.value.isPlaying) {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    super.dispose();
  }

  Widget _buildVideoPlayer() {
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

  Widget _buildChaptersList() {
    if (_isLoadingChapters) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    if (_chapters == null || _chapters!.isEmpty) {
      return const Center(
        child: Text('No chapters available'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: _chapters!.length,
      itemBuilder: (context, index) {
        final chapter = _chapters![index];
        return ListTile(
          title: Text(chapter.summary),
          subtitle: Text(
            '${(chapter.startTime / 60).floor()}:${(chapter.startTime % 60).round().toString().padLeft(2, '0')} - '
            '${(chapter.endTime / 60).floor()}:${(chapter.endTime % 60).round().toString().padLeft(2, '0')}',
          ),
          onTap: () => _seekToChapter(chapter),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Player'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildVideoPlayer(),
          // Video controls
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      _isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                ),
              ],
            ),
          ),
          // Chapters section
          Expanded(
            child: _buildChaptersList(),
          ),
        ],
      ),
    );
  }
} 