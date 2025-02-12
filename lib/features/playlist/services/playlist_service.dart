import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/playlist_model.dart';

class PlaylistService {
  final FirebaseFirestore _firestore;
  
  PlaylistService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _playlists => 
      _firestore.collection('playlists');

  // Create a new playlist
  Future<PlaylistModel> createPlaylist({
    required String userId,
    required String title,
    String? description,
    PlaylistPrivacy privacy = PlaylistPrivacy.public,
  }) async {
    try {
      final docRef = await _playlists.add({
        'userId': userId,
        'title': title,
        'description': description,
        'privacy': privacy.name,
        'videoIds': [],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'videoCount': 0,
      });

      // Wait for the document to be created and fetch it
      final doc = await docRef.get();
      if (!doc.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          message: 'Failed to create playlist document',
        );
      }

      return PlaylistModel.fromFirestore(doc);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error creating playlist: ${e.toString()}',
      );
    }
  }

  // Get a playlist by ID
  Future<PlaylistModel?> getPlaylist(String playlistId) async {
    try {
      final doc = await _playlists.doc(playlistId).get();
      if (!doc.exists) return null;
      return PlaylistModel.fromFirestore(doc);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching playlist: ${e.toString()}',
      );
    }
  }

  // Get all public playlists
  Stream<List<PlaylistModel>> getPublicPlaylists() {
    return _playlists
        .where('privacy', isEqualTo: PlaylistPrivacy.public.toString())
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlaylistModel.fromFirestore(doc))
            .toList());
  }

  // Get user's playlists
  Stream<List<PlaylistModel>> getUserPlaylists(String userId) {
    return _playlists
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PlaylistModel.fromFirestore(doc))
            .toList());
  }

  // Update playlist details
  Future<void> updatePlaylist(String playlistId, {
    String? title,
    String? description,
    String? thumbnailUrl,
    PlaylistPrivacy? privacy,
    List<String>? videoIds,
  }) async {
    try {
      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (title != null) updates['title'] = title;
      if (description != null) updates['description'] = description;
      if (thumbnailUrl != null) updates['thumbnailUrl'] = thumbnailUrl;
      if (privacy != null) updates['privacy'] = privacy.toString();
      if (videoIds != null) {
        updates['videoIds'] = videoIds;
        updates['videoCount'] = videoIds.length;
      }

      await _playlists.doc(playlistId).update(updates);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error updating playlist: ${e.toString()}',
      );
    }
  }

  // Add video to playlist
  Future<void> addVideoToPlaylist(String playlistId, String videoId) async {
    try {
      await _playlists.doc(playlistId).update({
        'videoIds': FieldValue.arrayUnion([videoId]),
        'videoCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error adding video to playlist: ${e.toString()}',
      );
    }
  }

  // Remove video from playlist
  Future<void> removeVideoFromPlaylist(String playlistId, String videoId) async {
    try {
      await _playlists.doc(playlistId).update({
        'videoIds': FieldValue.arrayRemove([videoId]),
        'videoCount': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error removing video from playlist: ${e.toString()}',
      );
    }
  }

  // Delete playlist
  Future<void> deletePlaylist(String playlistId) async {
    try {
      await _playlists.doc(playlistId).delete();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error deleting playlist: ${e.toString()}',
      );
    }
  }

  // Reorder videos in playlist
  Future<void> reorderPlaylistVideos(
    String playlistId, 
    List<String> newVideoOrder
  ) async {
    try {
      await _playlists.doc(playlistId).update({
        'videoIds': newVideoOrder,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error reordering playlist videos: ${e.toString()}',
      );
    }
  }
} 