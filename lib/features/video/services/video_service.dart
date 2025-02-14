import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_model.dart';
import '../../video_processing/services/video_search_service.dart';

class VideoService {
  final FirebaseFirestore _firestore;
  
  VideoService({FirebaseFirestore? firestore}) 
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _videos => 
      _firestore.collection('videos');

  // Search videos by keyword
  Future<List<VideoModel>> searchVideosByKeyword(String keyword) async {
    try {
      // Normalize the keyword to match the format in Firestore
      final normalizedKeyword = VideoSearchService.normalizeSearchTerm(keyword);
      
      try {
        // Try the compound query first
        final snapshot = await _videos
            .where('keywords', arrayContains: normalizedKeyword)
            .orderBy('timestamp', descending: true)
            .get();
        
        return _convertSnapshotToVideos(snapshot);
      } on FirebaseException catch (e) {
        // Handle index not ready error
        if (e.code == 'failed-precondition') {
          // Fall back to client-side filtering while index is building
          final allVideos = await _videos
              .orderBy('timestamp', descending: true)
              .get();
          
          return _convertSnapshotToVideos(allVideos)
              .where((video) => video.keywords?.any(
                  (k) => VideoSearchService.isKeywordMatch(normalizedKeyword, k)
                ) ?? false)
              .toList();
        }
        rethrow;
      }
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error searching videos: ${e.toString()}',
      );
    }
  }

  // Convert snapshot to video models
  List<VideoModel> _convertSnapshotToVideos(QuerySnapshot<Map<String, dynamic>> snapshot) {
    return snapshot.docs.map((doc) {
      final data = doc.data();
      return VideoModel(
        id: doc.id,
        userId: data['userId'] as String,
        url: data['url'] as String,
        thumbnailUrl: data['thumbnailUrl'] as String?,
        timestamp: (data['timestamp'] as Timestamp).toDate(),
        summary: data['summary'] as String?,
        keywords: (data['keywords'] as List?)?.map((e) => e as String).toList(),
        suggestedTitle: data['suggestedTitle'] as String?,
      );
    }).toList();
  }

  // Get all videos
  Future<List<VideoModel>> getAllVideos() async {
    try {
      final snapshot = await _videos
          .orderBy('timestamp', descending: true)
          .get();
      
      return _convertSnapshotToVideos(snapshot);
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
        summary: data['summary'] as String?,
        keywords: (data['keywords'] as List?)?.map((e) => e as String).toList(),
        suggestedTitle: data['suggestedTitle'] as String?,
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
      
      return _convertSnapshotToVideos(snapshot);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching user videos: ${e.toString()}',
      );
    }
  }
} 