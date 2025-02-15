import 'services/video_processing_service.dart';

// Example of how to use the VideoProcessingService
Future<void> processVideo(String videoPath) async {
  final service = VideoProcessingService();

  try {
    // Get video summary
    final summary = await service.getSummary(videoPath);
    print('Video Summary: ${summary.summary}');

    // Generate chapters
    final chapters = await service.generateChapters(videoPath);
    print('Video ID: ${chapters.videoId}');
    print('Chapters:');
    for (final chapter in chapters.chapters) {
      print('- Start: ${chapter.start}, End: ${chapter.end}');
    }
  } on VideoProcessingException catch (e) {
    print('Error processing video: ${e.toString()}');
  } catch (e) {
    print('Unexpected error: ${e.toString()}');
  } finally {
    service.dispose();
  }
} 