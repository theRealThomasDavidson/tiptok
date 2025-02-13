import 'package:json_annotation/json_annotation.dart';

part 'video_chapter_model.g.dart';

@JsonSerializable()
class VideoChapter {
  final double startTime;
  final double endTime;
  final String summary;
  final String text;
  final List<String>? topics;
  final List<String>? keywords;

  const VideoChapter({
    required this.startTime,
    required this.endTime,
    required this.summary,
    required this.text,
    this.topics,
    this.keywords,
  });

  // Get duration in seconds
  double get duration => endTime - startTime;

  // Factory constructor for JSON serialization
  factory VideoChapter.fromJson(Map<String, dynamic> json) => 
      _$VideoChapterFromJson(json);

  // Convert to JSON
  Map<String, dynamic> toJson() => _$VideoChapterToJson(this);

  // Create a copy with optional parameter updates
  VideoChapter copyWith({
    double? startTime,
    double? endTime,
    String? summary,
    String? text,
    List<String>? topics,
    List<String>? keywords,
  }) {
    return VideoChapter(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      summary: summary ?? this.summary,
      text: text ?? this.text,
      topics: topics ?? this.topics,
      keywords: keywords ?? this.keywords,
    );
  }

  @override
  String toString() {
    return 'VideoChapter(${startTime.toStringAsFixed(1)}s - ${endTime.toStringAsFixed(1)}s): $summary';
  }
} 