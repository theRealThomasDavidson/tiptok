import 'package:cloud_firestore/cloud_firestore.dart';

enum PlaylistPrivacy {
  public,
  private,
  unlisted
}

class PlaylistModel {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? thumbnailUrl;
  final PlaylistPrivacy privacy;
  final List<String> videoIds;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Get video count directly from videoIds length
  int get videoCount => videoIds.length;

  PlaylistModel({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.thumbnailUrl,
    this.privacy = PlaylistPrivacy.public,
    List<String>? videoIds,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : videoIds = videoIds ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // Create from Firestore document
  factory PlaylistModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final videoIds = List<String>.from(data['videoIds'] ?? []);
    return PlaylistModel(
      id: doc.id,
      userId: data['userId'] as String,
      title: data['title'] as String,
      description: data['description'] as String?,
      thumbnailUrl: data['thumbnailUrl'] as String?,
      privacy: PlaylistPrivacy.values.firstWhere(
        (e) => e.name == data['privacy'],
        orElse: () => PlaylistPrivacy.public,
      ),
      videoIds: videoIds,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'thumbnailUrl': thumbnailUrl,
      'privacy': privacy.toString(),
      'videoIds': videoIds,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'videoCount': videoIds.length,  // Include for backwards compatibility
    };
  }

  // Create a copy with updated fields
  PlaylistModel copyWith({
    String? title,
    String? description,
    String? thumbnailUrl,
    PlaylistPrivacy? privacy,
    List<String>? videoIds,
  }) {
    return PlaylistModel(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: description ?? this.description,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      privacy: privacy ?? this.privacy,
      videoIds: videoIds ?? this.videoIds,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  // Add a video to the playlist
  PlaylistModel addVideo(String videoId) {
    if (videoIds.contains(videoId)) return this;
    final newVideoIds = [...videoIds, videoId];
    return copyWith(videoIds: newVideoIds);
  }

  // Remove a video from the playlist
  PlaylistModel removeVideo(String videoId) {
    if (!videoIds.contains(videoId)) return this;
    final newVideoIds = videoIds.where((id) => id != videoId).toList();
    return copyWith(videoIds: newVideoIds);
  }

  // Reorder videos in the playlist
  PlaylistModel reorderVideos(int oldIndex, int newIndex) {
    if (oldIndex < 0 || 
        newIndex < 0 || 
        oldIndex >= videoIds.length || 
        newIndex >= videoIds.length) {
      return this;
    }

    final newVideoIds = List<String>.from(videoIds);
    final String item = newVideoIds.removeAt(oldIndex);
    newVideoIds.insert(newIndex, item);

    return copyWith(videoIds: newVideoIds);
  }
} 