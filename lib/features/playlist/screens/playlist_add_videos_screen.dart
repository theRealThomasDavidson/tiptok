import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import '../../video/models/video_model.dart';
import '../../video/services/video_service.dart';

class PlaylistAddVideosScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final FirebaseAuth auth;
  final PlaylistService playlistService;
  final VideoService videoService;

  PlaylistAddVideosScreen({
    super.key,
    required this.playlist,
    FirebaseAuth? auth,
    PlaylistService? playlistService,
    VideoService? videoService,
  })  : auth = auth ?? FirebaseAuth.instance,
        playlistService = playlistService ?? PlaylistService(),
        videoService = videoService ?? VideoService();

  @override
  State<PlaylistAddVideosScreen> createState() => _PlaylistAddVideosScreenState();
}

class _PlaylistAddVideosScreenState extends State<PlaylistAddVideosScreen> {
  bool _isLoading = false;
  final Set<String> _selectedVideoIds = {};
  List<VideoModel> _allVideos = [];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all available videos from Firestore
      _allVideos = await widget.videoService.getAllVideos();
      debugPrint('Loaded ${_allVideos.length} videos');
    } catch (e) {
      debugPrint('Error loading videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading videos: ${e.toString()}'),
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

  void _toggleVideoSelection(String videoId) {
    setState(() {
      if (_selectedVideoIds.contains(videoId)) {
        _selectedVideoIds.remove(videoId);
      } else {
        _selectedVideoIds.add(videoId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get included videos (already in playlist)
    final includedVideos = _allVideos.where(
      (video) => widget.playlist.videoIds.contains(video.id)
    ).toList();

    // Get available videos (not in playlist)
    final availableVideos = _allVideos.where(
      (video) => !widget.playlist.videoIds.contains(video.id)
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Playlist'),
        actions: [
          TextButton(
            onPressed: _selectedVideoIds.isEmpty ? null : _saveSelectedVideos,
            child: Text(
              'Save',
              style: TextStyle(
                color: _selectedVideoIds.isEmpty ? Colors.grey : Colors.blue,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Included Videos Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Included Videos',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (includedVideos.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No videos in playlist yet',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          height: 120,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: includedVideos.length,
                            itemBuilder: (context, index) {
                              final video = includedVideos[index];
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _VideoThumbnail(
                                  video: video,
                                  isSelected: _selectedVideoIds.contains(video.id),
                                  onTap: () => _toggleVideoSelection(video.id),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(thickness: 2),

                // Available Videos Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Available Videos',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Available Videos Grid
                Expanded(
                  child: availableVideos.isEmpty
                      ? const Center(
                          child: Text(
                            'No more videos available to add',
                            style: TextStyle(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 16 / 9,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: availableVideos.length,
                          itemBuilder: (context, index) {
                            final video = availableVideos[index];
                            return _VideoThumbnail(
                              video: video,
                              isSelected: _selectedVideoIds.contains(video.id),
                              onTap: () => _toggleVideoSelection(video.id),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _saveSelectedVideos() async {
    if (_selectedVideoIds.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Add selected videos to playlist
      for (final videoId in _selectedVideoIds) {
        await widget.playlistService.addVideoToPlaylist(
          widget.playlist.id,
          videoId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Videos added to playlist successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding videos: ${e.toString()}'),
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
}

class _VideoThumbnail extends StatelessWidget {
  final VideoModel video;
  final bool isSelected;
  final VoidCallback onTap;

  const _VideoThumbnail({
    required this.video,
    required this.isSelected,
    required this.onTap,
  });

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: const Center(
        child: Icon(
          Icons.video_library,
          size: 32,
          color: Colors.grey,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
              border: isSelected
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: video.thumbnailUrl != null
                  ? Image.network(
                      video.thumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholder();
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    )
                  : _buildPlaceholder(),
            ),
          ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }
} 