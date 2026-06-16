import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/config/api_config.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../core/utils/ui_standards.dart';

//-----------------------------//
// Modelo de dados para câmera
//-----------------------------//
class CameraData {
  final String id;
  final String nome;
  final bool isOnline;

  const CameraData({
    required this.id,
    required this.nome,
    this.isOnline = true,
  });
}

//-----------------------------//
// Dados mock de câmeras (conforme imagem)
//-----------------------------//
final List<CameraData> mockCameras = [
  const CameraData(id: '1', nome: 'PORTARIA PRINCIPAL', isOnline: true),
  const CameraData(id: '2', nome: 'PISCINA Lazer', isOnline: true),
  const CameraData(id: '3', nome: 'HALL TORRE A', isOnline: true),
  const CameraData(id: '4', nome: 'ENTRADA GARAGEM', isOnline: true),
  const CameraData(id: '5', nome: 'GARAGEM SUBSOLO', isOnline: true),
  const CameraData(id: '6', nome: 'HALL TORRE A', isOnline: true),
  const CameraData(id: '7', nome: 'HALL TORRE B', isOnline: true),
  const CameraData(id: '8', nome: 'ACADEMIA', isOnline: true),
  // Adicionar mais câmeras para chegar a 20 (para teste de divisão)
  const CameraData(id: '9', nome: 'ENTRADA SERVIÇO', isOnline: true),
  const CameraData(id: '10', nome: 'ELEVADOR 1', isOnline: true),
  const CameraData(id: '11', nome: 'ELEVADOR 2', isOnline: true),
  const CameraData(id: '12', nome: 'SALÃO DE FESTAS', isOnline: true),
  const CameraData(id: '13', nome: 'CHURRASQUEIRA', isOnline: true),
  const CameraData(id: '14', nome: 'QUADRA', isOnline: true),
  const CameraData(id: '15', nome: 'PLAYGROUND', isOnline: true),
  const CameraData(id: '16', nome: 'LOBBY PRINCIPAL', isOnline: true),
  const CameraData(id: '17', nome: 'COBERTURA', isOnline: true),
  const CameraData(id: '18', nome: 'RAMPAS', isOnline: true),
  const CameraData(id: '19', nome: 'ENTRADA LATERAL', isOnline: true),
  const CameraData(id: '20', nome: 'SAÍDA EMERGÊNCIA', isOnline: true),
];

//-----------------------------//
// Função helper para abrir o modal em nova janela
//-----------------------------//
void showCamerasModal(BuildContext context) {
  if (kIsWeb) {
    final currentUrl = html.window.location.href.split('?')[0].split('#')[0];
    final camerasUrl = '$currentUrl?view=cameras';

    final features = [
      'width=1400',
      'height=900',
      'left=${(html.window.screen?.width ?? 1920) ~/ 2 - 700}',
      'top=${(html.window.screen?.height ?? 1080) ~/ 2 - 450}',
      'resizable=yes',
      'scrollbars=no',
      'toolbar=no',
      'menubar=no',
      'location=no',
      'directories=no',
      'status=no',
    ].join(',');

    html.window.open(camerasUrl, 'cameras_window', features);
  } else {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Fechar',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation) {
        return CamerasModal(
          onClose: () => Navigator.of(context).pop(),
        );
      },
    );
  }
}

//-----------------------------//
// Função para verificar se está na view de câmeras
//-----------------------------//
bool isCamerasView() {
  if (kIsWeb) {
    final uri = Uri.parse(html.window.location.href);
    return uri.queryParameters['view'] == 'cameras';
  }
  return false;
}

//-----------------------------//
// Função para obter o lado da divisão (left ou right)
//-----------------------------//
String? getSplitSide() {
  if (kIsWeb) {
    final uri = Uri.parse(html.window.location.href);
    return uri.queryParameters['side']; // 'left' ou 'right'
  }
  return null;
}

//-----------------------------//
// Widget principal do modal de câmeras
//-----------------------------//
class CamerasModal extends StatefulWidget {
  final VoidCallback onClose;

  const CamerasModal({super.key, required this.onClose});

  @override
  State<CamerasModal> createState() => _CamerasModalState();
}

class _CamerasModalState extends State<CamerasModal> {
  int _selectedMenuIndex =
      6; // 0 = Todos, 1 = Câmeras, 2 = Playback, 3 = Ambientes, 4 = Configurações, 5 = Dividir, 6 = 4, 7 = 8 (padrão: 6 = modo 4)
  int? _selectedCameraIndex;
  String _currentDateTime = '';
  Timer? _dateTimeTimer;
  double _timelineValue = 0.0;
  Uint8List? _userPhotoBytes; // Para avatar da sidebar
  bool _isExpandedMode = false; // Modo expandido (câmera grande)
  String? _splitSide; // 'left' ou 'right' - se null, mostra todas as câmeras
  int _viewMode = 4; // 0 = todas, 4 = 4 telas, 8 = 8 telas (padrão: 4)
  List<Map<String, dynamic>> _unidadesList = []; // Lista de unidades da API
  final Map<String, Map<String, dynamic>?> _unidadesSelecionadas =
      {}; // Unidade selecionada por câmera (cameraId -> unidade)
  bool _loadingUnidades = false; // Loading ao carregar unidades
  final Map<String, int> _abrirPortaoEstado =
      {}; // Estado das bolinhas por câmera: 0 = nenhuma, 1 = primeira, 2 = ambas
  final Map<String, Timer?> _abrirPortaoResetTimer =
      {}; // Timer para resetar após sucesso
  bool _showInterfonePopup = false; // Controla se o popup está visível
  CameraData? _currentInterfoneCamera; // Câmera da chamada atual
  Map<String, dynamic>? _currentInterfoneUnidade; // Unidade da chamada atual
  Offset _interfonePopupPosition =
      const Offset(100, 100); // Posição do popup arrastável
  List<CameraData> _fourCamerasView =
      []; // Lista das 4 câmeras sendo exibidas no modo 4
  List<CameraData> _eightCamerasView =
      []; // Lista das 8 câmeras sendo exibidas no modo 8
  String _searchText = ''; // Texto de busca para a lista lateral
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentDateTime = _getCurrentDateTime();
    _loadUserPhoto();
    _splitSide = getSplitSide(); // Verificar se está em modo dividido

