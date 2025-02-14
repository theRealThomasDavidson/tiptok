class VideoSummary {
  final String videoId;
  final String summary;
  final List<String> keywords;
  final String suggestedTitle;

  VideoSummary({
    required this.videoId,
    required this.summary,
    required this.keywords,
    required this.suggestedTitle,
  });

  factory VideoSummary.fromJson(Map<String, dynamic> json) {
    // Normalize keywords to lowercase
    final rawKeywords = (json['keywords'] as List?)?.map((e) => e as String).toList() ?? [];
    final normalizedKeywords = rawKeywords.map((k) => k.toLowerCase().trim()).toList();

    return VideoSummary(
      videoId: json['video_id'] as String? ?? '',
      summary: json['summary'] as String? ?? 'No summary available',
      keywords: normalizedKeywords,
      suggestedTitle: json['suggested_title'] as String? ?? 'Untitled Video',
    );
  }

  Map<String, dynamic> toJson() => {
    'video_id': videoId,
    'summary': summary,
    'keywords': keywords,
    'suggested_title': suggestedTitle,
  };

  /// Gets keywords with underscores replaced by spaces for display
  List<String> get displayKeywords => 
    keywords.map((k) => k.replaceAll('_', ' ')).toList();

  /// Gets keywords with spaces for search (keeps underscores)
  String get searchKeywords => keywords.join(' ');

  /// Gets a displayable string of keywords
  String get keywordsDisplay => displayKeywords.join(', ');

  @override
  String toString() => 'VideoSummary(id: $videoId, ${summary.length} chars, keywords: $keywordsDisplay, title: $suggestedTitle)';
} 