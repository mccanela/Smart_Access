import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/permission_service.dart';
import '../../core/config/app_version.dart';

//-----------------------------//
// Instância global para controle da sidebar
//-----------------------------//
late _SidebarDrawerState? _globalSidebarState;

// Função global para resetar seleção da sidebar
void resetarSelecaoSidebar() {
  _globalSidebarState?.resetarSelecao();
}

// Função global para selecionar item na sidebar pelo modalKey
void selecionarItemSidebar(String modalKey) {
  _globalSidebarState?.selecionarPorModalKey(modalKey);
}

class SidebarDrawer extends StatefulWidget {
  final void Function(String modal, BuildContext context)? onOpenModal;
  final VoidCallback? onCloseModal;
  final VoidCallback? onLogout;
  const SidebarDrawer(
      {super.key, this.onOpenModal, this.onCloseModal, this.onLogout});

  @override
  State<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends State<SidebarDrawer> {
  int? _selectedIndex; // null quando nenhum item está selecionado
  Uint8List? _userPhotoBytes; // Bytes da imagem carregada
  String _nomePorteiro = 'Nome do Porteiro'; // Nome do porteiro para tooltip
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;
  bool _showSettingsMenu = false;
  final LayerLink _settingsLayerLink = LayerLink();
  OverlayEntry? _settingsOverlay;
  Timer? _settingsCloseTimer; // Temporizador para fechar ao sair o mouse
  bool _isMouseOverMenu = false; // Controle de estado do mouse no menu
  bool _isMouseOverGear = false; // Controle de estado do mouse na engrenagem
  bool _openSettingsToRight =
      false; // Define se o menu abre para o lado ou para cima
  String _urlEncomendas =
      'https://encomendas-6q3.pages.dev/'; // Nome do porteiro para tooltip
  //-----------------------------//
  // Método público para resetar seleção
  //-----------------------------//
  void resetarSelecao() {
    if (mounted) {
      setState(() {
        _selectedIndex = null;
      });
    }
  }

  //-----------------------------//
  // Método público para selecionar item pelo modalKey
  //-----------------------------//
  void selecionarPorModalKey(String modalKey) {
    if (mounted) {
      final index = _items.indexWhere((item) => item.modalKey == modalKey);
      if (index != -1) {
        setState(() {
          _selectedIndex = index;
        });
      }
    }
  }

  List<_SidebarItemData> get _items {
    final allItems = [
      // _SidebarItemData('Ocorrências', Icons.report_problem_rounded, 'ocorrencias'),
      _SidebarItemData('Chaves', Icons.key_rounded, 'chaves'),
      _SidebarItemData('Ramais', Icons.phone_in_talk_rounded, 'ramais'),

      _SidebarItemData('Condominio', Icons.business_rounded, 'condominio'),
      _SidebarItemData(
          'Alertas', Icons.notifications_active_rounded, 'alertas'),
      _SidebarItemData('Turnos', Icons.schedule_rounded, 'turnos'),
      _SidebarItemData('Encomenda', Icons.inventory_2_rounded, null,
          url: _urlEncomendas),
      _SidebarItemData('Novia X', Icons.smart_toy_outlined, 'noviax'),
    ];

    return allItems.where((item) {
      // Itens com URL externa sempre são exibidos (links para módulos externos)
      if (item.url != null) return true;

      // Tenta mapear pelo Label ou pelo modalKey
      int? id = PermissionService.getIdForFeature(item.label);
      if (id == null && item.modalKey != null) {
        id = PermissionService.getIdForFeature(item.modalKey!);
      }

      if (id == null) {
        return true; // Se não tem ID mapeado, é fixo (sempre exibe)
      }
      return PermissionService().hasPermission(id);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _globalSidebarState = this; // Registrar instância global
    _loadUserPhoto();
    _loadNomePorteiro();
    _loadUrlEncomenda();

    // Adicionar listener para detectar quando há scroll disponível
    _scrollController.addListener(_updateScrollIndicator);

    // Verificar após o primeiro frame se há scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollIndicator();
    });
  }

  void _updateScrollIndicator() {
    if (!mounted) return;

    final hasScroll = _scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0;

    final isNotAtBottom = _scrollController.hasClients &&
        _scrollController.position.pixels <
            _scrollController.position.maxScrollExtent - 10;

    final shouldShow = hasScroll && isNotAtBottom;

    if (_showScrollIndicator != shouldShow) {
      setState(() {
        _showScrollIndicator = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollIndicator);
    _scrollController.dispose();
    if (_globalSidebarState == this) {
      _globalSidebarState = null; // Limpar referência global
    }
    super.dispose();
  }

  //-----------------------------//
  // Carrega o nome do porteiro
  //-----------------------------//
  Future<void> _loadNomePorteiro() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedUsuarioNome = prefs.getString('usuario_nome') ?? '';
      if (encryptedUsuarioNome.isNotEmpty) {
        final nome = decryptText(encryptedUsuarioNome);
        if (mounted) {
          setState(() {
            _nomePorteiro = nome.isNotEmpty ? nome : 'Nome do Porteiro';
          });
        }
      }
    } catch (e) {
      // Erro ao carregar nome, manter padrão
    }
  }

  //-----------------------------//
  // Obtém o token criptografado do CNS (encriptcns) e concatena na URL de Encomenda
  //-----------------------------//
  Future<void> _loadUrlEncomenda() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
      final usuarioId =
          encryptedUsuarioId.isNotEmpty ? decryptText(encryptedUsuarioId) : '';

      if (usuarioId.isEmpty) {
        print('UsuarioId não encontrado no SharedPreferences');
        return;
      }

      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        print('Token de sessão não encontrado');
        return;
      }
      print('Carregando token de encomenda para tokenSessao: $tokenSessao');
      final url = Uri.parse(ApiConfig.getEndpoint('condominio', 'encriptcns'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({'key': '1000', 'usuario_id': usuarioId}),
      );

      if (response.statusCode == 200) {
        final dataCripto = jsonDecode(response.body);
        final usercripto = dataCripto['data']['usucrypto'];
        final sigla = dataCripto['data']['sigla'];
        print('Resposta encriptcns: $usercripto');

        if (usercripto != null && usercripto.toString().isNotEmpty && mounted) {
          setState(() {
            _urlEncomendas += sigla + '/?card=' + usercripto;
          });
        }
      }
    } catch (e) {
      // Silenciosamente ignora erro ao carregar token de encomenda
      print('Erro ao carregar token de encomenda na sidebar: $e');
    }
  }

  void _onItemTap(int index) {
    final item = _items[index];

    // Se o item tem URL, abrir em nova aba sem alterar seleção
    if (item.url != null) {
      html.window.open(item.url!, '_blank');
      return;
    }

    // Se clicar no mesmo item selecionado, deseleciona e fecha modal
    if (_selectedIndex == index) {
      setState(() => _selectedIndex = null);
      // Fechar modal usando callback
      if (widget.onCloseModal != null) {
        widget.onCloseModal!();
      }
      return;
    }

    setState(() => _selectedIndex = index);
    final modal = item.modalKey;
    if (modal != null && widget.onOpenModal != null) {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      widget.onOpenModal!(modal, rootContext);
    }
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
        print('UsuarioId não encontrado no SharedPreferences');
        return;
      }

      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        print('Token de sessão não encontrado');
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

      if (mounted) {
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          final data = responseData['data'];
          final fotoBase64 = data['fotobase64'] ?? data['fotoBase64'] ?? '';

          if (fotoBase64 != null &&
              fotoBase64.isNotEmpty &&
              fotoBase64 is String) {
            // Processar foto removendo prefixo se existir
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
              print('Erro ao decodificar foto base64: $e');
            }
          }
        }
      }
    } catch (e) {
      // Silenciosamente ignora erro ao carregar foto
      print('Erro ao carregar foto do usuário na sidebar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    //-----------------------------//
    // ESPECIFICAÇÕES DA IMAGEM
    //-----------------------------//
    // Cores: #451D6B (roxo escuro), #9B3CBC (roxo médio), #000000 (preto)
    // Dimensões: 50x50 (avatar e logo), 30x30 (ícones), 70x50 (item selecionado)
    // Espaçamentos: 10, 20
    //-----------------------------//

    final double screenWidth = MediaQuery.of(context).size.width;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double sidebarWidth = 70.0; // Largura fixa conforme especificação
    final double marginH = (screenWidth * 0.018).clamp(8.0, 20.0);
    final double marginV = (screenHeight * 0.02).clamp(12.0, 20.0);
    final double avatarSize = 50.0; // 50x50 conforme especificação
    final double logoSize = 50.0; // 50x50 conforme especificação
    final double iconSize = 30.0; // 30x30 conforme especificação
    final double topSpacing = 10.0; // Espaçamento 10 conforme especificação

    final expanded = false; // Sempre compacto, apenas ícones
    final borderRadius =
        BorderRadius.circular(12.0); // Mesmo ângulo dos campos de input

    // Cores conforme especificação
    final Color topSectionColor = const Color(0xFF451D6B); // Roxo escuro
    final Color middleSectionColor = const Color(0xFF10133E); // Azul escuro
    final Color selectedItemColor = const Color(0xFF9B3CBC); // Roxo médio
    final Color bottomSectionColor = const Color(0xFF000000); // Preto

    return Container(
      width: sidebarWidth,
      height: double.infinity,
      margin: EdgeInsets.only(left: marginH, top: marginV, bottom: marginV),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
          decoration: BoxDecoration(
            color: middleSectionColor,
            borderRadius: borderRadius,
          ),
          child: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                //-----------------------------//
                // SEÇÃO SUPERIOR - FUNDO ROXO COM AVATAR
                //-----------------------------//
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: topSpacing, bottom: topSpacing),
                  decoration: BoxDecoration(
                    color: topSectionColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(borderRadius.topLeft.x),
                      topRight: Radius.circular(borderRadius.topRight.x),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: SideTooltip(
                          message: _nomePorteiro,
                          child: Container(
                            width: avatarSize,
                            height: avatarSize,
                            decoration: BoxDecoration(
                              borderRadius:
                                  BorderRadius.circular(avatarSize / 2),
                            ),
                            child: ClipOval(
                              child: _userPhotoBytes != null
                                  ? Image.memory(
                                      _userPhotoBytes!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) =>
                                          Container(
                                        color: const Color(0xFFE5E7EB),
                                        child: const Icon(Icons.person,
                                            color: Color(0xFF6B7280), size: 30),
                                      ),
                                    )
                                  : Container(
                                      color: const Color(0xFFE5E7EB),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Color(0xFF6B7280)),
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Indicador de status SignalR
                    ],
                  ),
                ),
                //-----------------------------//
                // SEÇÃO DO MEIO - MENU COM ÍCONES
                //-----------------------------//
                Expanded(
                  child: Container(
                    color: middleSectionColor,
                    child: Column(
                      children: [
                        Expanded(
                          child: Stack(
                            children: [
                              ListView.builder(
                                controller: _scrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _items.length,
                                itemBuilder: (context, i) {
                                  final item = _items[i];
                                  final selected = _selectedIndex == i;
                                  return Padding(
                                    padding: EdgeInsets.only(
                                      top: i == 0 ? 6.0 : 0.0,
                                      bottom: 0.0,
                                    ),
                                    child: Container(
                                      height:
                                          50.0, // Altura fixa de 50 conforme especificação
                                      margin: EdgeInsets.only(
                                          bottom:
                                              6.0), // Espaçamento de 6 entre itens
                                      width: double
                                          .infinity, // Garantir largura total
                                      child: _SidebarModernItem(
                                        icon: item.icon,
                                        label: item.label,
                                        expanded: expanded,
                                        selected: selected,
                                        iconSize: iconSize,
                                        selectedColor: selectedItemColor,
                                        onTap: () => _onItemTap(i),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              // Indicador de scroll - gradiente sutil no final
                              if (_showScrollIndicator)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: IgnorePointer(
                                    child: Container(
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            middleSectionColor.withValues(
                                                alpha: 0.0),
                                            middleSectionColor.withValues(
                                                alpha: 0.8),
                                            middleSectionColor,
                                          ],
                                        ),
                                      ),
                                      child: Center(
                                        child: TweenAnimationBuilder<double>(
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          duration: const Duration(
                                              milliseconds: 1500),
                                          curve: Curves.easeInOut,
                                          builder: (context, value, child) {
                                            return Transform.translate(
                                              offset:
                                                  Offset(0, 3 * (1 - value)),
                                              child: Opacity(
                                                opacity: value * 0.9,
                                                child: Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            );
                                          },
                                          onEnd: () {
                                            // Reiniciar animação
                                            if (mounted) {
                                              setState(() {});
                                            }
                                          },
                                        ),
                                      ),
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
                // Botão de Configurações - Agora fora do scroll
                CompositedTransformTarget(
                  link: _settingsLayerLink,
                  child: MouseRegion(
                    onEnter: (_) {
                      _isMouseOverGear = true;
                      _openSettingsMenu();
                    },
                    onExit: (_) {
                      _isMouseOverGear = false;
                      _startSettingsCloseTimer();
                    },
                    child: Container(
                      height: 50.0,
                      margin: const EdgeInsets.symmetric(vertical: 0.0),
                      color: middleSectionColor,
                      child: _SidebarModernItem(
                        icon: Icons.settings_rounded,
                        label: 'Configurações',
                        expanded: expanded,
                        selected: _showSettingsMenu,
                        iconSize: iconSize,
                        selectedColor: selectedItemColor,
                        onTap:
                            () {}, // Tap não é mais necessário, mas seguro manter
                        showTooltip: false,
                      ),
                    ),
                  ),
                ),
                // Versão do app
                Container(
                  color: middleSectionColor,
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Center(
                    child: Text(
                      'v$appVersion',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
                //-----------------------------//
                // SEÇÃO INFERIOR - LOGO COM FUNDO PRETO
                //-----------------------------//
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10.0),
                  decoration: BoxDecoration(
                    color: bottomSectionColor,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(borderRadius.bottomLeft.x),
                      bottomRight: Radius.circular(borderRadius.bottomRight.x),
                    ),
                  ),
                  child: Center(
                    child: SideTooltip(
                      message: 'ConectCon® - Blindagem Condominial',
                      child: SizedBox(
                        width: logoSize,
                        height: logoSize,
                        child: Image.asset(
                          'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.apartment_rounded,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
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

  void _openSettingsMenu() {
    if (_showSettingsMenu) {
      _settingsCloseTimer?.cancel();
      return;
    }

    // Calcular se abre para a direita ou para cima
    final double screenHeight = MediaQuery.of(context).size.height;
    final double marginV = (screenHeight * 0.02).clamp(12.0, 20.0);
    final double sidebarHeight = screenHeight - (2 * marginV);

    // Altura das seções (estimativas baseadas no build)
    final double avatarSectionHeight =
        78.0; // Estimado do build (avatarSize + paddings)
    final double logoSectionHeight =
        70.0; // Estimado do build (logoSize + paddings)
    final double gearButtonHeight = 50.0;

    final double middleAreaHeight = sidebarHeight -
        avatarSectionHeight -
        logoSectionHeight -
        gearButtonHeight;
    final double listContentHeight =
        (_items.length * 56.0) + 6.0; // (height + margin) + padding inicial

    final double gapBelowList = middleAreaHeight - listContentHeight;

    // Menu de settings tem (3 fixed + 1 opcional logout) itens
    int menuItemsCount = 3 + (widget.onLogout != null ? 1 : 0);
    final double menuHeight =
        menuItemsCount * 58.0; // (height 50 + margins 4+4)

    // Se o gap for menor que a altura do menu, abre para o lado para não sobrepor ícones fixos
    _openSettingsToRight = gapBelowList < menuHeight;

    _settingsOverlay = _createSettingsOverlay();
    Overlay.of(context).insert(_settingsOverlay!);
    setState(() => _showSettingsMenu = true);
  }

  void _startSettingsCloseTimer() {
    _settingsCloseTimer?.cancel();
    _settingsCloseTimer = Timer(const Duration(milliseconds: 200), () {
      if (!_isMouseOverMenu && !_isMouseOverGear) {
        _closeSettingsMenu();
      }
    });
  }

  void _closeSettingsMenu() {
    _settingsOverlay?.remove();
    _settingsOverlay = null;
    _settingsCloseTimer?.cancel();
    if (mounted) {
      setState(() => _showSettingsMenu = false);
    }
  }

  OverlayEntry _createSettingsOverlay() {
    // Cores conforme sidebar
    final Color menuBgColor = const Color(0xFF10133E);
    final Color selectedItemColor = const Color(0xFF9B3CBC);
    final double iconSize = 30.0;

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned(
            width: 70, // Mesma largura da sidebar
            child: CompositedTransformFollower(
              link: _settingsLayerLink,
              showWhenUnlinked: false,
              targetAnchor: _openSettingsToRight
                  ? Alignment.bottomRight
                  : Alignment.topCenter,
              followerAnchor: _openSettingsToRight
                  ? Alignment.bottomLeft
                  : Alignment.bottomCenter,
              offset: _openSettingsToRight ? const Offset(12, 0) : Offset.zero,
              child: MouseRegion(
                onEnter: (_) {
                  _isMouseOverMenu = true;
                  _settingsCloseTimer?.cancel();
                },
                onExit: (_) {
                  _isMouseOverMenu = false;
                  _startSettingsCloseTimer();
                },
                child: Material(
                  elevation: 12,
                  color: menuBgColor,
                  borderRadius: _openSettingsToRight
                      ? BorderRadius.circular(12)
                      : const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Novidades
                      _buildSettingsItem(
                        icon: Icons.new_releases_rounded,
                        label: 'Novidades',
                        onTap: () {
                          _closeSettingsMenu();
                          if (widget.onOpenModal != null) {
                            widget.onOpenModal!('novidades', this.context);
                          }
                        },
                        iconSize: iconSize,
                        selectedColor: selectedItemColor,
                      ),
                      // Suporte
                      _buildSettingsItem(
                        icon: Icons.headset_mic_rounded,
                        label: 'Suporte',
                        onTap: () {
                          html.window
                              .open('https://wa.me/5511934637096', '_blank');
                        },
                        iconSize: iconSize,
                        selectedColor: selectedItemColor,
                      ),
                      // Tema
                      _buildSettingsItem(
                        icon:
                            Theme.of(this.context).brightness == Brightness.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                        label: 'Tema',
                        onTap: () {
                          ThemeToggleProvider.of(this.context)?.onToggle();
                        },
                        iconSize: iconSize,
                        selectedColor: selectedItemColor,
                      ),

                      // Atualizar
                      _buildSettingsItem(
                        icon: Icons.refresh_rounded,
                        label: 'Atualizar',
                        onTap: () {
                          html.window.location.reload();
                        },
                        iconSize: iconSize,
                        selectedColor: selectedItemColor,
                      ),
                      // Sair
                      if (widget.onLogout != null)
                        _buildSettingsItem(
                          icon: Icons.logout_rounded,
                          label: 'Sair',
                          onTap: () {
                            _mostrarDialogSair();
                          },
                          iconSize: iconSize,
                          selectedColor: selectedItemColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double iconSize,
    required Color selectedColor,
  }) {
    return Container(
      height: 50.0,
      width: 70.0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: _SidebarModernItem(
        icon: icon,
        label: label,
        expanded: false,
        selected: false,
        iconSize: iconSize,
        selectedColor: selectedColor,
        onTap: onTap,
      ),
    );
  }

  void _mostrarDialogSair() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF040F39),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                child: Image.asset(
                  'assets/images/0dc836ea-409a-4737-83c0-89532a174dcc-md-removebg-preview.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.logout_rounded,
                      size: 50,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Sair',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Text('Deseja realmente sair da sessão?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15)),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancelar',
                          style: TextStyle(color: Colors.white70)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        widget.onLogout?.call();
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444)),
                      child: const Text('Sair',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarItemData {
  final String label;
  final IconData icon;
  final String? modalKey;
  final String? url;
  const _SidebarItemData(this.label, this.icon, this.modalKey, {this.url});
}

class _SidebarModernItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool expanded;
  final bool selected;
  final double iconSize;
  final Color selectedColor;
  final VoidCallback onTap;
  final bool showTooltip;
  const _SidebarModernItem({
    required this.icon,
    required this.label,
    required this.expanded,
    required this.selected,
    this.iconSize = 30.0,
    this.selectedColor = const Color(0xFF9B3CBC),
    required this.onTap,
    this.showTooltip = true,
  });

  @override
  State<_SidebarModernItem> createState() => _SidebarModernItemState();
}

class _SidebarModernItemState extends State<_SidebarModernItem> {
  bool _isHovered = false;
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determinar a cor baseada no estado (selecionado, hover ou normal)
    Color getBackgroundColor() {
      if (widget.selected) {
        return widget.selectedColor; // Fundo roxo médio quando selecionado
      } else if (_isHovered) {
        return Colors.white.withValues(alpha: 0.1); // Hover sutil
      }
      return Colors.transparent; // Transparente quando normal
    }

    Color getIconColor() {
      // Ícones sempre brancos
      return Colors.white;
    }

    Color getTextColor() {
      // Texto sempre branco
      return Colors.white;
    }

    final content = MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: () {
            widget.onTap();
          },
          splashColor: Colors.transparent, // Remover efeito de splash
          highlightColor: Colors.transparent, // Remover efeito de highlight
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOut,
            margin: widget.selected
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding: EdgeInsets.symmetric(
              horizontal: widget.expanded ? 16 : 0,
              vertical: 10,
            ),
            width: double.infinity, // Sempre ocupar toda largura disponível
            decoration: BoxDecoration(
              color: getBackgroundColor(),
              borderRadius: BorderRadius.zero,
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
              mainAxisAlignment: widget.expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  widget.icon,
                  color: getIconColor(),
                  size: widget.iconSize,
                ),
                if (widget.expanded) ...[
                  const SizedBox(width: 14),
                  Flexible(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            widget.selected ? FontWeight.w500 : FontWeight.w300,
                        color: getTextColor(),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.showTooltip) {
      return SideTooltip(
        message: widget.label,
        child: content,
      );
    }
    return content;
  }
}

// Widget para divider com padrão de blocos alternados
class _PatternDivider extends StatelessWidget {
  const _PatternDivider();

  @override
  Widget build(BuildContext context) {
    // Lista de cores para oscilar
    final List<Color> colors = [
      const Color(0xFF636B88), // #10133e
      const Color(0xFFB587CD), // #b587cd
      const Color(0xFF7D949F), // #7d949f
      const Color(0xFF10133E), // #636b88
      const Color(0xFF7C38A5), // #7c38a5
    ];

    return SizedBox(
      height: 8,
      width: double.infinity,
      child: Row(
        children: List.generate(5, (index) {
          // Usar apenas 5 blocos (uma cor cada) para esticar horizontalmente
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
// Widget Customizado para Tooltip na Lateral
//-----------------------------//
class SideTooltip extends StatefulWidget {
  final String message;
  final Widget child;
  const SideTooltip({required this.message, required this.child, super.key});

  @override
  State<SideTooltip> createState() => _SideTooltipState();
}

class _SideTooltipState extends State<SideTooltip> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  void _showOverlay() {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          targetAnchor: Alignment.centerRight,
          followerAnchor: Alignment.centerLeft,
          offset: const Offset(12, 0), // Distância de 12px da sidebar
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(4),
              elevation: 4,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: MouseRegion(
        onEnter: (_) => _showOverlay(),
        onExit: (_) => _hideOverlay(),
        child: widget.child,
      ),
    );
  }
}

// Widget para prover o método de alternância de tema
class ThemeToggleProvider extends InheritedWidget {
  final VoidCallback onToggle;
  const ThemeToggleProvider(
      {required this.onToggle, required super.child, super.key});

  @override
  bool updateShouldNotify(ThemeToggleProvider oldWidget) => false;

  static ThemeToggleProvider? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ThemeToggleProvider>();
}
