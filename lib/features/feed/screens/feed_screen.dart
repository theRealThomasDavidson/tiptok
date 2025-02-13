import 'package:flutter/material.dart';
import '../../../features/video/models/video_model.dart';
import '../../../features/video/screens/video_player_screen.dart';
import '../../../features/video/services/video_storage_service.dart';
import '../widgets/video_card.dart';

class FeedScreen extends StatefulWidget {
  final VideoStorageService videoService;

  const FeedScreen({Key? key, required this.videoService}) : super(key: key);

  @override
  _FeedScreenState createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<VideoModel>> _videosFuture;
  final _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _videosFuture = _loadVideos();
  }

  Future<List<VideoModel>> _loadVideos() async {
    try {
      return await widget.videoService.getAllVideos();
    } catch (e) {
      print('Error loading feed: $e');
      throw e; // Let the FutureBuilder handle the error state
    }
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _videosFuture = _loadVideos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        key: _refreshKey,
        onRefresh: _handleRefresh,
        child: FutureBuilder<List<VideoModel>>(
          future: _videosFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading feed\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _handleRefresh,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              );
            }

            final videos = snapshot.data ?? [];
            
            if (videos.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.video_library_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No videos yet\nBe the first to post!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: videos.length,
              itemBuilder: (context, index) {
                final video = videos[index];
                return VideoCard(
                  video: video,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VideoPlayerScreen(video: video),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
} 