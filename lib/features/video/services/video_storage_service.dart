import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../models/video_model.dart';
import '../../video_processing/services/video_processing_service.dart';
import '../../video_processing/models/video_summary.dart';

class VideoStorageService {
  final FirebaseStorage storage;
  final FirebaseFirestore _firestore;
  final VideoProcessingService _processingService;

  VideoStorageService({
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    VideoProcessingService? processingService,
  }) : storage = storage ?? FirebaseStorage.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _processingService = processingService ?? VideoProcessingService();

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

      // Wait a bit for Firebase to process the video and retry API call if needed
      VideoSummary? summary;
      int retries = 3;
      while (retries > 0) {
        try {
          // Small delay before each attempt
          await Future.delayed(Duration(seconds: 2));
          
          // Check if App Check token is available
          try {
            await FirebaseAppCheck.instance.getToken();
          } catch (appCheckError) {
            print('Warning: App Check error: $appCheckError');
            // Continue anyway - we're using debug provider
          }
          
          summary = await _processingService.getSummary(videoPath);
          break; // Success, exit loop
        } catch (e) {
          print('Attempt ${3 - retries + 1} failed: $e');
          retries--;
          if (retries == 0) {
            if (e.toString().contains('No AppCheckProvider installed')) {
              // If it's an App Check error, try one last time without waiting
              try {
                summary = await _processingService.getSummary(videoPath);
                break;
              } catch (finalError) {
                throw Exception('Failed to process video after retries: $finalError');
              }
            } else {
              rethrow; // Other errors, just rethrow
            }
          }
          // Otherwise continue to next retry
        }
      }

      if (summary == null) {
        throw Exception('Failed to get video summary after retries');
      }

      // Create video metadata in Firestore
      final videoRef = await _firestore.collection('videos').add({
        'userId': userId,
        'url': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'timestamp': FieldValue.serverTimestamp(),
        'summary': summary.summary,
        'keywords': summary.keywords,
        'suggestedTitle': summary.suggestedTitle,
      });

      // Create and return the video model
      return VideoModel(
        id: videoRef.id,
        userId: userId,
        url: videoUrl,
        thumbnailUrl: thumbnailUrl,
        timestamp: DateTime.now(),
        summary: summary.summary,
        keywords: summary.keywords,
        suggestedTitle: summary.suggestedTitle,
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
              // Ignore if thumbnail doesn't exist
              print('Thumbnail not found for ${item.name}: $e');
            }

            // Only add videos that successfully loaded
            videos.add(VideoModel(
              id: item.name,
              userId: prefix.name,
              url: url,
              thumbnailUrl: thumbnailUrl,
              timestamp: metadata.timeCreated ?? DateTime.now(),
            ));
          } catch (e) {
            print('Error loading video ${item.name}: $e');
            // If this was a 404 error, clean up the reference from Firestore
            if (e is FirebaseException && e.code == 'storage/object-not-found') {
              try {
                // Get video ID from the file name
                final videoId = item.name.split('.').first;
                await _firestore.collection('videos').doc(videoId).delete();
                print('Cleaned up orphaned reference for video $videoId');
              } catch (cleanupError) {
                print('Error cleaning up orphaned reference: $cleanupError');
              }
            }
            // Continue to next video
            continue;
          }
        }
      }
      
      videos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return videos;
    } catch (e) {
      print('Error fetching videos: $e');
      throw Exception('Failed to fetch videos: $e');
    }
  }
} 