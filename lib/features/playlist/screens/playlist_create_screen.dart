import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/playlist_model.dart';
import '../services/playlist_service.dart';
import '../screens/playlist_add_videos_screen.dart';

class PlaylistCreateScreen extends StatefulWidget {
  final FirebaseAuth auth;
  final PlaylistService playlistService;

  PlaylistCreateScreen({
    super.key,
    FirebaseAuth? auth,
    PlaylistService? playlistService,
  })  : auth = auth ?? FirebaseAuth.instance,
        playlistService = playlistService ?? PlaylistService();

  @override
  State<PlaylistCreateScreen> createState() => _PlaylistCreateScreenState();
}

class _PlaylistCreateScreenState extends State<PlaylistCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  PlaylistPrivacy _privacy = PlaylistPrivacy.public;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createPlaylist() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = widget.auth.currentUser?.uid;
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please sign in to create playlists')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint('Creating playlist with title: ${_titleController.text}');
      debugPrint('Current user ID: $userId');
      
      final playlist = await widget.playlistService.createPlaylist(
        userId: userId,
        title: _titleController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        privacy: _privacy,
      );

      debugPrint('Playlist created successfully');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PlaylistAddVideosScreen(
              playlist: playlist,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error creating playlist: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating playlist: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _createPlaylist,
            ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Playlist'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Privacy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<PlaylistPrivacy>(
                      title: const Text('Public'),
                      subtitle: const Text('Anyone can view this playlist'),
                      value: PlaylistPrivacy.public,
                      groupValue: _privacy,
                      onChanged: (value) {
                        setState(() {
                          _privacy = value!;
                        });
                      },
                    ),
                    RadioListTile<PlaylistPrivacy>(
                      title: const Text('Private'),
                      subtitle: const Text('Only you can view this playlist'),
                      value: PlaylistPrivacy.private,
                      groupValue: _privacy,
                      onChanged: (value) {
                        setState(() {
                          _privacy = value!;
                        });
                      },
                    ),
                    RadioListTile<PlaylistPrivacy>(
                      title: const Text('Unlisted'),
                      subtitle: const Text(
                          'Anyone with the link can view this playlist'),
                      value: PlaylistPrivacy.unlisted,
                      groupValue: _privacy,
                      onChanged: (value) {
                        setState(() {
                          _privacy = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createPlaylist,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(),
                      )
                    : const Text('Create Playlist'),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 