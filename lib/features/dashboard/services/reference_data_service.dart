import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import 'dashboard_api_helper.dart';

/// Service para buscar dados de referência (listas estáticas).
class ReferenceDataService {
  /// Busca marcas e cores de veículos.
  /// Retorna {'marcas': [...], 'cores': [...]}.
  static Future<Map<String, List<Map<String, dynamic>>>>
      fetchMarcasECores() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return {'marcas': [], 'cores': []};

    final data = await DashboardApiHelper.post(
      ApiConfig.getEndpoint('dashboard', 'veiculos'),
      {},
      token: auth.token,
    );

    return {
      'marcas': List<Map<String, dynamic>>.from(
          data?['data']?['marcas'] ?? []),
      'cores': List<Map<String, dynamic>>.from(
          data?['data']?['cor'] ?? []),
    };
  }

  /// Busca vagas avulso.
  static Future<List<Map<String, dynamic>>> fetchVagasAvulso() async {
    final headers = await ApiConfig.getDefaultHeaders();
    final url = Uri.parse('${ApiConfig.gateUrl}/vagasavulso');

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bruto = data['data'] ?? data['vagas'] ?? data;
        if (bruto is List) {
          return List<Map<String, dynamic>>.from(bruto);
        } else if (bruto is Map && bruto['lista'] is List) {
          return List<Map<String, dynamic>>.from(bruto['lista']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Busca crachás.
  static Future<List<Map<String, dynamic>>> fetchCrachas() async {
    final headers = await ApiConfig.getDefaultHeaders();
    final condominioIdStr = await ApiConfig.getCondominioId();
    final condominioId = int.tryParse(condominioIdStr) ?? 0;
    final url = Uri.parse(
        '${ApiConfig.getEndpoint('crachas', 'lista')}?condominio_id=$condominioId');

    try {
      final response = await http.post(url, headers: headers);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final bruto = data['data'] ?? data;
        if (bruto is List) {
          return List<Map<String, dynamic>>.from(bruto);
        } else if (bruto is Map && bruto['lista'] is List) {
          return List<Map<String, dynamic>>.from(bruto['lista']);
        }
      }
    } catch (_) {}
    return [];
  }

  /// Busca lista de unidades (autorizantes) com normalização de campos.
  static Future<List<Map<String, dynamic>>> fetchUnidades() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      ApiConfig.getEndpoint('dashboard', 'unidades'),
      {"condominio_id": auth.condominioId, "flg_principal": "S"},
      token: auth.token,
    );

    final unidadesRaw = data?['data']?['unidades'] ?? [];
    if (unidadesRaw is! List) return [];

    return unidadesRaw.map((u) {
      final m = Map<String, dynamic>.from(u);
      if (m['unidade'] == null || m['unidade'].toString().isEmpty) {
        m['unidade'] = m['numero'] ?? m['unidade_numero'] ?? '';
      }
      if (m['predio'] == null || m['predio'].toString().isEmpty) {
        m['predio'] =
            m['torre'] ?? m['bloco'] ?? m['predio_nome'] ?? 'Torre A';
      }
      return m;
    }).toList();
  }

  /// Busca lista de veículos do condomínio.
  static Future<List<Map<String, dynamic>>> fetchVeiculos() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      'https://gate.conectcon.net.br/pt-br/veiculolist',
      {"condominio_id": auth.condominioIdInt},
      token: auth.token,
    );
    if (data == null) return [];

    final raiz = data['data'] ?? data;
    if (raiz is Map && raiz.containsKey('veiculos') && raiz['veiculos'] is List) {
      return List<Map<String, dynamic>>.from(raiz['veiculos']);
    } else if (raiz is List) {
      return List<Map<String, dynamic>>.from(raiz);
    } else if (data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data']);
    }
    return [];
  }

  /// Busca lista de vagas do condomínio.
  static Future<List<Map<String, dynamic>>> fetchVagas() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      'https://gate.conectcon.net.br/pt-br/vagas',
      {"condominio_id": auth.condominioIdInt},
      token: auth.token,
    );

    return DashboardApiHelper.extractList(data);
  }

  /// Busca lista de entregas (encomendas pendentes).
  static Future<List<Map<String, dynamic>>> fetchEntregas() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      ApiConfig.getEndpoint('encomendas', 'lista'),
      {"condominio_id": auth.condominioIdInt},
      token: auth.token,
    );

    return DashboardApiHelper.extractList(data);
  }

  /// Busca histórico de passagens.
  static Future<List<Map<String, dynamic>>> fetchHistoricoPassagens() async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      ApiConfig.getEndpoint('dashboard', 'passagem'),
      {"condominio_id": auth.condominioIdInt},
      token: auth.token,
    );

    if (data != null && data['data'] is List) {
      return List<Map<String, dynamic>>.from(data['data']);
    }
    return [];
  }

  /// Busca lista de unidades para filtro.
  static Future<List<Map<String, dynamic>>> fetchUnidadesFiltro({
    String nome = '',
  }) async {
    final auth = await DashboardApiHelper.getAuthData();
    if (auth == null) return [];

    final data = await DashboardApiHelper.post(
      'https://gate.conectcon.net.br/pt-br/unidadelist',
      {
        "condominio_id": auth.condominioIdInt,
        "apto_id": 0,
        "unidade": "",
        "flg_principal": "S",
        "nome": nome,
        "placa": "",
        "vaga_id": 0,
      },
      token: auth.token,
    );

    if (data != null && data['data']?['unidades'] is List) {
      return List<Map<String, dynamic>>.from(data['data']['unidades']);
    }
    return [];
  }
}
