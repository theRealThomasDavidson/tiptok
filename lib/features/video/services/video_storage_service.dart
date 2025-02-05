import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/video_model.dart';

class VideoStorageService {
  final FirebaseStorage storage;

  VideoStorageService({
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  Future<String> uploadVideo(
    File videoFile, 
    String userId, 
    void Function(double)? onProgress
  ) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = 'videos/$userId/$timestamp.mp4';
    
    try {
      final ref = storage.ref().child(path);
      final uploadTask = ref.putFile(videoFile);
      
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });
      
      final snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
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
          final url = await item.getDownloadURL();
          final metadata = await item.getMetadata();
          
          videos.add(VideoModel(
            id: item.name,
            userId: prefix.name,
            url: url,
            timestamp: metadata.timeCreated ?? DateTime.now(),
          ));
        }
      }
      
      videos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return videos;
    } catch (e) {
      throw Exception('Failed to fetch videos: $e');
    }
  }
} 