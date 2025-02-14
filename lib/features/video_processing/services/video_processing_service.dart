import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/video_summary.dart';
import '../models/video_chapter.dart';

class VideoProcessingException implements Exception {
  final String message;
  final int? statusCode;

  VideoProcessingException(this.message, [this.statusCode]);

  @override
  String toString() => 'VideoProcessingException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class VideoProcessingService {
  static const String baseUrl = 'http://ec2-3-86-192-27.compute-1.amazonaws.com/api';
  final http.Client _client;

  VideoProcessingService({http.Client? client}) : _client = client ?? http.Client();

  Future<VideoSummary> getSummary(String videoPath) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/get_summary'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'videoPath': videoPath}),
      );

      if (response.statusCode == 200) {
        return VideoSummary.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw VideoProcessingException(
          error['error'] ?? 'Failed to get video summary',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is VideoProcessingException) rethrow;
      throw VideoProcessingException('Failed to process request: ${e.toString()}');
    }
  }

  Future<VideoChapters> generateChapters(String videoPath) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/generate_chapters'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'videoPath': videoPath}),
      );

      if (response.statusCode == 200) {
        return VideoChapters.fromJson(jsonDecode(response.body));
      } else {
        final error = jsonDecode(response.body);
        throw VideoProcessingException(
          error['error'] ?? 'Failed to generate chapters',
          response.statusCode,
        );
      }
    } catch (e) {
      if (e is VideoProcessingException) rethrow;
      throw VideoProcessingException('Failed to process request: ${e.toString()}');
    }
  }

  void dispose() {
    _client.close();
  }
} 