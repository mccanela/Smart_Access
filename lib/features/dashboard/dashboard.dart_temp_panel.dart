import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// Painel lateral para exibir detalhes da encomenda entregue
class _DetalhesEntregaPanel extends StatelessWidget {
  final Map<String, dynamic> entrega;
  final VoidCallback onClose;

  const _DetalhesEntregaPanel({
    required this.entrega,
    required this.onClose,
  });

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '-';
    try {
      if (dateStr is String) {
        final date = DateTime.tryParse(dateStr);
        if (date != null) {
          return DateFormat('dd/MM/yyyy HH:mm').format(date);
        }
        return dateStr;
      }
    } catch (e) {
      return dateStr.toString();
    }
    return dateStr.toString();
  }

  @override
  Widget build(BuildContext context) {
    // Extraindo dados
    final quemRetirou = entrega['quemrecebeu']?.toString() ?? '-';
    final dataEntrega = _formatDate(entrega['dataentrega']);
    final dataChegada = _formatDate(entrega['dt_Emissao'] ?? entrega['data']);
    final documento =
        entrega['documentorecebedor']?.toString() ?? '-'; // Se houver
    final parentesco =
        entrega['parentescorecebedor']?.toString() ?? '-'; // Se houver
    final unidade = (entrega['unidade']?.toString() ?? '')
        .replaceAll('<br>', ' - ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final fotoRecebedor = entrega['fotorecebedor']; // Se houver (base64)
    final fotoAssinatura = entrega['assinatura']; // Se houver (base64)

    return Container(
      width: MediaQuery.of(context).size.width *
          (MediaQuery.of(context).size.width > 800 ? 0.35 : 0.85),
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1F2937)
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF374151)
                  : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_shipping_rounded,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Detalhes da Entrega',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black54,
                  ),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.green.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Text(
                          'ENTREGUE EM: $dataEntrega',
                          style: const TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildDetailSection(
                    context,
                    'Informações da Encomenda',
                    Icons.inventory_2_outlined,
                    [
                      _DetailItem('Unidade', unidade),
                      _DetailItem('Chegada na Portaria', dataChegada),
                      _DetailItem('Descrição',
                          entrega['texto']?.toString() ?? 'Encomenda'),
                      if (entrega['codigobarra'] != null &&
                          entrega['codigobarra'].toString().isNotEmpty)
                        _DetailItem('Código de Barras',
                            entrega['codigobarra'].toString()),
                      if (entrega['empresa'] != null &&
                          entrega['empresa'].toString().isNotEmpty)
                        _DetailItem('Transportadora/Entregador',
                            entrega['empresa'].toString()),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildDetailSection(
                    context,
                    'Informações da Retirada',
                    Icons.person_outline,
                    [
                      _DetailItem('Retirado por', quemRetirou),
                      if (documento != '-') _DetailItem('Documento', documento),
                      if (parentesco != '-')
                        _DetailItem('Parentesco/Vínculo', parentesco),
                      _DetailItem('Data da Retirada', dataEntrega),
                      // Quem registrou a saída?
                      if (entrega['usuariosaida_nome'] != null)
                        _DetailItem('Registrado por',
                            entrega['usuariosaida_nome'].toString()),
                    ],
                  ),

                  // Foto de quem retirou (se disponível)
                  if (fotoRecebedor != null &&
                      fotoRecebedor.toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Foto do Recebedor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fotoRecebedor.toString().startsWith('http')
                              ? fotoRecebedor
                              : 'data:image/jpeg;base64,$fotoRecebedor',
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, _, __) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ],

                  // Assinatura (se disponível)
                  if (fotoAssinatura != null &&
                      fotoAssinatura.toString().isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text(
                      'Assinatura',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[300]
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors
                            .white, // Assinatura geralmente precisa de fundo branco
                        border: Border.all(
                            color: Colors.grey.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fotoAssinatura.toString().startsWith('http')
                              ? fotoAssinatura
                              : 'data:image/jpeg;base64,$fotoAssinatura',
                          fit: BoxFit.contain,
                          errorBuilder: (ctx, _, __) =>
                              const Center(child: Icon(Icons.broken_image)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection(BuildContext context, String title, IconData icon,
      List<_DetailItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.blue[300]
                  : const Color(0xFF1E40AF),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF374151)
                : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF4B5563)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _DetailItem {
  final String label;
  final String value;
  _DetailItem(this.label, this.value);
}
