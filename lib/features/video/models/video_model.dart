/// Represents a video's metadata and properties 

class VideoModel {
  final String id;
  final String userId;
  final String url;
  final String? thumbnailUrl;
  final String? name;
  final String? description;
  final DateTime timestamp;

  VideoModel({
    required this.id,
    required this.userId,
    required this.url,
    this.thumbnailUrl,
    this.name,
    this.description,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'name': name,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
  };

  factory VideoModel.fromJson(Map<String, dynamic> json) => VideoModel(
    id: json['id'] as String,
    userId: json['userId'] as String,
    url: json['url'] as String,
    thumbnailUrl: json['thumbnailUrl'] as String?,
    name: json['name'] as String?,
    description: json['description'] as String?,
    timestamp: DateTime.parse(json['timestamp'] as String),
  );
} 