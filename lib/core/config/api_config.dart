import 'package:shared_preferences/shared_preferences.dart';
import '../services/crypto_utils.dart';
import '../localization/app_localizations.dart';

class ApiConfig {
  // URLs base da API - agora com suporte a internacionalização
  static String get baseUrl {
    final language = AppLocalizations.currentLanguage;
    return language == 'en'
        ? 'https://socialh.conectcon.net.br/usa'
        : 'https://socialh.conectcon.net.br/pt-br';
  }

  static String get gateUrl {
    final language = AppLocalizations.currentLanguage;
    return language == 'en'
        ? 'https://gate.conectcon.net.br/usa'
        : 'https://gate.conectcon.net.br/pt-br';
  }

  static String get socialhUrl {
    final language = AppLocalizations.currentLanguage;
    return language == 'en'
        ? 'https://socialh.conectcon.net.br/usa'
        : 'https://socialh.conectcon.net.br/pt-br';
  }

  // APIs externas
  static const String ipCheckUrl = 'https://api.ipify.org';
  static const String ocrUrl = 'https://api.ocr.space/parse/image';

  // Mapa de endpoints organizados por módulo
  static Map<String, Map<String, String>> get endpoints {
    return {
      'auth': {
        'login': '$socialhUrl/auth',
        'createSession': '$socialhUrl/createsessao/',
        'deleteSession': '$socialhUrl/deletesessao',
        'getSession': '$gateUrl/getsessao',
        'permissoes': '$socialhUrl/CondominioFuncaoPerfil',
        'sendTwoFactor': '$socialhUrl/TBD_SEND_2FA_PATH',
        'validateTwoFactor': '$socialhUrl/TBD_VALIDATE_2FA_PATH',
      },
      'config': {
        'rota': '$socialhUrl/rota',
      },
      'condominio': {
        'endereco': '$socialhUrl/condominio',
        'condominio': '$socialhUrl/condominio',
        'corpoDiretivo': '$baseUrl/corpodiretivolist',
        'param': '$socialhUrl/condominioparam',
        'equipamentolist': '$gateUrl/equipamentolist',
        'encriptcns': '$socialhUrl/encriptcns',
        'CondominioGeoPosicao': '$socialhUrl/CondominioGeoPosicao',
      },
      'ramais': {
        'lista': '$socialhUrl/ramaislist',
      },
      'chaves': {
        'lista': '$gateUrl/chavesdisponiveis',
        'disponiveis': '$gateUrl/chavesdisponiveis',
        'unidades': '$gateUrl/unidadelist',
        'unidades-pessoas': '$gateUrl/unidadelist',
        'historico': '$gateUrl/chavehistorico',
        'registrarEntrega': '$gateUrl/chavesregistrarentrega',
        'registrarDevolucao': '$gateUrl/chavesregistrardevolucao',
      },
      'turnos': {
        'lista': '$gateUrl/turnolist',
        'usuarios': '$gateUrl/turnousuariolist',
        'usuario': '$gateUrl/turnousuariolist',
        'historico': '$gateUrl/turnolist',
        'registrar': '$gateUrl/turnoregistrar',
        'novoAtendimento': '$baseUrl/atendimentonovo',
      },
      'dashboard': {
        'unidades': '$gateUrl/unidadelist',
        'agendamentos': '$socialhUrl/Agendamentolist',
        'convidados': '$socialhUrl/convidadolist',
        'veiculos': '$gateUrl/veiculosmarcacor',
        // Lista de veículos por unidade (apto_id)
        'veiculosUnidade': '$gateUrl/veiculolist',
        'cadastroAvulso': '$gateUrl/cadastroavulsolist/',
        'avulsoSelecionado': '$gateUrl/avulsoselecionado',
        'registroEntradaAvulso': '$gateUrl/avulsoregistroentrada',
        'editarCadastro': '$gateUrl/editacadastro/',
        'passagem': '$gateUrl/passagem',
        'historicoPassagem': '$gateUrl/passagemhistorico',
        'baixaManual': '$gateUrl/baixamanual',
        'buscaentrada': '$gateUrl/buscaentrada',
        'passagemUsuarioUpd': '$gateUrl/passagemusuarioupd',
        'ConectConIAPortaria': '$gateUrl/ConectConIAPortaria',
      },
      'encomendas': {
        'imagem': '$gateUrl/encomendaimagem',
        'unidades': '$gateUrl/encomendaunidadelist',
        'registrar': '$gateUrl/encomendaregistrar',
        'lista': '$gateUrl/encomendalist',
        'entrega': '$gateUrl/encomendaentrega',
        'reenvioEntrega': '$gateUrl/reenvioentrega',
      },
      'unidade': {
        'foto': '$socialhUrl/unidadefoto',
        'fotolistar': '$gateUrl/FotoListar',
      },
      'listas': {
        'listas': '$gateUrl/listas?pai=98',
      },
      'alertas': {
        'categorias': '$gateUrl/listas',
        'lista': '$gateUrl/listas',
        'registrar': '$gateUrl/alertaregistrar',
        'historico': '$gateUrl/alertalist',
      },
      'ocorrencias': {
        'unidades': '$gateUrl/unidadelist',
        'registrar': '$gateUrl/ocorrenciaregistrar',
        'historico': '$gateUrl/ocorrencialist',
      },
      'crachas': {
        'lista': '$gateUrl/crachaslist',
      },
      'convidados': {
        'mover': '$socialhUrl/convidadomov/',
        'atualizar': '$socialhUrl/convidadoupd/',
        'entrada': '$socialhUrl/convidadomov/',
        'saida': '$socialhUrl/convidadomov/',
      },
    };
  }

