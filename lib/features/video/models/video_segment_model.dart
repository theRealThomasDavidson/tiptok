class VideoSegment {
  final String id;
  final double startTime;
  final double endTime;
  final String originalVideoPath;

  VideoSegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.originalVideoPath,
  });

  double get duration => endTime - startTime;

  VideoSegment copyWith({
    String? id,
    double? startTime,
    double? endTime,
    String? originalVideoPath,
  }) {
    return VideoSegment(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      originalVideoPath: originalVideoPath ?? this.originalVideoPath,
    );
  }
} 