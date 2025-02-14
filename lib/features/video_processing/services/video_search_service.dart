import '../models/video_summary.dart';
import '../models/video_chapter.dart';

class VideoSearchResult {
  final String videoId;
  final VideoSummary? summary;
  final VideoChapters? chapters;
  final double relevanceScore;
  final List<String> matchedKeywords;

  VideoSearchResult({
    required this.videoId,
    this.summary,
    this.chapters,
    required this.relevanceScore,
    required this.matchedKeywords,
  });

  @override
  String toString() => 
    'VideoSearchResult(videoId: $videoId, score: ${relevanceScore.toStringAsFixed(2)}, matches: ${matchedKeywords.join(", ")})';
}

class VideoSearchService {
  /// Normalizes a search term by:
  /// - Converting to lowercase
  /// - Replacing spaces with underscores
  /// - Removing special characters
  static String normalizeSearchTerm(String term) {
    return term.toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '')  // Remove special chars
        .replaceAll(RegExp(r'\s+'), '_');     // Replace spaces with underscore
  }

  /// Normalizes a keyword for comparison by:
  /// - Converting to lowercase
  /// - Removing special characters
  static String normalizeKeyword(String keyword) {
    return keyword.toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s_]'), ''); // Keep underscores but remove other special chars
  }

  /// Checks if a search term matches a keyword
  /// Handles both exact matches and partial matches
  static bool isKeywordMatch(String searchTerm, String keyword) {
    final normalizedSearch = normalizeSearchTerm(searchTerm);
    final normalizedKeyword = normalizeKeyword(keyword);
    
    // Check exact match (with and without underscores)
    if (normalizedKeyword == normalizedSearch || 
        normalizedKeyword.replaceAll('_', '') == normalizedSearch.replaceAll('_', '')) {
      return true;
    }

    // Check if search term is part of a compound keyword
    // e.g., "learning" matches "machine_learning"
    final keywordParts = normalizedKeyword.split('_');
    if (keywordParts.contains(normalizedSearch)) {
      return true;
    }

    // Check if keyword contains search term
    return normalizedKeyword.contains(normalizedSearch) || 
           normalizedKeyword.replaceAll('_', '').contains(normalizedSearch.replaceAll('_', ''));
  }

  /// Calculate relevance score based on number and quality of matches
  static double calculateRelevanceScore(List<String> videoKeywords, List<String> searchTerms) {
    double score = 0.0;
    final matchedTerms = <String>[];

    for (final term in searchTerms) {
      for (final keyword in videoKeywords) {
        if (isKeywordMatch(term, keyword)) {
          // Exact matches get higher score
          if (normalizeKeyword(keyword) == normalizeSearchTerm(term)) {
            score += 1.0;
          } else {
            score += 0.5; // Partial matches get lower score
          }
          matchedTerms.add(term);
          break;
        }
      }
    }

    // Bonus for matching multiple terms
    if (matchedTerms.length > 1) {
      score *= 1.0 + (matchedTerms.length / searchTerms.length) * 0.5;
    }

    return score;
  }

  /// Search videos using keywords
  /// Returns results sorted by relevance
  static List<VideoSearchResult> search(
    List<VideoSummary> summaries,
    String query, {
    double minimumScore = 0.5,
  }) {
    final searchTerms = query.split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList();

    if (searchTerms.isEmpty) return [];

    final results = <VideoSearchResult>[];

    for (final summary in summaries) {
      final matchedKeywords = <String>[];
      
      // Check each search term against keywords
      for (final term in searchTerms) {
        for (final keyword in summary.keywords) {
          if (isKeywordMatch(term, keyword)) {
            matchedKeywords.add(keyword);
          }
        }
      }

      if (matchedKeywords.isNotEmpty) {
        final score = calculateRelevanceScore(summary.keywords, searchTerms);
        if (score >= minimumScore) {
          results.add(VideoSearchResult(
            videoId: summary.videoId, // You'll need to add videoId to VideoSummary
            summary: summary,
            relevanceScore: score,
            matchedKeywords: matchedKeywords.toSet().toList(), // Remove duplicates
          ));
        }
      }
    }

    // Sort by relevance score (highest first)
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
    return results;
  }
} 