import 'dart:convert';
import 'dart:typed_data';

// FUNÇÃO TOP-LEVEL EXECUTADA EM ISOLATE (SEPARADO DA UI PRINCIPAL)
// Isso impede travamentos (jank/violations) durante processamento pesado de imagens/json
List<Map<String, dynamic>> processSignalRData(Map<String, dynamic> params) {
  final rawList = params['rawList'] as List<dynamic>;

  // 1. Converter e Logar
  final passagensMap = rawList
      .map((item) {
        if (item is Map) return Map<String, dynamic>.from(item);
        if (item is String) {
          try {
            return jsonDecode(item) as Map<String, dynamic>;
          } catch (_) {
            return <String, dynamic>{};
          }
        }
        return <String, dynamic>{};
      })
      .where((p) => p.isNotEmpty)
      .map((p) => p)
      .toList();

  // 2. Processamento de Imagens (Gargalo de CPU)
  for (var p in passagensMap) {
    // Processar link_foto se existir (prioridade)
    if (p.containsKey('link_foto') &&
        p['link_foto'] != null &&
        p['link_foto'].toString().isNotEmpty) {
      // Se tem link_foto, usar diretamente (já é uma URL)
      p['foto'] = p['link_foto'];
    }
    // Se não tem link_foto, processar foto como array de bytes (legado)
    else if (p.containsKey('foto') && p['foto'] != null) {
      final foto = p['foto'];
      try {
        if (foto is List && foto.isNotEmpty) {
          // Otimizaçao: Tenta evitar map se já for inteiros
          final bytes = Uint8List.fromList(List<int>.from(foto));
          p['foto'] = base64Encode(bytes);
        } else if (foto is Uint8List) {
          p['foto'] = base64Encode(foto);
        }
      } catch (_) {
        p['foto'] = null;
      }
    }
  }

  return passagensMap;
}
