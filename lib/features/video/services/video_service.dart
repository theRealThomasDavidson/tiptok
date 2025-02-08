import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';

class VideoService {
  final FirebaseFirestore _firestore;
  
  VideoService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _videos => 
      _firestore.collection('videos');

  // Get all videos
  Future<List<VideoModel>> getAllVideos() async {
    try {
      final snapshot = await _videos
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return VideoModel(
          id: doc.id,
          userId: data['userId'] as String,
          url: data['url'] as String,
          thumbnailUrl: data['thumbnailUrl'] as String?,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching videos: ${e.toString()}',
      );
    }
  }

  // Get video by ID
  Future<VideoModel?> getVideo(String videoId) async {
    try {
      final doc = await _videos.doc(videoId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      return VideoModel(
        id: doc.id,
        userId: data['userId'] as String,
        url: data['url'] as String,
        thumbnailUrl: data['thumbnailUrl'] as String?,
        timestamp: (data['timestamp'] as Timestamp).toDate(),
      );
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching video: ${e.toString()}',
      );
    }
  }

  // Get videos by user ID
  Future<List<VideoModel>> getUserVideos(String userId) async {
    try {
      final snapshot = await _videos
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return VideoModel(
          id: doc.id,
          userId: data['userId'] as String,
          url: data['url'] as String,
          thumbnailUrl: data['thumbnailUrl'] as String?,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
        );
      }).toList();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching user videos: ${e.toString()}',
      );
    }
  }
} 