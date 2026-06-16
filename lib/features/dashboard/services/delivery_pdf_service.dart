import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
// import 'package:flutter/foundation.dart' show kIsWeb;
// import 'package:universal_html/html.dart' as html; // We will use conditional export or dynamic import approach if needed, or just dart:html if project allows.
// For now, I'll stick to a platform agnostic generation and a separate handling method.

class DeliveryPdfService {
  // Singleton
  static final DeliveryPdfService _instance = DeliveryPdfService._internal();
  factory DeliveryPdfService() => _instance;
  DeliveryPdfService._internal();

  Future<Uint8List> generateDeliveryPdf(Map<String, dynamic> delivery) async {
    final pdf = pw.Document();

    // Data collection
    final unidade = _cleanHtml(delivery['unidade']?.toString() ?? 'N/A');
    final nomePessoa =
        _extractPersonName(delivery['unidade']?.toString() ?? '');
    final codigoBarra = delivery['codigobarra']?.toString() ?? 'Sem código';
    final dataChegada = _formatDate(delivery['datachegada']);
    final dataEntrega = _formatDate(delivery['dataentrega'] ??
        delivery['dt_entrega']); // Fallback to dt_entrega
    final quemRecebeu = delivery['quemrecebeu']?.toString() ??
        delivery['quemretirou_txt']?.toString() ??
        'Não informado';
    final tipo = delivery['tipo']?.toString() ?? 'Encomenda';
    final descricao = delivery['descricao']?.toString() ?? '';
    final observacao = delivery['observacao']?.toString() ?? '';

    // Load custom font if available, else use standard
    // final font = await rootBundle.load("assets/fonts/OpenSans-Regular.ttf");
    // final ttf = pw.Font.ttf(font);

    // Placeholder logo or load asset
    // final logo = await rootBundle.load('assets/images/logo_conectcon.png');
    // final image = pw.MemoryImage(logo.buffer.asUint8List());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              pw.SizedBox(height: 20),
              _buildTitle('Comprovante de Entrega'),
              pw.SizedBox(height: 20),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              // Info Grid
              _buildInfoRow('Unidade', unidade),
              _buildInfoRow('Destinatário', nomePessoa),
              _buildInfoRow('Tipo de Encomenda', tipo),
              if (descricao.isNotEmpty) _buildInfoRow('Descrição', descricao),

              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),

              _buildInfoRow('Chegou em', dataChegada),
              _buildInfoRow('Entregue em', dataEntrega),
              _buildInfoRow('Recebido por', quemRecebeu),
              if (observacao.isNotEmpty)
                _buildInfoRow('Observação', observacao),

              pw.SizedBox(height: 20),
              _buildBarcodeSection(codigoBarra),

              pw.Spacer(),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildHeader() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text('CONECTCON',
            style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800)),
        pw.Text('Sistema de Portaria',
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _buildTitle(String title) {
    return pw.Center(
      child: pw.Text(
        title.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 18,
          fontWeight: pw.FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.normal),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBarcodeSection(String code) {
    if (code == 'Sem código' || code.trim().isEmpty) return pw.SizedBox();
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        children: [
          pw.Text('Cód. Rastreio / Barras',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 4),
          pw.Text(code,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.BarcodeWidget(
            barcode: pw.Barcode.code128(),
            data: code,
            width: 200,
            height: 50,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Gerado em ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
            pw.Text(
              'Smart Portaria',
              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
            ),
          ],
        ),
      ],
    );
  }

  String _cleanHtml(String html) {
    // Basic cleanup for <br> and simplistic html tags if any
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _extractPersonName(String rawUnidade) {
    // Based on previous code: "11 Torre A<br>Alessandro Fernandes"
    final parts = rawUnidade.split('<br>');
    if (parts.length > 1) {
      return parts[1].trim();
    }
    return '';
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      if (dateStr is String) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          return DateFormat('dd/MM/yyyy HH:mm').format(date);
        }
        // Try parsing standard formats if needed
        return dateStr;
      }
    } catch (e) {
      return dateStr.toString();
    }
    return dateStr.toString();
  }
}
