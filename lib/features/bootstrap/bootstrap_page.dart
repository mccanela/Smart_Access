import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import 'dart:js_interop';
import 'dart:html' as html;
import 'widgets/bootstrap_image_widget.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/permission_service.dart';

@JS('_originalHref')
external JSString? get _jsOriginalHref;

class BootstrapPage extends StatefulWidget {
  final VoidCallback? onConfigured;

  const BootstrapPage({super.key, this.onConfigured});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  String _statusMessage = 'Inicializando sistema...';
  bool _hasError = false;
  bool _condominioNotFound = false;
  String? _notFoundLogo;
  String? _notFoundBg;

  @override
  void initState() {
    super.initState();
    // Schedule the configuration load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarConfiguracao();
    });
  }

  /// Extracts the slug from the current URL (Path or Hash)
  String? _getSlug() {
    if (kIsWeb) {
      // Ler URL original salva pelo JS no index.html (antes do Flutter carregar)
      String href = '';
      try {
        final jsHref = _jsOriginalHref?.toDart;

        if (jsHref != null && jsHref.isNotEmpty) {
          href = jsHref;
        }
      } catch (_) {}
      // Fallback: originalUrl do main.dart > sessionStorage > location.href
      if (href.isEmpty) {
        try {
          href = html.window.sessionStorage['_original_url'] ?? '';
        } catch (_) {}
      }
      if (href.isEmpty) href = html.window.location.href;
      print('🔍 [BOOTSTRAP] Raw HREF: $href');
      final uri = Uri.parse(href);

      // Strategy 1: Hash Fragment (e.g., /#/summit)
      if (uri.fragment.isNotEmpty) {
        final cleanFragment = uri.fragment.startsWith('/')
            ? uri.fragment.substring(1)
            : uri.fragment;

        // Split by / and take first non-empty
        final parts = cleanFragment.split('/');
        for (final part in parts) {
          if (part.isNotEmpty) {
            print('🔍 [BOOTSTRAP] Slug found in FRAGMENT: $part');
            return part;
          }
        }
      }

      // Strategy 2: Path Segments (e.g., /summit)
      // Ignore 'fallback' or known flutter web paths if any
      if (uri.pathSegments.isNotEmpty) {
        // Itera de trás para frente para encontrar o primeiro segmento significativo
        for (var i = uri.pathSegments.length - 1; i >= 0; i--) {
          final segment = uri.pathSegments[i];
          // Ignora segmentos técnicos ou o prefixo 'rota' se ele for o primeiro da lista
          if (segment.isNotEmpty &&
              segment != 'index.html' &&
              segment != 'rota') {
            print('🔍 [BOOTSTRAP] Slug found in PATH: $segment');
            return segment;
          }
        }
      }

      // Strategy 3: Subdomain (e.g., smartaccess.conectcon.net.br)
      // If we are at root but the subdomain isn't www or standard ones, use as slug.
      final host = uri.host.toLowerCase();
      if (host.isNotEmpty &&
          !host.startsWith('localhost') &&
          !host.contains('web.app') &&
          !host.contains('workers.dev') &&
          !host.contains('pages.dev') &&
          !host.contains('firebaseapp.com')) {
        final hostParts = host.split('.');
        if (hostParts.length >= 3 && hostParts[0] != 'www') {
          print('🔍 [BOOTSTRAP] Slug found in SUBDOMAIN: ${hostParts[0]}');
          return hostParts[0];
        }
      }
    }
    print('🔍 [BOOTSTRAP] No slug found from URL parsing (ROOT).');
    return null;
  }

  Future<void> _carregarConfiguracao() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();

      final currentSlug = _getSlug();
      final savedSlug = prefs.getString('app_slug');
      final hasSession = prefs.getString('tokensessao_txt') != null;
      final hasSlugKey =
          prefs.containsKey('app_slug'); // Verifica se já salvou alguma vez

      final String safeSavedSlug = savedSlug ?? '';
      final String safeCurrentSlug = currentSlug ?? '';

      // Normalização para comparação case-insensitive
      final normCurrent = safeCurrentSlug.trim().toLowerCase();
      final normSaved = safeSavedSlug.trim().toLowerCase();

      print(
          '🔍 [BOOTSTRAP] Saved="$safeSavedSlug", Current="$safeCurrentSlug", HasSession=$hasSession, HasSlugKey=$hasSlugKey');

      // ---------------------------------------------------------
      // 🔐 LÓGICA DE SESSÃO APRIMORADA
      // Qualquer mudança de URL (slug) ativa deve provocar Logout.

      bool shouldWipe = false;

      print('🧐 [BOOTSTRAP DEBUG] Comparando Slugs:');
      print('   -> Current (URL): "$normCurrent" (Raw: "$safeCurrentSlug")');
      print('   -> Saved (Pref):  "$normSaved" (Raw: "$safeSavedSlug")');

      if (hasSession) {
        if (normSaved.isEmpty && normCurrent.isNotEmpty) {
          // 🔄 SAÍDA DA ROOT: Estava na root e foi para um condomínio específico
          print(
              '🔄 [BOOTSTRAP] Saída da Root detectada ("" -> "$normCurrent"). Forçando Logout.');
          shouldWipe = true;
        } else if (normCurrent == normSaved) {
          // ✅ MESMO CONDOMÍNIO
          print('✅ [BOOTSTRAP] Slugs IDÊNTICOS. Mantendo sessão.');
          shouldWipe = false;
        } else {
          // 🔄 MUDANÇA GENÉRICA
          print('🔄 [BOOTSTRAP] Slugs DIFERENTES. Forçando Logout.');
          shouldWipe = true;
        }
      } else {
        // ❌ SEM SESSÃO
        shouldWipe = (normCurrent != normSaved);
      }

      // ---------------------------------------------------------
      // 🧹 EXECUÇÃO DA LIMPEZA (se necessário)
      // ---------------------------------------------------------

      if (shouldWipe) {
        print('🧹 [BOOTSTRAP] LOGOUT - Iniciando limpeza completa...');

        // 1. Deletar sessão na API
        try {
          final encryptedToken = prefs.getString('tokensessao_txt');
          if (encryptedToken != null && encryptedToken.isNotEmpty) {
            final tokenSessao = decryptText(encryptedToken);
            if (tokenSessao.isNotEmpty) {
              final url =
                  Uri.parse(ApiConfig.getEndpoint('auth', 'deleteSession'));
              await http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $tokenSessao',
                },
              );
            }
          }
        } catch (e) {
          print('⚠️ Erro ao deletar sessão: $e');
        }

        // 2. Limpar SharedPreferences (Flutter)
        await prefs.remove('tokensessao_txt');
        await prefs.remove('app_slug');
        await prefs.clear();

        // 3. Limpar LocalStorage (Manual - Fallback)
        if (kIsWeb) {
          try {
            html.window.localStorage.remove('flutter.tokensessao_txt');
            html.window.localStorage.remove('flutter.app_slug');
            html.window.localStorage.remove('flutter.condominio_id');
            print('🧹 [BOOTSTRAP] LocalStorage limpo manualmente.');
          } catch (e) {
            print('⚠️ Erro ao limpar LocalStorage: $e');
          }
        }

        // 4. Limpar Browser Storage e Cookies (legado)
        if (kIsWeb) {
          try {
            final savedOrigUrl = html.window.sessionStorage['_original_url'];
            html.window.sessionStorage.clear();
            if (savedOrigUrl != null) {
              html.window.sessionStorage['_original_url'] = savedOrigUrl;
            }
          } catch (e) {}
        }

        // 5. Check if we need to FORCE RELOAD to clear memory state
        // Only force reload IF there was a session that we just destroyed.
        // If we are already clean, reloading causes a loop on the Login page.
        if (kIsWeb && hasSession) {
          print(
              '[BOOTSTRAP] Forçando Recarga da Página para garantir Limpeza...');
          // Pequeno delay para garantir que os storages foram limpos
          await Future.delayed(const Duration(milliseconds: 100));
          html.window.location.reload();
          return;
        }

        await _clearConfig();
      } else {
        // Não vai fazer wipe - salvar o slug atual para próximos refreshes
        if (hasSession) {
          // Salvar SEMPRE, mesmo se vazio (root), para distinguir de "nunca salvou"
          await prefs.setString('app_slug', safeCurrentSlug);
          print(
              '💾 [BOOTSTRAP] Slug salvo para próximos refreshes: "$safeCurrentSlug"');
        }
      }

      final slug = safeCurrentSlug;

      // Se o slug está vazio (Root URL)
      if (slug.isEmpty) {
        // Se temos sessão válida e NÃO fizemos wipe, significa que o usuário
        // está logado na root e deu refresh -> Manter logado
        if (hasSession && !shouldWipe) {
          print(
              '✅ [BOOTSTRAP] Root com sessão válida. Recuperando slug salvo...');
          // Não retornamos antecipadamente. Deixamos cair na lógica abaixo.
          // O slug será recuperado do savedSlug.
        } else {
          // Caso contrário, navegar para login/home se não tiver slug
          if (slug.isEmpty) {
            print(
                'ℹ️ [BOOTSTRAP] Root sem sessão ou após wipe. Navegando para login...');
            _navegarParaHome();
            return;
          }
        }
      }

      // Determinar o slug final para usar na configuração
      final String finalSlug =
          slug.isNotEmpty ? slug : (hasSession ? safeSavedSlug : '');

      if (finalSlug.isEmpty) {
        // Se não temos slug mas temos sessão, tentamos carregar permissões com o que temos (condominio_id salvo)
        if (hasSession) {
          print(
              '⚠️ [BOOTSTRAP] Slug vazio mas sessão válida. Tentando carregar permissões via storage...');
          await PermissionService().loadPermissions();
        }

        // Se ainda assim for vazio, não temos o que fazer -> Login/Home
        _navegarParaHome();
        return;
      }

      setState(() {
        _statusMessage = 'Configurando ambiente...';
      });

      // 1. Obter Sessão (Bearer Token)
      // Endpoint: auth/getSession -> gate.conectcon.net.br/pt-br/getsessao
      final getSessaoUrl = ApiConfig.getEndpoint('auth', 'getSession');

      setState(() {
        _statusMessage = 'Conectando ao servidor de autenticação...';
      });

      final sessaoResponse = await http.post(
        Uri.parse(getSessaoUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'usuario_id': 1183}),
      );

      print(
          '🔍 [BOOTSTRAP] Session Response Status: ${sessaoResponse.statusCode}');

      if (sessaoResponse.statusCode != 200) {
        throw Exception(
            'Erro ao conectar ao servidor (Sessão): ${sessaoResponse.statusCode}');
      }

      final sessaoData = jsonDecode(sessaoResponse.body);

      // Extract bearer token
      String token = '';
      if (sessaoData is Map) {
        if (sessaoData.containsKey('data')) {
          // USER INSTRUCTION: "pegue o data que esta em response de getsessao ... ele é o bearer"
          token = sessaoData['data']?.toString() ?? '';
        } else if (sessaoData.containsKey('token')) {
          token = sessaoData['token'];
        } else if (sessaoData.containsKey('access_token')) {
          token = sessaoData['access_token'];
        } else {
          // Fallback
          token = sessaoData.values
              .firstWhere((v) => v is String && v.length > 20, orElse: () => '')
              .toString();
        }
      }

      if (token.isEmpty) {
        throw Exception('Token de acesso não encontrado na resposta.');
      }

      // Save fresh token for global usage (fixes issues on F5)
      // prefs is already defined in the function scope
      // ⚠️ FIX: NÃO SALVAR O TOKEN DE BOOTSTRAP COMO SESSÃO DO USUÁRIO
      // O token obtido aqui (geralmente user 1183) é apenas para configuração (rota).
      // Se salvarmos no 'tokensessao_txt', o app achará que o usuário está logado incorretamente.
      // Mantendo apenas na variável local 'token' para uso na chamada de Rota abaixo.
      /*
      if (token.isNotEmpty) {
        final encryptedToken = encryptText(token);
        await prefs.setString('tokensessao_txt', encryptedToken);
        // Force reload to ensure other contexts see it immediately
        await prefs.reload();
      }
      */

      setState(() {
        _statusMessage = 'Obtendo configurações do condomínio ($finalSlug)...';
      });

      print('🔍 [BOOTSTRAP] Fetching Rota for: $finalSlug');
      final rotaUrl = '${ApiConfig.getEndpoint('config', 'rota')}/$finalSlug';
      print('🔍 [BOOTSTRAP] Rota URL: $rotaUrl');

      final rotaResponse = await http.get(
        Uri.parse(rotaUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      print('🔍 [BOOTSTRAP] Rota Response Status: ${rotaResponse.statusCode}');

      if (rotaResponse.statusCode != 200) {
        throw Exception(
            'Condomínio não encontrado (Config): ${rotaResponse.statusCode}');
      }

      final rotaResponseJson = jsonDecode(rotaResponse.body);
      Map<String, dynamic> configData = {};
      if (rotaResponseJson is Map &&
          rotaResponseJson.containsKey('data') &&
          rotaResponseJson['data'] is Map) {
        configData = Map<String, dynamic>.from(rotaResponseJson['data']);
      } else if (rotaResponseJson is Map<String, dynamic>) {
        configData = rotaResponseJson;
      }

      // Check for valid condominio
      if (configData['condominio_id'] == null) {
        // Condomínio não encontrado/inválido. Show Error Screen.
        setState(() {
          _condominioNotFound = true;
          _statusMessage = '';

          // Prioritize specific images first, then fallback to defaults
          // Logo
          if (configData['link_logo'] != null &&
              configData['link_logo'].toString().isNotEmpty) {
            _notFoundLogo = configData['link_logo'];
          } else {
            _notFoundLogo = configData['link_logo_padrao'];
          }

          // Background
          if (configData['link_fundo'] != null &&
              configData['link_fundo'].toString().isNotEmpty) {
            _notFoundBg = configData['link_fundo'];
          } else {
            _notFoundBg = configData['link_fundo_padrao'];
          }
        });
        return;
      }

      // 3. Salvar Configuração
      // prefs já foi instanciado no início da função

      if (configData['condominio_id'] != null) {
        prefs.setString(
            'condominio_id_config', configData['condominio_id'].toString());

        // Sync with main application state (mimic login)
        final encryptedCondoId =
            encryptText(configData['condominio_id'].toString());
        prefs.setString('condominio_id', encryptedCondoId);
      }
      if (configData['condominio_ds'] != null) {
        prefs.setString(
            'condominio_nome_config', configData['condominio_ds'].toString());
      }
      if (configData['cor_web'] != null) {
        prefs.setString('cor_web', configData['cor_web'].toString());
      }
      if (configData['cor_app'] != null) {
        prefs.setString('cor_app', configData['cor_app'].toString());
      }
      if (configData['link_logo'] != null) {
        prefs.setString('link_logo', configData['link_logo'].toString());
      }
      if (configData['link_logo_padrao'] != null) {
        prefs.setString(
            'link_logo_padrao', configData['link_logo_padrao'].toString());
      }
      if (configData['link_fundo'] != null) {
        prefs.setString('link_fundo', configData['link_fundo'].toString());
      }
      if (configData['link_fundo_padrao'] != null) {
        prefs.setString(
            'link_fundo_padrao', configData['link_fundo_padrao'].toString());
      }
      if (configData['adm_id'] != null) {
        prefs.setString('adm_id_config', configData['adm_id'].toString());
      }
      if (configData['prestador_id'] != null) {
        prefs.setString(
            'prestador_id_config', configData['prestador_id'].toString());
      }

      // Store the slug itself to mark as configured
      // Store the RAW slug (URL) to ensure strict URL matching on next load
      // This prevents "hidden" context switches where internal state != URL
      await prefs.setString('app_slug', safeCurrentSlug);

      // Update status with the condominium name for user feedback
      if (configData.containsKey('condominio_ds')) {
        setState(() {
          _statusMessage = configData['condominio_ds'].toString();
        });

        // Short delay to allow user to see the confirmed condominium name
        await Future.delayed(const Duration(seconds: 2));
      }

      // 4. Update URL to clean state, preserving existing query parameters/fragments
      if (kIsWeb) {
        final currentHref = html.window.location.href;
        final currentUri = Uri.parse(currentHref);

        // Construct new URI: /rota/slug (como solicitado para padronização)
        final newPath = '/$finalSlug';

        // Only update if the path changed
        if (currentUri.path != newPath) {
          final newUri = currentUri.replace(path: newPath);
          html.window.history.pushState({}, '', newUri.toString());
        }
      }

      // 5. Load Permissions
      // Calls standard loadPermissions which relies on saved 'condominio_id' (from login)
      // and fresh 'tokensessao_txt' (just saved above).
      // Garantir que carregamos as permissões ao recarregar na root
      await PermissionService().loadPermissions();
      _navegarParaHome();
      return;
    } catch (e) {
      debugPrint('Erro no bootstrap: $e');
      setState(() {
        _hasError = true;
        _statusMessage = 'Não foi possível carregar as configurações.\n$e';
      });
    }
  }

  Future<void> _clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('condominio_id_config');
    await prefs.remove('condominio_nome_config');
    await prefs.remove('cor_web');
    await prefs.remove('cor_app');
    await prefs.remove('link_logo');
    await prefs.remove('link_logo_padrao');
    await prefs.remove('link_fundo');
    await prefs.remove('link_fundo_padrao');
    await prefs.remove('adm_id_config');
    await prefs.remove('app_slug');
  }

  void _navegarParaHome() {
    if (widget.onConfigured != null) {
      widget.onConfigured!();
    } else {
      // Fallback fallback if used outside of main logic
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_condominioNotFound) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SizedBox.expand(
          child: BootstrapImageWidget(
            url: 'assets/images/ops_bg.png',
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xFF1A0F35), // Dark Purple (Login Form Color)
      body: Stack(
        children: [
          // Top Text
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 60, left: 40),
              child: Text(
                'SMART ACCESS',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          // Center Content
          Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.zero,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                child: _hasError
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 60, color: Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Erro de Configuração',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _statusMessage = 'Retentando...';
                              });
                              _carregarConfiguracao();
                            },
                            child: const Text('Tentar Novamente'),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo wrapper with circular progress indicator around it
                          SizedBox(
                            width: 140, // Increased size slightly
                            height: 140,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Circular Loading Animation
                                const SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                    strokeWidth: 4,
                                  ),
                                ),
                                // Logo Centered - No zoom, full contain
                                Container(
                                  width: 90,
                                  height: 90,
                                  padding: const EdgeInsets.all(
                                      8.0), // Padding to ensure breathing room
                                  child: Image.asset(
                                    'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Status/Condominium Name Text
                          Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.white, // White text on purple bg
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
