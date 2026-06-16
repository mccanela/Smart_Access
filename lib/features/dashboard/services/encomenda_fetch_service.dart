import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/services/crypto_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashboard_api_helper.dart';

/// Service para buscar dados de referência de encomendas.
/// Retorna os dados puros — o caller é responsável pelo setState.
class EncomendaFetchService {
  /// Busca lista de unidades para encomendas.
  static Future<List<Map<String, dynamic>>> fetchUnidadesEncomenda() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final url =
        '${ApiConfig.getEndpoint('encomendas', 'unidades')}?condominio_id=${auth.condominioIdInt}';
    final data = await DashboardApiHelper.post(
      url,
      {"condominio_id": auth.condominioIdInt},
      token: auth.token,
    );

    var list = DashboardApiHelper.extractList(data);

    // Normalizar campos obrigatórios
    return list.map((u) {
      final m = Map<String, dynamic>.from(u);
      m['unidade'] ??= m['numero'] ?? m['unidade_numero'] ?? '';
      if ((m['predio']?.toString() ?? '').isEmpty) {
        m['predio'] = m['torre'] ?? m['bloco'] ?? m['predio_nome'] ?? '';
      }
      return m;
    }).toList();
  }

  /// Busca tipos de encomenda (pai=98).
  static Future<List<Map<String, dynamic>>> fetchTiposEncomenda() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      'https://gate.conectcon.net.br/pt-br/listas?pai=98',
      {},
      token: auth.token,
    );

    return DashboardApiHelper.extractList(data);
  }

  /// Busca locais de entrega (pai=1986).
  static Future<List<Map<String, dynamic>>> fetchLocaisEncomenda() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      'https://gate.conectcon.net.br/pt-br/listas?pai=1986',
      {},
      token: auth.token,
    );

    return DashboardApiHelper.extractList(data);
  }

  /// Upload foto da pessoa na entrega.
  static Future<void> uploadFotoPessoa(
      String usuarioId, Uint8List fotoBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final condominioId = await ApiConfig.getCondominioId();

      await http.post(
        Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "tipoUSU": "USU",
          "ordem_num": 1,
          "pessoacadastro_id": int.tryParse(usuarioId) ?? 0,
          "foto": base64Encode(fotoBytes),
        }),
      );
    } catch (_) {}
  }

  /// Upload foto da encomenda.
  static Future<void> uploadFotoEncomenda(
      int protocoloId, Uint8List fotoBytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      await http.post(
        Uri.parse(ApiConfig.getEndpoint('encomendas', 'imagem')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "id": protocoloId,
          "index": "0",
          "base64": base64Encode(fotoBytes),
        }),
      );
    } catch (_) {}
  }

  /// Busca histórico de encomendas com filtros.
  static Future<List<Map<String, dynamic>>> fetchHistoricos({
    required Map<String, dynamic> payload,
  }) async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    payload['condominio_id'] = auth.condominioIdInt;

    final data = await DashboardApiHelper.post(
      ApiConfig.getEndpoint('encomendas', 'lista'),
      payload,
      token: auth.token,
    );

    if (data == null) return [];

    final list = List<Map<String, dynamic>>.from(
      data['data']?['lista'] ?? data['lista'] ?? [],
    );
    list.sort((a, b) {
      final dataA = a['dt_Emissao']?.toString() ?? '';
      final dataB = b['dt_Emissao']?.toString() ?? '';
      return dataB.compareTo(dataA);
    });
    return list;
  }
}
