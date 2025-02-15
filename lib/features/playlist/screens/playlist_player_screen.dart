import 'package:flutter/material.dart';
import '../../../features/video/models/video_model.dart';
import '../../../features/video/widgets/video_player_widget.dart';

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
  late int _currentVideoIndex;
  late PageController _pageController;
  double _currentAspectRatio = 16 / 9; // Default aspect ratio until video loads

  @override
  void initState() {
    super.initState();
    _currentVideoIndex = widget.initialVideoIndex;
    _pageController = PageController(initialPage: _currentVideoIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _playNextVideo() {
    if (_currentVideoIndex < widget.videos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _playPreviousVideo() {
    if (_currentVideoIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
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
          // Video Player with PageView for swipe navigation
          LayoutBuilder(
            builder: (context, constraints) {
              final screenHeight = MediaQuery.of(context).size.height;
              final playerHeight = screenHeight * 0.6; // 60% of screen height
              final playerWidth = constraints.maxWidth;

              // Calculate dimensions to maintain aspect ratio
              late final double effectiveWidth;
              late final double effectiveHeight;

              if (playerWidth / playerHeight > _currentAspectRatio) {
                // Screen is wider than video aspect ratio
                effectiveHeight = playerHeight;
                effectiveWidth = playerHeight * _currentAspectRatio;
              } else {
                // Screen is narrower than video aspect ratio
                effectiveWidth = playerWidth;
                effectiveHeight = playerWidth / _currentAspectRatio;
              }

              return Container(
                height: playerHeight,
                color: Colors.black,
                child: Center(
                  child: SizedBox(
                    width: effectiveWidth,
                    height: effectiveHeight,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentVideoIndex = index;
                        });
                      },
                      itemCount: widget.videos.length,
                      itemBuilder: (context, index) {
                        return VideoPlayerWidget(
                          videoUrl: widget.videos[index].url,
                          onAspectRatioUpdated: (aspectRatio) {
                            if (index == _currentVideoIndex) {
                              setState(() {
                                _currentAspectRatio = aspectRatio;
                              });
                            }
                          },
                        );
                      },
                    ),
                  ),
                ),
              );
            },
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
                const SizedBox(height: 16),
                
                // Playlist controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      onPressed: _currentVideoIndex > 0 ? _playPreviousVideo : null,
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
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
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