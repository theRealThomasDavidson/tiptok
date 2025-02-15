import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_model.dart';
import '../../video_processing/services/video_search_service.dart';
import 'package:flutter/foundation.dart';

class VideoService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  
  VideoService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  // Collection reference
  CollectionReference<Map<String, dynamic>> get _videos => 
      _firestore.collection('videos');

  // Validate and refresh video URL if needed
  Future<String> _getValidVideoUrl(String storagePath) async {
    try {
      final ref = _storage.ref(storagePath);
      // Get a fresh URL with maximum expiration
      return await ref.getDownloadURL();
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error getting valid video URL: ${e.toString()}',
      );
    }
  }

  // Convert snapshot to video models with URL validation
  Future<List<VideoModel>> _convertSnapshotToVideos(QuerySnapshot<Map<String, dynamic>> snapshot) async {
    final videos = <VideoModel>[];
    
    for (var doc in snapshot.docs) {
      try {
        final data = doc.data();
        String url = data['url'] as String;
        String? thumbnailUrl = data['thumbnailUrl'] as String?;
        
        // If we have storage paths, try to get fresh URLs
        final storagePath = data['storagePath'] as String?;
        final thumbnailPath = data['thumbnailPath'] as String?;
        
        if (storagePath != null) {
          try {
            url = await _getValidVideoUrl(storagePath);
          } catch (e) {
            debugPrint('Error refreshing video URL for ${doc.id}: $e');
            // Continue with existing URL if refresh fails
          }
        }
        
        if (thumbnailPath != null) {
          try {
            thumbnailUrl = await _storage.ref(thumbnailPath).getDownloadURL();
          } catch (e) {
            debugPrint('Error refreshing thumbnail URL for ${doc.id}: $e');
            // Continue with existing URL if refresh fails
          }
        }

        videos.add(VideoModel(
          id: doc.id,
          userId: data['userId'] as String,
          url: url,
          storagePath: storagePath,
          thumbnailUrl: thumbnailUrl,
          thumbnailPath: thumbnailPath,
          timestamp: (data['timestamp'] as Timestamp).toDate(),
          summary: data['summary'] as String?,
          keywords: (data['keywords'] as List?)?.map((e) => e as String).toList(),
          suggestedTitle: data['suggestedTitle'] as String?,
        ));
      } catch (e) {
        debugPrint('Error converting video ${doc.id}: $e');
        // Skip invalid videos
        continue;
      }
    }
    
    return videos;
  }

  // Search videos by keyword
  Future<List<VideoModel>> searchVideosByKeyword(String keyword) async {
    try {
      final normalizedKeyword = VideoSearchService.normalizeSearchTerm(keyword);
      
      try {
        final snapshot = await _videos
            .where('keywords', arrayContains: normalizedKeyword)
            .orderBy('timestamp', descending: true)
            .get();
        
        return await _convertSnapshotToVideos(snapshot);
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          final allVideos = await _videos
              .orderBy('timestamp', descending: true)
              .get();
          
          final videos = await _convertSnapshotToVideos(allVideos);
          return videos.where((video) => video.keywords?.any(
              (k) => VideoSearchService.isKeywordMatch(normalizedKeyword, k)
            ) ?? false).toList();
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

  // Get all videos
  Future<List<VideoModel>> getAllVideos() async {
    try {
      final snapshot = await _videos
          .orderBy('timestamp', descending: true)
          .get();
      
      return await _convertSnapshotToVideos(snapshot);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching videos: ${e.toString()}',
      );
    }
  }

  // Get video by ID with fresh URL
  Future<VideoModel?> getVideo(String videoId) async {
    try {
      final doc = await _videos.doc(videoId).get();
      if (!doc.exists) return null;
      
      final data = doc.data()!;
      final storagePath = data['storagePath'] as String?;
      String url = data['url'] as String;
      
      // If we have a storage path, get a fresh URL
      if (storagePath != null) {
        try {
          url = await _getValidVideoUrl(storagePath);
        } catch (e) {
          debugPrint('Error refreshing URL for video $videoId: $e');
          // Continue with existing URL if refresh fails
        }
      }

      return VideoModel(
        id: doc.id,
        userId: data['userId'] as String,
        url: url,
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
      
      return await _convertSnapshotToVideos(snapshot);
    } catch (e) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        message: 'Error fetching user videos: ${e.toString()}',
      );
    }
  }
} 