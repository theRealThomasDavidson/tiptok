import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../../video/models/video_model.dart';
import '../../video/services/video_service.dart';
import '../../video/widgets/video_player_widget.dart';

class PlaylistPlaybackScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final int initialVideoIndex;
  final VideoService videoService;

  PlaylistPlaybackScreen({
    super.key,
    required this.playlist,
    required this.initialVideoIndex,
    VideoService? videoService,
  }) : videoService = videoService ?? VideoService();

  @override
  State<PlaylistPlaybackScreen> createState() => _PlaylistPlaybackScreenState();
}

class _PlaylistPlaybackScreenState extends State<PlaylistPlaybackScreen> {
  List<VideoModel>? _videos;
  late int _currentIndex;
  bool _isLoading = true;
  String? _error;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialVideoIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _loadPlaylistVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylistVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get fresh videos one by one
      final playlistVideos = <VideoModel>[];
      for (final videoId in widget.playlist.videoIds) {
        final video = await widget.videoService.getVideo(videoId);
        if (video != null) {
          playlistVideos.add(video);
        }
      }

      setState(() {
        _videos = playlistVideos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _playNextVideo() {
    if (_videos == null || _currentIndex >= _videos!.length - 1) return;
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _playPreviousVideo() {
    if (_videos == null || _currentIndex <= 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.playlist.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadPlaylistVideos,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _videos!.isEmpty
                  ? const Center(
                      child: Text('No videos in this playlist'),
                    )
                  : Column(
                      children: [
                        // Video Player with PageView for swipe navigation
                        Expanded(
                          child: Container(
                            color: Colors.black,
                            child: PageView.builder(
                              controller: _pageController,
                              onPageChanged: (index) {
                                setState(() {
                                  _currentIndex = index;
                                });
                              },
                              itemCount: _videos!.length,
                              itemBuilder: (context, index) {
                                return Center(
                                  child: VideoPlayerWidget(
                                    videoUrl: _videos![index].url,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        // Playlist Controls
                        Container(
                          padding: const EdgeInsets.all(16),
                          color: Colors.black87,
                          child: Column(
                            children: [
                              // Progress indicator
                              LinearProgressIndicator(
                                value: (_currentIndex + 1) / _videos!.length,
                                backgroundColor: Colors.grey[800],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Video info and swipe hint
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Video ${_currentIndex + 1} of ${_videos!.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.swipe,
                                    color: Colors.white.withOpacity(0.7),
                                    size: 16,
                                  ),
                                  Text(
                                    ' Swipe to navigate',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Control buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.skip_previous),
                                    onPressed: _currentIndex > 0
                                        ? _playPreviousVideo
                                        : null,
                                    color: Colors.white,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.skip_next),
                                    onPressed: _currentIndex < _videos!.length - 1
                                        ? _playNextVideo
                                        : null,
                                    color: Colors.white,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
} 