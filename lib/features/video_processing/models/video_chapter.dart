class VideoChapter {
  final double start;
  final double end;

  VideoChapter({
    required this.start,
    required this.end,
  });

  factory VideoChapter.fromJson(Map<String, dynamic> json) {
    return VideoChapter(
      start: (json['start'] as num).toDouble(),
      end: (json['end'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
  };

  @override
  String toString() => 'VideoChapter(start: ${start.toStringAsFixed(2)}s, end: ${end.toStringAsFixed(2)}s)';
}

class VideoChapters {
  final String videoId;
  final List<VideoChapter> chapters;
  final String suggestedTitle;

  VideoChapters({
    required this.videoId,
    required this.chapters,
    required this.suggestedTitle,
  });

  factory VideoChapters.fromJson(Map<String, dynamic> json) {
    return VideoChapters(
      videoId: json['video_id'] as String,
      chapters: (json['chapters'] as List)
          .map((e) => VideoChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
      suggestedTitle: json['suggested_title'] as String? ?? 'Untitled Video',
    );
  }

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'chapters': chapters.map((e) => e.toJson()).toList(),
    'suggested_title': suggestedTitle,
  };

  Duration get totalDuration => Duration(
    milliseconds: (chapters.last.end * 1000).round()
  );

  @override
  String toString() => 'VideoChapters(videoId: $videoId, chapters: ${chapters.length}, duration: $totalDuration, title: $suggestedTitle)';
} 