    // Inicializar as 4 e 8 primeiras câmeras
    final cameras = getCamerasForSide();
    _fourCamerasView = cameras.take(4).toList();
    _eightCamerasView = cameras.take(8).toList();

    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentDateTime = _getCurrentDateTime();
        });
      } else {
        timer.cancel();
      }
    });
  }

  //-----------------------------//
  // Toggle tema claro/escuro
  //-----------------------------//
  Future<void> _toggleTheme(BuildContext context) async {
    try {
      if (!mounted) return;
      final currentTheme = Theme.of(context).brightness;
      final isDark = currentTheme == Brightness.dark;
      final newTheme = isDark ? 'light' : 'dark';

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', newTheme);

      // Recarregar a janela para aplicar o novo tema
      if (kIsWeb && mounted) {
        html.window.location.reload();
      }
    } catch (e) {
      // Erro ao alternar tema
    }
  }

  //-----------------------------//
  // Abrir nova janela com metade das câmeras
  //-----------------------------//
  void _openSplitWindow() {
    if (!kIsWeb) return;

    final currentUrl = html.window.location.href.split('?')[0].split('#')[0];

    // Se já está em modo dividido, não fazer nada (já está dividido)
    if (_splitSide != null) {
      return;
    }

    // Se não está dividido, abrir nova janela com lado direito
    // e modificar esta janela para mostrar lado esquerdo (sem recarregar)
    final features = [
      'width=1400',
      'height=900',
      'left=${(html.window.screen?.width ?? 1920) ~/ 2}',
      'top=${(html.window.screen?.height ?? 1080) ~/ 2 - 450}',
      'resizable=yes',
      'scrollbars=no',
      'toolbar=no',
      'menubar=no',
      'location=no',
      'directories=no',
      'status=no',
    ].join(',');

    // Abrir nova janela com lado direito
    html.window.open(
        '$currentUrl?view=cameras&side=right', 'cameras_split_right', features);

    // Atualizar esta janela para mostrar lado esquerdo (usando setState para não recarregar)
    setState(() {
      _splitSide = 'left';
    });

    // Atualizar URL sem recarregar a página
    html.window.history
        .pushState(null, '', '$currentUrl?view=cameras&side=left');
  }

  //-----------------------------//
  // Obter lista de câmeras baseado no lado
  //-----------------------------//
  List<CameraData> getCamerasForSide() {
    if (_splitSide == null) {
      return mockCameras; // Mostrar todas se não estiver dividido
    }

    final totalCameras = mockCameras.length;
    final camerasPerSide = (totalCameras / 2).ceil();

    if (_splitSide == 'left') {
      return mockCameras.sublist(0, camerasPerSide);
    } else {
      return mockCameras.sublist(camerasPerSide);
    }
  }

  //-----------------------------//
  // Carregar unidades da API
  //-----------------------------//
  Future<void> _carregarUnidades() async {
    if (_loadingUnidades) return;

    setState(() {
      _loadingUnidades = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (condominioId.isEmpty) {
        setState(() {
          _loadingUnidades = false;
        });
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('chaves', 'unidades'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "apto_id": 0,
          "unidade": "",
          "flg_principal": "S",
          "nome": "",
          "placa": "",
          "vaga_id": 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final unidades = List<Map<String, dynamic>>.from(
          data['data']?['unidades'] ?? data['data']?['lista'] ?? [],
        );

        if (mounted) {
          setState(() {
            _unidadesList = unidades;
            _loadingUnidades = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _loadingUnidades = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingUnidades = false;
        });
      }
    }
  }

  //-----------------------------//
  // Widget seletor de unidade (botão estilo da imagem)
  //-----------------------------//
  Widget _buildUnidadeSelectorButton(BuildContext context, CameraData camera,
      {bool isLarge = false}) {
    final unidadeSelecionada = _unidadesSelecionadas[camera.id];
    final unidadeTexto = unidadeSelecionada != null
        ? (unidadeSelecionada['unidade_mostra']?.toString() ??
            unidadeSelecionada['nome']?.toString() ??
            'Unidade')
        : 'Unidade';

    return GestureDetector(
      onTap: () {
        _abrirModalSelecaoUnidade(context, camera);
      },
      child: Container(
        height: isLarge ? 42 : 36,
        padding: EdgeInsets.symmetric(horizontal: isLarge ? 10 : 8),
        decoration: BoxDecoration(
          color: getSurfaceColor(context),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                unidadeTexto.toUpperCase(),
                style: TextStyle(
                  color: getTextColor(context),
                  fontSize: isLarge ? 13 : 12,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_loadingUnidades)
              SizedBox(
                width: isLarge ? 16 : 14,
                height: isLarge ? 16 : 14,
                child: const CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                Icons.arrow_drop_down,
                color: getTextColor(context),
                size: isLarge ? 20 : 18,
              ),
          ],
        ),
      ),
    );
  }

  //-----------------------------//
  // Abrir modal de seleção de unidade
  //-----------------------------//
  Future<void> _abrirModalSelecaoUnidade(
      BuildContext context, CameraData camera) async {
    // Carregar unidades se necessário
    if (_unidadesList.isEmpty) {
      await _carregarUnidades();
    }

    if (!mounted) return;

    final unidadeSelecionada = _unidadesSelecionadas[camera.id];

    if (!mounted) return;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: this.context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: getSurfaceColor(dialogContext),
          title: Text(
            'Unidade',
            style: TextStyle(color: getTextColor(dialogContext)),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: _loadingUnidades
                ? const Center(child: CircularProgressIndicator())
                : _unidadesList.isEmpty
                    ? const SizedBox.shrink()
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: _unidadesList.map((unidade) {
                            final unidadeTexto =
                                unidade['unidade_mostra']?.toString() ??
                                    unidade['nome']?.toString() ??
                                    'Unidade';
                            final isSelected = unidadeSelecionada != null &&
                                unidadeSelecionada['apto_id'] ==
                                    unidade['apto_id'];

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(dialogContext).pop(unidade);
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue.withValues(alpha: 0.2)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blue
                                        : Colors.white.withValues(alpha: 0.2),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Radio button (círculo)
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.blue
                                              : Colors.white
                                                  .withValues(alpha: 0.5),
                                          width: 2,
                                        ),
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.transparent,
                                      ),
                                      child: isSelected
                                          ? const Icon(
                                              Icons.check,
                                              size: 10,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        unidadeTexto,
                                        style: TextStyle(
                                          color: getTextColor(dialogContext),
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: Text(
                'Cancelar',
                style: TextStyle(color: getTextColor(dialogContext)),
              ),
            ),
          ],
        );
      },
    );

    if (resultado != null && mounted) {
      setState(() {
        _unidadesSelecionadas[camera.id] = resultado;
      });
    }
  }

  //-----------------------------//
  // Handler para interfonar
  //-----------------------------//
  void _handleInterfonar(CameraData camera) {
    final unidadeSelecionada = _unidadesSelecionadas[camera.id];
    if (unidadeSelecionada == null) return;

    _abrirPopupInterfone(context, camera, unidadeSelecionada);
  }

  //-----------------------------//
  // Handler para WhatsApp
  //-----------------------------//
  void _handleWhatsApp(CameraData camera) {
    final unidadeSelecionada = _unidadesSelecionadas[camera.id];
    if (unidadeSelecionada == null) return;

    final telefone = unidadeSelecionada['telefone']?.toString() ??
        unidadeSelecionada['celular']?.toString() ??
        unidadeSelecionada['telefone1']?.toString() ??
        '';

    if (telefone.isEmpty) {
      FeedbackUtils.showError(
        context: context,
        title: 'Telefone Não Encontrado',
        message: 'Telefone não encontrado para esta unidade',
      );
      return;
    }

    // Remover caracteres não numéricos do telefone
    final telefoneLimpo = telefone.replaceAll(RegExp(r'[^\d]'), '');

    // Abrir WhatsApp Web ou app
    final whatsappUrl = 'https://wa.me/$telefoneLimpo';

    if (kIsWeb) {
      html.window.open(whatsappUrl, '_blank');
    } else {
      // Para outras plataformas, pode usar url_launcher
      FeedbackUtils.showSuccess(
        context: context,
        title: 'Abrindo WhatsApp',
        message: 'Abrindo WhatsApp para $telefoneLimpo...',
      );
    }
  }

  //-----------------------------//
  // Abrir popup de chamada de interfone
  //-----------------------------//
  void _abrirPopupInterfone(
    BuildContext context,
    CameraData camera,
    Map<String, dynamic> unidade,
  ) {
    setState(() {
      _showInterfonePopup = true;
      _currentInterfoneCamera = camera;
      _currentInterfoneUnidade = unidade;
      // Posição inicial centralizada
      final screenSize = MediaQuery.of(context).size;
      _interfonePopupPosition = Offset(
        (screenSize.width - 400) / 2,
        (screenSize.height - 500) / 2,
      );
    });
  }

  //-----------------------------//
  // Fechar popup de interfone
  //-----------------------------//
  void _fecharPopupInterfone() {
    setState(() {
      _showInterfonePopup = false;
      _currentInterfoneCamera = null;
      _currentInterfoneUnidade = null;
    });
  }

  //-----------------------------//
  // Handler para "Abrir Portão" (duplo clique com bolinhas)
  //-----------------------------//
  void _handleAbrirPortaoClick(CameraData camera) {
    final currentEstado = _abrirPortaoEstado[camera.id] ?? 0;

    // Cancelar timer anterior se existir
    _abrirPortaoResetTimer[camera.id]?.cancel();

    if (currentEstado == 0) {
      // Primeiro clique - preencher primeira bolinha
      setState(() {
        _abrirPortaoEstado[camera.id] = 1;
      });
    } else if (currentEstado == 1) {
      // Segundo clique - preencher segunda bolinha e mostrar sucesso
      setState(() {
        _abrirPortaoEstado[camera.id] = 2;
      });

      FeedbackUtils.showSuccess(
        context: context,
        title: 'Abertura Realizada',
        message: 'Abertura realizada com sucesso',
      );

      // Resetar após 2 segundos
      _abrirPortaoResetTimer[camera.id] = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _abrirPortaoEstado[camera.id] = 0;
          });
          _abrirPortaoResetTimer[camera.id] = null;
        }
      });

      // Aqui você pode adicionar a chamada da API para abrir portão
    } else {
      // Já está no estado final, resetar imediatamente
      setState(() {
        _abrirPortaoEstado[camera.id] = 0;
      });
    }
  }

  @override
  void dispose() {
    _dateTimeTimer?.cancel();
    // Cancelar todos os timers de reset
    for (var timer in _abrirPortaoResetTimer.values) {
      timer?.cancel();
    }
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        border: Border(
          left: BorderSide(
            color: isDarkMode(context)
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Menu lateral esquerdo
          _buildSidebar(context),
          // Conteúdo principal
          Expanded(
            child: Column(
              children: [
                // Header
                _buildHeader(context),
                // Conteúdo com grid e feed principal
                Expanded(
                  child: _buildMainContent(context),
                ),
                // Barra de status
                _buildStatusBar(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //-----------------------------//
  // Menu lateral esquerdo (mesmo padrão da sidebar principal)
  //-----------------------------//
  Widget _buildSidebar(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sidebarWidth = (screenWidth * 0.07).clamp(52.0, 76.0);
    final double marginH = (screenWidth * 0.018).clamp(8.0, 20.0);
    final double marginV = (screenHeight * 0.02).clamp(12.0, 20.0);
    final double avatarSize = (sidebarWidth * 0.74).clamp(48.0, 64.0);
    final double logoSize = (sidebarWidth * 0.65).clamp(44.0, 56.0);
    final double topSpacing = (screenHeight * 0.022).clamp(12.0, 20.0);
    final borderRadius =
        BorderRadius.circular((sidebarWidth * 0.46).clamp(28.0, 40.0));

    // Cor da sidebar (mesma para modo claro e escuro) - totalmente opaca, sem transparência
    // R: 0.075, G: 0.047, B: 0.227
    // Convertido para 0-255: R: 19, G: 12, B: 58
    // Usando fromRGBO com opacity 1.0 para garantir opacidade total (igual ao dashboard)
    final sidebarColor = const Color.fromRGBO(19, 12, 58, 1.0);

    final menuItems = [
      {'icon': Icons.list_alt, 'label': 'Todos', 'viewMode': 0},
      {'icon': Icons.videocam_rounded, 'label': 'Câmeras'},
      {'icon': Icons.play_circle_outline_rounded, 'label': 'Playback'},
      {'icon': Icons.room_outlined, 'label': 'Ambientes'},
      {'icon': Icons.settings_outlined, 'label': 'Configurações'},
      {'icon': Icons.view_column_rounded, 'label': 'Dividir'},
      {'icon': Icons.grid_view, 'label': '4', 'viewMode': 4},
      {'icon': Icons.grid_on, 'label': '8', 'viewMode': 8},
    ];

    return Container(
      width: sidebarWidth,
      height: double.infinity,
      margin: EdgeInsets.only(left: marginH, top: marginV, bottom: marginV),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            color: sidebarColor, // Cor totalmente opaca, sem transparência
            borderRadius: borderRadius,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
                spreadRadius: 1,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: topSpacing),
                // Avatar superior
                Container(
                  width: avatarSize,
                  height: avatarSize,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(avatarSize / 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _userPhotoBytes != null
                        ? Image.memory(
                            _userPhotoBytes!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) => Container(
                              color: const Color(0xFFE5E7EB),
                              child: const Icon(Icons.person,
                                  color: Color(0xFF6B7280), size: 36),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFE5E7EB),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF6B7280)),
                              ),
                            ),
                          ),
                  ),
                ),
                SizedBox(height: (screenHeight * 0.025).clamp(12.0, 24.0)),
                // Lista de itens (scrollável quando necessário)
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final selected = _selectedMenuIndex == index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: _SidebarCameraItem(
                          icon: item['icon'] as IconData,
                          label: item['label'] as String,
                          selected: selected,
                          onTap: () {
                            if (index == 4) {
                              // Dividir
                              _openSplitWindow();
                            } else if (item['viewMode'] != null) {
                              // Modo 4 ou 8 telas
                              final newViewMode = item['viewMode'] as int;
                              setState(() {
                                _selectedMenuIndex = index;
                                _viewMode = newViewMode;
                                _isExpandedMode = false;
                                // Inicializar as câmeras quando mudar de modo
                                final cameras = getCamerasForSide();
                                if (newViewMode == 4) {
                                  _fourCamerasView = cameras.take(4).toList();
                                } else if (newViewMode == 8) {
                                  _eightCamerasView = cameras.take(8).toList();
                                }
                              });
                            } else {
                              setState(() {
                                _selectedMenuIndex = index;
                                _viewMode =
                                    0; // Modo padrão (sem viewMode específico)
                                _isExpandedMode = false;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
                // Toggle tema
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.wb_sunny
                          : Icons.nightlight_round,
                      color: Colors.white,
                    ),
                    tooltip: 'Alternar tema',
                    onPressed: () {
                      _toggleTheme(context);
                    },
                  ),
                ),
                // Divider entre itens e logo
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 15),
                  child: _PatternDivider(),
                ),
                // Logo inferior
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: SizedBox(
                    width: logoSize,
                    height: logoSize,
                    child: Image.asset(
                      'assets/assets/images/Símbolo-Oficial-para-fundo-Azul-Marinho.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.apartment_rounded,
                        color: Color(0xFF636366),
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  //-----------------------------//
  // Carrega a foto do usuário via API unidadefoto
  //-----------------------------//
  Future<void> _loadUserPhoto() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
      final usuarioId =
          encryptedUsuarioId.isNotEmpty ? decryptText(encryptedUsuarioId) : '';

      if (usuarioId.isEmpty) {
        return;
      }

      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        return;
      }

      final url = Uri.parse(
          '${ApiConfig.socialhUrl}/unidadefoto?id=$usuarioId&tipo=USU');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final data = responseData['data'];
        final fotoBase64 = data['fotobase64'] ?? data['fotoBase64'] ?? '';

        if (fotoBase64 != null &&
            fotoBase64.isNotEmpty &&
            fotoBase64 is String) {
          final fotoProcessada = fotoBase64
              .replaceFirst('data:image/png;base64,', '')
              .replaceFirst('data:image/jpeg;base64,', '')
              .replaceFirst('data:image/jpg;base64,', '');

          try {
            final fotoBytes = base64Decode(fotoProcessada);
            if (mounted) {
              setState(() {
                _userPhotoBytes = fotoBytes;
              });
            }
          } catch (e) {
            // Erro ao decodificar
          }
        }
      }
    } catch (e) {
      // Erro silencioso
    }
  }

  //-----------------------------//
  // Header
  //-----------------------------//
  Widget _buildHeader(BuildContext context) {
    final double logoSize = 48.0;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF10133E),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Logo da empresa (mesma da sidebar)
          SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/assets/images/Símbolo-Oficial-para-fundo-Azul-Marinho.png',
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
                child: const Center(
                  child: Text(
                    'TT',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Texto "ConectCon"
          const Text(
            'ConectCon',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          // Data e hora
          Text(
            _currentDateTime,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          if (!isCamerasView()) ...[
            const SizedBox(width: 20),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: widget.onClose,
              tooltip: 'Fechar',
            ),
          ],
        ],
      ),
    );
  }

  //-----------------------------//
  // Conteúdo principal
  //-----------------------------//
  Widget _buildMainContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
      ),
      child: Stack(
        children: [
          // Conteúdo
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isExpandedMode
                ? _buildExpandedView(context)
                : _viewMode == 4
                    ? _build4CamerasView(context)
                    : _viewMode == 8
                        ? _build8CamerasView(context)
                        : _buildNormalView(context),
          ),
          // Controles no canto inferior direito (onde está marcado em vermelho)
          Positioned(
            bottom: 16,
            right: 16,
            child: _buildControls(context),
          ),
          // Popup de interfone (arrastável, não bloqueia a tela)
          if (_showInterfonePopup &&
              _currentInterfoneCamera != null &&
              _currentInterfoneUnidade != null)
            Positioned(
              left: _interfonePopupPosition.dx,
              top: _interfonePopupPosition.dy,
              child: _InterfonePopup(
                camera: _currentInterfoneCamera!,
                unidadeTexto:
                    _currentInterfoneUnidade!['unidade_mostra']?.toString() ??
                        _currentInterfoneUnidade!['nome']?.toString() ??
                        'Unidade',
                moradorNome:
                    _currentInterfoneUnidade!['nome_responsavel']?.toString() ??
                        _currentInterfoneUnidade!['pessoa_nome']?.toString() ??
                        'Morador',
                onClose: _fecharPopupInterfone,
                onDragUpdate: (delta) {
                  setState(() {
                    _interfonePopupPosition = Offset(
                      (_interfonePopupPosition.dx + delta.dx)
                          .clamp(0.0, MediaQuery.of(context).size.width - 400),
                      (_interfonePopupPosition.dy + delta.dy)
                          .clamp(0.0, MediaQuery.of(context).size.height - 500),
                    );
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  //-----------------------------//
  // Visualização normal (grid de câmeras)
  //-----------------------------//
  Widget _buildNormalView(BuildContext context) {
    final cameras = getCamerasForSide(); // Usar câmeras filtradas por lado
    return Column(
      children: [
        // Grid de câmeras quadradas (menores)
        Expanded(
          child: _buildCameraGrid(context, cameras: cameras),
        ),
        const SizedBox(height: 16),
        // Timeline/Scrubber
        _buildTimeline(context),
      ],
    );
  }

  //-----------------------------//
  // Widget DragTarget para receber câmeras arrastadas (modo 4)
  //-----------------------------//
  Widget _buildDragTargetCamera(
      BuildContext context, int position, CameraData currentCamera) {
    final cameraIndex = mockCameras.indexOf(currentCamera);
    return DragTarget<CameraData>(
      onAcceptWithDetails: (details) {
        setState(() {
          // Trocar (swap): a câmera que estava na posição principal vai para a lista lateral
          _fourCamerasView[position] = details.data;
          // A câmera antiga automaticamente será mostrada na lista lateral
          // pois a lista é filtrada excluindo as que estão em _fourCamerasView
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border:
                isHighlighted ? Border.all(color: Colors.blue, width: 3) : null,
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCameraIndex = cameraIndex;
                _isExpandedMode = true;
              });
            },
            child: _buildCameraCard(
              context,
              currentCamera,
              cameraIndex == _selectedCameraIndex,
              isLarge: true,
            ),
          ),
        );
      },
    );
  }

  //-----------------------------//
  // Widget DragTarget para receber câmeras arrastadas (modo 8)
  //-----------------------------//
  Widget _buildDragTargetCamera8(
      BuildContext context, int position, CameraData currentCamera) {
    final cameraIndex = mockCameras.indexOf(currentCamera);
    return DragTarget<CameraData>(
      onAcceptWithDetails: (details) {
        setState(() {
          // Trocar (swap): a câmera que estava na posição principal vai para a lista lateral
          _eightCamerasView[position] = details.data;
          // A câmera antiga automaticamente será mostrada na lista lateral
          // pois a lista é filtrada excluindo as que estão em _eightCamerasView
        });
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border:
                isHighlighted ? Border.all(color: Colors.blue, width: 3) : null,
          ),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedCameraIndex = cameraIndex;
                _isExpandedMode = true;
              });
            },
            child: _buildCameraCard(
              context,
              currentCamera,
              cameraIndex == _selectedCameraIndex,
              isLarge: true,
            ),
          ),
        );
      },
    );
  }

  //-----------------------------//
  // Visualização 4 câmeras grandes + lista ao lado
  //-----------------------------//
  Widget _build4CamerasView(BuildContext context) {
    final cameras = getCamerasForSide();
    // Garantir que _fourCamerasView tenha exatamente 4 câmeras
    if (_fourCamerasView.length != 4) {
      _fourCamerasView = cameras.take(4).toList();
    }
    // Lista de outras câmeras (excluindo as que já estão nas 4) + filtro de busca
    var otherCameras =
        cameras.where((camera) => !_fourCamerasView.contains(camera)).toList();
    if (_searchText.isNotEmpty) {
      otherCameras = otherCameras
          .where((camera) =>
              camera.nome.toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 câmeras grandes (2x2) - Layout fixo sem scroll
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      // Primeira linha (2 câmeras)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera(
                                  context,
                                  0,
                                  _fourCamerasView[0],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera(
                                  context,
                                  1,
                                  _fourCamerasView[1],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Segunda linha (2 câmeras)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera(
                                  context,
                                  2,
                                  _fourCamerasView[2],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera(
                                  context,
                                  3,
                                  _fourCamerasView[3],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildTimeline(context),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Lista de outras câmeras ao lado - COM SCROLL
        Expanded(
          flex: 1,
          child: Column(
            children: [
              // Campo de busca
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar câmera',
                    hintStyle: TextStyle(
                      color: getSecondaryTextColor(context),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: getSecondaryTextColor(context),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: getSurfaceColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  // SEM NeverScrollableScrollPhysics - permite scroll
                  itemCount: otherCameras.length,
                  itemBuilder: (context, index) {
                    final camera = otherCameras[index];
                    final cameraIndex = mockCameras.indexOf(camera);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: LongPressDraggable<CameraData>(
                          data: camera,
                          dragAnchorStrategy: childDragAnchorStrategy,
                          feedback: Material(
                            color: Colors.transparent,
                            child: Container(
                              width: 200,
                              height: 112.5, // 200 * 9/16
                              decoration: BoxDecoration(
                                color: getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Opacity(
                                opacity: 0.9,
                                child: _buildCameraCard(
                                  context,
                                  camera,
                                  false,
                                  isLarge: false,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.3,
                            child: _buildCameraCard(
                              context,
                              camera,
                              false,
                              isLarge: false,
                            ),
                          ),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedCameraIndex = cameraIndex;
                                _isExpandedMode = true;
                              });
                            },
                            child: Stack(
                              children: [
                                _buildCameraCard(
                                  context,
                                  camera,
                                  false,
                                  isLarge: false,
                                ),
                                // Ícone de drag handle no canto superior direito
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: IgnorePointer(
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.black
                                            .withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.drag_handle,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //-----------------------------//
  // Visualização 8 câmeras (grid 4x2) + lista ao lado
  //-----------------------------//
  Widget _build8CamerasView(BuildContext context) {
    final cameras = getCamerasForSide();
    // Garantir que _eightCamerasView tenha exatamente 8 câmeras
    if (_eightCamerasView.length != 8) {
      _eightCamerasView = cameras.take(8).toList();
    }
    // Lista de outras câmeras (excluindo as que já estão nas 8) + filtro de busca
    var otherCameras =
        cameras.where((camera) => !_eightCamerasView.contains(camera)).toList();
    if (_searchText.isNotEmpty) {
      otherCameras = otherCameras
          .where((camera) =>
              camera.nome.toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 8 câmeras grandes (4x2) - Layout fixo sem scroll
        Expanded(
          flex: 3,
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Column(
                    children: [
                      // Primeira linha (4 câmeras)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  0,
                                  _eightCamerasView[0],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  1,
                                  _eightCamerasView[1],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  2,
                                  _eightCamerasView[2],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  3,
                                  _eightCamerasView[3],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Segunda linha (4 câmeras)
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  4,
                                  _eightCamerasView[4],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  5,
                                  _eightCamerasView[5],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  6,
                                  _eightCamerasView[6],
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: _buildDragTargetCamera8(
                                  context,
                                  7,
                                  _eightCamerasView[7],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _buildTimeline(context),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Lista de outras câmeras ao lado - COM SCROLL
        Expanded(
          flex: 1,
          child: Column(
            children: [
              // Campo de busca
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: CharacterCounterField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Buscar câmera',
                    hintStyle: TextStyle(
                      color: getSecondaryTextColor(context),
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: getSecondaryTextColor(context),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: getSurfaceColor(context),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: getBorderColor(context),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: Colors.blue,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: otherCameras.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                        // SEM NeverScrollableScrollPhysics - permite scroll
                        itemCount: otherCameras.length,
                        itemBuilder: (context, index) {
                          final camera = otherCameras[index];
                          final cameraIndex = mockCameras.indexOf(camera);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: LongPressDraggable<CameraData>(
                                data: camera,
                                dragAnchorStrategy: childDragAnchorStrategy,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 200,
                                    height: 112.5, // 200 * 9/16
                                    decoration: BoxDecoration(
                                      color: getSurfaceColor(context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Opacity(
                                      opacity: 0.9,
                                      child: _buildCameraCard(
                                        context,
                                        camera,
                                        false,
                                        isLarge: false,
                                      ),
                                    ),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _buildCameraCard(
                                    context,
                                    camera,
                                    false,
                                    isLarge: false,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedCameraIndex = cameraIndex;
                                          _isExpandedMode = true;
                                        });
                                      },
                                      child: _buildCameraCard(
                                        context,
                                        camera,
                                        false,
                                        isLarge: false,
                                      ),
                                    ),
                                    // Ícone de drag handle no canto superior direito
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: IgnorePointer(
                                        child: Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.75),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.white
                                                  .withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.drag_handle,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //-----------------------------//
  // Visualização expandida (câmera grande + outras ao lado)
  //-----------------------------//
  Widget _buildExpandedView(BuildContext context) {
    if (_selectedCameraIndex == null) {
      return _buildNormalView(context);
    }

    final cameras = getCamerasForSide(); // Usar câmeras do lado atual
    final selectedCamera = mockCameras[_selectedCameraIndex!];

    // Filtrar apenas as câmeras do lado atual que não são a selecionada
    final otherCamerasIndices = cameras
        .map((camera) => mockCameras.indexOf(camera))
        .where((index) => index >= 0 && index != _selectedCameraIndex)
        .toList();

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Câmera selecionada grande
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    Expanded(
                      child: _buildCameraCard(context, selectedCamera, true,
                          isLarge: true),
                    ),
                    const SizedBox(height: 12),
                    // Timeline embaixo da câmera grande
                    _buildTimeline(context),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Outras câmeras pequenas ao lado (apenas do lado atual)
              Expanded(
                flex: 1,
                child: otherCamerasIndices.isEmpty
                    ? const SizedBox()
                    : ListView.builder(
                        itemCount: otherCamerasIndices.length,
                        itemBuilder: (context, index) {
                          final cameraIndex = otherCamerasIndices[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedCameraIndex = cameraIndex;
                                  });
                                },
                                child: _buildCameraCard(
                                  context,
                                  mockCameras[cameraIndex],
                                  false,
                                  isLarge: false,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  //-----------------------------//
  // Grid de câmeras quadradas (menores, 5 por linha)
  //-----------------------------//
  Widget _buildCameraGrid(BuildContext context, {List<CameraData>? cameras}) {
    final camerasToShow = cameras ?? getCamerasForSide();
    // Mapear índice local para índice global
    final localToGlobalMap = <int, int>{};
    for (int i = 0; i < camerasToShow.length; i++) {
      localToGlobalMap[i] = mockCameras.indexOf(camerasToShow[i]);
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 7 câmeras por linha (quadrados menores)
        childAspectRatio: 1.0, // Quadrado (1:1)
        crossAxisSpacing: 6, // Menor espaçamento
        mainAxisSpacing: 6, // Menor espaçamento
      ),
      itemCount: camerasToShow.length,
      itemBuilder: (context, index) {
        final globalIndex = localToGlobalMap[index] ?? index;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCameraIndex = globalIndex;
              _isExpandedMode = true; // Expandir câmera ao clicar
            });
          },
          child: _buildCameraCard(context, camerasToShow[index],
              globalIndex == _selectedCameraIndex,
              isLarge: false),
        );
      },
    );
  }

  //-----------------------------//
  // Card de câmera individual
  //-----------------------------//
  Widget _buildCameraCard(
    BuildContext context,
    CameraData camera,
    bool isSelected, {
    bool isLarge = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSelected ? Colors.blue : Colors.white.withValues(alpha: 0.2),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          // Placeholder para vídeo
          Center(
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withValues(alpha: 0.8),
              child: Icon(
                Icons.videocam,
                color: Colors.white.withValues(alpha: 0.2),
                size: isLarge ? 64 : 24, // Menor quando não expandida
              ),
            ),
          ),
          // Nome da câmera
          Positioned(
            left: 4,
            bottom:
                isLarge ? 84 : 72, // Espaço para os botões maiores (2 linhas)
            right: 4,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLarge ? 8 : 4,
                vertical: isLarge ? 4 : 2,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                camera.nome,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isLarge ? 14 : 10, // Menor quando não expandida
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          // Botões na parte inferior
          Positioned(
            left: 4,
            bottom: 4,
            right: 4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Linha 1: Botão "Abrir Portão" (duplo clique) com duas bolinhas
                Container(
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _handleAbrirPortaoClick(camera);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: EdgeInsets.symmetric(
                        horizontal: isLarge ? 12 : 10,
                        vertical: isLarge ? 10 : 8,
                      ),
                      minimumSize: Size(0, isLarge ? 42 : 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Duas bolinhas (radio buttons) - preenchidas progressivamente
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: isLarge ? 14 : 12,
                              height: isLarge ? 14 : 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_abrirPortaoEstado[camera.id] ?? 0) >= 1
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            SizedBox(width: isLarge ? 6 : 4),
                            Container(
                              width: isLarge ? 14 : 12,
                              height: isLarge ? 14 : 12,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (_abrirPortaoEstado[camera.id] ?? 0) >= 2
                                    ? Colors.white
                                    : Colors.transparent,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: isLarge ? 10 : 8),
                        Icon(Icons.lock_open,
                            size: isLarge ? 22 : 18, color: Colors.white),
                        SizedBox(width: isLarge ? 8 : 6),
                        Expanded(
                          child: Text(
                            (_abrirPortaoEstado[camera.id] ?? 0) >= 2
                                ? 'Abertura realizada com sucesso'
                                : 'Abrir Portão',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isLarge ? 15 : 13,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Linha 2: Seletor de Unidade e Interfonar
                Row(
                  children: [
                    // Seletor de Unidade (estilo da imagem com radio button)
                    Expanded(
                      flex: 2,
                      child: _buildUnidadeSelectorButton(context, camera,
                          isLarge: isLarge),
                    ),
                    const SizedBox(width: 4),
                    // Botões "Interfonar" e "WhatsApp" (só aparecem quando unidade selecionada)
                    if (_unidadesSelecionadas[camera.id] != null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _handleInterfonar(camera);
                          },
                          icon: Icon(Icons.phone, size: isLarge ? 20 : 18),
                          label: Text(
                            'Interfonar',
                            style: TextStyle(
                              fontSize: isLarge ? 14 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isLarge ? 10 : 8,
                              vertical: isLarge ? 10 : 8,
                            ),
                            minimumSize: Size(0, isLarge ? 42 : 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _handleWhatsApp(camera);
                          },
                          icon: Icon(Icons.phone_android,
                              size: isLarge ? 20 : 18),
                          label: Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: isLarge ? 14 : 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: isLarge ? 10 : 8,
                              vertical: isLarge ? 10 : 8,
                            ),
                            minimumSize: Size(0, isLarge ? 42 : 36),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  //-----------------------------//
  // Timeline/Scrubber
  //-----------------------------//
  Widget _buildTimeline(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            '00',
            style: TextStyle(
              color: getSecondaryTextColor(context),
              fontSize: 12,
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.blue,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                thumbColor: Colors.blue,
              ),
              child: Slider(
                value: _timelineValue,
                onChanged: (value) {
                  setState(() {
                    _timelineValue = value;
                  });
                },
                min: 0,
                max: 30,
              ),
            ),
          ),
          Text(
            '30',
            style: TextStyle(
              color: getSecondaryTextColor(context),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  //-----------------------------//
  // Controles no canto inferior direito (onde está marcado em vermelho)
  //-----------------------------//
  Widget _buildControls(BuildContext context) {
    final controls = [
      {'label': 'Zoom', 'icon': Icons.zoom_in},
      {'label': 'Recarregar', 'icon': Icons.refresh},
      {'label': 'Playback', 'icon': Icons.play_circle_outline},
      {'label': 'Remover', 'icon': Icons.remove_circle_outline},
      {'label': 'Voltar', 'icon': Icons.arrow_back},
    ];

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: controls.map((control) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (control['label'] == 'Voltar') {
                  setState(() {
                    _isExpandedMode = false;
                  });
                }
                // Outras ações dos controles
              },
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      control['icon'] as IconData,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      control['label'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  //-----------------------------//
  // Barra de status
  //-----------------------------//
  Widget _buildStatusBar(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.green,
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'STATUS: TODAS AS CÂMERAS ATIVAS',
            style: TextStyle(
              color: getTextColor(context),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  //-----------------------------//
  // Data e hora atual
  //-----------------------------//
  String _getCurrentDateTime() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}

//-----------------------------//
// Widget para divider com padrão de blocos alternados
//-----------------------------//
class _PatternDivider extends StatelessWidget {
  const _PatternDivider();

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = [
      const Color(0xFF636B88),
      const Color(0xFFB587CD),
      const Color(0xFF7D949F),
      const Color(0xFF10133E),
      const Color(0xFF7C38A5),
    ];

    return SizedBox(
      height: 8,
      width: double.infinity,
      child: Row(
        children: List.generate(5, (index) {
          return Expanded(
            child: Container(
              color: colors[index],
            ),
          );
        }),
      ),
    );
  }
}

//-----------------------------//
// Item da sidebar (mesmo padrão da sidebar principal)
//-----------------------------//
class _SidebarCameraItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarCameraItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarCameraItem> createState() => _SidebarCameraItemState();
}

class _SidebarCameraItemState extends State<_SidebarCameraItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Determinar a cor baseada no estado (selecionado, hover ou normal)
    Color getBackgroundColor() {
      if (widget.selected) {
        return Colors.white.withValues(
            alpha: 0.2); // Fundo branco semi-transparente quando selecionado
      } else if (_isHovered) {
        return Colors.white.withValues(alpha: 0.1); // Hover sutil
      }
      return Colors.transparent; // Transparente quando normal
    }

    Color getIconColor() {
      // Ícones sempre brancos
      return Colors.white;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Tooltip(
        message: widget.label,
        preferBelow: false,
        verticalOffset: 20,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding: const EdgeInsets.symmetric(
              horizontal: 0, // Sempre compacto, apenas ícones
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: getBackgroundColor(),
              borderRadius: BorderRadius.circular(12),
              border: null,
              boxShadow: _isHovered && !widget.selected
                  ? [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: getIconColor(),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

//-----------------------------//
// Popup de chamada de interfone (arrastável)
//-----------------------------//
class _InterfonePopup extends StatefulWidget {
  final CameraData camera;
  final String unidadeTexto;
  final String moradorNome;
  final VoidCallback onClose;
  final ValueChanged<Offset> onDragUpdate;

  const _InterfonePopup({
    required this.camera,
    required this.unidadeTexto,
    required this.moradorNome,
    required this.onClose,
    required this.onDragUpdate,
  });

  @override
  State<_InterfonePopup> createState() => _InterfonePopupState();
}

class _InterfonePopupState extends State<_InterfonePopup>
    with TickerProviderStateMixin {
  String _status = 'Chamando...'; // 'Chamando...', 'Em chamada', 'Encerrada'
  Duration _callDuration = Duration.zero;
  Timer? _callTimer;
  Timer? _ringingTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Simular que após 3 segundos, a chamada é atendida
    _ringingTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _status = 'Em chamada';
        });
        _startCallTimer();
      }
    });
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _callDuration = Duration(seconds: _callDuration.inSeconds + 1);
        });
      } else {
        timer.cancel();
      }
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _encerrarChamada() {
    _callTimer?.cancel();
    _ringingTimer?.cancel();
    _pulseController.dispose();
    widget.onClose();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        widget.onDragUpdate(details.delta);
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: getSurfaceColor(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com câmera
              Row(
                children: [
                  Icon(
                    Icons.videocam,
                    color: getTextColor(context),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.camera.nome,
                      style: TextStyle(
                        color: getSecondaryTextColor(context),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    color: getTextColor(context),
                    onPressed: _encerrarChamada,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Avatar do morador (pulsando quando chamando)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final scale = _status == 'Chamando...'
                      ? 1.0 + (_pulseController.value * 0.1)
                      : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _status == 'Chamando...'
                            ? Colors.orange.withValues(alpha: 0.3)
                            : Colors.green.withValues(alpha: 0.3),
                        border: Border.all(
                          color: _status == 'Chamando...'
                              ? Colors.orange
                              : Colors.green,
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          _status == 'Chamando...'
                              ? Icons.phone
                              : Icons.phone_in_talk,
                          size: 60,
                          color: _status == 'Chamando...'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Nome do morador
              Text(
                widget.moradorNome,
                style: TextStyle(
                  color: getTextColor(context),
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Unidade
              Text(
                widget.unidadeTexto,
                style: TextStyle(
                  color: getSecondaryTextColor(context),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              // Status e duração da chamada
              Text(
                _status == 'Em chamada'
                    ? _formatDuration(_callDuration)
                    : _status,
                style: TextStyle(
                  color:
                      _status == 'Chamando...' ? Colors.orange : Colors.green,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 32),

              // Botões de controle
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Botão encerrar (sempre visível)
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.call_end,
                          color: Colors.white, size: 28),
                      onPressed: _encerrarChamada,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
