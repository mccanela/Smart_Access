import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/app_version.dart';
import 'dart:math';
import '../../core/services/crypto_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/config/api_config.dart';
import 'dart:ui_web' as ui_web;
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'vertical_separator.dart';
import 'refresh_button.dart';
import '../../core/services/permission_service.dart';
import 'two_factor_dialog.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLogin;
  const LoginPage({super.key, this.onLogin});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final TextEditingController _captchaController = TextEditingController();
  bool _obscure = true;
  bool _obscureUser = true;
  bool _loading = false;
  String? _error;

  // Configuração Dinâmica
  // Default to assets as requested
  String _logoUrl = 'assets/images/logo_removebg.png';
  String? _logoFallbackUrl;

  String _bgUrl = 'assets/images/fundo_login_conectcon1.jpg';
  String? _bgFallbackUrl;

  String? _condominioNome;
  String? _admId;
  String? _prestadorId;

  // Constantes para espaçamentos consistentes
  static const double kSpacingLarge = 20.0;
  static const double kFieldHeight = 44.0;
  static const double kCardPadding = 28.0;
  static const double kLogoSpacing = 40.0; // Espaçamento dobrado após logo

  // Constantes para espaçamentos internos dos campos
  static const double kFieldHorizontalPadding = 14.0;
  static const double kFieldVerticalPadding = 12.0;

  // Função auxiliar para detectar tema escuro
  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Funções auxiliares para cores adaptáveis ao tema
  Color getBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF1F2937) : Colors.white;
  }

  Color getSurfaceColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF374151) : Colors.white;
  }

  Color getCardColor(BuildContext context) {
    return isDarkMode(context)
        ? const Color(0xFF374151)
        : const Color(0xFFF8F9FB);
  }

  Color getTextColor(BuildContext context) {
    return isDarkMode(context) ? Colors.white : Colors.black;
  }

  Color getSecondaryTextColor(BuildContext context) {
    return isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF6B7280);
  }

  Color getBorderColor(BuildContext context) {
    return isDarkMode(context) ? Colors.grey[600]! : Colors.grey.shade300;
  }

  Color getSecondaryBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF4B5563) : Colors.grey.shade100;
  }

  // (Opcional) Captcha simples
  int _captchaA = 0;
  int _captchaB = 0;
  String _captchaInput = '';
  bool _captchaFieldFocused = false;
  late FocusNode _captchaFocusNode;

  bool get _captchaOk =>
      int.tryParse(_captchaInput.trim()) == (_captchaA + _captchaB);

  @override
  void initState() {
    super.initState();
    _captchaFocusNode = FocusNode();
    _captchaFocusNode.addListener(_onCaptchaFocusChange);
    _generateCaptcha();
    _initializeLanguage();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // Logic for Logo Fallback: Priority 1 -> link_logo, Priority 2 -> link_logo_padrao, Priority 3 -> Default (Assets)
      final linkLogo = prefs.getString('link_logo');
      final linkLogoPadrao = prefs.getString('link_logo_padrao');

      if (linkLogo != null && linkLogo.isNotEmpty) {
        _logoUrl = linkLogo;
        _logoFallbackUrl = linkLogoPadrao; // Use padrao as fallback
      } else if (linkLogoPadrao != null && linkLogoPadrao.isNotEmpty) {
        _logoUrl = linkLogoPadrao;
        _logoFallbackUrl = null;
      }

      // Logic for Background Fallback: Priority 1 -> link_fundo, Priority 2 -> link_fundo_padrao, Priority 3 -> Default (Assets)
      final linkFundo = prefs.getString('link_fundo');
      final linkFundoPadrao = prefs.getString('link_fundo_padrao');

      if (linkFundo != null && linkFundo.isNotEmpty) {
        _bgUrl = linkFundo;
        _bgFallbackUrl = linkFundoPadrao; // Use padrao as fallback
      } else if (linkFundoPadrao != null && linkFundoPadrao.isNotEmpty) {
        _bgUrl = linkFundoPadrao;
        _bgFallbackUrl = null;
      }

      _condominioNome = prefs.getString('condominio_nome_config');
      _admId = prefs.getString('adm_id_config');
      _prestadorId = prefs.getString('prestador_id_config');
    });
  }

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    _captchaController.dispose();
    _captchaFocusNode.removeListener(_onCaptchaFocusChange);
    _captchaFocusNode.dispose();
    super.dispose();
  }

  void _onCaptchaFocusChange() {
    setState(() {
      _captchaFieldFocused = _captchaFocusNode.hasFocus;
    });
  }

  void _generateCaptcha() {
    final rand = Random();
    setState(() {
      _captchaA = rand.nextInt(10) + 1;
      _captchaB = rand.nextInt(10) + 1;
      _captchaInput = '';
      _captchaController.clear();
    });
  }

  Future<void> _initializeLanguage() async {
    await AppLocalizations.initialize();
    setState(() {});
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.translate('select_language')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Text('🇧🇷', style: TextStyle(fontSize: 24)),
              title: Text('Português'),
              onTap: () async {
                await AppLocalizations.setLanguage('pt');
                Navigator.of(context).pop();
                setState(() {});
              },
            ),
            ListTile(
              leading: Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: Text('English'),
              onTap: () async {
                await AppLocalizations.setLanguage('en');
                Navigator.of(context).pop();
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  void _attemptLogin() {
    if (_loading) return;
    if (_captchaOk) {
      _login();
    } else {
      setState(() {
        _error = 'Resultado da soma incorreto.';
        _captchaController.clear();
      });
    }
  }

  Future<void> _login() async {
    if (_userController.text.trim().isEmpty || _passController.text.isEmpty) {
      setState(() {
        _error = AppLocalizations.translate('fill_user_password');
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Limpeza adicional para garantir que não há dados residuais
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('tokensessao_txt');
      await prefs.remove('usuario_id');
      await prefs.remove('condominio_id');

      // Limpar cache do navegador (Web) para garantir ambiente limpo
      if (kIsWeb) {
        try {
          html.window.localStorage.clear();
          html.window.sessionStorage.clear();
          // Não fazemos reload aqui para não interromper o fluxo de login,
          // apenas limpamos os dados armazenados.
        } catch (e) {
          // Ignora erro se não conseguir limpar
        }
      }
    } catch (e) {
      // Ignora erro na limpeza
    }

    final url = Uri.parse(ApiConfig.getEndpoint('auth', 'login'));
    final payload = {
      "email_txt": _userController.text.trim(),
      "senha_txt": _passController.text,
      "perfilparam_id": 0,
    };
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('tokensessao_txt');
        if (data is Map && data['data'] is List && data['data'].isNotEmpty) {
          final user = data['data'][0];
          String? tokenSessao;
          final sessao = user['sessao'];
          if (sessao is Map && sessao.isNotEmpty) {
            tokenSessao = (sessao['tokensessao_txt'] ?? '').toString().trim();
          }
          if (tokenSessao != null && tokenSessao.isNotEmpty) {
            // REMOVIDO: Prints de debug do token
            final encryptedToken = encryptText(tokenSessao);
            // REMOVIDO: Print do token criptografado
            await prefs.setString('tokensessao_txt', encryptedToken);
            // REMOVIDO: Print do token salvo

            // 🔐 SALVAR SLUG ATUAL APÓS LOGIN BEM-SUCEDIDO
            // Isso permite que o bootstrap detecte mudanças de URL corretamente
            if (kIsWeb) {
              try {
                final href = html.window.location.href;
                final uri = Uri.parse(href);
                String? currentSlug;

                // Tentar pegar do Path primeiro
                if (uri.pathSegments.isNotEmpty) {
                  for (var i = uri.pathSegments.length - 1; i >= 0; i--) {
                    final segment = uri.pathSegments[i];
                    if (segment.isNotEmpty) {
                      currentSlug = segment;
                      break;
                    }
                  }
                }

                // Se não encontrou no path, tentar no fragmento
                if (currentSlug == null && uri.fragment.isNotEmpty) {
                  final cleanFragment = uri.fragment.startsWith('/')
                      ? uri.fragment.substring(1)
                      : uri.fragment;
                  final fragmentParts = cleanFragment.split('/');
                  if (fragmentParts.isNotEmpty) {
                    currentSlug = fragmentParts.firstWhere(
                      (e) => e.isNotEmpty,
                      orElse: () => '',
                    );
                  }
                }

                // Salvar o slug (mesmo se vazio = root)
                final slugToSave = currentSlug ?? '';
                await prefs.setString('app_slug', slugToSave);
                print('💾 [LOGIN] Slug salvo após login: "$slugToSave"');
              } catch (e) {
                print('⚠️ [LOGIN] Erro ao salvar slug: $e');
              }
            }

            final usuarioIdStr = user['usuario_id'].toString();
            final encryptedUsuarioId = encryptText(usuarioIdStr);
            await prefs.setString('usuario_id', encryptedUsuarioId);
            // REMOVIDO: conferências locais do usuario_id

            // VALIDAÇÃO: Verificar se o condominio_id do login é igual ao da rota
            final condominioIdStr = user['condominio_id'].toString();
            final condominioIdLogin = int.tryParse(condominioIdStr) ?? 0;

            // Obter condominio_id da configuração (rota/bootstrap)
            final condominioIdConfig =
                prefs.getString('condominio_id_config') ?? '0';
            final condominioIdRota = int.tryParse(condominioIdConfig) ?? 0;

            // Se os IDs forem diferentes, bloquear o login
            if (condominioIdRota > 0 && condominioIdLogin != condominioIdRota) {
              setState(() {
                _loading = false;
                _error = 'E-mail ou senha incorretos.';
              });
              return;
            }

            final encryptedCondominioId = encryptText(condominioIdStr);
            await prefs.setString('condominio_id', encryptedCondominioId);
            // REMOVIDO: conferências locais do condominio_id
            // Salvar nome do usuário se disponível
            final usuarioNome =
                user['nome'] ?? user['nome_txt'] ?? user['usuario_nome'] ?? '';
            if (usuarioNome.toString().isNotEmpty) {
              final encryptedUsuarioNome = encryptText(usuarioNome.toString());
              await prefs.setString('usuario_nome', encryptedUsuarioNome);
            }
            // Chamada à API createsessao usando o token da API Auth
            final sessaoPayload = {
              "sessao_id": sessao['sessao_id'] ?? '',
              "usuario_id": user['usuario_id'] ?? 0,
              "datainicio": sessao['datainicio'] ?? '',
              "datafim": sessao['datafim'] ?? '',
              "registration_ids": sessao['registration_ids'] ?? '',
              "sistemaoperacional_txt": sessao['sistemaoperacional_txt'] ?? '',
              "tipo_txt": sessao['tipo_txt'] ?? '',
              "dispositivo_id": sessao['dispositivo_id'] ?? '',
              "modelo_txt": sessao['modelo_txt'] ?? '',
              "atualizadisp_flg": sessao['atualizadisp_flg'] ?? '',
              "atualizadisp_txt": sessao['atualizadisp_txt'] ?? '',
              "tokensessao_txt": sessao['tokensessao_txt'] ?? '',
              "versao_txt": "1.0",
            };
            final createSessaoUrl = Uri.parse(
              ApiConfig.getEndpoint('auth', 'createSession'),
            );
            await http.post(
              createSessaoUrl,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $tokenSessao',
              },
              body: jsonEncode(sessaoPayload),
            );
            // REMOVIDO: leitura local do token apenas para debug

            // Verificar se há observação de turno pendente
            final encryptedObservacao =
                prefs.getString('turno_pendente_observacao');
            if (encryptedObservacao != null && encryptedObservacao.isNotEmpty) {
              try {
                final observacao = decryptText(encryptedObservacao);
                if (observacao.isNotEmpty && mounted) {
                  // Mostrar observação em um dialog
                  await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Observação do Turno'),
                        content: Text(observacao),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              } catch (e) {
                // Erro ao descriptografar observação
              }
              // Limpar dados do turno pendente
              await prefs.remove('turno_pendente_observacao');
            }

            // 5. SmartAccess check — verify if condominio has gate system
            bool requiresTwoFactor = false;
            try {
              final condominioUrl = Uri.parse(
                ApiConfig.getEndpoint('condominio', 'condominio'),
              );
              final condominioResponse = await http.post(
                condominioUrl,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $tokenSessao',
                },
                body: jsonEncode({
                  'condominio_id': user['condominio_id'],
                }),
              );
              print(
                  '[2FA DEBUG] condominio status: ${condominioResponse.statusCode}');
              print('[2FA DEBUG] condominio body: ${condominioResponse.body}');
              if (condominioResponse.statusCode == 200) {
                final condData = jsonDecode(condominioResponse.body);
                // flg_possui_gate may be at root or inside data array
                bool isSmartAccess = false;
                if (condData is Map) {
                  print(
                      '[2FA DEBUG] condData is Map, keys: ${condData.keys.toList()}');
                  if (condData['flg_possui_gate'] == true) {
                    isSmartAccess = true;
                    print('[2FA DEBUG] flg_possui_gate found at root = true');
                  } else if (condData['data'] is List &&
                      (condData['data'] as List).isNotEmpty) {
                    final firstItem = condData['data'][0];
                    print(
                        '[2FA DEBUG] data[0] keys: ${firstItem is Map ? firstItem.keys.toList() : 'not a map'}');
                    print(
                        '[2FA DEBUG] data[0] flg_possui_gate: ${firstItem is Map ? firstItem['flg_possui_gate'] : 'N/A'}');
                    if (firstItem is Map &&
                        firstItem['flg_possui_gate'] == true) {
                      isSmartAccess = true;
                    }
                  } else if (condData['data'] is Map &&
                      condData['data']['result'] is List &&
                      (condData['data']['result'] as List).isNotEmpty) {
                    final firstItem = condData['data']['result'][0];
                    print(
                        '[2FA DEBUG] data.result[0] keys: ${firstItem is Map ? firstItem.keys.toList() : 'not a map'}');
                    print(
                        '[2FA DEBUG] data.result[0] flg_possui_gate: ${firstItem is Map ? firstItem['flg_possui_gate'] : 'N/A'}');
                    if (firstItem is Map &&
                        firstItem['flg_possui_gate'] == true) {
                      isSmartAccess = true;
                    }
                  }
                } else {
                  print(
                      '[2FA DEBUG] condData is NOT a Map, type: ${condData.runtimeType}');
                }

                print(
                    '[2FA DEBUG] isSmartAccess: $isSmartAccess, kIsWeb: $kIsWeb');
                if (isSmartAccess && kIsWeb) {
                  final cookies = html.document.cookie ?? '';
                  print('[2FA DEBUG] cookies: "$cookies"');
                  // TODO: replace 'SMARTACCESS_2FA' with actual cookie name
                  final hasValidCookie = cookies.contains('SMARTACCESS_2FA=');
                  print('[2FA DEBUG] hasValidCookie: $hasValidCookie');
                  if (!hasValidCookie) {
                    requiresTwoFactor = false; // TODO: inativo temporariamente
                  }
                }
              }
            } catch (e) {
              print('[2FA DEBUG] ERROR: $e');
            }

            // 6. If SmartAccess without cookie, show 2FA dialog
            if (requiresTwoFactor && mounted) {
              final twoFactorOk = await showTwoFactorDialog(
                context: context,
                token: tokenSessao,
                usuarioId: user['usuario_id'] is int
                    ? user['usuario_id']
                    : int.tryParse(user['usuario_id'].toString()) ?? 0,
                condominioId: condominioIdLogin,
              );
              if (!twoFactorOk) {
                // User cancelled 2FA — clear session and abort login
                await prefs.remove('tokensessao_txt');
                await prefs.remove('usuario_id');
                await prefs.remove('condominio_id');
                await prefs.remove('usuario_nome');
                setState(() {
                  _loading = false;
                  _error = 'Two-factor authentication required.';
                });
                return;
              }

              // Salvar cookie local criptografado após validação 2FA com sucesso
              if (kIsWeb) {
                try {
                  final encryptedVal = encryptText('VALIDATED');
                  final encodedVal = Uri.encodeComponent(encryptedVal);
                  // 30 dias de expiração
                  const maxAge = 60 * 60 * 24 * 30;
                  html.document.cookie =
                      'SMARTACCESS_2FA=$encodedVal; max-age=$maxAge; path=/';
                  print('🍪 [LOGIN] Cookie 2FA salvo com sucesso: $encodedVal');
                } catch (e) {
                  print('⚠️ [LOGIN] Erro ao salvar cookie 2FA: $e');
                }
              }
            }

            // 7. Load permissions
            await PermissionService().loadPermissions();

            if (widget.onLogin != null) {
              widget.onLogin!();
            }
            return;
          } else {
            setState(() {
              _error = 'Login ou senha incorretos';
            });
            return;
          }
        }
        await prefs.remove('usuario_id');
        await prefs.remove('condominio_id');
        await prefs.remove('tokensessao_txt');
        setState(() {
          _error = AppLocalizations.translate('wrong_credentials');
          _generateCaptcha();
        });
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('usuario_id');
        await prefs.remove('condominio_id');
        await prefs.remove('tokensessao_txt');
        setState(() {
          _error = AppLocalizations.translate('wrong_credentials');
          _generateCaptcha();
        });
      }
    } catch (e) {
      setState(() {
        _error = AppLocalizations.translate('connection_error');
        _generateCaptcha();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildExtraBubble(String url, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: ClipOval(
        child: CorsImageWidget(
          url: url,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // LADO ESQUERDO - Banner/Logo
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFF040F39),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                CorsImageWidget(
                  url: _bgUrl,
                  fallbackUrl: _bgFallbackUrl,
                  fit: BoxFit.cover,
                ),
                // Overlay
                Container(
                  color: const Color(0xFF040F39).withValues(alpha: 0.3),
                ),
                // Logo Top Right
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 80, bottom: 580),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_admId != null && _admId!.isNotEmpty) ...[
                          _buildExtraBubble(
                              'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/adms/$_admId/imagens/logo.jpg',
                              90),
                          const SizedBox(width: 20),
                        ],
                        Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(30.0),
                            child: CorsImageWidget(
                              url: _logoUrl,
                              fallbackUrl: _logoFallbackUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        if (_prestadorId != null &&
                            _prestadorId != '0' &&
                            _prestadorId!.isNotEmpty) ...[
                          const SizedBox(width: 20),
                          _buildExtraBubble(
                              'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/patrocinador/$_prestadorId/imagens/logo.jpg',
                              90),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Separator
        const VerticalOscillatingSeparator(),
        // LADO DIREITO - Formulário e Títulos
        Expanded(
          flex: 1,
          child: Container(
            color: const Color(0xFF130B29), // Deep dark purple background
            child: SafeArea(
              child: Stack(
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      // Title Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          children: [
                            Text(
                              _condominioNome ?? 'ConectCon',
                              style: const TextStyle(
                                color: Color(0xFFA855F7), // Purple color
                                fontSize: 42,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Acesse uma experiência condominial mais elegante, integrada e segura;\nblindada pela inteligência da ConectCon®.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Form Section with Custom Border Gap
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 350),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _AnimatedBorderContainer(
                              child: Container(
                                padding: const EdgeInsets.all(48),
                                child: _buildLoginForm(
                                    isMobile: false, showHeader: false),
                              ),
                            ),
                            Positioned(
                              bottom: -14,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  color: const Color(
                                      0xFF130B29), // Match background to hide border
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 30),
                                  child: const Text(
                                    'Suporte',
                                    style: TextStyle(
                                      color:
                                          Color(0xFF130B29), // Match background
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _buildFooter(isMobile: false),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // Topo: Imagem e Branding (35% da altura ou fixo)
        Expanded(
          flex: 35,
          child: Container(
            color: const Color(0xFF040F39),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CorsImageWidget(
                  url: _bgUrl,
                  fallbackUrl: _bgFallbackUrl,
                  fit: BoxFit.cover,
                ),
                Container(
                  color: const Color(0xFF040F39).withValues(alpha: 0.6),
                ),
                Positioned(
                  top: 40,
                  left: 20,
                  child: Text(
                    'SMART ACCESS v$appVersion',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20, // Slightly smaller on mobile
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                Center(child: _buildBrandingHeader(isMobile: true)),
              ],
            ),
          ),
        ),
        // Base: Formulário em fundo branco
        Expanded(
          flex: 65,
          child: Container(
            color: const Color(0xFF1A0F35), // Elegant Dark Purple
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 32),
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight -
                                100, // Ajuste para o footer
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 250),
                              child: Column(
                                children: [
                                  _buildLoginForm(isMobile: true),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _buildFooter(isMobile: true),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBrandingHeader({required bool isMobile}) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_admId != null && _admId!.isNotEmpty) ...[
              _buildExtraBubble(
                  'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/adms/$_admId/imagens/logo.jpg',
                  isMobile ? 80 : 100),
              const SizedBox(width: 10),
            ],
            Container(
              width: isMobile ? 160 : 200,
              height: isMobile ? 160 : 200,
              padding: const EdgeInsets.all(
                  30), // Increased padding to prevent clipping
              decoration: BoxDecoration(
                color: Colors.white, // Solid white background
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CorsImageWidget(
                url: _logoUrl,
                fallbackUrl: _logoFallbackUrl,
                fit: BoxFit.contain, // Show entire logo without cropping
              ),
            ),
            if (_prestadorId != null &&
                _prestadorId != '0' &&
                _prestadorId!.isNotEmpty) ...[
              const SizedBox(width: 10),
              _buildExtraBubble(
                  'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/patrocinador/$_prestadorId/imagens/logo.jpg',
                  isMobile ? 80 : 100),
            ],
          ],
        ),
        const SizedBox(height: 30),
        if (_condominioNome != null && _condominioNome!.isNotEmpty)
          Text(
            _condominioNome!,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 10),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Acesse uma experiência condominial mais elegante, integrada e segura;\nblindada pela inteligência da ConectCon®.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter({required bool isMobile}) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Suporte moved to _buildLoginForm
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '2026 ConectCon® - Blindagem Condominial',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'SMART ACCESS v$appVersion',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Logo T (Fixo ConectCon)
              SizedBox(
                height: 50,
                width: 50,
                child: Image.asset(
                  'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm({bool isMobile = false, bool showHeader = true}) {
    // Agora o formulário é limpo, sem card
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile && showHeader) ...[
          const Center(
            child: Text(
              'Fazer Login',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Column(
              children: [
                const Text(
                  'Acesse sua conta',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C38A5).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline,
                    color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _userController,
            inputFormatters: [LengthLimitingTextInputFormatter(200)],
            obscureText: _obscureUser,
            style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Usuário',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureUser
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscureUser = !_obscureUser),
              ),
            ),
            onSubmitted: (_) => _attemptLogin(),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: _passController,
            inputFormatters: [LengthLimitingTextInputFormatter(25)],
            obscureText: _obscure,
            style: const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
            decoration: InputDecoration(
              hintText: 'Senha',
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            onSubmitted: (_) => _attemptLogin(),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$_captchaA + $_captchaB = ?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _captchaController,
                  focusNode: _captchaFocusNode,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => setState(() => _captchaInput = v),
                  style:
                      const TextStyle(fontSize: 16, color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Resultado',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh,
                          color: Color(0xFF94A3B8), size: 18),
                      onPressed: _generateCaptcha,
                    ),
                  ),
                  onSubmitted: (_) => _attemptLogin(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _NeonButton(
          onPressed: _loading ? null : _attemptLogin,
          loading: _loading,
        ),
        const SizedBox(height: 24),
        if (kIsWeb) ...[
          Row(
            children: [
              Expanded(
                child: RefreshButton(
                  label: 'Atualizar',
                  icon: Icons.refresh,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: RefreshButton(
                  label: 'Suporte',
                  icon: Icons.support_agent,
                  shouldRotate: false,
                  onPressed: () async {
                    final url = Uri.parse('https://wa.me/5511934637096');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
          ),
        ] else ...[
          Center(
            child: RefreshButton(
              label: 'Suporte',
              icon: Icons.support_agent,
              shouldRotate: false,
              onPressed: () async {
                final url = Uri.parse('https://wa.me/5511934637096');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class CorsImageWidget extends StatelessWidget {
  final String url;
  final String? fallbackUrl;
  final BoxFit fit;

  const CorsImageWidget(
      {super.key,
      required this.url,
      this.fallbackUrl,
      this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    // Check if it's a network URL
    final isNetwork = url.startsWith('http://') || url.startsWith('https://');

    if (isNetwork) {
      if (kIsWeb) {
        final String viewType = 'cors-image-${url.hashCode}-${fit.index}';
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
          final img = html.ImageElement()
            ..src = url
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = fit == BoxFit.cover ? 'cover' : 'contain';

          // Handle Fallback on Web
          if (fallbackUrl != null && fallbackUrl!.isNotEmpty) {
            img.onError.listen((event) {
              if (img.src != fallbackUrl) {
                img.src = fallbackUrl!;
              }
            });
          }
          return img;
        });
        return HtmlElementView(viewType: viewType);
      }
      return Image.network(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          // Handle Fallback on Mobile
          if (fallbackUrl != null && fallbackUrl!.isNotEmpty) {
            return Image.network(
              fallbackUrl!,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.grey.withValues(alpha: 0.1),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                );
              },
            );
          }
          return Container(
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Icon(Icons.broken_image, color: Colors.grey),
          );
        },
      );
    } else {
      // Assume Asset
      return Image.asset(
        url,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('Error loading asset image: $url -> $error');
          return Container(
            color: Colors.grey.withValues(alpha: 0.1),
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
        },
      );
    }
  }
}

// Neon Button Widget with hover effect
class _NeonButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const _NeonButton({
    required this.onPressed,
    required this.loading,
  });

  @override
  State<_NeonButton> createState() => _NeonButtonState();
}

class _NeonButtonState extends State<_NeonButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: _isHovering && !widget.loading
              ? [
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 4,
                  ),
                  BoxShadow(
                    color: const Color(0xFFA855F7).withValues(alpha: 0.2),
                    blurRadius: 60,
                    spreadRadius: 6,
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: widget.onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7C38A5),
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                const Color(0xFF7C38A5).withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'CONECTAR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }
}

// Widget com borda animada (efeito de luz se movendo)
class _AnimatedBorderContainer extends StatefulWidget {
  final Widget child;

  const _AnimatedBorderContainer({required this.child});

  @override
  State<_AnimatedBorderContainer> createState() =>
      _AnimatedBorderContainerState();
}

class _AnimatedBorderContainerState extends State<_AnimatedBorderContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _AnimatedBorderPainter(
            animation: _controller,
            color: const Color(0xFFA855F7),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFA855F7).withValues(alpha: 0.3),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.child,
          ),
        );
      },
    );
  }
}

// Painter para desenhar a borda animada
class _AnimatedBorderPainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;

  _AnimatedBorderPainter({
    required this.animation,
    required this.color,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));

    // Criar gradiente que se move ao redor da borda
    final progress = animation.value;

    // Calcular posições do gradiente baseado no progresso
    final gradientStart = Offset(
      size.width * (progress - 0.5).clamp(0.0, 1.0),
      size.height * (progress * 2 - 0.5).clamp(0.0, 1.0),
    );

    final gradientEnd = Offset(
      size.width * (progress + 0.5).clamp(0.0, 1.0),
      size.height * ((progress * 2) + 0.5).clamp(0.0, 1.0),
    );

    paint.shader = LinearGradient(
      begin: Alignment(
        (progress * 4 - 2).clamp(-1.0, 1.0),
        (progress * 4 - 2).clamp(-1.0, 1.0),
      ),
      end: Alignment(
        ((progress + 0.25) * 4 - 2).clamp(-1.0, 1.0),
        ((progress + 0.25) * 4 - 2).clamp(-1.0, 1.0),
      ),
      colors: [
        color.withValues(alpha: 0.0),
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 1.0),
        color.withValues(alpha: 0.8),
        color.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
    ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_AnimatedBorderPainter oldDelegate) {
    return oldDelegate.animation != animation || oldDelegate.color != color;
  }
}
