import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import '../models/video_model.dart';
import 'package:flutter/foundation.dart';

class VideoStorageService {
  final FirebaseStorage storage;
  final FirebaseFirestore _firestore;

  VideoStorageService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
  }) : storage = storage ?? FirebaseStorage.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String> _generateThumbnail(File videoFile) async {
    final tempDir = await getTemporaryDirectory();
    final thumbnailPath = '${tempDir.path}/thumbnail_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // Use FFmpeg to extract a frame at 0.0 seconds as thumbnail
    final command = '-i "${videoFile.path}" -ss 0.0 -vframes 1 "$thumbnailPath"';
    
    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      throw Exception('Failed to generate thumbnail');
    }

    return thumbnailPath;
  }

  Future<String> _uploadThumbnail(String thumbnailPath, String userId, String videoTimestamp) async {
    final path = 'thumbnails/$userId/${videoTimestamp}_thumb.jpg';
    final thumbnailFile = File(thumbnailPath);
    
    try {
      final ref = storage.ref().child(path);
      final uploadTask = ref.putFile(thumbnailFile);
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } finally {
      // Clean up the temporary thumbnail file
      try {
        await thumbnailFile.delete();
      } catch (e) {
        // Ignore cleanup errors
      }
    }
  }

  Future<VideoModel> uploadVideo(
    File videoFile, 
    String userId, 
    void Function(double)? onProgress
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final videoPath = 'videos/$userId/${timestamp}.mp4';
    String? thumbnailUrl;
    String? videoUrl;
    
    try {
      // Generate and upload thumbnail first
      final thumbnailPath = await _generateThumbnail(videoFile);
      thumbnailUrl = await _uploadThumbnail(thumbnailPath, userId, timestamp);

      // Upload the video
      final ref = storage.ref().child(videoPath);
      final uploadTask = ref.putFile(videoFile);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      final snapshot = await uploadTask;
      videoUrl = await snapshot.ref.getDownloadURL();

      // Create video metadata in Firestore
      final videoRef = await _firestore.collection('videos').add({
        'userId': userId,
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Create and return the video model
      return VideoModel(
        id: videoRef.id,
        userId: userId,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      // If thumbnail or video was uploaded but Firestore update failed, try to clean up
      if (thumbnailUrl != null) {
        try {
          await storage.refFromURL(thumbnailUrl).delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      if (videoUrl != null) {
        try {
          await storage.refFromURL(videoUrl).delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<List<VideoModel>> getAllVideos() async {
    try {
      final ListResult result = await storage.ref('videos').listAll();
      List<VideoModel> videos = [];
      
      for (var prefix in result.prefixes) {
        try {
          final userVideos = await prefix.listAll();
          
          for (var item in userVideos.items) {
            try {
              final url = await item.getDownloadURL();
              final metadata = await item.getMetadata();
              
              // Try to get thumbnail URL
              String? thumbnailUrl;
              try {
                final thumbRef = storage.ref('thumbnails/${prefix.name}/${item.name}_thumb.jpg');
                thumbnailUrl = await thumbRef.getDownloadURL();
              } catch (e) {
                // Ignore thumbnail errors
                debugPrint('Thumbnail not found for video ${item.name}');
              }
              
              videos.add(VideoModel(
                id: item.name,
                userId: prefix.name,
                url: url,
                thumbnailUrl: thumbnailUrl,
                timestamp: metadata.timeCreated ?? DateTime.now(),
              ));
            } catch (e) {
              // Ignore errors for individual videos
              debugPrint('Error processing video ${item.name}: $e');
              continue;
            }
          }
        } catch (e) {
          // Ignore errors for user folders
          debugPrint('Error processing user folder ${prefix.name}: $e');
          continue;
        }
      }
      
      videos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return videos;
    } catch (e) {
      debugPrint('Failed to fetch videos: $e');
      return []; // Return empty list instead of throwing
    }
  }
} 