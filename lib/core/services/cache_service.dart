import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/constants/document.dart';

class CacheService {
  static const String _documentsKey = 'cached_documents';
  static const String _cacheVersionKey = 'cache_version';
  static const int _currentVersion = 1;

  static Future<String> get _cacheDirectory async {
    final directory = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${directory.path}/pdf_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir.path;
  }

  static Future<String> _getCacheFilePath(String documentId) async {
    final cacheDir = await _cacheDirectory;
    return '$cacheDir/$documentId.json';
  }

  static Future<void> saveDocument(Document document) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheFilePath = await _getCacheFilePath(document.id);

      // Salvar no arquivo
      final file = File(cacheFilePath);
      await file.writeAsString(jsonEncode(document.toJson()));

      // Atualizar lista de documentos em cache
      final cachedDocs = await getCachedDocuments();
      final updatedDocs = Map<String, Document>.from(cachedDocs);
      updatedDocs[document.id] = document;

      await _saveDocumentsList(updatedDocs);
      await prefs.setInt(_cacheVersionKey, _currentVersion);
    } catch (e) {
     
    }
  }

  static Future<Document?> getDocument(String documentId) async {
    try {
      final cacheFilePath = await _getCacheFilePath(documentId);
      final file = File(cacheFilePath);

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final json = jsonDecode(content);
      return Document.fromJson(json);
    } catch (e) {
     
      return null;
    }
  }

  static Future<Map<String, Document>> getCachedDocuments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final documentsJson = prefs.getString(_documentsKey);

      if (documentsJson == null) {
        return {};
      }

      final documentsMap = jsonDecode(documentsJson) as Map<String, dynamic>;
      final documents = <String, Document>{};

      for (final entry in documentsMap.entries) {
        try {
          documents[entry.key] = Document.fromJson(entry.value);
        } catch (e) {
         
        }
      }

      return documents;
    } catch (e) {
     
      return {};
    }
  }

  static Future<void> _saveDocumentsList(Map<String, Document> documents) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final documentsJson = jsonEncode(
        documents.map((key, value) => MapEntry(key, value.toJson()))
      );
      await prefs.setString(_documentsKey, documentsJson);
    } catch (e) {
   
    }
  }

  static Future<void> removeDocument(String documentId) async {
    try {
      // Remover arquivo
      final cacheFilePath = await _getCacheFilePath(documentId);
      final file = File(cacheFilePath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remover da lista
      final cachedDocs = await getCachedDocuments();
      cachedDocs.remove(documentId);
      await _saveDocumentsList(cachedDocs);
    } catch (e) {
    
    }
  }

  static Future<void> clearCache() async {
    try {
      final cacheDir = await _cacheDirectory;
      final directory = Directory(cacheDir);

      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_documentsKey);
      await prefs.remove(_cacheVersionKey);
    } catch (e) {
   
    }
  }

  static Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final cacheDir = await _cacheDirectory;
      final directory = Directory(cacheDir);

      int fileCount = 0;
      int totalSize = 0;

      if (await directory.exists()) {
        await for (final file in directory.list()) {
          if (file is File) {
            fileCount++;
            totalSize += await file.length();
          }
        }
      }

      final documents = await getCachedDocuments();

      return {
        'fileCount': fileCount,
        'totalSize': totalSize,
        'documentCount': documents.length,
        'cachePath': cacheDir,
      };
    } catch (e) {
      return {
        'error': e.toString(),
      };
    }
  }

  static Future<bool> isDocumentUpToDate(String documentId, DateTime fileModified) async {
    try {
      final cachedDoc = await getDocument(documentId);
      if (cachedDoc == null) {
        return false;
      }

      return cachedDoc.lastProcessed != null &&
             cachedDoc.lastProcessed!.isAfter(fileModified);
    } catch (e) {
      return false;
    }
  }

  static Future<int> getCacheVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_cacheVersionKey) ?? 0;
  }
}
