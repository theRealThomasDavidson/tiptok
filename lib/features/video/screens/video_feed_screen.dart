import 'package:flutter/material.dart';
import '../models/video_model.dart';
import '../services/video_storage_service.dart';
import '../widgets/video_player_widget.dart';

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  final VideoStorageService _storageService = VideoStorageService();
  List<VideoModel>? _videos;
  String? _error;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() {
        _error = null;
      });
      final videos = await _storageService.getAllVideos();
      setState(() {
        _videos = videos;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(
              onPressed: _loadVideos,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_videos == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_videos!.isEmpty) {
      return const Center(
        child: Text('No videos uploaded yet'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVideos,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: _videos!.length,
        itemBuilder: (context, index) {
          final video = _videos![index];
          return Container(
            color: Colors.black,
            child: SafeArea(
              child: Stack(
                children: [
                  // Center the video player while maintaining aspect ratio
                  Center(
                    child: VideoPlayerWidget(
                      videoUrl: video.url,
                    ),
                  ),

                  // Metadata Overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (video.name != null)
                            Text(
                              video.name!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Uploaded by: ${video.userId}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          if (video.description != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              video.description!,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  // Swipe Indicator
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white.withOpacity(0.8),
                          ),
                          Text(
                            'Swipe up for next video',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
} 