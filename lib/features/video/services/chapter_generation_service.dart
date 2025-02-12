import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_chapter_model.dart';
import '../../../config/api_config.dart';

class ChapterGenerationService {
  // Generate chapters for a video that's already uploaded to Firebase Storage
  Future<List<VideoChapter>> generateChapters(String firebaseVideoPath) async {
    try {
      // Call our local API
      final response = await http.post(
        Uri.parse(ApiConfig.generateChaptersEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Origin': ApiConfig.baseUrl,
        },
        body: json.encode({
          'videoPath': firebaseVideoPath,
          'chapterDuration': 30.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Parse the chapters from the response
        if (data['chapters'] != null) {
          return (data['chapters'] as List)
              .map((chapter) => VideoChapter.fromJson(chapter))
              .toList();
        }
        throw Exception('No chapters in response');
      } else {
        print('Error response: ${response.body}');  // Add debug logging
        throw Exception('Failed to generate chapters: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating chapters: $e');  // Add debug logging
      throw Exception('Error generating chapters: $e');
    }
  }

  // Get existing chapters for a video
  Future<List<VideoChapter>> getExistingChapters(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getChaptersEndpoint}/$videoId'),
        headers: {
          'Accept': 'application/json',
          'Origin': ApiConfig.baseUrl,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['chapters'] != null) {
          return (data['chapters'] as List)
              .map((chapter) => VideoChapter.fromJson(chapter))
              .toList();
        }
        return [];  // No chapters yet
      } else if (response.statusCode == 404) {
        return [];  // No chapters yet
      } else {
        print('Error response: ${response.body}');  // Add debug logging
        throw Exception('Failed to fetch chapters: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching chapters: $e');  // Add debug logging
      throw Exception('Error fetching chapters: $e');
    }
  }
} 