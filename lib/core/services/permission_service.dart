import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  static const String _storageKey = 'permissions_cache_v1';

  // IDs que são controlados pela API.
  // Se um item tiver um ID nesta lista, ele só será mostrado se a API retorná-lo.
  // Se não estiver nesta lista, é considerado "fixo" e sempre mostrado.
  static const Set<int> _controlledIds = {
    1, // Mural
    2, // Serviços
    3, // Condomínio
    5, // Avisos
    20, // Ocorrências
    24, // Bens Patrimoniais
    27, // Corpo Diretivo
    30, // Liberação de Login
    32, // Unidades
    33, // Terceirizados
    34, // Relatórios
    37, // Wi-Fi
    40, // Registro de Entrada
    41, // Encomendas
    42, // Ramais
    77, // Chaves
    106, // Manutenção predial
    107, // Outras Atividades
  };

  Set<int> _allowedIds = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  // Verifica se uma funcionalidade deve ser exibida
  bool hasPermission(int featureId) {
    if (!_controlledIds.contains(featureId)) {
      // Se não é controlado, exibe sempre (fixo)
      return true;
    }
    // Se é controlado, verifica se está na lista de permitidos
    return _allowedIds.contains(featureId);
  }

  // Carrega do cache local
  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> list = jsonDecode(jsonString);
        _allowedIds = list
            .map((e) => int.tryParse(e.toString()) ?? 0)
            .where((e) => e != 0)
            .toSet();
        _isLoaded = true;
        print(
            '📦 [PermissionService] Permissões restauradas do cache: $_allowedIds');
      }
    } catch (e) {
      print('⚠️ [PermissionService] Erro ao carregar cache: $e');
    }
  }

  // Salva no cache local
  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _allowedIds.toList();
      await prefs.setString(_storageKey, jsonEncode(list));
    } catch (e) {
      print('⚠️ [PermissionService] Erro ao salvar cache: $e');
    }
  }

  Future<void> loadPermissions(
      {int? condominioIdOverride, String? tokenOverride}) async {
    // 1. Tenta restaurar cache primeiro (para UX imediata/offline)
    await _loadFromCache();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload(); // Garantir dados frescos

      final token = tokenOverride ?? await ApiConfig.getBearerToken();

      if (token.isEmpty) {
        print('⚠️ [PermissionService] Sem token. Mantendo cache se existir.');
        return;
      }

      int condominioId = 0;
      if (condominioIdOverride != null && condominioIdOverride > 0) {
        condominioId = condominioIdOverride;
      } else {
        // Tenta pegar do storage padrão (login)
        final condominioIdStr = await ApiConfig.getCondominioId();
        condominioId = int.tryParse(condominioIdStr) ?? 0;

        // Se falhar (0), tenta pegar do storage de config (bootstrap)
        if (condominioId == 0) {
          final configId = prefs.getString('condominio_id_config');
          if (configId != null) {
            condominioId = int.tryParse(configId) ?? 0;
          }
        }
      }

      if (condominioId == 0) {
        print(
            '⚠️ [PermissionService] Condomínio ID não encontrado (0). Abortando requisição para preservar cache.');
        return;
      }

      final perfilStr = prefs.getString('perfil_id') ?? '0';
      final _perfilId = int.tryParse(perfilStr) ?? 0;

      // Payload conforme solicitado (com funcoes_id para garantir compatibilidade)
      final payload = {
        "condominio_id": condominioId,
        "perfil_id": _perfilId,
        "funcoes_id": 0
      };
      final url = Uri.parse(ApiConfig.getEndpoint('auth', 'permissoes'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        List<dynamic> items = [];
        if (data is Map && data.containsKey('data')) {
          if (data['data'] is List) {
            items = data['data'];
          }
        } else if (data is List) {
          items = data;
        }

        final newAllowedIds = <int>{};

        for (var item in items) {
          int? id;
          if (item is int) {
            id = item;
          } else if (item is Map) {
            // Tenta campos comuns de ID
            id = int.tryParse(item['funcao_id']?.toString() ?? '') ??
                int.tryParse(item['funcoes_id']?.toString() ?? '') ??
                int.tryParse(item['id']?.toString() ?? '');
          }

          if (id != null) {
            newAllowedIds.add(id);
          }
        }

        // Atualiza memória e cache somente se obteve sucesso
        _allowedIds = newAllowedIds;
        _isLoaded = true;
        await _saveToCache();

        print(
            '🔒 [PermissionService] Permissões atualizadas: $_allowedIds (${_allowedIds.length} itens)');
      } else {
        print(
            '⚠️ [PermissionService] Erro na API: ${response.statusCode} ${response.body}. Mantendo cache.');
      }
    } catch (e) {
      print(
          '⚠️ [PermissionService] Erro ao carregar permissões: $e. Mantendo cache.');
    }
  }

  // Mapeamento de Labels/Chaves para IDs (Helper)
  static int? getIdForFeature(String featureKey) {
    switch (featureKey.toLowerCase()) {
      case 'mural':
        return 1;
      case 'serviços':
      case 'servicos':
        return 2;
      case 'condomínio':
      case 'condominio':
        return 3;
      case 'avisos':
      case 'alertas':
        return 5; // Mapeando Alertas -> Avisos
      case 'ocorrências':
      case 'ocorrencias':
        return 20;
      case 'bens patrimoniais':
        return 24;
      case 'corpo diretivo':
        return 27;
      case 'liberação de login':
        return 30;
      case 'unidades':
        return 32;
      case 'terceirizados':
        return 33;
      case 'relatórios':
        return 34;
      case 'wi-fi':
      case 'wifi':
        return 37;
      case 'registro de entrada':
        return 40;
      case 'encomendas':
        return 41;
      case 'ramais':
        return 42;
      case 'chaves':
        return 77;
      case 'manutenção predial':
        return 106;
      case 'outras atividades':
        return 107;
      default:
        return null; // Não controlado ou desconhecido
    }
  }
}
