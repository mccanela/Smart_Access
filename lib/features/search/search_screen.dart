import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../shared/constants/document.dart';
import 'search_result.dart';
import '../../core/utils/pdf_text_extractor.dart';
import '../../core/services/search_service.dart';
import '../../core/services/cache_service.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/theme/icon_colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final List<Document> _documents = [];
  final List<SearchResult> _searchResults = [];
  bool _isSearching = false;
  bool _isProcessingFiles = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCachedDocuments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    PDFTextExtractor.dispose();
    super.dispose();
  }

  Future<void> _loadCachedDocuments() async {
    try {
      final cachedDocs = await CacheService.getCachedDocuments();
      setState(() {
        _documents.clear();
        _documents.addAll(cachedDocs.values);
      });
    } catch (e) {
      _showError('Erro ao carregar documentos em cache: $e');
    }
  }

  Future<void> _pickPDFFiles() async {
    try {
      // Solicitar permissões
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showError('Permissão de armazenamento necessária');
        return;
      }

      setState(() {
        _isProcessingFiles = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        for (final file in result.files) {
          if (file.path != null) {
            await _processPDFFile(file.path!);
          }
        }
      }
    } catch (e) {
      _showError('Erro ao selecionar arquivos: $e');
    } finally {
      setState(() {
        _isProcessingFiles = false;
      });
    }
  }

  Future<void> _processPDFFile(String filePath) async {
    try {
      final document = await PDFTextExtractor.extractTextFromPDF(filePath);

      setState(() {
        // Remover documento antigo se existir
        _documents.removeWhere((doc) => doc.id == document.id);
        _documents.add(document);
      });

      // Salvar no cache
      await CacheService.saveDocument(document);

      _showSuccess('Arquivo processado: ${document.name}');
    } catch (e) {
      _showError('Erro ao processar ${filePath.split('/').last}: $e');
    }
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty || _documents.isEmpty) {
      setState(() {
        _searchResults.clear();
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchQuery = query;
    });

    try {
      final results = await SearchService.searchInDocuments(query, _documents);
      final groupedResults =
          await SearchService.searchInGroupedResults(results);

      setState(() {
        _searchResults.clear();
        _searchResults.addAll(groupedResults);
      });
    } catch (e) {
      _showError('Erro na busca: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _showError(String message) {
    FeedbackUtils.showError(
      context: context,
      title: 'Erro',
      message: message,
    );
  }

  void _showSuccess(String message) {
    FeedbackUtils.showSuccess(
      context: context,
      title: 'Sucesso',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca em PDFs Offline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _pickPDFFiles,
            tooltip: 'Adicionar PDFs',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCachedDocuments,
            tooltip: 'Atualizar cache',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Digite sua busca',
                hintStyle: const TextStyle(fontSize: 16),
                prefixIcon:
                    Icon(Icons.search, color: IconColors.search(context)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) {
                if (value.length >= 3) {
                  _performSearch(value);
                } else if (value.isEmpty) {
                  setState(() {
                    _searchResults.clear();
                    _searchQuery = '';
                  });
                }
              },
            ),
          ),

          // Status dos documentos
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFE3F2FD),
            child: Row(
              children: [
                Icon(
                  _documents.isEmpty ? Icons.warning : Icons.description,
                  color: _documents.isEmpty ? Colors.orange : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  '${_documents.length} documento(s) carregado(s)',
                  style: TextStyle(
                    color: _documents.isEmpty ? Colors.orange : Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (_isProcessingFiles) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  const Text('Processando...'),
                ],
              ],
            ),
          ),

          // Resultados da busca
          Expanded(
            child: _buildResultsView(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsView() {
    if (_isSearching) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Buscando...'),
          ],
        ),
      );
    }

    if (_searchQuery.isEmpty) {
      return _buildDocumentList();
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: const Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum resultado encontrado para "$_searchQuery"',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFF757575),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return _buildSearchResults();
  }

  Widget _buildDocumentList() {
    if (_documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 64,
              color: const Color(0xFFBDBDBD),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum documento carregado',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF757575),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Toque em + para adicionar PDFs',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
              ),
            ),
          ],
        ),
      );
    }

    // Agrupar documentos por nome
    final groupedDocuments = <String, List<Document>>{};
    for (final doc in _documents) {
      final key = doc.name;
      if (!groupedDocuments.containsKey(key)) {
        groupedDocuments[key] = [];
      }
      groupedDocuments[key]!.add(doc);
    }

    return ListView.builder(
      itemCount: groupedDocuments.length,
      itemBuilder: (context, index) {
        final docName = groupedDocuments.keys.elementAt(index);
        final docs = groupedDocuments[docName]!;
        final doc = docs.first;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            leading: Icon(
              doc.hasTextLayer ? Icons.text_fields : Icons.image,
              color: doc.hasTextLayer ? Colors.green : Colors.orange,
            ),
            title: Text(doc.name),
            subtitle: Text(
              '${doc.pageCount} páginas • ${doc.hasTextLayer ? 'Texto extraído' : 'OCR necessário'}',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () async {
                await CacheService.removeDocument(doc.id);
                await _loadCachedDocuments();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    // Agrupar resultados por documento
    final groupedResults = <String, List<SearchResult>>{};
    for (final result in _searchResults) {
      final key = result.documentName;
      if (!groupedResults.containsKey(key)) {
        groupedResults[key] = [];
      }
      groupedResults[key]!.add(result);
    }

    return ListView.builder(
      itemCount: groupedResults.length,
      itemBuilder: (context, index) {
        final docName = groupedResults.keys.elementAt(index);
        final results = groupedResults[docName]!;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ExpansionTile(
            title: Text(
              docName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${results.length} resultado(s) encontrado(s)'),
            children:
                results.map((result) => _buildResultItem(result)).toList(),
          ),
        );
      },
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: const Border(
          top: BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                size: 16,
                color: const Color(0xFF757575),
              ),
              const SizedBox(width: 4),
              Text(
                'Página ${result.pageNumber}',
                style: TextStyle(
                  color: const Color(0xFF757575),
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getRelevanceColor(result.relevanceScore),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  result.relevanceScore.toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: _buildHighlightedText(result),
              style: const TextStyle(
                color: Colors.black,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _buildHighlightedText(SearchResult result) {
    final spans = <TextSpan>[];

    if (result.contextBefore.isNotEmpty) {
      spans.add(TextSpan(
        text: '${result.contextBefore} ',
        style: const TextStyle(color: Colors.grey),
      ));
    }

    spans.add(TextSpan(
      text: result.matchedText,
      style: const TextStyle(
        backgroundColor: Colors.yellow,
        fontWeight: FontWeight.bold,
      ),
    ));

    if (result.contextAfter.isNotEmpty) {
      spans.add(TextSpan(
        text: ' ${result.contextAfter}',
        style: const TextStyle(color: Colors.grey),
      ));
    }

    return spans;
  }

  Color _getRelevanceColor(double score) {
    if (score >= 4.0) return Colors.green;
    if (score >= 3.0) return Colors.blue;
    if (score >= 2.0) return Colors.orange;
    return Colors.red;
  }
}
