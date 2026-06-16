class SearchResult {
  final String documentId;
  final String documentName;
  final String matchedText;
  final int pageNumber;
  final int matchStart;
  final int matchEnd;
  final String contextBefore;
  final String contextAfter;
  final double relevanceScore;

  SearchResult({
    required this.documentId,
    required this.documentName,
    required this.matchedText,
    required this.pageNumber,
    required this.matchStart,
    required this.matchEnd,
    required this.contextBefore,
    required this.contextAfter,
    required this.relevanceScore,
  });

  String get snippet {
    final before = contextBefore.isNotEmpty ? '...$contextBefore' : '';
    final after = contextAfter.isNotEmpty ? '$contextAfter...' : '';
    return '$before$matchedText$after';
  }

  String get highlightedSnippet {
    final before = contextBefore.isNotEmpty ? '...$contextBefore' : '';
    final after = contextAfter.isNotEmpty ? '$contextAfter...' : '';
    return '$before**$matchedText**$after';
  }
}
