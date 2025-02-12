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
      setState(() {
        _error = e.toString();
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

  Widget _buildVideoThumbnail(VideoModel video) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: video.thumbnailUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                video.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.video_library,
                      size: 32,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Icon(
                Icons.video_library,
                size: 32,
                color: Colors.grey[400],
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
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadVideos,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
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
                                  child: InkWell(
                                    onTap: () => _addVideoToPlaylist(video),
                                    child: _buildVideoThumbnail(video),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                    const Divider(thickness: 2),

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
                            return ListTile(
                              leading: SizedBox(
                                width: 80,
                                height: 60,
                                child: _buildVideoThumbnail(video),
                              ),
                              title: Text(
                                video.name ?? 'Video ${index + 1}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removeVideoFromPlaylist(video),
                              ),
                              onTap: () => _navigateToPlayback(index),
                            );
                          },
                        ),
                      ),
                  ],
                ),
    );
  }
} 