import 'package:flutter/material.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import '../../video/models/video_model.dart';
import '../../video/services/video_service.dart';
import 'playlist_add_videos_screen.dart';
import 'playlist_playback_screen.dart';

class PlaylistViewScreen extends StatefulWidget {
  final PlaylistModel playlist;
  final VideoService videoService;
  final PlaylistService playlistService;

  PlaylistViewScreen({
    super.key,
    required this.playlist,
    VideoService? videoService,
    PlaylistService? playlistService,
  }) : videoService = videoService ?? VideoService(),
       playlistService = playlistService ?? PlaylistService();

  @override
  State<PlaylistViewScreen> createState() => _PlaylistViewScreenState();
}

class _PlaylistViewScreenState extends State<PlaylistViewScreen> {
  List<VideoModel>? _videos;
  List<VideoModel>? _availableVideos;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allVideos = await widget.videoService.getAllVideos();
      
      // Filter videos into playlist videos and available videos
      final playlistVideos = <VideoModel>[];
      final availableVideos = <VideoModel>[];
      
      for (final video in allVideos) {
        if (widget.playlist.videoIds.contains(video.id)) {
          playlistVideos.add(video);
        } else {
          availableVideos.add(video);
        }
      }

      // Sort playlist videos according to playlist order
      playlistVideos.sort((a, b) {
        final indexA = widget.playlist.videoIds.indexOf(a.id);
        final indexB = widget.playlist.videoIds.indexOf(b.id);
        return indexA.compareTo(indexB);
      });

      setState(() {
        _videos = playlistVideos;
        _availableVideos = availableVideos;
        _isLoading = false;
      });
    } catch (e) {
      // Instead of showing error, just show empty state
      setState(() {
        _videos = [];
        _availableVideos = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _addVideoToPlaylist(VideoModel video) async {
    // Optimistically update UI
    setState(() {
      _availableVideos!.remove(video);
      _videos ??= [];
      _videos!.add(video);
    });

    try {
      await widget.playlistService.addVideoToPlaylist(
        widget.playlist.id,
        video.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video added to playlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        _videos!.remove(video);
        _availableVideos!.insert(0, video);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeVideoFromPlaylist(VideoModel video) async {
    // Optimistically update UI
    setState(() {
      _videos!.remove(video);
      _availableVideos!.insert(0, video);  // Add to front of available videos
    });

    try {
      await widget.playlistService.removeVideoFromPlaylist(
        widget.playlist.id,
        video.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video removed from playlist'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Revert UI on error
      setState(() {
        _availableVideos!.remove(video);
        _videos!.add(video);
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToPlayback(int startIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistPlaybackScreen(
          playlist: widget.playlist,
          initialVideoIndex: startIndex,
        ),
      ),
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
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available Videos Section
                if (_availableVideos != null && _availableVideos!.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Available Videos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      SizedBox(
                        height: 150,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          itemCount: _availableVideos!.length,
                          itemBuilder: (context, index) {
                            final video = _availableVideos![index];
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: SizedBox(
                                width: 200,
                                child: Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _addVideoToPlaylist(video),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Expanded(
                                          child: Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              if (video.thumbnailUrl != null)
                                                Image.network(
                                                  video.thumbnailUrl!,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return _buildPlaceholder();
                                                  },
                                                )
                                              else
                                                _buildPlaceholder(),
                                              Container(
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.center,
                                                    end: Alignment.bottomCenter,
                                                    colors: [
                                                      Colors.transparent,
                                                      Colors.black.withOpacity(0.7),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              const Center(
                                                child: Icon(
                                                  Icons.add_circle_outline,
                                                  color: Colors.white,
                                                  size: 40,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Text(
                                            'Tap to add',
                                            style: Theme.of(context).textTheme.bodyMedium,
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(height: 32, thickness: 2),
                    ],
                  ),

                // Playlist Videos Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Playlist Videos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (_videos == null || _videos!.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('No videos in playlist yet'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _videos!.length,
                      itemBuilder: (context, index) {
                        final video = _videos![index];
                        return Card(
                          margin: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 8,
                          ),
                          child: Column(
                            children: [
                              AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                  child: video.thumbnailUrl != null
                                      ? Image.network(
                                          video.thumbnailUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildPlaceholder();
                                          },
                                        )
                                      : _buildPlaceholder(),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Video ${index + 1}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline),
                                          color: Colors.red,
                                          onPressed: () => _removeVideoFromPlaylist(video),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () => _navigateToPlayback(index),
                                          icon: const Icon(Icons.play_arrow),
                                          label: const Text('Play'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 48,
          color: Colors.white,
        ),
      ),
    );
  }
} 