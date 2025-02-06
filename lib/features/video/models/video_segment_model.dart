class VideoSegment {
  final String id;
  final double startTime;
  final double endTime;
  final String originalVideoPath;
  String? processedVideoPath;

  VideoSegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.originalVideoPath,
    this.processedVideoPath,
  });

  Duration get duration => Duration(
    milliseconds: ((endTime - startTime) * 1000).round()
  );

  bool get isProcessed => processedVideoPath != null;

  VideoSegment copyWith({
    String? id,
    double? startTime,
    double? endTime,
    String? originalVideoPath,
    String? processedVideoPath,
  }) {
    return VideoSegment(
      id: id ?? this.id,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      originalVideoPath: originalVideoPath ?? this.originalVideoPath,
      processedVideoPath: processedVideoPath ?? this.processedVideoPath,
    );
  }
} 