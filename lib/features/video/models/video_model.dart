/// Represents a video's metadata and properties 

class VideoModel {
  final String id;
  final String userId;
  final String url;
  final String? thumbnailUrl;
  final String? name;
  final String? description;
  final DateTime timestamp;
  final String? summary;
  final List<String>? keywords;
  final String? suggestedTitle;

  VideoModel({
    required this.id,
    required this.userId,
    required this.url,
    this.thumbnailUrl,
    this.name,
    this.description,
    required this.timestamp,
    this.summary,
    this.keywords,
    this.suggestedTitle,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'url': url,
    'thumbnailUrl': thumbnailUrl,
    'name': name,
    'description': description,
    'timestamp': timestamp.toIso8601String(),
    'summary': summary,
    'keywords': keywords,
    'suggestedTitle': suggestedTitle,
  };

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // Normalize keywords to lowercase
    final rawKeywords = (json['keywords'] as List?)?.map((e) => e as String).toList();
    final normalizedKeywords = rawKeywords?.map((k) => k.toLowerCase().trim()).toList();

    return VideoModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      url: json['url'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      summary: json['summary'] as String?,
      keywords: normalizedKeywords,
      suggestedTitle: json['suggestedTitle'] as String?,
    );
  }

  @override
  String toString() => 'VideoModel(id: $id, userId: $userId, title: $suggestedTitle)';
} 