import '../../shared/constants/document.dart';
import '../../features/search/search_result.dart';

class SearchService {
  static Future<List<SearchResult>> searchInDocuments(
    String query,
    List<Document> documents,
  ) async {
  
    if (query.trim().isEmpty) {
      
      return [];
    }

    final results = <SearchResult>[];

    final normalizedQuery = _normalizeText(query);
    final queryWords = normalizedQuery.split(' ')
        .where((word) => word.length > 2)
        .toList();

   

    if (queryWords.isEmpty) {
      
      return [];
    }

    for (final document in documents) {
     

      if (document.extractedText == null || document.extractedText!.isEmpty) {
        continue;
      }

      final docResults = await _searchInDocument(
        normalizedQuery,
        queryWords,
        document,
      );

     
      results.addAll(docResults);
    }

    // Ordenar por relevância
    results.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));

    return results.take(100).toList(); // Limitar a 100 resultados
  }

  static Future<List<SearchResult>> _searchInDocument(
    String normalizedQuery,
    List<String> queryWords,
    Document document,
  ) async {
    final results = <SearchResult>[];
    final text = _normalizeText(document.extractedText!);

    // Procurar por todas as ocorrências
    final matches = _findAllMatches(text, queryWords);

    for (final match in matches) {
      final contextBefore = _getContext(text, match.start, -150);
      final contextAfter = _getContext(text, match.end, 150);
      final pageNumber = _estimatePageNumber(text, match.start);

      final relevanceScore = _calculateRelevanceScore(
        match,
        queryWords,
        document.extractedText!,
      );

      results.add(SearchResult(
        documentId: document.id,
        documentName: document.name,
        matchedText: match.text,
        pageNumber: pageNumber,
        matchStart: match.start,
        matchEnd: match.end,
        contextBefore: contextBefore,
        contextAfter: contextAfter,
        relevanceScore: relevanceScore,
      ));
    }

    return results;
  }

  static List<_TextMatch> _findAllMatches(String text, List<String> queryWords) {
    final matches = <_TextMatch>[];

    // Procurar por frases completas primeiro
    final fullPhrase = queryWords.join(' ');
    if (fullPhrase.length > 3) {
      int startIndex = 0;
      while (true) {
        final index = text.indexOf(fullPhrase, startIndex);
        if (index == -1) break;

        matches.add(_TextMatch(
          text: fullPhrase,
          start: index,
          end: index + fullPhrase.length,
        ));

        startIndex = index + 1;
      }
    }

    // Procurar por palavras individuais
    for (final word in queryWords) {
      int startIndex = 0;
      while (true) {
        final index = text.indexOf(word, startIndex);
        if (index == -1) break;

        // Verificar se já foi encontrado como parte de uma frase
        final alreadyFound = matches.any((match) =>
          index >= match.start && index <= match.end
        );

        if (!alreadyFound) {
          matches.add(_TextMatch(
            text: word,
            start: index,
            end: index + word.length,
          ));
        }

        startIndex = index + 1;
      }
    }

    return matches;
  }

  static String _getContext(String text, int position, int length) {
    if (length < 0) {
      // Contexto antes
      final start = (position + length).clamp(0, position);
      final context = text.substring(start, position);
      return context.trim();
    } else {
      // Contexto depois
      final end = (position + length).clamp(position, text.length);
      final context = text.substring(position, end);
      return context.trim();
    }
  }

  static int _estimatePageNumber(String text, int position) {
    // Contar quantos marcadores de página existem antes da posição
    final pageMarkers = RegExp(r'=== Página (\d+) ===');
    final matches = pageMarkers.allMatches(text.substring(0, position));

    if (matches.isNotEmpty) {
      final lastMatch = matches.last;
      final pageNumber = int.tryParse(lastMatch.group(1) ?? '1') ?? 1;
      return pageNumber;
    }

    return 1;
  }

  static double _calculateRelevanceScore(
    _TextMatch match,
    List<String> queryWords,
    String originalText,
  ) {
    double score = 0.0;

    // Pontuação por correspondência exata de frase
    if (match.text.contains(' ')) {
      score += 3.0;
    }

    // Pontuação por palavras encontradas
    final matchedWords = queryWords.where((word) =>
      match.text.toLowerCase().contains(word.toLowerCase())
    ).length;
    score += matchedWords * 1.5;

    // Bônus por proximidade com outras palavras da query
    final context = _getContext(originalText, match.start, -100) +
                   _getContext(originalText, match.end, 100);

    for (final word in queryWords) {
      if (context.toLowerCase().contains(word.toLowerCase())) {
        score += 0.5;
      }
    }

    // Penalização por matches muito curtos
    if (match.text.length < 3) {
      score *= 0.5;
    }

    return score.clamp(0.0, 10.0);
  }

  static String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Future<List<SearchResult>> searchInGroupedResults(
    List<SearchResult> allResults,
  ) async {
    // Agrupar resultados por documento
    final groupedResults = <String, List<SearchResult>>{};

    for (final result in allResults) {
      if (!groupedResults.containsKey(result.documentId)) {
        groupedResults[result.documentId] = [];
      }
      groupedResults[result.documentId]!.add(result);
    }

    // Retornar apenas os melhores resultados por documento
    final bestResults = <SearchResult>[];

    for (final results in groupedResults.values) {
      if (results.isNotEmpty) {
        // Removido o limite fixo de 3 resultados conforme solicitado
        final sorted = results..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
        bestResults.addAll(sorted);
      }
    }

    return bestResults..sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
  }
}

class _TextMatch {
  final String text;
  final int start;
  final int end;

  _TextMatch({
    required this.text,
    required this.start,
    required this.end,
  });
}
