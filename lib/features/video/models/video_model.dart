/// Represents a video's metadata and properties 

class VideoModel {
  final String id;
  final String userId;
  final String url;
  final DateTime timestamp;

  VideoModel({
    required this.id,
    required this.userId,
    required this.url,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'url': url,
    'timestamp': timestamp.toIso8601String(),
  };

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    url: json['url'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
} 