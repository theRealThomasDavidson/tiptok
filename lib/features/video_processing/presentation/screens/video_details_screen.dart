import 'package:flutter/material.dart';
import '../../models/video_summary.dart';
import '../../models/video_chapter.dart';
import '../widgets/keyword_chip.dart';

class VideoDetailsScreen extends StatelessWidget {
  final VideoSummary summary;
  final VideoChapters? chapters;

  const VideoDetailsScreen({
    super.key,
    required this.summary,
    this.chapters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(summary.suggestedTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Summary section
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              summary.summary,
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            // Keywords section
            const Text(
              'Keywords',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: summary.displayKeywords
                  .map((keyword) => KeywordChip(
                        keyword: keyword,
                        onTap: () {
                          // Navigate back to search screen with this keyword
                          Navigator.pop(context, keyword);
                        },
                      ))
                  .toList(),
            ),

            // Chapters section (if available)
            if (chapters != null) ...[
              const SizedBox(height: 24),
              const Text(
                'Chapters',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: chapters!.chapters.length,
                itemBuilder: (context, index) {
                  final chapter = chapters!.chapters[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text('${index + 1}'),
                      ),
                      title: Text('Chapter ${index + 1}'),
                      subtitle: Text(
                        '${_formatDuration(Duration(milliseconds: (chapter.start * 1000).round()))} - ${_formatDuration(Duration(milliseconds: (chapter.end * 1000).round()))}',
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
} 