  // Função para obter endpoint por módulo e ação
  static String getEndpoint(String module, String action) {
    if (endpoints.containsKey(module) &&
        endpoints[module]!.containsKey(action)) {
      return endpoints[module]![action]!;
    }
    throw Exception('Endpoint não encontrado: $module/$action');
  }

  // Função para obter URL completa com parâmetros
  static String getUrl(String module, String action,
      {Map<String, String>? params}) {
    String url = getEndpoint(module, action);

    if (params != null && params.isNotEmpty) {
      String queryString = params.entries
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');
      url += url.contains('?') ? '&$queryString' : '?$queryString';
    }

    return url;
  }

  // Função para obter o token descriptografado
  static Future<String> getBearerToken() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    return (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
  }

  // Função para obter o ID do condomínio descriptografado
  static Future<String> getCondominioId() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    return (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
  }

  // Função para obter o ID do usuário descriptografado
  static Future<String> getUsuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
    return (encryptedUsuarioId.isNotEmpty)
        ? decryptText(encryptedUsuarioId)
        : '';
  }

  // Função para obter o nome do usuário descriptografado
  static Future<String> getUsuarioNome() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedUsuarioNome = prefs.getString('usuario_nome') ?? '';
    return (encryptedUsuarioNome.isNotEmpty)
        ? decryptText(encryptedUsuarioNome)
        : '';
  }

  // Headers padrão para requisições POST
  static Future<Map<String, String>> getDefaultHeaders() async {
    final token = await getBearerToken();
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Headers para requisições GET (sem Content-Type)
  static Future<Map<String, String>> getGetHeaders() async {
    final token = await getBearerToken();
    return {
      'Authorization': 'Bearer $token',
    };
  }

  // Função para obter URL de APIs externas
  static String getExternalUrl(String type) {
    switch (type) {
      case 'ipCheck':
        return ipCheckUrl;
      case 'ocr':
        return ocrUrl;
      default:
        throw Exception('URL externa não encontrada: $type');
    }
  }

  // Função para validar se uma URL é válida
  static bool isValidUrl(String url) {
    try {
      Uri.parse(url);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Função para obter todos os endpoints de um módulo
  static Map<String, String> getModuleEndpoints(String module) {
    if (endpoints.containsKey(module)) {
      return Map.from(endpoints[module]!);
    }
    return {};
  }

  // Função para listar todos os módulos disponíveis
  static List<String> getAvailableModules() {
    return endpoints.keys.toList();
  }

  // Função para obter informações de debug sobre as APIs
  static Map<String, dynamic> getApiInfo() {
    return {
      'baseUrls': {
        'social': baseUrl,
        'gate': gateUrl,
        'socialh': socialhUrl,
      },
      'externalUrls': {
        'ipCheck': ipCheckUrl,
        'ocr': ocrUrl,
      },
      'modules': endpoints.keys.toList(),
      'totalEndpoints':
          endpoints.values.fold(0, (sum, module) => sum + module.length),
      'currentLanguage': AppLocalizations.currentLanguage,
      'languageName':
          AppLocalizations.getLanguageName(AppLocalizations.currentLanguage),
    };
  }

  // Função para obter o idioma atual das APIs
  static String getCurrentApiLanguage() {
    return AppLocalizations.currentLanguage == 'en' ? 'usa' : 'pt-br';
  }

  // Função para verificar se está usando inglês
  static bool isEnglish() {
    return AppLocalizations.currentLanguage == 'en';
  }

  // Função para obter URLs base com idioma específico
  static String getBaseUrlWithLanguage(String server, String language) {
    final baseUrls = {
      'social': 'https://social.conectcon.net.br',
      'gate': 'https://gate.conectcon.net.br',
      'socialh': 'https://social.conectcon.net.br',
    };

    final langSuffix = language == 'en' ? '/usa' : '/pt-br';
    return baseUrls[server]! + langSuffix;
  }
}
