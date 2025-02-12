import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import 'playlist_create_screen.dart';
import 'playlist_view_screen.dart';
import 'playlist_add_videos_screen.dart';

class PlaylistListScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final PlaylistService playlistService;

  PlaylistListScreen({
    super.key,
    FirebaseAuth? auth,
    PlaylistService? playlistService,
  })  : auth = auth ?? FirebaseAuth.instance,
        playlistService = playlistService ?? PlaylistService();

  @override
  State<PlaylistListScreen> createState() => _PlaylistListScreenState();
}

class _PlaylistListScreenState extends State<PlaylistListScreen> {
  Future<void> _navigateToCreatePlaylist() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => PlaylistCreateScreen(
          auth: widget.auth,
          playlistService: widget.playlistService,
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Playlist created successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.auth.currentUser?.uid;
    if (userId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Please sign in to view playlists',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/signin');
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Playlists'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreatePlaylist,
          ),
        ],
      ),
      body: StreamBuilder<List<PlaylistModel>>(
        stream: widget.playlistService.getUserPlaylists(userId),
        builder: (context, snapshot) {
          final playlists = snapshot.data ?? [];
          
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return _PlaylistCard(playlist: playlist);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToCreatePlaylist,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  final PlaylistModel playlist;

  const _PlaylistCard({
    required this.playlist,
  });

  Widget _buildThumbnail() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: playlist.thumbnailUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                playlist.thumbnailUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.playlist_play,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  );
                },
              ),
            )
          : Center(
              child: Icon(
                Icons.playlist_play,
                size: 48,
                color: Colors.grey[400],
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PlaylistViewScreen(
                playlist: playlist,
              ),
            ),
          );
        },
        onLongPress: () {
          // Show options menu
          showModalBottomSheet(
            context: context,
            builder: (context) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.add),
                  title: const Text('Add Videos'),
                  onTap: () {
                    Navigator.pop(context); // Close bottom sheet
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PlaylistAddVideosScreen(
                          playlist: playlist,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Playlist'),
                  onTap: () {
                    // TODO: Implement edit playlist
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: _buildThumbnail(),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          playlist.privacy == PlaylistPrivacy.private
                              ? Icons.lock
                              : playlist.privacy == PlaylistPrivacy.unlisted
                                  ? Icons.link
                                  : Icons.public,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${playlist.videoCount} videos',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 