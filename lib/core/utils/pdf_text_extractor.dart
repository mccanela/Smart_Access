import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as path;
import '../../shared/constants/document.dart';
import '../../core/services/cache_service.dart';

class PDFTextExtractor {
  static final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  static Future<Document> extractTextFromPDF(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Arquivo não encontrado: $filePath');
      }

      final fileName = path.basename(filePath);
      final fileId = _generateFileId(filePath);
      final fileModified = await file.lastModified();

      // Verificar cache
      final cachedDoc = await CacheService.getDocument(fileId);
      if (cachedDoc != null &&
          cachedDoc.lastProcessed != null &&
          cachedDoc.lastProcessed!.isAfter(fileModified)) {
        return cachedDoc;
      }

      // Ler bytes
      final pdfBytes = await file.readAsBytes();

      // Extrair texto direto
      String? extractedText;
      bool hasTextLayer = false;

      try {
        extractedText = await _extractEmbeddedText(pdfBytes);
        if (extractedText != null && extractedText.trim().isNotEmpty) {
          hasTextLayer = true;
        }
      } catch (e) {}

      // Se não conseguiu, faz OCR
      if (extractedText == null || extractedText.trim().isEmpty) {
        extractedText = await _extractTextWithOCR(filePath);
        hasTextLayer = false;
      }

      // Contar páginas
      final pageCount = await _getPageCount(pdfBytes);

      final document = Document(
        id: fileId,
        name: fileName,
        path: filePath,
        extractedText: extractedText,
        lastProcessed: DateTime.now(),
        hasTextLayer: hasTextLayer,
        pageCount: pageCount,
      );

      await CacheService.saveDocument(document);
      return document;
    } catch (e) {
      throw Exception('Erro ao processar PDF: $e');
    }
  }

  /// Extrair texto quando PDF tem camada de texto (web/mobile puro Dart)
  static Future<String?> _extractEmbeddedText(Uint8List pdfBytes) async {
    try {
      final sf.PdfDocument doc = sf.PdfDocument(inputBytes: pdfBytes);
      final buffer = StringBuffer();
      for (int i = 0; i < doc.pages.count; i++) {
        final extractor = sf.PdfTextExtractor(doc);
        final text = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (text.isNotEmpty) {
          buffer.writeln('=== Página ${i + 1} ===');
          buffer.writeln(text.trim());
          buffer.writeln();
        }
      }
      doc.dispose();
      final output = buffer.toString().trim();
      return output.isNotEmpty ? output : null;
    } catch (e) {
      return null;
    }
  }

  /// OCR quando PDF é imagem (somente mobile)
  static Future<String> _extractTextWithOCR(String filePath) async {
    try {
      // Em web, OCR do MLKit não funciona; retornar vazio para evitar erros
      if (kIsWeb) {
        return '';
      }
      final pdf = await PdfDocument.openFile(filePath);
      final pageCount = pdf.pagesCount;
      final extractedTexts = <String>[];

      final maxPages = pageCount > 20 ? 20 : pageCount;

      for (int i = 1; i <= maxPages; i++) {
        try {
          final page = await pdf.getPage(i);
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );

          if (pageImage != null) {
            final inputImage = InputImage.fromBytes(
              bytes: pageImage.bytes,
              metadata: InputImageMetadata(
                size: Size(pageImage.width?.toDouble() ?? 0,
                    pageImage.height?.toDouble() ?? 0),
                rotation: InputImageRotation.rotation0deg,
                format: InputImageFormat.bgra8888,
                bytesPerRow: (pageImage.width ?? 0) * 4,
              ),
            );

            final recognizedText =
                await _textRecognizer.processImage(inputImage);
            if (recognizedText.text.isNotEmpty) {
              extractedTexts.add('=== Página $i ===\n${recognizedText.text}');
            }
          }

          await page.close();
        } catch (e) {}
      }

      return extractedTexts.join('\n\n');
    } catch (e) {
      throw Exception('Erro no OCR: $e');
    }
  }

  /// Número de páginas
  static Future<int> _getPageCount(Uint8List pdfBytes) async {
    try {
      // Usar pdfx para contar páginas
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/temp_pdf_count_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await tempFile.writeAsBytes(pdfBytes);

      final pdf = await PdfDocument.openFile(tempFile.path);
      final pageCount = pdf.pagesCount;

      await pdf.close();
      await tempFile.delete();

      return pageCount;
    } catch (e) {
      return 1; // fallback
    }
  }

  static String _generateFileId(String filePath) {
    return filePath.hashCode.toString();
  }

  /// Extrair texto de PDFs em assets
  static Future<List<String>> extractTextFromAssetPDFs() async {
    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final manifestMap = json.decode(manifestContent) as Map<String, dynamic>;

      final pdfFiles = manifestMap.keys
          .where(
              (key) => key.startsWith('assets/pdfs/') && key.endsWith('.pdf'))
          .toList();

      final extractedTexts = <String>[];

      for (final pdfPath in pdfFiles) {
        try {
          final byteData = await rootBundle.load(pdfPath);
          final pdfBytes = byteData.buffer.asUint8List();

          final text = await _extractEmbeddedText(pdfBytes);
          if (text != null && text.trim().isNotEmpty) {
            extractedTexts.add('Arquivo: ${path.basename(pdfPath)}\n\n$text');
          } else {
            extractedTexts.add(
                'Arquivo: ${path.basename(pdfPath)}\n\n[PDF é imagem, necessário OCR]');
          }
        } catch (e) {
          extractedTexts.add('Erro ao processar ${path.basename(pdfPath)}: $e');
        }
      }

      return extractedTexts;
    } catch (e) {
      return ['Erro ao carregar PDFs dos assets: $e'];
    }
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
