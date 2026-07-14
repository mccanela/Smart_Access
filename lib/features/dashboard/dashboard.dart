import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/config/api_config.dart';
import '../../core/services/feedback_utils.dart';

import '../../features/unidades/unidade_detalhe_screen.dart'
    hide
        isDarkMode,
        getBackgroundColor,
        getSurfaceColor,
        getCardColor,
        getTextColor,
        getSecondaryTextColor,
        getBorderColor,
        getShadowColor;
import '../../shared/widgets/facial_capture_modal.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/services/image_utils.dart';
import '../../core/services/permission_service.dart';
import '../../core/theme/icon_colors.dart';

import '../../core/services/signalr_service.dart';
import '../../core/utils/file_download/file_download.dart';
import 'services/delivery_pdf_service.dart';
import '../../shared/widgets/character_counter_field.dart';
import 'dashboard_isolate.dart';
import 'dashboard_camera_panel.dart';
import '../../shared/widgets/inline_period_picker.dart';
import '../../shared/widgets/inline_single_date_picker.dart';
import '../../core/utils/ui_standards.dart';
import 'widgets/vertical_separator.dart';
import 'widgets/floating_navigation_button.dart';
import 'widgets/equipamentos_fab.dart';
import 'widgets/segmented_tab_bar.dart';
import 'widgets/standard_autocomplete.dart';
import 'widgets/mini_segmented.dart';
import 'widgets/transparent_icon_group.dart';
import 'widgets/dashboard_small_widgets.dart';
import '../modals/noviax_modal.dart';
import 'services/encomenda_fetch_service.dart';
import 'services/reference_data_service.dart';

part 'widgets/range_calendar_dialog.dart';
part 'widgets/painel_selecao_convidados.dart';
part 'widgets/locacao_temporaria_panel.dart';
part 'widgets/tipo_documento_selector.dart';
part 'widgets/entrada_convidado_panel.dart';
part 'widgets/editar_convidado_panel.dart';
part 'widgets/camera_modal_widget.dart';
part 'widgets/modal_selecao_espacos.dart';
part 'widgets/convidados_modal.dart';
part 'widgets/usuario_detalhes_panel.dart';
part 'widgets/resultados_busca_entrada.dart';
part 'widgets/detalhes_entrega_panel.dart';

// Funçao auxiliar para obter condomínio ID do SignalR (preferencial) ou ApiConfig
Future<int> getCondominioIdAtual() async {
  // Prioridade 1: Pegar do SignalR se estiver disponível
  final signalRCondominioId = SignalRService().condominioId;
  print('signalRCondominioId: $signalRCondominioId');
  if (signalRCondominioId != null && signalRCondominioId > 0) {
    return signalRCondominioId;
  }

  // Prioridade 2: Fallback para ApiConfig
  final condominioIdStr = await ApiConfig.getCondominioId();
  return int.tryParse(condominioIdStr) ?? 0;
}

// isDarkMode, cores e inputDecorationPadrao importados de ui_standards.dart

//-----------------------------//
// Abrir câmera lateral
//-----------------------------//
void abrirCameraLateral({
  bool isFrontal = false,
  String? deviceId,
  CameraFrameType frameType = CameraFrameType.none,
  required Function(String) onPhotoTaken,
}) {
  try {
    // Criar o widget da câmera
    final cameraWidget = CameraSidePanelWidget(
      isFrontal: isFrontal,
      deviceId: deviceId,
      frameType: frameType,
      onPhotoTaken: onPhotoTaken,
    );

    // Abrir painel lateral diretamente
    // A função será sobrescrita no build do Dashboard, então sempre funcionará
    // Se ainda não foi inicializada, a função padrão vai apenas logar um aviso
    abrirPainelLateralGlobal(cameraWidget);
  } catch (e) {
    // Erro silencioso
  }
}

// Funçao global para registrar entrada/saída
Future<bool> registrarEntradaSaidaGlobal(
    String reservaId, String reservaconvidadoId, bool isEntrada) async {
  final prefs = await SharedPreferences.getInstance();
  final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
  final tokenSessao =
      (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

  if (tokenSessao.isEmpty) return false;

  final condominioId = await getCondominioIdAtual();
  final usuarioId = await ApiConfig.getUsuarioId();

  final url = Uri.parse(
    ApiConfig.getEndpoint('convidados', 'mover'),
  );

  // Gerar timestamp atual
  final now = DateTime.now();

  final formattedDate =
      '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

  try {
    final payload = {
      'condominio_id': condominioId,
      'origem': isEntrada ? 'E' : 'S',
      'reserva_id': reservaId,
      'reservaconvidado_id': reservaconvidadoId,
      'tipo': 'A',
      'usuario_registro': usuarioId,
    };

    // Adicionar campos específicos para entrada ou saída
    if (isEntrada) {
      payload['dt_entrada'] = formattedDate;
    } else {
      payload['dt_saida'] = formattedDate;
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenSessao',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 200) {
        // Retorna sucesso para que o modal possa atualizar
        return true;
      } else {
        return false;
      }
    } else {
      return false;
    }
  } catch (e) {
    return false;
  }
}

// Funçao global para fechar painel lateral
// Funçao global para atualizar convidado após entrada (buscar novamente da API)
Future<void> Function(String)? removerConvidadoGlobal;

// Funçao global para restaurar painel anterior (usado quando câmera fecha)
void Function()? restaurarPainelAnteriorGlobal;

void Function() fecharPainelLateralGlobal = () {
  // Funçao padrão - será sobrescrita quando o painel for criado
};

// Funçao global para abrir painel lateral
//-----------------------------//
// Funçao global para abrir painel lateral
//-----------------------------//
void Function(Widget) abrirPainelLateralGlobal = (Widget painel) {
  // Funçao padrão vazia - será sobrescrita quando o Dashboard for construído
};

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _panelEntradaSaidasKey = GlobalKey();
  String _feedbackMessageEntrada = '';
  @override
  void setState(VoidCallback fn) {
    if (!mounted) return;
    super.setState(fn);
  }

  Widget? _buildContador(
    BuildContext context, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) {
    if (maxLength == null) return null;

    // Mesmo comportamento visual do CharacterCounterField:
    // - Só mostra quando o campo está focado
    if (!isFocused) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$currentLength/$maxLength',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: currentLength > maxLength * 0.9
              ? Colors.orange
              : (isDark ? Colors.grey[400] : const Color(0xFF6B7280)),
        ),
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Funçao auxiliar para anonimizar dados (LGPD)
  String _maskName(String name) {
    if (name.isEmpty) return name;
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    final firstName = parts[0];
    final secondPart = parts[1];
    if (secondPart.isEmpty) return firstName;
    return '$firstName ${secondPart[0]}.';
  }

  String _maskDocument(String doc) {
    if (doc.isEmpty) return doc;
    final cleanDoc = doc.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDoc.length < 3) return '***';
    return '${cleanDoc.substring(0, 3)}${'*' * (min(cleanDoc.length, 11) - 3)}';
  }

  // Controle de exibição de PII (LGPD)
  final Set<String> _revealedPii = {};

  // Variáveis para controle de erros visuais
  bool _mostrarErrosVisuais = false;

  // Permissá£o de acesso ao cadastramento de dispositivos
  // true = pode editar/cadastrar (S), false = somente leitura (N), null = ainda não verificado
  bool? _permissaoAcessoPessoas;
  final int _tabPassagensSaidas = 0; // 0: Passagens, 1: Saídas
  // int _tabEncom = 0; // 0: Encomendas, 1: Entregar
  int? _tabUnidades; // 0: Unidade, 1: Veículos, 2: Vagas
  int _tipoPessoa = 1; // 0: P. Serviá§o, 1: Visitante
  int _tabAvulsoAgendamentosSaidas = 0; // 0: Avulso, 1: Agendamentos, 2: Saídas

  // Controle da navegaçao em tablets
  int _currentPage =
      0; // 0: Página 1 (Entrada + Agendamentos + Passagens + Saídas), 1: Página 2 (Unidades + Encomendas/Entregar)

  String _feedbackMessageRegistroEncomenda = '';

  //-----------------------------
  // VARIáVEIS DE ESTADO PARA APIS
  //-----------------------------

  // Overlay para painel lateral
  OverlayEntry? _painelLateralOverlay;
  OverlayEntry? _painelAnteriorOverlay;
  void Function()? _fecharPainelAnteriorFunction;

  // Variáveis para o painel lateral gerenciado na Stack
  Widget? _sidePanelCurrentWidget;
  double _currentSidePanelWidth = 0;
  bool _isSidePanelOpen = false;

  // Unidades e autorizante
  List<Map<String, dynamic>> _unidadesList = [];
  Map<String, dynamic>? _selectedUnidade;

  // Veículos - marcas e cores
  List<Map<String, dynamic>> _marcasList = [];
  List<Map<String, dynamic>> _coresList = [];
  bool _loadingMarcas = false;
  bool _loadingCores = false;
  Map<String, dynamic>? _selectedMarca;
  Map<String, dynamic>? _selectedCor;

  // Vagas avulso e Crachás (para o formulário de Entrada)
  List<Map<String, dynamic>> _vagasAvulsoList = [];
  List<Map<String, dynamic>> _crachasList = [];
  Map<String, dynamic>? _selectedVagaAvulso;
  Map<String, dynamic>? _selectedCracha;
  bool _loadingVagasAvulso = false;
  bool _loadingCrachas = false;

  // Foto capturada em base64
  String? _fotoBase64;

  // Variáveis para fotos
  Uint8List? _fotoEntrada;
  Uint8List? _fotoDocumento;
  String? _fotoDocumentoBase64;

  // Fotos do formulário de entrada
  String? _fotoRostoEntrada; // Foto do rosto em base64
  String? _fotoDocumentoEntrada; // Foto do documento em base64

  // Filtros para unidades
  final TextEditingController _filtroNomeUnidadeController =
      TextEditingController();
  final TextEditingController _filtroUnidadeController =
      TextEditingController();

  // Filtros para vagas
  final TextEditingController _filtroVagaController = TextEditingController();
  final TextEditingController _filtroOcupanteVagaController =
      TextEditingController();
  final TextEditingController _filtroUnidadeVagaController =
      TextEditingController();

  // Resultados da busca de convidados (para exibiçao inline)
  List<Map<String, dynamic>> _convidadosResultados = [];
  // Set para armazenar IDs (uniqueKey) de cards que tentaram entrar sem foto
  final Set<String> _cardsComErroFoto = {};
  // Mensagens de feedback por item (ID -> Mensagem)
  final Map<String, String> _itemFeedbackMessages = {};

  // Estado do cancelamento inline de encomenda
  String? _cancellingItemId;
  final Map<String, TextEditingController> _cancelMsgCtrls = {};
  final Set<String> _cancelLoading = {};

  // Controllers para campos de entrada
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _modeloController = TextEditingController();
  final TextEditingController _obsController = TextEditingController();
  // Filtro de veículos (busca por placa)
  final TextEditingController _filtroPlacaController = TextEditingController();
  final TextEditingController _autorizanteController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _filtroSaidasController = TextEditingController();
  final TextEditingController _filtroDataController = TextEditingController();
  final TextEditingController _dataFimController = TextEditingController();
  DateTime? _dataFimSelecionada;
  TimeOfDay? _horaFimSelecionada;

  // Focus nodes para validaçao
  final FocusNode _documentoFocusNode = FocusNode();
  final FocusNode _nomeFocusNode = FocusNode();
  final FocusNode _autorizanteFocusNode = FocusNode();
  final FocusNode _empresaFocusNode = FocusNode();
  final FocusNode _placaFocusNode = FocusNode();
  final FocusNode _modeloFocusNode = FocusNode();
  final FocusNode _obsFocusNode = FocusNode();

  bool _enableSignalR = true;

  // Timer para debounce das chamadas de API
  Timer? _documentoDebounceTimer;
  Timer? _cadastroDebounceTimer;
  Timer? _passagensDebounceTimer;
  Timer? _focusDebounceTimer;
  Timer? _cadastroUpdateDebounceTimer;
  bool _atualizandoCadastro = false;

  // Variáveis para filtros de saídas
  final String _filtroSaidas = '';

  // Variáveis para auto baixa (múltiplas saídas)
  bool _modoAutoBaixa = false;
  final Set<int> _itensSelecionados = {};

  // Dados de cadastro avulso
  Map<String, dynamic>? _cadastroAvulso;
  bool _buscandoCadastroAvulso = false;
  bool _temCadastroAvulso = false;
  bool _cadastroBuscado = false; // Controla se já foi feita a busca do cadastro
  dynamic _ultimoPessoadocumentoId;

  // Unidades para encomendas
  List<Map<String, dynamic>> _unidadesEncomendaList = [];
  bool _loadingUnidadesEncomenda = false;
  // Locais (ex.: Portaria, Recepçao...) para ENVIAR
  List<Map<String, dynamic>> _locaisEntregaList = [];
  bool _loadingLocaisEntrega = false;
  Map<String, dynamic>? _localEntregaSelecionado;

  // Tipos de encomenda
  List<Map<String, dynamic>> _tiposEncomendaList = [];
  bool _loadingTiposEncomenda = false;
  Map<String, dynamic>? _tipoEncomendaSelecionado;

  // Histórico de encomendas
  List<Map<String, dynamic>> _historicoEncomendasList = [];
  List<Map<String, dynamic>> _historicoEncomendasListOriginal = [];
  bool _loadingHistoricoEncomendas = false;
  // Multi-seleção de unidades para encomenda (até 10)
  List<Map<String, dynamic>> _selectedUnidadesEncomenda = [];
  dynamic _selectedUnidadeEncomenda; // mantido para compatibilidade

  // Filtros de Entregas
  DateTime? _filtroDataInicioEntrega;
  DateTime? _filtroDataFimEntrega;
  bool _filtroEntregues = false;
  bool _showFiltroEntreguesPeriodo = false;

  // Cache de status de fotos dos usuários (userId -> "has"|"none")
  final Map<String, String> _userPhotoStatusCache = {};
  final Map<String, bool> _userPhotoStatusLoading = {};

  // Cache de fotos dos usuários (userId -> imageUrl)
  final Map<String, String> _userPhotosCache = {};
  final Map<String, bool> _userPhotosLoading = {};

  // Loading para foto de encomenda
  bool _loadingFotoEncomenda = false;
  bool _loadingEnviarEncomenda = false;

  // Veículos
  List<Map<String, dynamic>> _veiculosList = [];
  bool _loadingVeiculos = false;

  // Vagas
  List<Map<String, dynamic>> _vagasList = [];
  bool _loadingVagas = false;

  // Veículo encontrado por placa
  Map<String, dynamic>? _veiculoFiltrado;
  bool _loadingVeiculo = false;

  // Filtros de agendamentos
  Map<String, dynamic>? _selectedUnidadeAgendamento;
  Map<String, String>? _tipoAgendamentoSelecionado;
  DateTime? _filtroDataInicioSelecionada;
  DateTime? _filtroDataFimSelecionada;

  // Filtros para saídas
  DateTime? _filtroDataInicioSaidas;
  DateTime? _filtroDataFimSaidas;

  // Busca de unidades para encomendas
  final TextEditingController _buscaUnidadeEncomendaController =
      TextEditingController();
  final TextEditingController _codigoBarrasEncomendaController =
      TextEditingController();
  final TextEditingController _identificacaoInternaEncomendaController =
      TextEditingController();
  final TextEditingController _observacaoEncomendaController =
      TextEditingController();
  final TextEditingController _identificacaoInternaEntregaController =
      TextEditingController();

  // Dados de agendamentos
  List<Map<String, dynamic>> _agendamentos = [];
  bool _loadingAgendamentos = false;

  // Dados de convidados por agendamento
  final Map<String, int> _quantidadeConvidados = {};

  // Dados de ramais

  // Dados de entregas
  List<Map<String, dynamic>> _entregasList = [];
  List<Map<String, dynamic>> _entregasListOriginal = [];
  bool _loadingEntregas = false;
  final TextEditingController _filtroNomeEntregaController =
      TextEditingController();
  final TextEditingController _filtroCodigoBarrasEntregaController =
      TextEditingController();

  // Dados de moradores/unidades para filtros
  final List<Map<String, dynamic>> _moradoresList = [];

  // Dados de passagens
  List<Map<String, dynamic>> _passagens =
      []; // Passagens ativas (sem data de saída)
  List<Map<String, dynamic>> _todasPassagens = []; // Todas as passagens do dia
  bool _loadingPassagens = false;
  bool _mostrarRecentes = false; // Controla se mostrar "Buscar" ou "Recentes"
  final Set<int> _passagensAtualizadas =
      {}; // Rastrear IDs de passagens já atualizadas via API

  // Dados de histórico usando API passagemhistorico
  List<Map<String, dynamic>> _historicoBaixa =
      []; // Histórico completo de passagens
  List<Map<String, dynamic>> _historicoFiltrado = []; // Histórico filtrado

  // Filtros para agendamentos
  final TextEditingController _filtroUnidadeAgendamentoController =
      TextEditingController();
  final TextEditingController _filtroNomeAgendamentoController =
      TextEditingController();
  final TextEditingController _autorizanteAgendamentoController =
      TextEditingController();
  final String _filtroUnidadeAgendamento = '';
  final String _filtroNomeAgendamento = '';

  // Filtros para histórico de passagens
  final TextEditingController _filtroNomeHistoricoController =
      TextEditingController();
  final TextEditingController _filtroDocumentoHistoricoController =
      TextEditingController();
  final TextEditingController _filtroPlacaHistoricoController =
      TextEditingController();
  final TextEditingController _filtroUnidadeHistoricoController =
      TextEditingController();
  DateTime? _filtroDataInicioHistorico;
  DateTime? _filtroDataFimHistorico;
  bool _loadingHistorico = false;

  // Filtros para saídas
  final TextEditingController _filtroNomeSaidasController =
      TextEditingController();
  final TextEditingController _filtroDocumentoSaidasController =
      TextEditingController();
  final TextEditingController _filtroPlacaSaidasController =
      TextEditingController();
  final TextEditingController _filtroUnidadeSaidasController =
      TextEditingController();
  final Set<String> _loadingSaidas = {};
  bool _loadingSaidasList = false;

  // Filtros para entrada
  final TextEditingController _filtroDocumentoEntradaController =
      TextEditingController();
  final TextEditingController _filtroUnidadeEntradaController =
      TextEditingController();
  final TextEditingController _filtroNomeEntradaController =
      TextEditingController();
  DateTime? _filtroDataEntrada;
  // Filtros de período para agendamento na entrada
  DateTime? _filtroDataInicioEntrada;
  DateTime? _filtroDataFimEntrada;

  // Estados para validaçao visual dos campos obrigatórios
  bool _erroDocumentoEntrada = false;
  bool _erroNomeEntrada = false;
  bool _erroDataEntrada = false;

  // Estado para busca de entradas
  List<Map<String, dynamic>> _resultadosBuscaEntrada = [];
  List<Map<String, dynamic>> _convidadosReserva =
      []; // Convidados da reserva quando tipo for AG
  Map<String, dynamic>?
      _reservaSelecionada; // Reserva selecionada para mostrar convidados
  String?
      _selectedConvidadoId; // ID do convidado selecionado para remoçao após entrada
  String? _selectedReservaId; // ID da reserva do convidado selecionado
  String?
      _documentoFiltroAplicado; // Documento usado no filtro para destacar convidado
  String?
      _filtrarReservaconvidadoId; // ID do convidado (filho) para mostrar apenas ele no painel

  // Keys para feedback contextual
  final Map<String, GlobalKey> _feedbackKeys = {};

  GlobalKey _getFeedbackKey(String id) {
    if (!_feedbackKeys.containsKey(id)) {
      _feedbackKeys[id] = GlobalKey();
    }
    return _feedbackKeys[id]!;
  }

  bool _loadingBuscaEntrada = false;
  bool _loadingBuscaAgendamentos = false;
  bool _loadingRegistroEntrada = false;
  bool _loadingUnidadesFiltro = false;
  final bool _loadingAtualizarFacial = false;
  final bool _loadingBaixaEmLote = false;
  final bool _loadingBuscarConvidadosReserva = false;
  bool _loadingEditarCadastro = false;
  bool _mostrarFormEntrada =
      false; // Comeá§a sem form, só mostra quando selecionar ou não encontrar
  bool _isNovoUsuario = false; // Indica se é cadastro de novo usuário
  bool _isAgendamento =
      false; // Indica se é um agendamento encontrado no modo Avulso
  String? _unidadeAgendamento; // Unidade do agendamento para exibir na tag
  Map<String, dynamic>?
      _unidadeFiltroSelecionada; // Unidade selecionada no filtro
  int? _unidadeFiltroAplicada; // ID da unidade aplicada no filtro

  // Espaá§os sociais (para filtro de entrada/agendamento)
  List<Map<String, dynamic>> _espacosSocialList = [];
  bool _loadingEspacosSocial = false;
  Map<String, dynamic>?
      _espacoSocialSelecionado; // Espaço social selecionado no filtro
  final List<int> _espacosSociaisSelecionados =
      []; // Lista de IDs de espaá§os sociais selecionados para busca de agendamento

  // Tipo de filtro de entrada: 0 = Avulso, 1 = Agendamentos
  int _tipoFiltroEntrada = 0;
  final Map<int, bool> _espacosSociaisSelecionadosFiltro =
      {}; // Seleá§ões de espaá§os sociais no filtro
  bool _filtroEntradaMinimizado = false; // Controla se o filtro está minimizado
  bool _agendamentoTiposFiltroExpandido =
      false; // Controla se os tipos de agendamento (espaá§os sociais) está£o expandidos
  bool _hasBotoeiras = false;

  // Dados para câmera em encomendas
  Uint8List? _fotoEncomenda;
  Uint8List? _fotoEncomendaEntrega;
  Uint8List? _fotoFacialEntrega;

  // Filtros para vagas
  String? _filtroVagasSelecionado;

  // Filtros para unidades
  List<Map<String, dynamic>> _unidadesFiltroList = [];
  String? _filtroUnidadeSelecionado;
  Uint8List? _fotoTiradaMorador;

  // Estado para cartões expandidos (Nova Entrada Avulso)
  final Set<String> _cardsExpandidos = {};
  final Map<String, Map<String, dynamic>> _unidadeSelecionadaAvulso = {};
  final Map<String, TextEditingController> _autorizanteAvulsoControllers = {};
  // Loading por card (Nova entrada / Entrada na última unidade)
  final Set<String> _loadingEntradaAvulsoKeys = {};

  // Cache do ID do condomínio para SignalR
  int _cachedCondominioId = 0;
  Timer? _signalRDebounceTimer;

  // Método para primeira entrada de agendamento (Atualiza + Move)
  Future<void> _registrarPrimeiraEntradaAgendamento(
      Map<String, dynamic> convidado) async {
    print('Iniciando registro de primeira entrada para: ${convidado['nome']}');

    setState(() {
      _loadingRegistroEntrada = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        throw Exception('Token de sessá£o inválido');
      }

      final condominioId = await getCondominioIdAtual();
      final usuarioId = await ApiConfig.getUsuarioId();

      // IDs
      final reservaId = convidado['reserva_id'] is int
          ? convidado['reserva_id']
          : int.tryParse(convidado['reserva_id']?.toString() ?? '0') ?? 0;
      final reservaconvidadoId = convidado['reservaconvidado_id'] is int
          ? convidado['reservaconvidado_id']
          : int.tryParse(convidado['reservaconvidado_id']?.toString() ?? '0') ??
              0;

      // 1. Validar Foto (Obrigatória na primeira entrada)
      // Se vier URL no campo 'foto' ou se tiver 'link_foto', precisamos baixar e converter
      String? fotoBase64 = convidado['foto']?.toString();
      final String? linkFoto = convidado['link_foto']?.toString();

      // Se a foto atual for URL ou nula, e tivermos um link_foto válido, tentar baixar
      bool hasUrlAsPhoto = fotoBase64 != null && fotoBase64.startsWith('http');
      bool hasLinkFoto = linkFoto != null &&
          linkFoto.isNotEmpty &&
          linkFoto.startsWith('http');

      if ((fotoBase64 == null ||
              fotoBase64.isEmpty ||
              fotoBase64 == 'null' ||
              hasUrlAsPhoto) &&
          hasLinkFoto) {
        try {
          print('ðŸ“¸ Baixando foto do perfil para base64: $linkFoto');
          final response = await http.get(Uri.parse(linkFoto));
          if (response.statusCode == 200) {
            fotoBase64 = base64Encode(response.bodyBytes);
          } else {
            print('âš ï¸ Falha ao baixar imagem: ${response.statusCode}');
          }
        } catch (e) {
          print('âš ï¸ Erro ao converter imagem de URL para Base64: $e');
        }
      }

      // Validaçao Final
      if (fotoBase64 == null ||
          fotoBase64.isEmpty ||
          fotoBase64 == 'null' ||
          fotoBase64.startsWith('http')) {
        throw Exception('Foto é obrigatória para a primeira entrada!');
      }

      // 2. Chamar convidadoupd
      final urlUpd =
          Uri.parse(ApiConfig.getEndpoint('convidados', 'atualizar'));

      // Preparar payload do update
      final payloadUpd = {
        'reserva_id': reservaId,
        'reservaconvidado_id': reservaconvidadoId,
        'convidado_txt': convidado['nome'] ?? convidado['convidado_txt'] ?? '',
        'email_txt': convidado['email'] ?? convidado['email_txt'] ?? '',
        'autorizante_txt':
            convidado['autorizante'] ?? convidado['autorizante_txt'] ?? '',
        'documento_txt':
            convidado['documento'] ?? convidado['documento_txt'] ?? '',
        'empresa_txt': convidado['empresa'] ?? convidado['empresa_txt'] ?? '',
        'creci_txt': convidado['creci'] ?? convidado['creci_txt'] ?? '',
        'placa': convidado['placa'] ?? '',
        'veiculo_txt': convidado['veiculo'] ?? convidado['veiculo_txt'] ?? '',
        'tipodoc_txt': convidado['tipodoc'] ?? convidado['tipodoc_txt'] ?? '',
        'quant_pessoas':
            int.tryParse(convidado['quant_pessoas']?.toString() ?? '1') ?? 1,
        'vaga_flg': (convidado['vaga_flg'] == 'S' ||
                convidado['flg_vaga'] == 'S' ||
                convidado['vaga'] != null)
            ? 'S'
            : 'N',
        'excluir': 'N',
        'id_acesso': '',
        'fotoBase64': fotoBase64, // Foto obrigatória
      };

      print('ðŸ“¤ Payload convidadoupd: $payloadUpd');

      final responseUpd = await http.post(
        urlUpd,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadUpd),
      );

      print('ðŸ“¥ Response convidadoupd: ${responseUpd.statusCode}');

      if (responseUpd.statusCode == 200) {
        final dataUpd = jsonDecode(responseUpd.body);
        if (dataUpd['status'] != 200) {
          throw Exception(
              'Erro ao atualizar dados do convidado: ${dataUpd['message']}');
        }
      } else {
        throw Exception('Erro HTTP na atualizaçao: ${responseUpd.statusCode}');
      }

      // 3. Chamar convidadomov (Entrada)
      print(' Atualizaçao OK. Realizando entrada (convidadomov)...');

      // Pequeno delay para garantir processamento no backend
      await Future.delayed(const Duration(milliseconds: 500));

      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final urlMov = Uri.parse(ApiConfig.getEndpoint('convidados', 'mover'));
      final payloadMov = {
        'condominio_id': int.tryParse(condominioId.toString()) ?? 0,
        'origem': 'E', // Entrada
        'tipo': 'A', // Agendamento
        'reserva_id': reservaId,
        'reservaconvidado_id': reservaconvidadoId,
        'usuario_registro': int.tryParse(usuarioId.toString()) ?? 0,
        'dt_entrada': formattedDate,
      };

      print('ðŸ“¤ Payload convidadomov: $payloadMov');

      final responseMov = await http.post(
        urlMov,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadMov),
      );

      print('ðŸ“¥ Response convidadomov: ${responseMov.statusCode}');

      if (responseMov.statusCode == 200) {
        final dataMov = jsonDecode(responseMov.body);
        if (dataMov['status'] == 200) {
          FeedbackUtils.showSuccess(
              context: context,
              title: 'Entrada Registrada',
              message: 'Entrada registrada com sucesso!');

          // Atualizar estado local
          setState(() {
            convidado['entrada'] = formattedDate;
            convidado['dt_entrada'] = formattedDate;
            convidado['saida'] = null;
            convidado['dt_saida'] = null;
            // Garantir que a foto fique salva no objeto
            if (convidado['foto'] == null && fotoBase64 != null) {
              convidado['foto'] = fotoBase64;
            }
          });
        } else {
          throw Exception('Erro na movimentaçao: ${dataMov['message']}');
        }
      } else {
        throw Exception('Erro HTTP na movimentaçao: ${responseMov.statusCode}');
      }
    } catch (e) {
      print('Erro em _registrarPrimeiraEntradaAgendamento: $e');
      FeedbackUtils.showError(
          context: context,
          title: 'Erro no Registro',
          message: 'Falha ao registrar entrada: $e');
    } finally {
      setState(() {
        _loadingRegistroEntrada = false;
      });
    }
  }

  // Método para entrada subsequente (já cadastrado, apenas move)
  Future<void> _realizarEntradaDireta(Map<String, dynamic> convidado) async {
    print('ðŸš€ Realizando re-entrada direta para: ${convidado['nome']}');
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
      final condominioId = await getCondominioIdAtual();
      final usuarioId = await ApiConfig.getUsuarioId();

      // IDs
      final reservaId = convidado['reserva_id'] is int
          ? convidado['reserva_id']
          : int.tryParse(convidado['reserva_id']?.toString() ?? '0') ?? 0;
      final reservaconvidadoId = convidado['reservaconvidado_id'] is int
          ? convidado['reservaconvidado_id']
          : int.tryParse(convidado['reservaconvidado_id']?.toString() ?? '0') ??
              0;

      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

      final urlMov = Uri.parse(ApiConfig.getEndpoint('convidados', 'mover'));
      final payloadMov = {
        'condominio_id': int.tryParse(condominioId.toString()) ?? 0,
        'origem': 'E', // Entrada
        'tipo': 'A', // Agendamento
        'reserva_id': reservaId,
        'reservaconvidado_id': reservaconvidadoId,
        'usuario_registro': int.tryParse(usuarioId.toString()) ?? 0,
        'dt_entrada': formattedDate,
      };

      print('ðŸ“¤ Payload convidadomov (Re-entrada): $payloadMov');

      final responseMov = await http.post(
        urlMov,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadMov),
      );

      if (responseMov.statusCode == 200) {
        final dataMov = jsonDecode(responseMov.body);
        if (dataMov['status'] == 200) {
          FeedbackUtils.showSuccess(
              context: context,
              title: 'Entrada Registrada',
              message: 'Entrada registrada com sucesso!');

          setState(() {
            convidado['entrada'] = formattedDate;
            convidado['dt_entrada'] = formattedDate;
            convidado['saida'] = null; // Limpa data de saída anterior
            convidado['dt_saida'] = null;
          });
        } else {
          FeedbackUtils.showError(
              context: context,
              title: 'Erro',
              message: dataMov['message'] ?? 'Erro desconhecido');
        }
      } else {
        FeedbackUtils.showError(
            context: context,
            title: 'Erro HTTP',
            message: 'Status ${responseMov.statusCode}');
      }
    } catch (e) {
      print('Erro na re-entrada: $e');
      FeedbackUtils.showError(
          context: context, title: 'Erro', message: e.toString());
    }
  }

  // Método auxiliar para converter IDs
  int? _convertToValidId(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) {
      if (value.isEmpty || value.toLowerCase() == 'null') return null;
      return int.tryParse(value);
    }
    return null;
  }

  // Método para registrar entrada de Avulso (com Unidade e Autorizante)
  // loadingKey: se informado, mostra loading no ícone do card e ao sucesso remove o card da lista
  Future<void> _registrarEntradaAvulsoSimples(
      Map<String, dynamic> convidado, int unidadeId, String autorizante,
      {String? loadingKey}) async {
    print(
        '🚀 Registrando entrada AVULSO (Simples) para: ${convidado['nome'] ?? convidado['convidado_txt']}');
    setState(() {
      _loadingRegistroEntrada = true;
      if (loadingKey != null) _loadingEntradaAvulsoKeys.add(loadingKey);
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioIdStr = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '0';
      final condominioId = int.tryParse(condominioIdStr) ?? 0;

      final url = Uri.parse(
          ApiConfig.getEndpoint('dashboard', 'registroEntradaAvulso'));

      // ---------------------------------------------------------
      // NOVO FLUXO: Buscar dados atualizados antes de registrar
      // ---------------------------------------------------------
      final documento =
          (convidado['documento'] ?? convidado['documento_txt'] ?? '')
              .toString();
      Map<String, dynamic> dadosEnriquecidos =
          Map<String, dynamic>.from(convidado);

      if (documento.isNotEmpty) {
        print('🔍 Refreshing visitor data for document: $documento');

        // 1. Chama cadastroavulsolist
        final urlList =
            Uri.parse(ApiConfig.getEndpoint('dashboard', 'cadastroAvulso'));
        try {
          final respList = await http.post(
            urlList,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao'
            },
            body: jsonEncode(
                {"condominio_id": condominioId, "documento": documento}),
          );
          if (respList.statusCode == 200) {
            final data = jsonDecode(respList.body);
            final lista = data['data']?['lista'] as List?;
            if (lista != null && lista.isNotEmpty) {
              dadosEnriquecidos.addAll(lista[0]);
            }
          }
        } catch (_) {}

        // 2. Chama avulsoselecionado
        final urlSel =
            Uri.parse(ApiConfig.getEndpoint('dashboard', 'avulsoSelecionado'));
        try {
          final respSel = await http.post(
            urlSel,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao'
            },
            body: jsonEncode(
                {"condominio_id": condominioId, "documento": documento}),
          );
          if (respSel.statusCode == 200) {
            final dataSel = jsonDecode(respSel.body);
            final listaSel = dataSel['data']?['selecionado'] as List?;
            if (listaSel != null && listaSel.isNotEmpty) {
              dadosEnriquecidos.addAll(listaSel[0]);
            }
          }
        } catch (_) {}
      }

      // --- CAPTURA DE FOTO PARA O PAYLOAD ---
      String? fotoBase64ParaPayload;
      String? sourceFoto =
          (dadosEnriquecidos['foto'] ?? convidado['foto'])?.toString();
      if (sourceFoto == 'null') sourceFoto = null;

      final linkFoto = (dadosEnriquecidos['link_foto'] ??
              dadosEnriquecidos['foto'] ??
              convidado['link_foto'] ??
              convidado['foto'])
          ?.toString();
      if (sourceFoto == null || sourceFoto.isEmpty) sourceFoto = linkFoto;

      if (sourceFoto != null && sourceFoto.isNotEmpty && sourceFoto != 'null') {
        if (sourceFoto.startsWith('http')) {
          print('📸 Downloading photo for payload: $sourceFoto');
          try {
            final respImg = await http.get(Uri.parse(sourceFoto));
            if (respImg.statusCode == 200) {
              fotoBase64ParaPayload = base64Encode(respImg.bodyBytes);
            }
          } catch (e) {
            print('⚠️ Error downloading photo: $e');
          }
        } else {
          fotoBase64ParaPayload = sourceFoto;
        }
      }

      // Limpeza do base64 para a API
      if (fotoBase64ParaPayload != null &&
          fotoBase64ParaPayload.contains(',')) {
        fotoBase64ParaPayload = fotoBase64ParaPayload.split(',').last;
      }

      // Obter IDs válidos dos dados enriquecidos
      final pessoadocumentoId = _convertToValidId(
              dadosEnriquecidos['pessoadocumento_id'] ??
                  dadosEnriquecidos['id']) ??
          0;
      final pessoaCadastroId =
          _convertToValidId(dadosEnriquecidos['pessoacadastro_id']) ?? 0;

      // --- CAPTURA DE NOME DO AUTORIZANTE (PROPRIETÁRIO DA UNIDADE) ---
      // Se o autorizante fornecido for "PORTARIA" ou estiver vazio, tentamos buscar o proprietário real da unidade via API unidadelist.
      String autorizanteFinal = autorizante.trim();
      if (unidadeId > 0 &&
          (autorizanteFinal.isEmpty ||
              autorizanteFinal.toUpperCase() == 'PORTARIA')) {
        print(
            '🏠 Refinando autorizante para unidade $unidadeId (Proprietário principal)');
        try {
          final urlUnid =
              Uri.parse(ApiConfig.getEndpoint('dashboard', 'unidades'));
          final respUnid = await http.post(
            urlUnid,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao',
            },
            body: jsonEncode({
              "condominio_id": condominioId,
              "apto_id": unidadeId,
              "unidade": "",
              "flg_principal": "S",
              "nome": "",
              "placa": "",
              "vaga_id": 0,
            }),
          );
          if (respUnid.statusCode == 200) {
            final dataUnid = jsonDecode(respUnid.body);
            final unidades = dataUnid['data']?['unidades'] as List?;
            if (unidades != null && unidades.isNotEmpty) {
              // Extrair o nome do proprietário principal
              final nomeProprietario = (unidades[0]['nome_morador'] ??
                      unidades[0]['morador'] ??
                      unidades[0]['pessoa'] ??
                      unidades[0]['nome'] ??
                      '')
                  .toString();
              if (nomeProprietario.isNotEmpty) {
                print(
                    '✅ Autorizante atualizado para proprietário principal: $nomeProprietario');
                autorizanteFinal = nomeProprietario;
              }
            }
          }
        } catch (e) {
          print('⚠️ Erro ao buscar proprietário da unidade: $e');
        }
      }
      if (autorizanteFinal.isEmpty) autorizanteFinal = 'PORTARIA';

      // Payload completo seguindo o fluxo de Salvar (Editar)
      final payload = {
        "condominio_id": condominioId,
        "pessoadocumento_id": pessoadocumentoId,
        "documento": (dadosEnriquecidos['documento'] ??
                dadosEnriquecidos['documento_txt'] ??
                convidado['documento'] ??
                '')
            .toString(),
        "nome": (dadosEnriquecidos['nome'] ??
                dadosEnriquecidos['convidado_txt'] ??
                convidado['nome'] ??
                '')
            .toString(),
        "entradacadastro_id": 0,
        "apto_id": unidadeId,
        "autorizante": autorizanteFinal,
        "tipovisita": (dadosEnriquecidos['tipovisita'] ??
                dadosEnriquecidos['tipo_visita'] ??
                convidado['tipovisita'] ??
                convidado['tipo_visita'] ??
                'V')
            .toString(),
        "leitor_id": 0,
        "outraident_id": _convertToValidId(dadosEnriquecidos['outraident_id'] ??
                convidado['outraident_id']) ??
            0,
        "vaga_id": _convertToValidId(
                dadosEnriquecidos['vaga_id'] ?? convidado['vaga_id']) ??
            0,
        "marca_id": _convertToValidId(
                dadosEnriquecidos['marca_id'] ?? convidado['marca_id']) ??
            0,
        "cor_id": _convertToValidId(
                dadosEnriquecidos['cor_id'] ?? convidado['cor_id']) ??
            0,
        "placa":
            (dadosEnriquecidos['placa'] ?? convidado['placa'] ?? '').toString(),
        "modelo": (dadosEnriquecidos['modelo'] ?? convidado['modelo'] ?? '')
            .toString(),
        "flg_garagem": '',
        "dt_fim": '',
        "observacao":
            (dadosEnriquecidos['observacao'] ?? convidado['observacao'] ?? '')
                .toString(),
        "fotobase64_1": fotoBase64ParaPayload ?? '',
        "fotobase64_2": fotoBase64ParaPayload ?? '',
      };

      print('📤 Payload registroEntradaAvulso (Fluxo Unificado):');
      print('   - pessoadocumento_id: $pessoadocumentoId');
      print('   - apto_id: $unidadeId');
      print('   - autorizante: ${payload['autorizante']}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      print('📥 Response registroEntradaAvulso: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          // FLUXO DE FOTO (IDEM AO SALVAR)
          String? fotoBase64 =
              (dadosEnriquecidos['foto'] ?? convidado['foto'])?.toString();
          if (fotoBase64 == 'null') fotoBase64 = null;

          final linkFoto = (dadosEnriquecidos['link_foto'] ??
                  dadosEnriquecidos['foto'] ??
                  convidado['link_foto'] ??
                  convidado['foto'])
              ?.toString();

          if ((fotoBase64 != null && fotoBase64.isNotEmpty) ||
              (linkFoto != null && linkFoto.isNotEmpty && linkFoto != 'null')) {
            final urlFoto = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');
            final sourceFoto = (fotoBase64 != null &&
                    fotoBase64.isNotEmpty &&
                    !fotoBase64.startsWith('http'))
                ? fotoBase64
                : linkFoto;

            if (sourceFoto != null && sourceFoto.isNotEmpty) {
              String fotoParaEnviar = '';
              bool downloadSucesso = true;

              if (sourceFoto.startsWith('http')) {
                try {
                  final respImg = await http.get(Uri.parse(sourceFoto));
                  if (respImg.statusCode == 200) {
                    fotoParaEnviar = base64Encode(respImg.bodyBytes);
                  } else {
                    downloadSucesso = false;
                  }
                } catch (e) {
                  downloadSucesso = false;
                }
              } else {
                fotoParaEnviar = sourceFoto;
              }

              if (downloadSucesso && fotoParaEnviar.isNotEmpty) {
                final fotoClean = fotoParaEnviar.contains(',')
                    ? fotoParaEnviar.split(',').last
                    : fotoParaEnviar;

                // Usar pessoacadastro_id se tiver, senão tenta o ID principal
                final targetPessoaId =
                    pessoaCadastroId > 0 ? pessoaCadastroId : pessoadocumentoId;

                final payloadFoto = {
                  "condominio_id": condominioId,
                  "tipoUSU": "USU",
                  "ordem_num": 1,
                  "pessoacadastro_id": targetPessoaId,
                  "foto": fotoClean,
                };

                print(
                    '📸 Enviando foto para FotoRegistrar (ID: $targetPessoaId)');
                await http.post(
                  urlFoto,
                  headers: {
                    'Content-Type': 'application/json',
                    'Authorization': 'Bearer $tokenSessao',
                  },
                  body: jsonEncode(payloadFoto),
                );
              }
            }
          }

          FeedbackUtils.showSuccess(
              context: context,
              title: 'Entrada Registrada',
              message: 'Entrada registrada com sucesso!');

          // Limpar tudo e fechar
          await _limparFormularioEntrada();
        } else {
          throw Exception(data['message'] ?? 'Erro no servidor');
        }
      } else {
        throw Exception('Erro HTTP: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro registro entrada unificado: $e');
      FeedbackUtils.showError(
          context: context, title: 'Erro', message: e.toString());
    } finally {
      setState(() {
        _loadingRegistroEntrada = false;
        if (loadingKey != null) _loadingEntradaAvulsoKeys.remove(loadingKey);
      });
    }
  }

  // Método para obter valor válido do filtro de unidade
  String? _getValidFiltroUnidadeValue() {
    if (_filtroUnidadeSelecionado == null) return null;

    // Criar lista de valores disponíveis (incluindo null para "Todas as unidades")
    final valoresDisponiveis = <String?>[null]; // "Todas as unidades"
    valoresDisponiveis.addAll(_unidadesFiltroList.map<String>((unidade) {
      return unidade['unidade_mostra'] ?? unidade['nome'] ?? 'Unidade';
    }));

    // Verificar se o valor selecionado existe na lista
    return valoresDisponiveis.contains(_filtroUnidadeSelecionado)
        ? _filtroUnidadeSelecionado
        : null;
  }

  // Método para obter items do dropdown de unidades
  List<DropdownMenuItem<String>> _getUnidadesDropdownItems() {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: null, child: Text('Unidades')),
    ];

    items.addAll(_unidadesFiltroList.map<DropdownMenuItem<String>>((unidade) {
      final unidadeNome =
          unidade['unidade_mostra'] ?? unidade['nome'] ?? 'Unidade';
      return DropdownMenuItem<String>(
        value: unidadeNome,
        child: Text(unidadeNome),
      );
    }));

    return items;
  }

  // Notifier para atualizar foto do morador na tela de entrega
  final ValueNotifier<Uint8List?> _fotoMoradorNotifier =
      ValueNotifier<Uint8List?>(null);

  // Funçao auxiliar para atualizar cadastro quando um campo perde foco
  void _atualizarCadastroComDebounce() {
    _cadastroUpdateDebounceTimer?.cancel();
    _cadastroUpdateDebounceTimer = Timer(const Duration(milliseconds: 100), () {
      _atualizarCadastroAvulso();
    });
  }

  // Busca veículo por placa (backup)
  Future<void> _buscarVeiculoPorPlaca(String placa) async {
    setState(() {
      _loadingVeiculo = true;
      _veiculoFiltrado = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final token = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao = (token.isNotEmpty) ? decryptText(token) : '';
      final url = Uri.parse('${ApiConfig.gateUrl}/veiculolist');
      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "placa": placa.trim().toUpperCase(),
      };
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic>? veiculos;
        if (data['data'] is Map) {
          final raiz = Map<String, dynamic>.from(data['data']);
          if (raiz['veiculos'] is List) {
            veiculos = raiz['veiculos'] as List;
          }
        } else if (data['data'] is List) {
          veiculos = data['data'] as List;
        }
        if (veiculos != null && veiculos.isNotEmpty) {
          setState(() {
            _veiculoFiltrado = Map<String, dynamic>.from(
              veiculos!.first as Map,
            );
          });
        } else {
          setState(() {
            _veiculoFiltrado = null;
          });
        }
      } else {
        setState(() {
          _veiculoFiltrado = null;
        });
      }
    } catch (_) {
      setState(() {
        _veiculoFiltrado = null;
      });
    } finally {
      setState(() {
        _loadingVeiculo = false;
      });
    }
  }

  // Atualizar indicador visual de atualizaçao
  void _setAtualizandoCadastro(bool atualizando) {
    setState(() {
      _atualizandoCadastro = atualizando;
    });
  }

  @override
  void initState() {
    super.initState();
    print(' ========== DASHBOARD INITSTATE EXECUTADO! ==========');

    _setupFocusListeners();
    // Centralizar toda a inicialização no método assíncrono
    _initializeData();
  }

  // Procura uma chave recursivamente em um objeto JSON (Map ou List)
  dynamic _findKeyDeep(dynamic json, String targetKey) {
    if (json is Map) {
      if (json.containsKey(targetKey)) {
        return json[targetKey];
      }
      for (var value in json.values) {
        final result = _findKeyDeep(value, targetKey);
        if (result != null) return result;
      }
    } else if (json is List) {
      for (var item in json) {
        final result = _findKeyDeep(item, targetKey);
        if (result != null) return result;
      }
    }
    return null;
  }

  // Verificar plano do condomínio (SmartAccess vs Smart)
  Future<void> _verificarPlanoCondominio() async {
    print('🔍 VERIFICANDO PLANO DO CONDOMÍNIO (SmartAccess vs Smart)...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id');
      final condominioIdStr =
          (encryptedCondominioId != null && encryptedCondominioId.isNotEmpty)
              ? decryptText(encryptedCondominioId)
              : '';

      print('🏢 condominioIdStr (decrypted): $condominioIdStr');

      if (condominioIdStr.isNotEmpty) {
        // FORÇAR PREMISSA: Se tem ID, assume que pode usar SignalR (comportamento "antigo")
        // O filtro de ID nos eventos tratará de descartar dados indesejados.
        print(
            '✅ [Plano] SignalR habilitado por ID presente ($condominioIdStr)');
        setState(() {
          _enableSignalR = true;
          // Garantir permissão default true, a ser refinada por _verificarPermissaoAcesso
          _permissaoAcessoPessoas ??= true;
        });
      } else {
        print('⚠️ Token ou condominio_id ausente. Usando configuração padrão.');
      }
    } catch (e) {
      print('❌ Erro ao verificar plano do condomínio: $e');
    }
  }

  // Verificar permissá£o de acesso ao cadastramento de dispositivos
  Future<void> _verificarPermissaoAcesso() async {
    print('VERIFICANDO PERMISSão DE ACESSO...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

      if (tokenSessao.isEmpty) {
        // Se não houver token, redirecionar para login
        _redirecionarParaLogin('Sessá£o expirada. Faá§a login novamente.');
        return;
      }

      final permissaoUrl = Uri.parse(
        ApiConfig.getEndpoint('condominio', 'param'),
      );
      final permissaoPayload = {
        "param_txt": "param_portaria_acessa_pessoas",
      };

      final permissaoResponse = await http.post(
        permissaoUrl,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(permissaoPayload),
      );

      print(
          'ðŸ“¡ Resposta da API condominioparam: ${permissaoResponse.statusCode}');
      print(' Body: ${permissaoResponse.body}');

      if (permissaoResponse.statusCode == 200) {
        final permissaoData = jsonDecode(permissaoResponse.body);
        print(' permissaoData Type: ${permissaoData.runtimeType}');
        print(' permissaoData Content: $permissaoData');

        // Verificar se a resposta contém o campo valor_txt
        String? valorTxt;
        if (permissaoData is Map) {
          // Tentar encontrar valor_txt em data (pode ser Map ou List)
          final data = permissaoData['data'];

          if (data is Map) {
            // Formato: data: { valor_txt: "..." }
            valorTxt = data['valor_txt']?.toString();
          } else if (data is List && data.isNotEmpty) {
            // Formato: data: [ { valor_txt: "..." } ]
            final item = data.first;
            if (item is Map) {
              valorTxt = item['valor_txt']?.toString();
            }
          }

          // Se não encontrou em data, tentar na raiz
          valorTxt ??= permissaoData['valor_txt']?.toString();

          // Debugging extra para identificar onde está o valor se ainda for null
          if (valorTxt == null) {
            print(
                'âš ï¸ valor_txt ainda é null. Estrutura de data: ${data.runtimeType} -> $data');
          }
        }

        // Salvar permissá£o no estado
        print(' Valor da permissá£o (valor_txt): $valorTxt');

        // Se o plano é Smart (sem gate), a permissá£o já foi forá§ada para false
        // Ná£o sobrescrever nesse caso
        if (!_enableSignalR) {
          print(
              'Plano Smart detectado. Permissá£o permanece INATIVA (ignorando condominioparam).');
          // Ná£o alterar _permissaoAcessoPessoas, já está false
        } else if (valorTxt != null && valorTxt.trim().toUpperCase() == 'N') {
          // Modo somente leitura (SmartAccess com param N)
          setState(() {
            _permissaoAcessoPessoas = false;
          });
          print('Permissá£o: SOMENTE LEITURA (N)');
        } else {
          // Modo ediçao completa (SmartAccess com param S ou não especificado)
          setState(() {
            _permissaoAcessoPessoas = true;
          });
          print(' Permissá£o: EDIá‡ão COMPLETA (S)');
        }
      } else {
        // Se a API de permissá£o falhar
        if (!_enableSignalR) {
          // Plano Smart: manter inativo
          print(
              'âš ï¸ API falhou, mas plano Smart detectado. Permissá£o permanece INATIVA.');
        } else {
          // SmartAccess: permitir o acesso (fallback)
          setState(() {
            _permissaoAcessoPessoas = true; // Fallback: permitir ediçao
          });
        }
      }
    } catch (e) {
      // Se houver erro na verificaçao de permissá£o
      print('Erro ao verificar permissá£o: $e');
      if (!_enableSignalR) {
        // Plano Smart: manter inativo
        print(
            'âš ï¸ Erro, mas plano Smart detectado. Permissá£o permanece INATIVA.');
      } else {
        // SmartAccess: permitir o acesso (fallback)
        setState(() {
          _permissaoAcessoPessoas = true; // Fallback: permitir ediçao
        });
      }
    }
  }

  // Redirecionar para login com mensagem de erro
  Future<void> _redirecionarParaLogin(String mensagem) async {
    // Limpar dados de sessá£o
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tokensessao_txt');
    await prefs.remove('usuario_id');
    await prefs.remove('condominio_id');
    await prefs.remove('usuario_nome');

    // Salvar mensagem de erro para exibir na tela de login
    await prefs.setString('login_error_message', mensagem);

    // Redirecionar para login
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _setupFocusListeners() {
    // Listeners para atualizar cadastro (onBlur - quando perde foco)
    _documentoFocusNode.addListener(() {
      if (!_documentoFocusNode.hasFocus &&
          _documentoController.text.trim().length >= 6 &&
          !_mostrarFormEntrada) {
        // Só buscar se formulário não estiver sendo mostrado
        // Ao sair do campo documento, buscar entradas filtradas (não cadastro avulso)
        final documento = _documentoController.text.trim();
        if (documento.isNotEmpty) {
          _filtroDocumentoEntradaController.text = documento;
          _buscarEntradasFiltradas();
        }
      } else if (!_documentoFocusNode.hasFocus) {}
    });

    // Também adicionar listener no controller para onChange (backup)
    _documentoController.addListener(() {});

    _nomeFocusNode.addListener(() {
      if (!_nomeFocusNode.hasFocus && _nomeController.text.trim().isNotEmpty) {
        // Ao sair do campo nome, atualizar cadastro via API editacadastro
        _atualizarCadastroComDebounce();
      } else if (!_nomeFocusNode.hasFocus) {}
    });

    _autorizanteFocusNode.addListener(() {
      if (!_autorizanteFocusNode.hasFocus) {
        // Ao sair do campo autorizante, atualizar cadastro via API editacadastro
        _atualizarCadastroComDebounce();
      }
    });

    _empresaFocusNode.addListener(() {
      if (!_empresaFocusNode.hasFocus) {
        _atualizarCadastroComDebounce();
      }
    });

    _placaFocusNode.addListener(() {
      if (!_placaFocusNode.hasFocus) {
        _atualizarCadastroComDebounce();
      }
    });

    _modeloFocusNode.addListener(() {
      if (!_modeloFocusNode.hasFocus) {
        _atualizarCadastroComDebounce();
      }
    });

    _obsFocusNode.addListener(() {
      if (!_obsFocusNode.hasFocus) {
        _atualizarCadastroComDebounce();
      }
    });
  }

  Future<void> _initializeData() async {
    // 0. VERIFICAR PERMISSÕES E PLANO DO CONDOMÍNIO (CRÍTICO - CONTROL F5)
    await _verificarPlanoCondominio();

    // INICIAR SIGNALR SE HABILITADO
    if (_enableSignalR) {
      print('🚀 [Dashboard] Iniciando SignalR...');
      _initializeSignalR();
    }

    // APIs essenciais que precisam funcionar na abertura da tela
    await _fetchAutorizantes();
    await _fetchMarcasECoresVeiculo();
    await _fetchVagasAvulso();
    await _fetchCrachas();
    // Passagens agora vêm do SignalR, não da API
    // await _fetchPassagens();
    await _fetchUnidadesEncomenda();
    await _fetchTiposEncomenda();
    await _fetchLocaisEncomenda();
    await _fetchUnidadesFiltro(); // Carregar unidades para filtro de entrada
    await _fetchEspacosSocial(); // Carregar espaá§os sociais para filtro de entrada
    await _fetchHistoricos();
    await _fetchAgendamentos();
    await _fetchEntregas();
    await _fetchVeiculos();
    await _fetchVagas();
    await _checkBotoeiras();
    // Equipamentos carregados pelo EquipamentosFAB widget

    // Listener para busca de unidades em encomendas removido

    // Listener para atualizar UI quando documento muda
    _documentoController.addListener(() {
      setState(() {}); // Atualizar UI apenas
    });

    // Listeners para atualizar UI quando os campos mudam
    _nomeController.addListener(() {
      setState(() {}); // Atualizar UI
    });

    _autorizanteController.addListener(() {
      setState(() {}); // Atualizar UI
    });

    // Listener para busca de unidades por nome em tempo real ao digitar
    _filtroNomeUnidadeController.addListener(() {
      setState(() {}); // Atualizar UI ao digitar o nome
    });

    // Listener para busca de unidades por número/morador em tempo real ao digitar
    _filtroUnidadeController.addListener(() {
      setState(() {}); // Atualizar UI ao digitar a unidade
    });
  }

  // Verificar se existem botoeiras para mostrar o botão correspondente
  Future<void> _checkBotoeiras() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) return;

      final condominioId = await getCondominioIdAtual();
      if (condominioId == 0) return;

      final url =
          Uri.parse(ApiConfig.getEndpoint('condominio', 'equipamentolist'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({'condominio_id': condominioId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Verifica o campo 'botoeira' conforme sua instrução
        final list = data['data']?['botoeira'] as List?;

        if (mounted) {
          setState(() {
            _hasBotoeiras = list != null && list.isNotEmpty;
          });
        }
      }
    } catch (e) {
      print('Erro ao verificar botoeiras: $e');
    }
  }

  // Buffer para acumular dados do SignalR durante debounce
  final List<dynamic> _pendingSignalRData = [];

  Future<void> _PassagensListar(List<dynamic> passagens) async {
    if (!mounted) return;

    // Acumular dados no buffer
    _pendingSignalRData.addAll(passagens);

    // Debounce mínimo para resposta instantânea (quase real-time)
    _signalRDebounceTimer?.cancel();
    _signalRDebounceTimer = Timer(const Duration(milliseconds: 10), () async {
      if (!mounted) return;

      // Copiar e limpar o buffer para processamento
      final processingData = List<dynamic>.from(_pendingSignalRData);
      _pendingSignalRData.clear();

      if (processingData.isEmpty) return;

      print('═══════════════════════════════════════════════════════════');
      print('🔔 [SignalR] RECEBIDO ATUALIZAÇÃO DO SERVIDOR (DEBOUNCED)');
      print('📊 Total de itens acumulados: ${processingData.length}');
      for (var i = 0;
          i < (processingData.length > 3 ? 3 : processingData.length);
          i++) {
        print('   Item $i: ${processingData[i]}');
      }
      print('═══════════════════════════════════════════════════════════');

      if (_cachedCondominioId == 0) {
        _cachedCondominioId = await getCondominioIdAtual();
      }

      try {
        // Processamento direto na Main Thread
        // Pegamos os 500 mais recentes se houver muitos
        final rawList = processingData.take(500).toList();
        final passagensMap = processSignalRData(
            {'rawList': rawList, 'condominioId': _cachedCondominioId});

        if (!mounted) return;

        // MAIN THREAD: Enriquecimento (Leve)
        final passagensEnriquecidas =
            _enriquecerPassagensComDadosUnidade(passagensMap);

        final passagensOrdenadas =
            List<Map<String, dynamic>>.from(passagensEnriquecidas);

        passagensOrdenadas.sort((a, b) {
          final dataA = _parseDataPassagem(a);
          final dataB = _parseDataPassagem(b);
          return dataB.compareTo(dataA);
        });

        // Throttling de atualizaçoes de leitura: apenas para itens NOVOS que o usuário ainda não viu
        // Pegamos o token uma única vez para o lote
        final token = await ApiConfig.getBearerToken();
        final List<String> idsParaAtualizar = [];

        for (var p in passagensOrdenadas) {
          final id = p['id']?.toString();
          if (id != null && id.isNotEmpty) {
            // Verificar se já temos esse ID na lista atual. Se não tem, é novo e precisa disparar o update.
            bool isNovo = !_todasPassagens
                .any((existing) => (existing['id']?.toString() ?? '') == id);

            if (isNovo) {
              idsParaAtualizar.add(id);
            }
          }
        }

        // Disparar atualizaçoes em background de forma controlada (apenas novos)
        for (var id in idsParaAtualizar) {
          await SignalRService().PassagemUpdateTela(id);
        }

        if (!mounted) return;

        print(
            '[SignalR Handler] Passagens processadas: ${passagensMap.length}');

        setState(() {
          // Lógica de MERGE SEMPRE ATIVA: Preservar histórico e atualizar/adicionar novos
          final Map<String, Map<String, dynamic>> currentItems = {
            for (var p in _todasPassagens) (p['id']?.toString() ?? ''): p
          };

          int novos = 0;
          int atualizados = 0;

          for (var p in passagensOrdenadas) {
            final id = p['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (currentItems.containsKey(id)) {
                atualizados++;
              } else {
                novos++;
              }
              currentItems[id] = p;
            }
          }

          final mergedList = currentItems.values.toList();

          // Re-ordenar por data (mais recente primeiro)
          mergedList.sort((a, b) {
            final dataA = _parseDataPassagem(a);
            final dataB = _parseDataPassagem(b);
            return dataB.compareTo(dataA);
          });

          _todasPassagens = mergedList;
          _passagens = mergedList;

          if (!_isUsingHistorico()) {
            _historicoFiltrado = _passagens;
          }
          print(
              '✅ [SignalR Update] Merge concluído: +$novos novos, $atualizados atualizados. Total: ${_todasPassagens.length}');
        });
      } catch (e) {
        print('🔴 [SignalR] Erro processamento main thread: $e');
      }
    });
  }

  bool _signalRInitialized = false;

  Future<void> _initializeSignalR() async {
    if (!mounted || _signalRInitialized) return;
    _signalRInitialized = true;

    print('🔌 ========== FAST SIGNALR INIT (SESSÃO TEMPORÁRIA) ==========');

    // 1. Configurar Listener (Callback) - ANTES de inicializar para não perder eventos iniciais
    print(
        '📝 [SignalR] Registrando callback onPassagensUpdate (ANTES DO INIT)');
    SignalRService().onPassagensUpdate = _PassagensListar;
    print(
        '✅ [SignalR] Callback registrado: ${SignalRService().onPassagensUpdate != null}');

    // 2. Iniciar Sessão Fresca (Destroi anterior se existir e cria nova)
    // O service deve lidar com debounce interno se necessário
    await SignalRService().initialize();

    // Old inline code disabled:
    Future<Null> _(passagens) async {
      // Bloqueio de ciclo de vida: Se a tela morreu, ignora tudo
      if (!mounted) {
        print('⚠️ [SignalR] Tela desmontada. Ignorando atualização.');
        return;
      }

      print('🔔 [SignalR] Recebido: ${passagens.length} cards.');

      // 2. Fetch Condominio ID se precisar (apenas para logging ou validação extra, o service já tem)
      if (_cachedCondominioId == 0) {
        _cachedCondominioId = await getCondominioIdAtual();
      }

      // 3. Processamento Pesado (conversoes, descricoes) FORA do setState
      // ... (Logica de conversao existente mantida nos bastidores do map abaixo) ...

      try {
        // Logica Otimizada: Limite de 500 itens para evitar crash da UI
        var rawList = passagens.take(500).toList();

        var passagensMap = rawList
            .map((item) {
              if (item is Map) return Map<String, dynamic>.from(item);
              if (item is String) {
                return jsonDecode(item) as Map<String, dynamic>;
              }
              return <String, dynamic>{};
            })
            .where((p) => p.isNotEmpty)
            .map((p) {
              // Processar link_foto se existir
              if (p.containsKey('link_foto') &&
                  p['link_foto'] != null &&
                  p['link_foto'].toString().isNotEmpty) {
                // Se tem link_foto, usar diretamente (já é uma URL)
                p['foto'] = p['link_foto'];
              }

              return p;
            })
            .toList();

        final passagensEnriquecidas =
            _enriquecerPassagensComDadosUnidade(passagensMap);
        final passagensOrdenadas =
            List<Map<String, dynamic>>.from(passagensEnriquecidas);
        passagensOrdenadas.sort((a, b) {
          final dataA = _parseDataPassagem(a);
          final dataB = _parseDataPassagem(b);
          return dataB.compareTo(dataA); // Mais recente primeiro
        });

        if (!mounted) return;

        print(
            '📊 [SignalR] Processado: ${passagens.length} recebidos -> ${passagensMap.length} aceitos');
        print(
            '📊 [SignalR] Passagens ordenadas: ${passagensOrdenadas.length} itens');
        print('📊 [SignalR] Primeiros 2 itens ordenados:');
        for (var i = 0;
            i < (passagensOrdenadas.length > 2 ? 2 : passagensOrdenadas.length);
            i++) {
          print(
              '   [$i]: ${passagensOrdenadas[i]['nome']} - ${passagensOrdenadas[i]['data']}');
        }

        setState(() {
          _todasPassagens = passagensOrdenadas;
          _passagens = passagensOrdenadas;
          if (!_isUsingHistorico()) {
            _historicoFiltrado = passagensOrdenadas;
          }
          print('✅ [SignalR] setState EXECUTADO!');
          print('   - _todasPassagens.length: ${_todasPassagens.length}');
          print('   - _passagens.length: ${_passagens.length}');
          print('   - _historicoFiltrado.length: ${_historicoFiltrado.length}');
        });
      } catch (e) {
        print('🔴 [SignalR] Erro procesamento lista: $e');
      }
    }

    if (!mounted) return;
  }

  @override
  void dispose() {
    _documentoDebounceTimer?.cancel();
    _cadastroDebounceTimer?.cancel();
    _passagensDebounceTimer?.cancel();
    _focusDebounceTimer?.cancel();
    _cadastroUpdateDebounceTimer?.cancel();
    _placaController.dispose();
    _modeloController.dispose();
    _obsController.dispose();
    _autorizanteController.dispose();
    _empresaController.dispose();
    _documentoController.dispose();
    _nomeController.dispose();
    _filtroSaidasController.dispose();
    _filtroDataController.dispose();
    _filtroNomeSaidasController.dispose();
    _filtroDocumentoSaidasController.dispose();
    _filtroPlacaSaidasController.dispose();
    _filtroUnidadeSaidasController.dispose();
    _documentoFocusNode.dispose();
    _nomeFocusNode.dispose();
    _autorizanteFocusNode.dispose();
    _empresaFocusNode.dispose();
    _placaFocusNode.dispose();
    _modeloFocusNode.dispose();

    // Limpar filtros
    _filtroDataInicioSaidas = null;
    _filtroDataFimSaidas = null;
    _obsFocusNode.dispose();
    _buscaUnidadeEncomendaController.dispose();
    _codigoBarrasEncomendaController.dispose();
    _identificacaoInternaEncomendaController.dispose();
    _observacaoEncomendaController.dispose();
    _identificacaoInternaEntregaController.dispose();
    _filtroNomeEntregaController.dispose();
    _filtroCodigoBarrasEntregaController.dispose();
    _filtroUnidadeAgendamentoController.dispose();
    _filtroNomeAgendamentoController.dispose();

    // DESTRUICAO TOTAL DA SESSAO SIGNALR

    // Limpar dados locais da tela para evitar vazamentos
    _todasPassagens.clear();
    _passagens.clear();
    _historicoFiltrado.clear();

    super.dispose();
  }

  // Decoraçao de input com validaçao visual
  InputDecoration _getInputDecoration(
      BuildContext context, String hintText, String campo) {
    final temErro = _mostrarErrosVisuais && _temErroNoCampo(campo);

    if (temErro) {
      return inputDecorationPadrao(context, hintText: hintText).copyWith(
        fillColor: const Color(0xFFFFEBEE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
      );
    }

    return inputDecorationPadrao(context, labelText: hintText);
  }

  // Decoraçao de input com erro visual para campos obrigatórios
  InputDecoration _getInputDecorationComErro(
      BuildContext context, String hintText, String campo, bool temErro) {
    InputDecoration decoration =
        inputDecorationPadrao(context, hintText: hintText);

    // Se o texto termina com *, cria um label com asterisco vermelho
    if (hintText.endsWith(' *')) {
      final text = hintText.substring(0, hintText.length - 2);
      final isDark = isDarkMode(context);

      decoration = inputDecorationPadrao(
        context,
        label: RichText(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
              fontSize: 16,
            ),
            children: const [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
      );
    }

    if (temErro) {
      return decoration.copyWith(
        fillColor: const Color(0xFFFFEBEE),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2.5),
        ),
      );
    }

    return decoration;
  }

  // Verifica se um campo específico tem erro de validaçao
  bool _temErroNoCampo(String campo) {
    return switch (campo) {
      'documento' => _documentoController.text.trim().isEmpty,
      'nome' => _nomeController.text.trim().isEmpty,
      'autorizante' => _autorizanteController.text.trim().isEmpty,
      'empresa' => _tipoPessoa == 0 && _empresaController.text.trim().isEmpty,
      'unidade' => _selectedUnidade == null,
      // Marca e cor só sá£o obrigatórios se algum foi selecionado
      'marca' => (_selectedMarca != null || _selectedCor != null) &&
          _selectedMarca == null,
      'cor' => (_selectedMarca != null || _selectedCor != null) &&
          _selectedCor == null,
      // Veículo só é obrigatório se marca ou cor foi selecionado
      'placa' => (_selectedMarca != null || _selectedCor != null) &&
          _placaController.text.trim().isEmpty,
      'modelo' => (_selectedMarca != null || _selectedCor != null) &&
          _modeloController.text.trim().isEmpty,
      // Vaga e crachá não sá£o obrigatórios
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Armazenar contexto do Dashboard para uso em funá§ões globais
    _dashboardContext = context;

    // Sempre inicializar ção global para abrir painel lateral no build
    // Isso garante que a ção esteja sempre disponível quando chamada
    abrirPainelLateralGlobal = (Widget painel) => _abrirPainelLateral(painel);

    // Inicializar ção global para fechar painel lateral também
    if (_painelLateralOverlay == null) {
      fecharPainelLateralGlobal = () {};
    } else {
      fecharPainelLateralGlobal = () => _fecharPainelLateral();
    }

    // Inicializar ção global para atualizar convidado após entrada
    removerConvidadoGlobal = (String reservaconvidadoId) async {
      // Buscar novamente os convidados da API para atualizar a data/hora da entrada
      if (_reservaSelecionada != null) {
        final reservaId = _reservaSelecionada!['id_pai']?.toString() ?? '';
        if (reservaId.isNotEmpty) {
          await _buscarConvidadosReserva(int.tryParse(reservaId) ?? 0);
          // Atualizar o painel com os dados atualizados
          if (_convidadosReserva.isNotEmpty) {
            _abrirPainelConvidados(_convidadosReserva);
          }
        }
      }
    };

    // Inicializar ção global para restaurar painel anterior
    restaurarPainelAnteriorGlobal = () {
      // Verificar se há um painel anterior para restaurar (caso de câmera sobre outro painel)
      if (_painelAnteriorOverlay != null) {
        _painelLateralOverlay?.remove();
        _painelLateralOverlay = _painelAnteriorOverlay;
        fecharPainelLateralGlobal = _fecharPainelAnteriorFunction ?? (() {});
        _painelAnteriorOverlay = null;
        _fecharPainelAnteriorFunction = null;
      }
    };

    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLayout =
        screenWidth <= 1366; // Detecta tablets e telas menores

    return Container(
      color: getBackgroundColor(context),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              top: 0, // Alinhado com o topo da sidebar
              right: 20,
              bottom: 20,
            ),
            child:
                isTabletLayout ? _buildTabletLayout() : _buildDesktopLayout(),
          ),
          // Indicador de página removido no modo tablet
          // Botão flutuante sobreposto aos cards e alinhado com sidebar
          if (isTabletLayout)
            FloatingNavigationButton(
              currentPage: _currentPage,
              onTogglePage: _togglePage,
              totalPages: 3,
            ),
          // Botoeiras FAB integrado na Stack
          if (_hasBotoeiras)
            EquipamentosFAB(fabLeftPosition: _computeFabLeft()),
        ],
      ),
    );
  }

  // Variável para armazenar o contexto do Dashboard
  BuildContext? _dashboardContext;

  Widget _buildPageIndicator() {
    return Positioned(
      top: 20,
      left: 20,
      right: 20,
      child: Container(
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: getBackgroundColor(context).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicadores de página interativos
              Row(
                children: List.generate(2, (index) {
                  final isActive = index == _currentPage;
                  final pageLabels = ['Passagens/Saídas', 'Unidades'];
                  final pageIcons = [Icons.meeting_room, Icons.home_rounded];

                  return Tooltip(
                    message: pageLabels[index],
                    waitDuration: const Duration(milliseconds: 300),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 120 : 32,
                        height: isActive ? 8 : 32,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.circular(isActive ? 16 : 8),
                          color: isActive
                              ? (index == 0
                                  ? const Color(0xFF7C4DFF)
                                      .withValues(alpha: 0.15)
                                  : const Color(0xFF4CAF50)
                                      .withValues(alpha: 0.15))
                              : Colors.grey.shade300,
                          border: Border.all(
                            color: isActive
                                ? (index == 0
                                    ? const Color(0xFF7C4DFF)
                                    : const Color(0xFF4CAF50))
                                : Colors.grey.shade400,
                            width: 1,
                          ),
                        ),
                        child: isActive
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    pageIcons[index],
                                    size: 14,
                                    color: index == 0
                                        ? const Color(0xFF7C4DFF)
                                        : const Color(0xFF4CAF50),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      pageLabels[index],
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: index == 0
                                            ? const Color(0xFF7C4DFF)
                                            : const Color(0xFF4CAF50),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Icon(
                                  pageIcons[index],
                                  size: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    // Layout Tabulado para tablet
    // Página 0: Entrada e Passagens (Principais)
    // Página 1: Unidades
    // Página 2: ConectCon IA

    // Verificar permissões
    final showEntrada =
        PermissionService().hasPermission(40); // Registro de Entrada
    final showUnidades = PermissionService().hasPermission(32); // Unidades

    if (_currentPage == 0) {
      List<Widget> children = [];
      if (showEntrada) {
        children.add(Expanded(child: _panelEntradaSaidas()));
        children.add(const VerticalSeparator());
      }
      children.add(Expanded(child: _panelPassagens()));

      if (children.isEmpty) return const Center(child: Text("Sem acesso"));

      if (children.isNotEmpty && children.last.key == const Key('separator')) {
        children.removeLast();
      }

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    } else if (_currentPage == 1) {
      if (!showUnidades) return const Center(child: Text("Sem acesso"));

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _panelUnidades()),
        ],
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _panelConectConIA()),
        ],
      );
    }
  }

  Widget _buildDesktopLayout() {
    // Verificar permissões
    final showEntrada =
        PermissionService().hasPermission(40); // Registro de Entrada
    final showUnidades = PermissionService().hasPermission(32); // Unidades

    List<Widget> children = [];

    if (showEntrada) {
      children.add(Expanded(child: _panelEntradaSaidas()));
      children.add(const VerticalSeparator());
    }

    children.add(Expanded(child: _panelPassagens()));

    if (showUnidades) {
      children.add(const VerticalSeparator());
      children.add(Expanded(child: _panelUnidades()));
    }

    children.add(const VerticalSeparator());
    children.add(Expanded(child: _panelConectConIA()));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  void _togglePage() {
    setState(() {
      _currentPage = (_currentPage + 1) % 3;
    });
  }

  Widget _buildStandardCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    String? photoBase64,
    required List<Widget> actions,
    Widget? extraContent,
    String? uniqueKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isRevealed =
        uniqueKey != null && _revealedPii.contains('${uniqueKey}_nome');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  bottomLeft: Radius.circular(11),
                ),
                child:
                    _buildCardPhoto(photoBase64, isDark, uniqueKey: uniqueKey),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (uniqueKey != null) {
                          setState(() {
                            _revealedPii.add('${uniqueKey}_nome');
                          });
                        }
                      },
                      child: Text(
                        isRevealed ? title : _maskName(title),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: getSecondaryTextColor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (extraContent != null) ...[
                      const SizedBox(height: 8),
                      extraContent,
                    ],
                  ],
                ),
              ),
            ),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardPhoto(String? photoBase64, bool isDark,
      {String? uniqueKey}) {
    final bool isRevealed =
        uniqueKey != null && _revealedPii.contains(uniqueKey);

    Widget buildImage() {
      if (photoBase64 != null &&
          photoBase64.isNotEmpty &&
          photoBase64 != 'null') {
        try {
          if (photoBase64.startsWith('http')) {
            return Image.network(
              photoBase64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const PhotoPlaceholder(),
            );
          }
          final bytes = _safeBase64Decode(photoBase64);
          if (bytes != null) {
            return Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const PhotoPlaceholder(),
            );
          }
        } catch (e) {
          return const PhotoPlaceholder();
        }
      }
      return const PhotoPlaceholder();
    }

    if (!isRevealed &&
        photoBase64 != null &&
        photoBase64.isNotEmpty &&
        photoBase64 != 'null') {
      return GestureDetector(
        onTap: () {
          if (uniqueKey != null) {
            setState(() {
              _revealedPii.add(uniqueKey);
            });
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagem desfocada ou placeholder elegante
            Container(
              color: isDark ? Colors.black45 : Colors.grey[200],
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.visibility_off_outlined,
                        size: 24,
                        color: isDark ? Colors.white54 : Colors.grey[600]),
                    const SizedBox(height: 4),
                    const Text('Ver Foto',
                        style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return buildImage();
  }

  // Painel 2 - Avulso + Agendamentos
  Widget _panelEntradaSaidas() {
    return DashboardCard(
      child: FocusScope(
        key: _panelEntradaSaidasKey, // 👈 VINCULE A CHAVE REAL AQUI!
        canRequestFocus: true,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Segmented control: Avulso / Agendamentos / Saídas no topo
              SegmentedTabBar(
                labels: const ['Avulso', 'Agendamentos', 'Saídas'],
                tooltips: const [
                  'Entrada de avulsos',
                  'Entrada de agendamentos',
                  'Saída de visitantes e colaboradores'
                ],
                selected: _tabAvulsoAgendamentosSaidas,
                onChanged: (i) {
                  setState(() {
                    _tabAvulsoAgendamentosSaidas = i;

                    if (i == 2) {
                      // Saídas - carregar API passagemhistorico
                      _fetchPassagens();
                    } else {
                      // Avulso (0) ou Agendamentos (1)
                      // Limpar todos os campos ao trocar entre Avulso e Agendamentos
                      _filtroDocumentoEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      _filtroUnidadeEntradaController.clear();
                      _unidadeFiltroSelecionada = null;
                      _unidadeFiltroAplicada = null;
                      _filtroDataEntrada = null;
                      _filtroDataInicioEntrada = null;
                      _filtroDataFimEntrada = null;
                      _erroDocumentoEntrada = false;
                      _erroNomeEntrada = false;
                      _erroDataEntrada = false;
                      _mostrarFormEntrada = false;
                      _espacosSociaisSelecionadosFiltro.clear();
                      _isNovoUsuario = false;
                      _isAgendamento = false;
                      _unidadeAgendamento = null;
                      _convidadosResultados.clear();
                      _cardsExpandidos.clear();

                      _tipoFiltroEntrada = i;
                      // Limpar seleá§ões de espaá§os sociais ao mudar de tipo
                      if (i == 0) {
                        _filtroEntradaMinimizado =
                            false; // Mostrar filtros no modo Avulso
                      } else {
                        _filtroEntradaMinimizado =
                            false; // Expandir no modo Agendamentos
                        // Ao mudar para agendamentos, carregar espaá§os sociais se ainda não foram carregados
                        if (_espacosSocialList.isEmpty &&
                            !_loadingEspacosSocial) {
                          _buscarEspacosSociaisParaFiltro();
                        } else {
                          // Se já foram carregados, apenas marcar todos os cards como selecionados
                          setState(() {
                            _espacosSociaisSelecionadosFiltro.clear();
                            for (final espaco in _espacosSocialList) {
                              final id =
                                  espaco['espacopublico_id'] as int? ?? 0;
                              _espacosSociaisSelecionadosFiltro[id] = true;
                            }
                          });
                        }
                      }
                    }
                  });
                },
                color: const Color(0xFF00C853),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _tabAvulsoAgendamentosSaidas == 2
                    ? _saidasList() // Mostrar lista de saídas
                    : Column(
                        children: [
                          // Filtros (sempre visíveis)
                          _buildFiltrosEntrada(),
                          const SizedBox(height: 12),
                          // Lista de Resultados Inline
                          if (_convidadosResultados.isNotEmpty &&
                              !_mostrarFormEntrada)
                            Expanded(child: _buildListaConvidadosResultados()),

                          // Formulário de entrada (mostrado apenas quando não há busca ativa E form requisitado)
                          if (_mostrarFormEntrada)
                            Expanded(child: _entradaForm()),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

// Adicionei o parâmetro condominioId na função chamadora
  Widget _panelConectConIA() {
    return DashboardCard(
      child: FocusScope(
        canRequestFocus: true,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    SegmentedTabBar(
                      labels: const ['NOVIA-X'],
                      // ADICIONE A PROPRIEDADE ICONS AQUI 👇
                      tooltips: const ['Assistente de IA ConectCon'],
                      selected: 0,
                      onChanged: (_) {},
                      color: const Color(0xFF6F34C4),
                    ),
                    // Passando o ID para o painel e fechando o parêntese corretamente
                    Expanded(
                      child: ConectConIAPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Painel 3 - Unidades (isolado)
  Widget _panelUnidades() {
    return DashboardCard(
      child: FocusScope(
        canRequestFocus: true,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    // Painel de unidades (expandido)
                    Expanded(child: _unidadesPanel()),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para listar resultados da busca inline
  Widget _buildListaConvidadosResultados() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Filtrar lista baseado na aba selecionada para garantir isolamento absoluto
    final filteredList = _convidadosResultados.where((c) {
      final origemTab = c['origem_tab'] ?? 0;
      // Só mostramos o registro se a origem dele bate com a aba atual
      return origemTab == _tabAvulsoAgendamentosSaidas;
    }).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const ClampingScrollPhysics(),
      itemCount: filteredList.length,
      itemBuilder: (context, index) {
        final convidado = filteredList[index];
        final uniqueKey = convidado['id']?.toString() ??
            convidado['reserva_id']?.toString() ??
            convidado['pessoadocumento_id']?.toString() ??
            '';

        // Dados básicos
        final nome = convidado['nome'] ??
            convidado['convidado_txt'] ??
            'Nome não informado';
        final documento =
            convidado['documento'] ?? convidado['documento_txt'] ?? '';
        final unidade =
            convidado['unidade_mostra'] ?? convidado['unidade'] ?? '';
        final placa = (convidado['placa'] ?? '').toString();
        final modelo = (convidado['modelo'] ??
                convidado['veiculo'] ??
                convidado['veiculo_txt'] ??
                '')
            .toString();

        // PRIORIDADE DE FOTO:
        // 1. link_foto (Se for URL oficial do banco)
        // 2. foto (Se for base64 capturado ou mapeado anteriormente)
        String? fotoParaExibir = convidado['link_foto']?.toString();
        if (fotoParaExibir == null ||
            fotoParaExibir.isEmpty ||
            fotoParaExibir == 'null') {
          fotoParaExibir = convidado['foto']?.toString();
        }
        if (fotoParaExibir == 'null') fotoParaExibir = null;

        // Erro de foto
        final temErroFoto = _cardsComErroFoto.contains(uniqueKey);

        // Status de Entrada/Saída - Mapeamento mais robusto
        final entradaStr = (convidado['entrada'] ??
                convidado['dt_entrada'] ??
                convidado['data_entrada'] ??
                convidado['dt_ini'] ??
                '')
            .toString();
        final saidaStr = (convidado['saida'] ??
                convidado['dt_saida'] ??
                convidado['data_saida'] ??
                convidado['dt_fim'] ??
                '')
            .toString();

        bool jaDeuEntrada = entradaStr.isNotEmpty;
        bool jaDeuSaida = saidaStr.isNotEmpty;

        Color borderColor = getBorderColor(context);
        if (jaDeuEntrada && !jaDeuSaida) {
          borderColor = Colors.orange;
        } else if (jaDeuEntrada && jaDeuSaida) {
          borderColor = Colors.green;
        }
        if (temErroFoto) {
          borderColor = Colors.red;
        }

        // Verificar se cartá£o está expandido
        final isExpanded = _cardsExpandidos.contains(uniqueKey);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(minHeight: 100),
          decoration: BoxDecoration(
            color: getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: temErroFoto ? 2 : 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lado Esquerdo: Foto
                    InkWell(
                      onTap: () async {
                        final globalContext = _dashboardContext ?? context;
                        final result = await showDialog(
                          context: globalContext,
                          barrierColor: Colors.black.withValues(alpha: 0.5),
                          builder: (ctx) => const FacialCaptureModal(),
                        );

                        if (result != null && result is String) {
                          setState(() {
                            convidado['foto'] = result;
                            _cardsComErroFoto.remove(uniqueKey);
                          });
                        }
                      },
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[850] : Colors.grey[100],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(11),
                            bottomLeft: isExpanded
                                ? Radius.zero
                                : const Radius.circular(11),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(11),
                            bottomLeft: Radius.circular(11),
                          ),
                          child: _buildCardPhoto(fotoParaExibir, isDark,
                              uniqueKey: uniqueKey),
                        ),
                      ),
                    ),

                    // Lado Direito: Informações e Ações
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Informações
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                GestureDetector(
                                  onTap: () => setState(() =>
                                      _revealedPii.add('${uniqueKey}_nome')),
                                  child: Text(
                                    _revealedPii.contains('${uniqueKey}_nome')
                                        ? nome
                                        : _maskName(nome),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: getTextColor(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (documento.isNotEmpty)
                                  GestureDetector(
                                    onTap: () => setState(() =>
                                        _revealedPii.add('${uniqueKey}_doc')),
                                    child: Text(
                                      _revealedPii.contains('${uniqueKey}_doc')
                                          ? documento
                                          : _maskDocument(documento),
                                      style: TextStyle(
                                        color: getSecondaryTextColor(context),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                if (unidade.isNotEmpty)
                                  Text(
                                    unidade,
                                    style: TextStyle(
                                      color: getSecondaryTextColor(context)
                                          .withValues(alpha: 0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                if (placa.isNotEmpty || modelo.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Row(
                                      children: [
                                        Icon(Icons.directions_car_rounded,
                                            size: 14,
                                            color:
                                                getSecondaryTextColor(context)
                                                    .withValues(alpha: 0.6)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            '${modelo.isNotEmpty ? modelo : ""}${modelo.isNotEmpty && placa.isNotEmpty ? " • " : ""}$placa',
                                            style: TextStyle(
                                              color:
                                                  getSecondaryTextColor(context)
                                                      .withValues(alpha: 0.8),
                                              fontSize: 12,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Seçao Expandida (Unidade e Autorizante)
              if (isExpanded)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border(
                        top: BorderSide(color: getDividerColor(context))),
                    color: isDark ? Colors.black12 : Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Selecione os dados para Nova Entrada:',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      // Dropdown Unidade
                      buildStandardAutocomplete<Map<String, dynamic>>(
                        context: context,
                        labelText: 'Unidade',
                        items: _unidadesFiltroList,
                        itemAsString: (u) =>
                            u['unidade_mostra'] ?? u['nome'] ?? '',
                        selectedItem: _unidadeSelecionadaAvulso[uniqueKey],
                        onSelected: (val) {
                          setState(() {
                            if (val != null) {
                              _unidadeSelecionadaAvulso[uniqueKey] = val;
                              // Auto-fill autorizante com o nome do morador/pessoa da unidade
                              final autorizanteController =
                                  _autorizanteAvulsoControllers.putIfAbsent(
                                      uniqueKey, () => TextEditingController());
                              final autorizanteNome = val['nome_morador'] ??
                                  val['morador'] ??
                                  val['pessoa'] ??
                                  val['nome'] ??
                                  val['unidade_mostra'] ??
                                  '';
                              autorizanteController.text = autorizanteNome;
                            }
                          });
                        },
                        constraints:
                            const BoxConstraints(maxHeight: 200, maxWidth: 300),
                        prefixIcon: Icons.home,
                      ),
                      const SizedBox(height: 12),
                      // Campo Autorizante
                      TextField(
                        controller: _autorizanteAvulsoControllers.putIfAbsent(
                            uniqueKey, () => TextEditingController()),
                        decoration: inputDecorationPadrao(context,
                            labelText: 'Autorizante'),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TransparentIconGroup([
                            IconActionData(
                              icon: Icons.close,
                              tooltip: 'Cancelar',
                              onPressed: () {
                                setState(() {
                                  _cardsExpandidos.remove(uniqueKey);
                                });
                              },
                              color: Colors.red,
                            ),
                            IconActionData(
                              icon: Icons.check,
                              tooltip: 'Confirmar Entrada',
                              onPressed: _loadingRegistroEntrada
                                  ? null
                                  : () {
                                      final unidadeSel =
                                          _unidadeSelecionadaAvulso[uniqueKey];
                                      final autorizanteTxt =
                                          _autorizanteAvulsoControllers[
                                                      uniqueKey]
                                                  ?.text ??
                                              '';

                                      if (unidadeSel == null) {
                                        FeedbackUtils.showWarning(
                                            context: context,
                                            title: 'Atençao',
                                            message: 'Selecione uma unidade.');
                                        return;
                                      }
                                      final unidadeId = _convertToValidId(
                                              unidadeSel['id'] ??
                                                  unidadeSel['apto_id'] ??
                                                  unidadeSel['unidade_id']) ??
                                          0;

                                      if (unidadeId == 0) {
                                        FeedbackUtils.showWarning(
                                            context: context,
                                            title: 'Unidade Inválida',
                                            message:
                                                'Não foi possível identificar o ID da unidade selecionada.');
                                        return;
                                      }

                                      _registrarEntradaAvulsoSimples(
                                        convidado,
                                        unidadeId,
                                        autorizanteTxt,
                                        loadingKey: uniqueKey,
                                      );
                                    },
                              color: Colors.green,
                              isLoading: _loadingRegistroEntrada ||
                                  _loadingEntradaAvulsoKeys.contains(uniqueKey),
                              isMarked: true,
                            ),
                          ]),
                        ],
                      )
                    ],
                  ),
                ),

              // Ação (Botões) - Só mostra se NÃO estiver expandido
              if (!isExpanded)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: getDividerColor(context),
                ),
              if (!isExpanded)
                Padding(
                  padding:
                      const EdgeInsets.only(right: 16, bottom: 12, top: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TransparentIconGroup([
                        if (convidado['tipo'] == 'AG_EMPTY')
                          IconActionData(
                            icon: Icons.person_add_rounded,
                            tooltip: 'Adicionar Visitante',
                            onPressed: () =>
                                _selecionarConvidadoParaEntrada(convidado),
                            color: Colors.blue[600],
                          )
                        else ...[
                          IconActionData(
                            icon: Icons.edit,
                            tooltip: 'Editar',
                            onPressed: () =>
                                _selecionarConvidadoParaEntrada(convidado),
                            isOpaque: false,
                          ),
                          if (jaDeuEntrada && !jaDeuSaida)
                            IconActionData(
                              icon: Icons.logout,
                              tooltip: 'Registrar Saída',
                              onPressed: () async {
                                final reservaId =
                                    convidado['reserva_id']?.toString() ??
                                        convidado['id_pai']?.toString() ??
                                        '';
                                final reservaconvidadoId =
                                    convidado['reservaconvidado_id']
                                            ?.toString() ??
                                        convidado['id_filho']?.toString() ??
                                        convidado['id']?.toString() ??
                                        '';

                                if (reservaId.isEmpty ||
                                    reservaconvidadoId.isEmpty) {
                                  FeedbackUtils.showError(
                                      context: context,
                                      title: 'Erro',
                                      message: 'IDs não encontrados');
                                  return;
                                }

                                final success =
                                    await registrarEntradaSaidaGlobal(
                                        reservaId, reservaconvidadoId, false);
                                if (success) {
                                  FeedbackUtils.showSuccess(
                                      context: context,
                                      title: 'Saída Registrada',
                                      message: 'Saída realizada com sucesso!');
                                  setState(() {
                                    final agora = DateTime.now();
                                    final dataFormatada =
                                        '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}:${agora.second.toString().padLeft(2, '0')}';
                                    convidado['saida'] = dataFormatada;
                                    convidado['dt_saida'] = dataFormatada;
                                  });
                                }
                              },
                              color: Colors.red,
                            ),
                          if (!jaDeuEntrada)
                            IconActionData(
                              icon: Icons.login,
                              tooltip: 'Nova Entrada',
                              onPressed: () async {
                                // Validar campos básicos
                                final nomeVal = convidado['nome'] ??
                                    convidado['convidado_txt'];
                                final docVal = convidado['documento'] ??
                                    convidado['documento_txt'];
                                if (nomeVal == null ||
                                    nomeVal.toString().trim().isEmpty ||
                                    docVal == null ||
                                    docVal.toString().trim().isEmpty) {
                                  FeedbackUtils.showWarning(
                                      context: context,
                                      title: 'Dados Incompletos',
                                      message: 'Preencha Nome e Documento.');
                                  return;
                                }

                                // Lógica de Foto
                                String? fotoBase64 =
                                    convidado['foto']?.toString();
                                bool fotoValida = fotoBase64 != null &&
                                    fotoBase64.isNotEmpty &&
                                    fotoBase64 != 'null' &&
                                    fotoBase64.length > 50;
                                if (fotoBase64 != null &&
                                    fotoBase64.startsWith('http')) {
                                  fotoValida = true;
                                }

                                // Verificar também link_foto (foto de perfil persistente)
                                if (!fotoValida) {
                                  final linkFoto =
                                      convidado['link_foto']?.toString();
                                  if (linkFoto != null &&
                                      linkFoto.startsWith('http')) {
                                    fotoValida = true;
                                  }
                                }

                                if (!fotoValida) {
                                  // Capturar foto antes de expandir
                                  final globalContext =
                                      _dashboardContext ?? context;
                                  final result = await showDialog(
                                    context: globalContext,
                                    barrierColor:
                                        Colors.black.withValues(alpha: 0.5),
                                    builder: (ctx) =>
                                        const FacialCaptureModal(),
                                  );
                                  if (result != null && result is String) {
                                    setState(() {
                                      convidado['foto'] = result;
                                      _cardsComErroFoto.remove(uniqueKey);
                                    });
                                  } else {
                                    FeedbackUtils.showWarning(
                                        context: context,
                                        title: 'Foto Obrigatória',
                                        message:
                                            'Tire a foto para prosseguir.');
                                    return;
                                  }
                                }

                                // Lógica Agendamento vs Avulso
                                if (convidado['tipo'] == 'AG') {
                                  final entry = (convidado['entrada'] ??
                                          convidado['dt_entrada'] ??
                                          '')
                                      .toString();
                                  final exit = (convidado['saida'] ??
                                          convidado['dt_saida'] ??
                                          '')
                                      .toString();
                                  bool isNovaEntrada =
                                      entry.isEmpty && exit.isEmpty;

                                  if (isNovaEntrada) {
                                    await _registrarPrimeiraEntradaAgendamento(
                                        convidado);
                                  } else {
                                    await _realizarEntradaDireta(convidado);
                                  }
                                } else {
                                  // Apenas expandir o card (não abrir form)
                                  setState(() {
                                    _cardsExpandidos.add(uniqueKey);
                                  });
                                }
                              },
                              isMarked: true,
                              color: Colors.green,
                            ),
                          // Botá£o Entrada com ášltimo Acesso - Dentro do grupo
                          if (!jaDeuEntrada &&
                              convidado['tipo'] != 'AG' &&
                              convidado['tipo'] != 'AG_EMPTY' &&
                              unidade.isNotEmpty)
                            IconActionData(
                              icon:
                                  _loadingEntradaAvulsoKeys.contains(uniqueKey)
                                      ? Icons.hourglass_empty
                                      : Icons.history,
                              tooltip:
                                  _loadingEntradaAvulsoKeys.contains(uniqueKey)
                                      ? 'Registrando...'
                                      : 'Entrada na última unidade: $unidade',
                              isLoading:
                                  _loadingEntradaAvulsoKeys.contains(uniqueKey),
                              onPressed: _loadingEntradaAvulsoKeys
                                      .contains(uniqueKey)
                                  ? null
                                  : () async {
                                      // Validar foto antes de registrar entrada
                                      String? fotoBase64 =
                                          convidado['foto']?.toString();
                                      bool fotoValida = fotoBase64 != null &&
                                          fotoBase64.isNotEmpty &&
                                          fotoBase64 != 'null' &&
                                          fotoBase64.length > 50;
                                      if (fotoBase64 != null &&
                                          fotoBase64.startsWith('http')) {
                                        fotoValida = true;
                                      }

                                      // Verificar também link_foto
                                      if (!fotoValida) {
                                        final linkFoto =
                                            convidado['link_foto']?.toString();
                                        if (linkFoto != null &&
                                            linkFoto.isNotEmpty &&
                                            linkFoto.startsWith('http')) {
                                          fotoValida = true;
                                        }
                                      }

                                      if (!fotoValida) {
                                        // Capturar foto antes de registrar
                                        final globalContext =
                                            _dashboardContext ?? context;
                                        final result = await showDialog(
                                          context: globalContext,
                                          barrierColor: Colors.black
                                              .withValues(alpha: 0.5),
                                          builder: (ctx) =>
                                              const FacialCaptureModal(),
                                        );
                                        if (result != null &&
                                            result is String) {
                                          setState(() {
                                            convidado['foto'] = result;
                                            _cardsComErroFoto.remove(uniqueKey);
                                          });
                                        } else {
                                          FeedbackUtils.showWarning(
                                              context: context,
                                              title: 'Foto Obrigatória',
                                              message:
                                                  'Tire a foto para prosseguir.');
                                          return;
                                        }
                                      }

                                      // Tentar encontrar o ID da unidade
                                      int unidadeId = 0;

                                      // Primeiro, tentar pegar o unidade_id diretamente do convidado
                                      if (convidado['unidade_id'] != null) {
                                        unidadeId =
                                            convidado['unidade_id'] is int
                                                ? convidado['unidade_id']
                                                : int.tryParse(
                                                        convidado['unidade_id']
                                                            .toString()) ??
                                                    0;
                                        print(
                                            ' Unidade ID encontrado no convidado: $unidadeId');
                                      }

                                      // Se não encontrou, buscar na lista de unidades
                                      if (unidadeId == 0) {
                                        try {
                                          print(
                                              'Buscando unidade "$unidade" na lista de ${_unidadesFiltroList.length} unidades');

                                          final unidadeObj =
                                              _unidadesFiltroList.firstWhere(
                                            (u) {
                                              final unidadeMostra =
                                                  (u['unidade_mostra'] ??
                                                          u['nome'] ??
                                                          '')
                                                      .toString();
                                              return unidadeMostra == unidade;
                                            },
                                            orElse: () {
                                              return _unidadesFiltroList
                                                  .firstWhere(
                                                (u) {
                                                  final unidadeMostra =
                                                      (u['unidade_mostra'] ??
                                                              u['nome'] ??
                                                              '')
                                                          .toString();
                                                  return unidadeMostra
                                                      .contains(unidade);
                                                },
                                                orElse: () => {},
                                              );
                                            },
                                          );

                                          if (unidadeObj.isNotEmpty) {
                                            unidadeId = _convertToValidId(
                                                    unidadeObj['id'] ??
                                                        unidadeObj['apto_id'] ??
                                                        unidadeObj[
                                                            'unidade_id']) ??
                                                0;
                                            print(
                                                ' Unidade encontrada: ${unidadeObj['unidade_mostra']} (ID: $unidadeId)');
                                          } else {
                                            print(
                                                'Unidade não encontrada na lista');
                                          }
                                        } catch (e) {
                                          print(
                                              'Erro ao buscar ID da unidade: $e');
                                        }
                                      }

                                      if (unidadeId > 0) {
                                        print(
                                            'ðŸš€ Registrando entrada na unidade ID: $unidadeId');
                                        _registrarEntradaAvulsoSimples(
                                          convidado,
                                          unidadeId,
                                          convidado['autorizante'] ??
                                              convidado['pessoa_autorizou'] ??
                                              '',
                                          loadingKey: uniqueKey,
                                        );
                                      } else {
                                        print(
                                            'Unidade ID não encontrado. Unidade: "$unidade"');
                                        FeedbackUtils.showWarning(
                                            context: context,
                                            title: 'Unidade não identificada',
                                            message:
                                                'Ná£o foi possível identificar a unidade. Use Nova Entrada.');
                                      }
                                    },
                              color: Colors.blue,
                            ),
                        ]
                      ]),
                    ],
                  ),
                ),

              if (temErroFoto)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(
                    'Foto obrigatória para entrada!',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // API para atualizar foto do convidado (convidadoupd)
  Future<void> _apiAtualizarFoto(String id, String fotoBase64) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (condominioId.isEmpty || tokenSessao.isEmpty) return;

      final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'convidadoupd'));
      final Map<String, dynamic> params = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'id': id, // ID do convidado/reservaconvidado
        'foto': fotoBase64,
      };

      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: json.encode(params),
      );
    } catch (e) {
      print('Erro ao atualizar foto: $e');
    }
  }

  // Widget para grupo de ícones estilo Cupertino/iOS

  Widget _entradaForm() {
    // Layout responsivo com scroll interno
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Mensagem para novo usuário ou agendamento
            if (_isNovoUsuario || _isAgendamento)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isAgendamento
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  border: Border.all(
                      color: _isAgendamento
                          ? Colors.green.shade200
                          : Colors.blue.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isAgendamento ? Icons.event : Icons.badge,
                      color: _isAgendamento
                          ? Colors.green.shade600
                          : Colors.blue.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isAgendamento
                          ? 'Editando Agendamento - ${_unidadeAgendamento ?? ''}'
                          : (_tipoPessoa == 0
                              ? 'Novo Prestador'
                              : 'Novo Visitante'),
                      style: TextStyle(
                        color: _isAgendamento
                            ? Colors.green.shade800
                            : Colors.blue.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            // Campos organizados: Documento ao lado do Tipo, Nome ao lado da Unidade
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Documento
                      CharacterCounterField(
                        controller: _documentoController,
                        maxLength: 14,
                        labelText: 'Documento',
                        focusNode: _documentoFocusNode,
                        style: const TextStyle(fontSize: 16),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        decoration: _getInputDecoration(
                          context,
                          'Documento',
                          'documento',
                        ),
                        onSubmitted: (_) {
                          if (_documentoController.text.trim().length >= 6) {
                            _atualizarCadastroComDebounce();
                          }
                        },
                      ),
                      if (!_isAgendamento) ...[
                        const SizedBox(height: 12),
                        // Tipo (P. Servico | Visitante)
                        Align(
                          alignment: Alignment.centerRight,
                          child: MiniSegmented(
                            labels: const ['Prestador', 'Visitante'],
                            selected: _tipoPessoa,
                            onChanged: (i) => setState(() => _tipoPessoa = i),
                            color: const Color(0xFF2E74FF),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Nome e Sobrenome
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CharacterCounterField(
                              controller: _nomeController,
                              maxLength: 50,
                              labelText: 'Nome e Sobrenome',
                              focusNode: _nomeFocusNode,
                              style: const TextStyle(fontSize: 16),
                              decoration: _getInputDecoration(
                                context,
                                'Nome e Sobrenome',
                                'nome',
                              ),
                              onSubmitted: (_) {
                                if (_nomeController.text.trim().isNotEmpty) {
                                  _atualizarCadastroComDebounce();
                                }
                              },
                            ),
                          ),
                          // Indicador de atualizaçao
                          if (_atualizandoCadastro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF79009),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Salvando...',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (_temCadastroAvulso) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _abrirModalEditarCadastroAvulso();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF7F56D9),
                                  size: 20,
                                ),
                              ),
                            ),
                          ] else ...[
                            // Botá£o para cadastrar documento quando não tem cadastro
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _abrirModalEditarCadastroAvulso();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7F56D9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.person_add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Unidade
                      LayoutBuilder(builder: (context, constraints) {
                        return buildStandardAutocomplete<Map<String, dynamic>>(
                          context: context,
                          labelText: 'Unidade',
                          items: _unidadesList,
                          itemAsString: (option) =>
                              unidadeLabelComMorador(option),
                          selectedItem: _selectedUnidade,
                          onSelected: (value) {
                            setState(() {
                              _selectedUnidade = value;
                              if (value != null) {
                                final nomeUnidade = value['nome_morador'] ??
                                    value['morador'] ??
                                    value['pessoa'] ??
                                    value['nome'] ??
                                    value['unidade_mostra'] ??
                                    '';
                                if (nomeUnidade.toString().isNotEmpty) {
                                  _autorizanteController.text =
                                      nomeUnidade.toString();
                                }
                              }
                            });
                          },
                          constraints: constraints,
                        );
                      }),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primeira linha: Documento e Tipo (P. Serviá§o | Visitante)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: CharacterCounterField(
                              controller: _documentoController,
                              maxLength: 14,
                              labelText: 'Documento',
                              focusNode: _documentoFocusNode,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              decoration: _getInputDecoration(
                                context,
                                'Documento',
                                'documento',
                              ),
                              onSubmitted: (_) {
                                if (_documentoController.text.trim().length >=
                                    6) {
                                  _atualizarCadastroComDebounce();
                                }
                              },
                            ),
                          ),
                          if (!_isAgendamento) ...[
                            const SizedBox(width: 12),
                            MiniSegmented(
                              labels: const ['Prestador', 'Visitante'],
                              selected: _tipoPessoa,
                              onChanged: (i) => setState(() => _tipoPessoa = i),
                              color: const Color(0xFF2E74FF),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Segunda linha: Nome e Sobrenome
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CharacterCounterField(
                              controller: _nomeController,
                              maxLength: 50,
                              labelText: 'Nome',
                              focusNode: _nomeFocusNode,
                              decoration: _getInputDecoration(
                                context,
                                'Nome e Sobrenome',
                                'nome',
                              ),
                              onSubmitted: (_) {
                                if (_nomeController.text.trim().isNotEmpty) {
                                  _atualizarCadastroComDebounce();
                                }
                              },
                            ),
                          ),
                          // Indicador de atualizaçao
                          if (_atualizandoCadastro) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF79009),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Salvando...',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Terceira linha: Unidade e Saída
                      LayoutBuilder(builder: (context, constraints) {
                        return buildStandardAutocomplete<Map<String, dynamic>>(
                          context: context,
                          labelText: 'Unidade',
                          items: _unidadesList,
                          itemAsString: (option) =>
                              unidadeLabelComMorador(option),
                          selectedItem: _selectedUnidade,
                          onSelected: (value) {
                            setState(() {
                              _selectedUnidade = value;
                              if (value != null) {
                                final nomeUnidade = value['nome_morador'] ??
                                    value['morador'] ??
                                    value['pessoa'] ??
                                    value['nome'] ??
                                    value['unidade_mostra'] ??
                                    '';
                                if (nomeUnidade.toString().isNotEmpty) {
                                  _autorizanteController.text =
                                      nomeUnidade.toString();
                                }
                              }
                            });
                          },
                          constraints: constraints,
                        );
                      }),
                    ],
                  ),
            const SizedBox(height: 12),

            // Quarta linha: Autorizante e Empresa - responsiva
            _tipoPessoa == 1
                ? // Modo visitante - autorizante ocupa toda a largura
                CharacterCounterField(
                    controller: _autorizanteController,
                    labelText: 'Autorizante',
                    maxLength: 50,
                    focusNode: _autorizanteFocusNode,
                    style: const TextStyle(fontSize: 16),
                    decoration: _getInputDecoration(
                      context,
                      'Autorizante',
                      'autorizante',
                    ),
                  )
                : // Modo P.Serviá§o - autorizante e empresa lado a lado ou empilhados
                isSmallScreen
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CharacterCounterField(
                            controller: _autorizanteController,
                            labelText: 'Autorizante',
                            maxLength: 50,
                            focusNode: _autorizanteFocusNode,
                            style: const TextStyle(fontSize: 16),
                            decoration: _getInputDecoration(
                              context,
                              'Autorizante',
                              'autorizante',
                            ),
                            onSubmitted: (_) {
                              if (_autorizanteController.text
                                  .trim()
                                  .isNotEmpty) {
                                _atualizarCadastroComDebounce();
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          CharacterCounterField(
                            controller: _empresaController,
                            labelText: 'Empresa',
                            maxLength: 50,
                            focusNode: _empresaFocusNode,
                            style: const TextStyle(fontSize: 16),
                            decoration: _getInputDecoration(
                              context,
                              'Empresa',
                              'empresa',
                            ),
                            onSubmitted: (_) {
                              _atualizarCadastroComDebounce();
                            },
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: CharacterCounterField(
                              controller: _autorizanteController,
                              labelText: 'Autorizante',
                              maxLength: 50,
                              focusNode: _autorizanteFocusNode,
                              style: const TextStyle(fontSize: 16),
                              decoration: _getInputDecoration(
                                context,
                                'Autorizante',
                                'autorizante',
                              ),
                              onSubmitted: (_) {
                                if (_autorizanteController.text
                                    .trim()
                                    .isNotEmpty) {
                                  _atualizarCadastroComDebounce();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CharacterCounterField(
                              controller: _empresaController,
                              labelText: 'Empresa',
                              maxLength: 50,
                              focusNode: _empresaFocusNode,
                              style: const TextStyle(fontSize: 16),
                              decoration: _getInputDecoration(
                                context,
                                'Empresa',
                                'empresa',
                              ),
                              onSubmitted: (_) {
                                _atualizarCadastroComDebounce();
                              },
                            ),
                          ),
                        ],
                      ),
            const SizedBox(height: 12),

            // Campos de Saída (Movido para baixo de Autorizante)
            InlineSingleDatePicker(
              label: 'Saída',
              selectedDate: _dataFimSelecionada,
              onDateSelected: (date) async {
                final TimeOfDay? pickedTime = await showTimePicker(
                  context: context,
                  initialTime: _horaFimSelecionada ?? TimeOfDay.now(),
                  builder: (BuildContext context, Widget? child) {
                    return MediaQuery(
                      data: MediaQuery.of(context)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    );
                  },
                );
                if (pickedTime != null) {
                  setState(() {
                    _dataFimSelecionada = date;
                    _horaFimSelecionada = pickedTime;
                    _dataFimController.text =
                        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}:00';
                  });
                }
              },
              onClear: () {
                setState(() {
                  _dataFimSelecionada = null;
                  _horaFimSelecionada = null;
                  _dataFimController.clear();
                });
              },
            ),
            const SizedBox(height: 12),

            // Campos de veículo - sempre visíveis
            // Quarta linha: Marca e Modelo - responsiva
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _loadingMarcas
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(builder: (context, constraints) {
                              return buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText:
                                    _selectedCor != null ? 'Marca *' : 'Marca',
                                items: _marcasList,
                                itemAsString: (item) =>
                                    item['descricao'] ?? 'Marca',
                                selectedItem: _selectedMarca,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedMarca = value;
                                    // Se desmarcou a marca, desmarcar também a cor
                                    if (value == null) {
                                      _selectedCor = null;
                                    }
                                  });
                                  // Atualizar cadastro quando marca é alterada
                                  _atualizarCadastroComDebounce();
                                },
                                constraints: constraints,
                              );
                            }),
                      const SizedBox(height: 12),
                      CharacterCounterField(
                        controller: _modeloController,
                        labelText:
                            _selectedMarca != null || _selectedCor != null
                                ? 'Modelo Veículo *'
                                : 'Modelo Veículo',
                        maxLength: 30, // Corrigido para 30 conforme original
                        focusNode: _modeloFocusNode,
                        style: const TextStyle(fontSize: 16),
                        decoration: _getInputDecoration(
                          context,
                          _selectedMarca != null || _selectedCor != null
                              ? 'Modelo Veículo *'
                              : 'Modelo Veículo',
                          'modelo',
                        ),
                        onSubmitted: (_) {
                          _atualizarCadastroComDebounce();
                        },
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _loadingMarcas
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(builder: (context, constraints) {
                                return buildStandardAutocomplete<
                                    Map<String, dynamic>>(
                                  context: context,
                                  labelText: _selectedCor != null
                                      ? 'Marca *'
                                      : 'Marca',
                                  items: _marcasList,
                                  itemAsString: (item) =>
                                      item['descricao'] ?? 'Marca',
                                  selectedItem: _selectedMarca,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedMarca = value;
                                      if (value == null) {
                                        _selectedCor = null;
                                      }
                                    });
                                    _atualizarCadastroComDebounce();
                                  },
                                  constraints: constraints,
                                );
                              }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: CharacterCounterField(
                          controller: _modeloController,
                          labelText:
                              _selectedMarca != null || _selectedCor != null
                                  ? 'Modelo Veículo *'
                                  : 'Modelo Veículo',
                          maxLength: 30, // Corrigido para 30 conforme original
                          focusNode: _modeloFocusNode,
                          decoration: _getInputDecoration(
                            context,
                            _selectedMarca != null || _selectedCor != null
                                ? 'Modelo Veículo *'
                                : 'Modelo Veículo',
                            'modelo',
                          ),
                          onSubmitted: (_) {
                            _atualizarCadastroComDebounce();
                          },
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

            // Quinta linha: Placa e Cor - responsiva
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CharacterCounterField(
                        controller: _placaController,
                        labelText:
                            _selectedMarca != null || _selectedCor != null
                                ? 'Placa *'
                                : 'Placa',
                        maxLength: 8,
                        focusNode: _placaFocusNode,
                        decoration: _getInputDecoration(
                          context,
                          _selectedMarca != null || _selectedCor != null
                              ? 'Placa *'
                              : 'Placa',
                          'placa',
                        ),
                        onSubmitted: (_) {
                          _atualizarCadastroComDebounce();
                        },
                      ),
                      const SizedBox(height: 12),
                      _loadingCores
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(builder: (context, constraints) {
                              return buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText:
                                    _selectedMarca != null ? 'Cor *' : 'Cor',
                                items: _coresList,
                                itemAsString: (item) =>
                                    item['descricao'] ?? 'Cor',
                                selectedItem: _selectedCor,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedCor = value;
                                    // Se desmarcou a cor, desmarcar também a marca
                                    if (value == null) {
                                      _selectedMarca = null;
                                    }
                                  });
                                  // Atualizar cadastro quando cor é alterada
                                  _atualizarCadastroComDebounce();
                                },
                                constraints: constraints,
                              );
                            }),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: CharacterCounterField(
                          controller: _placaController,
                          labelText:
                              _selectedMarca != null || _selectedCor != null
                                  ? 'Placa *'
                                  : 'Placa',
                          maxLength: 8,
                          focusNode: _placaFocusNode,
                          decoration: _getInputDecoration(
                            context,
                            _selectedMarca != null || _selectedCor != null
                                ? 'Placa *'
                                : 'Placa',
                            'Placa',
                          ),
                          onSubmitted: (_) {
                            _atualizarCadastroComDebounce();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: _loadingCores
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(builder: (context, constraints) {
                                return buildStandardAutocomplete<
                                    Map<String, dynamic>>(
                                  context: context,
                                  labelText:
                                      _selectedMarca != null ? 'Cor *' : 'Cor',
                                  items: _coresList,
                                  itemAsString: (item) =>
                                      item['descricao'] ?? 'Cor',
                                  selectedItem: _selectedCor,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedCor = value;
                                      // Se desmarcou a cor, desmarcar também a marca
                                      if (value == null) {
                                        _selectedMarca = null;
                                      }
                                    });
                                    _atualizarCadastroComDebounce();
                                  },
                                  constraints: constraints,
                                );
                              }),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

            // Sexta linha: Vaga e Crachá - responsiva
            isSmallScreen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _loadingVagasAvulso
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(builder: (context, constraints) {
                              return buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText: 'Vaga',
                                items: _vagasAvulsoList,
                                itemAsString: (v) {
                                  final txt = (v['vaga_txt'] ??
                                          v['vaga'] ??
                                          v['vaga_nome'] ??
                                          v['descricao'] ??
                                          '')
                                      .toString();
                                  final local = (v['local'] ?? '').toString();
                                  return [txt, local]
                                      .where((e) => e.isNotEmpty)
                                      .join(' Â· ');
                                },
                                selectedItem: _selectedVagaAvulso,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedVagaAvulso = value;
                                  });
                                  _atualizarCadastroComDebounce();
                                },
                                constraints: constraints,
                              );
                            }),
                      const SizedBox(height: 12),
                      _loadingCrachas
                          ? const Center(child: CircularProgressIndicator())
                          : LayoutBuilder(builder: (context, constraints) {
                              return buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText: 'Crachá',
                                items: _crachasList,
                                itemAsString: (c) {
                                  final titulo = (c['titulo_txt'] ??
                                          c['nome'] ??
                                          c['descricao'] ??
                                          '')
                                      .toString();
                                  final texto = (c['texto'] ??
                                          c['cracha'] ??
                                          c['codigo'] ??
                                          c['id'] ??
                                          '')
                                      .toString();
                                  final partes = [titulo, texto]
                                      .where((e) => e.isNotEmpty)
                                      .join(' ');
                                  return partes;
                                },
                                selectedItem: _selectedCracha,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedCracha = value;
                                  });
                                  _atualizarCadastroComDebounce();
                                },
                                constraints: constraints,
                              );
                            }),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _loadingVagasAvulso
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(builder: (context, constraints) {
                                return buildStandardAutocomplete<
                                    Map<String, dynamic>>(
                                  context: context,
                                  labelText: 'Vaga',
                                  items: _vagasAvulsoList,
                                  itemAsString: (v) {
                                    final txt = (v['vaga_txt'] ??
                                            v['vaga'] ??
                                            v['vaga_nome'] ??
                                            v['descricao'] ??
                                            '')
                                        .toString();
                                    final local = (v['local'] ?? '').toString();
                                    return [txt, local]
                                        .where((e) => e.isNotEmpty)
                                        .join(' Â· ');
                                  },
                                  selectedItem: _selectedVagaAvulso,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedVagaAvulso = value;
                                    });
                                    _atualizarCadastroComDebounce();
                                  },
                                  constraints: constraints,
                                );
                              }),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _loadingCrachas
                            ? const Center(child: CircularProgressIndicator())
                            : LayoutBuilder(builder: (context, constraints) {
                                return buildStandardAutocomplete<
                                    Map<String, dynamic>>(
                                  context: context,
                                  labelText: 'Crachá',
                                  items: _crachasList,
                                  itemAsString: (c) {
                                    final titulo = (c['titulo_txt'] ??
                                            c['nome'] ??
                                            c['descricao'] ??
                                            '')
                                        .toString();
                                    final texto = (c['texto'] ??
                                            c['cracha'] ??
                                            c['codigo'] ??
                                            c['id'] ??
                                            '')
                                        .toString();
                                    final partes = [titulo, texto]
                                        .where((e) => e.isNotEmpty)
                                        .join(' ');
                                    return partes;
                                  },
                                  selectedItem: _selectedCracha,
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedCracha = value;
                                    });
                                    _atualizarCadastroComDebounce();
                                  },
                                  constraints: constraints,
                                );
                              }),
                      ),
                    ],
                  ),
            const SizedBox(height: 12),

            // Campo de Observaçao
            // Campo de Observaçao e Botões na mesma linha
            // Campo de Observaçao (Linha Padrá£o)
            CharacterCounterField(
              controller: _obsController,
              labelText: 'Observação',
              maxLength: 255,
              focusNode: _obsFocusNode,
              style: const TextStyle(fontSize: 16),
              maxLines: 1, // Solicitado: Linha padrão como as demais
              decoration: _getInputDecoration(
                context,
                'Observação',
                'observacao',
              ),
              onSubmitted: (_) {
                if (_obsController.text.trim().isNotEmpty) {
                  _atualizarCadastroComDebounce();
                }
              },
            ),
            const SizedBox(height: 12),

            // Botões de Açao (Abaixo, alinhados á  direita)
            Align(
              alignment: Alignment.centerRight,
              child: TransparentIconGroup([
                IconActionData(
                  icon: Symbols.close,
                  tooltip: 'Cancelar',
                  color: Colors.red,
                  onPressed: () {
                    _limparFormulario();
                    _fecharFormulario();
                  },
                ),
                IconActionData(
                  icon: Symbols.ink_eraser,
                  tooltip: 'Limpar formulário',
                  color: IconColors.delete(context),
                  onPressed: _limparFormulario,
                ),
                IconActionData(
                  icon: Symbols.photo_camera,
                  tooltip: 'Tirar foto do rosto',
                  onPressed: _tirarFotoRosto,
                  isMarked: _fotoRostoEntrada != null,
                ),
                if (_reservaSelecionada == null) // Somente AVULSO
                  IconActionData(
                    icon: Symbols.document_scanner,
                    tooltip: 'Tirar foto do documento',
                    onPressed: _tirarFotoDocumento,
                    isMarked: _fotoDocumentoEntrada != null,
                  ),
                IconActionData(
                  icon: Icons.note_add_outlined,
                  color: Colors.green,
                  tooltip: 'Salvar dados',
                  onPressed: _loadingRegistroEntrada ? null : _salvarDados,
                  isLoading: _loadingRegistroEntrada,
                  isOpaque: false,
                ),
              ]),
            ),

            const SizedBox(height: 16),

            // Seçao de fotos capturadas (abaixo das observaá§ões)
            if (_fotoRostoEntrada != null || _fotoDocumentoEntrada != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: getCardColor(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: getBorderColor(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Foto Capturada',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Foto do rosto
                        if (_fotoRostoEntrada != null)
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Rosto',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: RepaintBoundary(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _fotoRostoEntrada!
                                              .startsWith('http')
                                          ? Image.network(
                                              _fotoRostoEntrada!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade100,
                                                  child: const Icon(
                                                    Icons.person_outline,
                                                    color: Colors.grey,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            )
                                          : () {
                                              final bytes = _safeBase64Decode(
                                                  _fotoRostoEntrada);
                                              if (bytes != null) {
                                                return Image.memory(
                                                  bytes,
                                                  fit: BoxFit.cover,
                                                  frameBuilder: (context,
                                                      child,
                                                      frame,
                                                      wasSynchronouslyLoaded) {
                                                    return child; // Sem animaçao para evitar piscar
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: const Icon(
                                                        Icons.person_outline,
                                                        color: Colors.grey,
                                                        size: 40,
                                                      ),
                                                    );
                                                  },
                                                );
                                              }
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: const Icon(
                                                  Icons.person_outline,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              );
                                            }(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_fotoRostoEntrada != null &&
                            _fotoDocumentoEntrada != null)
                          const SizedBox(width: 12),

                        // Foto do documento
                        if (_fotoDocumentoEntrada != null)
                          Expanded(
                            child: Column(
                              children: [
                                const Text(
                                  'Documento',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border:
                                        Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: RepaintBoundary(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _fotoDocumentoEntrada!
                                              .startsWith('http')
                                          ? Image.network(
                                              _fotoDocumentoEntrada!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return Container(
                                                  color: Colors.grey.shade100,
                                                  child: const Icon(
                                                    Icons
                                                        .document_scanner_outlined,
                                                    color: Colors.grey,
                                                    size: 40,
                                                  ),
                                                );
                                              },
                                            )
                                          : () {
                                              final bytes = _safeBase64Decode(
                                                  _fotoDocumentoEntrada);
                                              if (bytes != null) {
                                                return Image.memory(
                                                  bytes,
                                                  fit: BoxFit.cover,
                                                  frameBuilder: (context,
                                                      child,
                                                      frame,
                                                      wasSynchronouslyLoaded) {
                                                    return child; // Sem animaçao para evitar piscar
                                                  },
                                                  errorBuilder: (context, error,
                                                      stackTrace) {
                                                    return Container(
                                                      color:
                                                          Colors.grey.shade100,
                                                      child: const Icon(
                                                        Icons
                                                            .document_scanner_outlined,
                                                        color: Colors.grey,
                                                        size: 40,
                                                      ),
                                                    );
                                                  },
                                                );
                                              }
                                              return Container(
                                                color: Colors.grey.shade100,
                                                child: const Icon(
                                                  Icons
                                                      .document_scanner_outlined,
                                                  color: Colors.grey,
                                                  size: 40,
                                                ),
                                              );
                                            }(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

            if (_fotoRostoEntrada != null || _fotoDocumentoEntrada != null)
              const SizedBox(height: 20),

            // Botões de açao - X primeiro, último opaco (registrar) dentro do mesmo grupo
            // Botões de açao movidos para cima junto com observaçao
          ],
        ),
      ),
    );
  }

  Widget _infoCard(
      {required String label,
      required String value,
      required IconData icon,
      required Color color}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _getUltimaSaida() {
    if (_todasPassagens.isEmpty) return 'N/A';

    // Encontrar passagens com data de saída (que já saíram)
    final saidas = _todasPassagens
        .where(
            (p) => p['dt_saida'] != null && p['dt_saida'].toString().isNotEmpty)
        .toList();
    if (saidas.isEmpty) return 'Nenhuma';

    // Ordenar por data de saída mais recente
    saidas.sort((a, b) {
      final dtA = a['dt_saida']?.toString() ?? '';
      final dtB = b['dt_saida']?.toString() ?? '';
      return dtB.compareTo(dtA);
    });

    final ultima = saidas.first;
    final nome = (ultima['nome'] ?? '').toString();
    final nomeCurto = nome.length > 10 ? '${nome.substring(0, 10)}...' : nome;

    return nomeCurto.isNotEmpty ? nomeCurto : 'N/A';
  }

  String _formatarDataParaDisplay(DateTime date) {
    final dataStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    final horaStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return '$dataStr $horaStr';
  }

  DateTime? _parseDateTime(String dataHora) {
    if (dataHora.isEmpty) return null;
    try {
      // Tentar diferentes formatos
      if (dataHora.contains('-')) {
        final partes = dataHora.split(' ');
        if (partes.length >= 2) {
          final dataPartes = partes[0].split('-');
          final horaPartes = partes[1].split(':');
          if (dataPartes.length == 3 && horaPartes.length >= 2) {
            return DateTime(
              int.parse(dataPartes[2]),
              int.parse(dataPartes[1]),
              int.parse(dataPartes[0]),
              int.parse(horaPartes[0]),
              int.parse(horaPartes[1]),
            );
          }
        }
      }
      return DateTime.parse(dataHora);
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> _getTodasPassagensFiltradas() {
    // Se não há filtros, não retornar nada (apagar resultados ao limpar)
    if (_filtroNomeSaidasController.text.trim().isEmpty &&
        _filtroDocumentoSaidasController.text.trim().isEmpty &&
        _filtroPlacaSaidasController.text.trim().isEmpty &&
        _filtroUnidadeSaidasController.text.trim().isEmpty &&
        _filtroDataInicioSaidas == null &&
        _filtroDataFimSaidas == null) {
      return [];
    }

    return _todasPassagens.where((passagem) {
      // Filtrar por nome
      if (_filtroNomeSaidasController.text.trim().isNotEmpty) {
        final nome = (passagem['nome'] ?? '').toString().toLowerCase();
        if (!nome
            .contains(_filtroNomeSaidasController.text.trim().toLowerCase())) {
          return false;
        }
      }

      // Filtrar por documento
      if (_filtroDocumentoSaidasController.text.trim().isNotEmpty) {
        final documento =
            (passagem['documento'] ?? '').toString().toLowerCase();
        if (!documento.contains(
            _filtroDocumentoSaidasController.text.trim().toLowerCase())) {
          return false;
        }
      }

      // Filtrar por placa
      if (_filtroPlacaSaidasController.text.trim().isNotEmpty) {
        final placa = (passagem['placa'] ?? '').toString().toLowerCase();
        if (!placa
            .contains(_filtroPlacaSaidasController.text.trim().toLowerCase())) {
          return false;
        }
      }

      // Filtrar por unidade
      if (_filtroUnidadeSaidasController.text.trim().isNotEmpty) {
        final torre = (passagem['torre'] ?? '').toString().toLowerCase();
        final numero = (passagem['numero'] ?? '').toString().toLowerCase();
        final unidade = '$torre $numero'.trim().toLowerCase();
        if (!unidade.contains(
            _filtroUnidadeSaidasController.text.trim().toLowerCase())) {
          return false;
        }
      }

      // Filtrar por data (saídas)
      if (_filtroDataInicioSaidas != null || _filtroDataFimSaidas != null) {
        final saida = _parseDateTime(passagem['dt_saida']?.toString() ?? '');
        if (saida != null) {
          // Se temos data de início, verificar se a saída é posterior ou igual
          if (_filtroDataInicioSaidas != null) {
            final inicio = DateTime(_filtroDataInicioSaidas!.year,
                _filtroDataInicioSaidas!.month, _filtroDataInicioSaidas!.day);
            final dataSaida = DateTime(saida.year, saida.month, saida.day);
            if (dataSaida.isBefore(inicio)) return false;
          }

          // Se temos data de fim, verificar se a saída é anterior ou igual
          if (_filtroDataFimSaidas != null) {
            final fim = DateTime(
                _filtroDataFimSaidas!.year,
                _filtroDataFimSaidas!.month,
                _filtroDataFimSaidas!.day,
                23,
                59,
                59);
            if (saida.isAfter(fim)) return false;
          }
        }
      }

      return true;
    }).toList();
  }
  // Painel 2 - Passagens / Histórico

  // Conteúdo das passagens (sem cabeá§alho segmented)
  Widget _passagensHistoricoContent() {
    return Expanded(
      child: Column(
        children: [
          // Filtros sempre visíveis para passagens (com key para evitar rebuilds incorretos)
          // Filtros de histórico inline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getFormGrisColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: getBorderColor(context)),
            ),
            child: Column(
              children: [
                // Primeira linha: Documento (linha inteira)
                Row(
                  children: [
                    Expanded(
                      child: CharacterCounterField(
                        controller: _filtroDocumentoHistoricoController,
                        labelText: 'Documento',
                        maxLength: 14,
                        decoration: inputDecorationPadrao(context,
                            hintText: 'Documento'),
                        onSubmitted: (_) => _buscarHistoricoFiltrado(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Segunda linha: Nome e Sobrenome (linha inteira)
                Row(
                  children: [
                    Expanded(
                      child: CharacterCounterField(
                        controller: _filtroNomeHistoricoController,
                        labelText: 'Nome e Sobrenome',
                        maxLength: 50,
                        decoration: inputDecorationPadrao(context,
                            hintText: 'Nome e Sobrenome'),
                        onSubmitted: (_) => _buscarHistoricoFiltrado(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Terceira linha: Unidade e Placa
                Row(
                  children: [
                    Expanded(
                      child: CharacterCounterField(
                        controller: _filtroUnidadeHistoricoController,
                        labelText: 'Unidade',
                        maxLength: 20,
                        decoration:
                            inputDecorationPadrao(context, hintText: 'Unidade'),
                        onSubmitted: (_) => _buscarHistoricoFiltrado(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CharacterCounterField(
                        controller: _filtroPlacaHistoricoController,
                        labelText: 'Placa',
                        maxLength: 7,
                        decoration:
                            inputDecorationPadrao(context, hintText: 'Placa'),
                        onSubmitted: (_) => _buscarHistoricoFiltrado(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Terceira linha: Período
                _buildPeriodFilter(
                  context: context,
                  startDate: _filtroDataInicioHistorico,
                  endDate: _filtroDataFimHistorico,
                  onStartDateChanged: (date) =>
                      setState(() => _filtroDataInicioHistorico = date),
                  onEndDateChanged: (date) =>
                      setState(() => _filtroDataFimHistorico = date),
                ),
                const SizedBox(height: 12),
                // Botões de açao
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TransparentIconGroup([
                      IconActionData(
                        icon: Symbols.ink_eraser,
                        tooltip: 'Limpar filtros',
                        color: IconColors.delete(context),
                        onPressed: () {
                          setState(() {
                            _filtroNomeHistoricoController.clear();
                            _filtroDocumentoHistoricoController.clear();
                            _filtroPlacaHistoricoController.clear();
                            _filtroUnidadeHistoricoController.clear();
                            _filtroDataInicioHistorico = null;
                            _filtroDataFimHistorico = null;
                          });
                          _buscarHistoricoFiltrado();
                        },
                      ),
                      IconActionData(
                        icon: Symbols.search,
                        tooltip: 'Pesquisar',
                        color: IconColors.search(context),
                        onPressed: _loadingHistorico
                            ? null
                            : () => _buscarHistoricoFiltrado(),
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: _getPassagensLoading()
                ? const Center(child: CircularProgressIndicator())
                : _getPassagensList().isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        key: const ValueKey('lista_passagens'),
                        itemCount: _getPassagensList().length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final passagem = _getPassagensList()[index];
                          final nome =
                              (passagem['nome'] ?? 'Visitante').toString();
                          final unidade = (passagem['unidade'] ??
                                  passagem['destino'] ??
                                  passagem['torre'] ??
                                  '')
                              .toString();
                          final leitor =
                              (passagem['leitor_ds'] ?? '').toString();
                          final data =
                              (passagem['data'] ?? passagem['dt_ini'] ?? '')
                                  .toString();

                          final itemKey = 'pass_${passagem['id'] ?? index}';
                          return _buildStandardCard(
                            uniqueKey: itemKey,
                            context: context,
                            title: nome,
                            subtitle:
                                'destino: ${unidade.isNotEmpty ? unidade : 'â€”'}',
                            photoBase64: (passagem['link_foto'] ??
                                    passagem['foto'])
                                ?.toString(), // Tenta usar link_foto, senão foto
                            // Usa Container vazio para aá§ões se não houver nenhuma, ou remove o pará¢metro
                            actions: const [],
                            extraContent: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (leitor.isNotEmpty && leitor != '-')
                                  Text(
                                    leitor,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: getSecondaryTextColor(context),
                                    ),
                                  ),
                                if (data.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      'E: $data',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Painel 2 - Passagens
  Widget _panelPassagens() {
    return DashboardCard(
      child: FocusScope(
        canRequestFocus: true,
        child: FocusTraversalGroup(
          policy: WidgetOrderTraversalPolicy(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedTabBar(
                labels: const ['Passagens'],
                tooltips: const ['Passagem de usuários'],
                selected: 0,
                onChanged: (_) {},
                color: const Color(0xFF2196F3), // Azul padrão
              ),
              const SizedBox(height: 12),
              _passagensHistoricoContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _saidasList() {
    return Expanded(
      child: Column(
        children: [
          // Formulário de saída (sempre visível com key para evitar rebuilds)
          RepaintBoundary(
            key: const ValueKey('filtros_saidas'),
            child: Container(
              decoration: BoxDecoration(
                color: getFormGrisColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: getBorderColor(context)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Campos de busca e filtros
                  // Primeira linha: Documento (linha inteira)
                  Row(
                    children: [
                      Expanded(
                        child: CharacterCounterField(
                          key: const ValueKey('filtro_documento_saidas'),
                          controller: _filtroDocumentoSaidasController,
                          labelText: 'Documento',
                          maxLength: 14,
                          decoration: _getInputDecoration(
                              context, 'Documento', 'documento_saidas'),
                          enableInteractiveSelection: true,
                          readOnly: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Segunda linha: Nome e Sobrenome (linha inteira)
                  Row(
                    children: [
                      Expanded(
                        child: CharacterCounterField(
                          key: const ValueKey('filtro_nome_saidas'),
                          controller: _filtroNomeSaidasController,
                          labelText: 'Nome e Sobrenome',
                          maxLength: 50,
                          decoration: _getInputDecoration(
                              context, 'Nome e Sobrenome', 'nome_saidas'),
                          enableInteractiveSelection: true,
                          readOnly: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Terceira linha: Placa + Unidade lado a lado
                  Row(
                    children: [
                      Expanded(
                        child: CharacterCounterField(
                          key: const ValueKey('filtro_placa_saidas'),
                          controller: _filtroPlacaSaidasController,
                          labelText: 'Placa',
                          maxLength: 8,
                          decoration: _getInputDecoration(
                              context, 'Placa', 'placa_saidas'),
                          enableInteractiveSelection: true,
                          readOnly: false,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CharacterCounterField(
                          key: const ValueKey('filtro_unidade_saidas'),
                          controller: _filtroUnidadeSaidasController,
                          labelText: 'Unidade',
                          maxLength: 20,
                          decoration: _getInputDecoration(
                              context, 'Unidade', 'unidade_saidas'),
                          enableInteractiveSelection: true,
                          readOnly: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Terceira linha: Período (ocupando largura total)
                  _buildPeriodFilter(
                    context: context,
                    startDate: _filtroDataInicioSaidas,
                    endDate: _filtroDataFimSaidas,
                    onStartDateChanged: (date) =>
                        setState(() => _filtroDataInicioSaidas = date),
                    onEndDateChanged: (date) =>
                        setState(() => _filtroDataFimSaidas = date),
                  ),
                  const SizedBox(height: 12),

                  // Quarta linha: Botões de açao
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TransparentIconGroup([
                        IconActionData(
                          icon: Symbols.ink_eraser,
                          tooltip: 'Limpar filtros',
                          color: IconColors.delete(context),
                          onPressed: () {
                            _filtroNomeSaidasController.clear();
                            _filtroDocumentoSaidasController.clear();
                            _filtroPlacaSaidasController.clear();
                            _filtroUnidadeSaidasController.clear();
                            setState(() {
                              _filtroDataInicioSaidas = null;
                              _filtroDataFimSaidas = null;
                              // Limpar lista de resultados ao limpar filtros
                              _historicoFiltrado.clear();
                              _todasPassagens
                                  .clear(); // Correção: remove os resultados visíveis
                            });
                            // _fetchPassagens(); // Desativado - passagens vêm do SignalR
                          },
                        ),
                        IconActionData(
                          icon: Symbols.search,
                          tooltip: 'Pesquisar',
                          color: IconColors.search(context),
                          onPressed: _buscarSaidasFiltradas,
                          isLoading: _loadingSaidasList,
                        ),
                        IconActionData(
                          icon: Symbols.assignment_turned_in,
                          tooltip: 'Auto baixa (selecionar múltiplas)',
                          onPressed: () {
                            setState(() {
                              _modoAutoBaixa = !_modoAutoBaixa;
                              if (!_modoAutoBaixa) {
                                _itensSelecionados.clear();
                              }
                            });
                          },
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Botá£o de baixa em lote quando há itens selecionados
          if (_modoAutoBaixa && _itensSelecionados.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loadingPassagens
                    ? null
                    : () {
                        _executarBaixaEmLote();
                      },
                icon: _loadingPassagens
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.assignment_turned_in),
                label: Text(_loadingPassagens
                    ? 'Processando...'
                    : 'Baixar ${_itensSelecionados.length} selecionado(s)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF79009),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          Expanded(
            child: _loadingSaidasList
                ? const Center(child: CircularProgressIndicator())
                : _getTodasPassagensFiltradas().isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _getTodasPassagensFiltradas().length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final passagem = _getTodasPassagensFiltradas()[index];
                          final temSaida = (passagem['dt_saida'] ?? '')
                              .toString()
                              .isNotEmpty;
                          final isAtiva = !temSaida;

                          return _modoAutoBaixa && isAtiva
                              ? _listItemComCheckbox(
                                  passagem: passagem,
                                  index: index,
                                  isSelected:
                                      _itensSelecionados.contains(index),
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected) {
                                        _itensSelecionados.add(index);
                                      } else {
                                        _itensSelecionados.remove(index);
                                      }
                                    });
                                  },
                                )
                              : _buildSaidaCard(
                                  context: context,
                                  uniqueKey:
                                      'saida_${passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? index}',
                                  title: '${passagem['nome'] ?? 'Visitante'}',
                                  subtitle:
                                      '${passagem['destino'] ?? 'Torre Unidade'}${passagem['destino'] != null ? ', ' : ''}${_getTipoFormatado(passagem)}',
                                  photoBase64: (passagem['link_foto'] ??
                                          passagem['foto'])
                                      ?.toString(), // API passagemhistorico: link_foto é a foto
                                  extraContent: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (passagem['documento'] != null &&
                                          passagem['documento']
                                              .toString()
                                              .isNotEmpty)
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              final key =
                                                  'saida_${passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? index}_doc';
                                              if (_revealedPii.contains(key)) {
                                                _revealedPii.remove(key);
                                              } else {
                                                _revealedPii.add(key);
                                              }
                                            });
                                          },
                                          child: Text(
                                            _revealedPii.contains('Doc: '
                                                    'saida_${passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? index}_doc')
                                                ? passagem['documento']
                                                    .toString()
                                                : (passagem['documento']
                                                            .toString()
                                                            .length >
                                                        3
                                                    ? '${passagem['documento'].toString().substring(0, 3)}...'
                                                    : '***'),
                                            style: TextStyle(
                                              color: getSecondaryTextColor(
                                                  context),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Text(
                                            'E: ${passagem['dt_ini'] ?? ''}',
                                            style: const TextStyle(
                                                color: Colors.green,
                                                fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      if (temSaida) ...[
                                        Row(
                                          children: [
                                            const SizedBox(width: 0),
                                            Text(
                                              'S: ${passagem['dt_saida'] ?? ''}',
                                              style: const TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (passagem['placa'] != null &&
                                          passagem['placa']
                                              .toString()
                                              .isNotEmpty)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Veículo: ${passagem['placa']}',
                                            style: const TextStyle(
                                                color: Colors.blue,
                                                fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                  actions: !temSaida &&
                                          !_cardsExpandidos.contains(
                                              'saida_${passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? ''}')
                                      ? [
                                          IconActionData(
                                            icon: _loadingSaidas.contains(
                                                    passagem['id']
                                                            ?.toString() ??
                                                        passagem['passagem_id']
                                                            ?.toString())
                                                ? Icons.hourglass_empty
                                                : Icons.logout,
                                            tooltip: _loadingSaidas.contains(
                                                    passagem['id']
                                                            ?.toString() ??
                                                        passagem['passagem_id']
                                                            ?.toString())
                                                ? 'Processando saída...'
                                                : 'Registrar saída',
                                            onPressed: _loadingSaidas.contains(
                                                    passagem['id']
                                                            ?.toString() ??
                                                        passagem['passagem_id']
                                                            ?.toString())
                                                ? () {}
                                                : () => _mostrarOpcoesSaida(
                                                    passagem),
                                            color: Colors.red,
                                          ),
                                        ]
                                      : [],
                                  isExpanded: !temSaida &&
                                      _cardsExpandidos.contains(
                                          'saida_${passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? ''}'),
                                  passagem: passagem,
                                );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaidaCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required List<IconActionData> actions,
    String? photoBase64,
    Widget? extraContent,
    VoidCallback? onPhotoTap,
    bool hasError = false,
    bool isExpanded = false,
    Map<String, dynamic>? passagem,
    String? uniqueKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = hasError ? Colors.red : getBorderColor(context);

    // LGPD Masking logic
    final bool isNameMasked =
        uniqueKey != null && !_revealedPii.contains('${uniqueKey}_title');
    final bool isPhotoMasked =
        uniqueKey != null && !_revealedPii.contains('${uniqueKey}_photo');

    final String displayedTitle = isNameMasked ? _maskName(title) : title;

    // Placeholder content
    Widget photoContainer;
    if (photoBase64 != null &&
        photoBase64.isNotEmpty &&
        photoBase64 != 'null') {
      if (photoBase64.startsWith('http')) {
        photoContainer = Image.network(
          photoBase64,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const PhotoPlaceholder(),
        );
      } else {
        final bytes = _safeBase64Decode(photoBase64);
        if (bytes != null) {
          photoContainer = Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const PhotoPlaceholder(),
          );
        } else {
          photoContainer = const PhotoPlaceholder();
        }
      }
    } else {
      photoContainer = const PhotoPlaceholder();
    }

    Widget photoContent = isPhotoMasked
        ? Container(
            color: Colors.grey.shade300,
            child: const Center(
              child: Icon(Icons.lock_outline, color: Colors.grey),
            ),
          )
        : photoContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Parte superior: foto + conteúdo + ações (mesmo padrão do card de entrada)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Foto (link_foto da API passagemhistorico)
                InkWell(
                  onTap: uniqueKey != null
                      ? () {
                          setState(() {
                            final key = '${uniqueKey}_photo';
                            if (_revealedPii.contains(key)) {
                              _revealedPii.remove(key);
                            } else {
                              _revealedPii.add(key);
                            }
                          });
                        }
                      : onPhotoTap,
                  child: Container(
                    width: 80,
                    height: 1,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(11),
                        bottomLeft: isExpanded
                            ? Radius.zero
                            : const Radius.circular(11),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(11),
                        bottomLeft: isExpanded
                            ? Radius.zero
                            : const Radius.circular(11),
                      ),
                      child: photoContent,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GestureDetector(
                          onTap: uniqueKey != null
                              ? () {
                                  setState(() {
                                    final key = '${uniqueKey}_title';
                                    if (_revealedPii.contains(key)) {
                                      _revealedPii.remove(key);
                                    } else {
                                      _revealedPii.add(key);
                                    }
                                  });
                                }
                              : null,
                          child: Text(
                            displayedTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: getTextColor(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: getSecondaryTextColor(context),
                            fontSize: 12,
                          ),
                        ),
                        if (extraContent != null) ...[
                          const SizedBox(height: 2),
                          extraContent,
                        ],
                      ],
                    ),
                  ),
                ),
                if (actions.isNotEmpty && !isExpanded)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TransparentIconGroup(actions),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          // Seção expandida: mesmo padrão da entrada (borda topo, fundo cinza, botões)
          if (isExpanded && passagem != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border:
                    Border(top: BorderSide(color: getDividerColor(context))),
                color: isDark ? Colors.black12 : Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Escolha como registrar a saída:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: getTextColor(context),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TransparentIconGroup(
                      [
                        IconActionData(
                          icon: Icons.exit_to_app,
                          tooltip: 'Saída Agora',
                          color: const Color(0xFFEF4444),
                          isLoading: _loadingSaidas.contains(
                            passagem['id']?.toString() ??
                                passagem['passagem_id']?.toString(),
                          ),
                          onPressed: _loadingSaidas.contains(
                            passagem['id']?.toString() ??
                                passagem['passagem_id']?.toString(),
                          )
                              ? null
                              : () {
                                  _registrarSaida(passagem, saidaAgora: true);
                                },
                        ),
                        IconActionData(
                          icon: Icons.schedule,
                          tooltip: 'Selecionar Horário',
                          color: const Color(0xFF684F8E),
                          isOpaque: _loadingSaidas.contains(
                            passagem['id']?.toString() ??
                                passagem['passagem_id']?.toString(),
                          ),
                          onPressed: _loadingSaidas.contains(
                            passagem['id']?.toString() ??
                                passagem['passagem_id']?.toString(),
                          )
                              ? null
                              : () {
                                  _selecionarHorarioSaida(passagem);
                                },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _mediaBox(
      {required String label, required IconData icon, VoidCallback? onTap}) {
    // Verificar se há foto capturada
    final hasPhoto = (label == 'Foto do Rosto' && _fotoEntrada != null) ||
        (label == 'Foto do Documento' && _fotoDocumento != null) ||
        (label == 'Foto Encomenda' && _fotoEncomenda != null);

    // Funçao para remover foto baseada no tipo
    void removerFoto() {
      setState(() {
        if (label == 'Foto do Rosto') {
          _fotoEntrada = null;
        } else if (label == 'Foto do Documento') {
          _fotoDocumento = null;
        } else if (label == 'Foto Encomenda') {
          _fotoEncomenda = null;
        }
      });
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120, // Largura fixa
        height: 120, // Altura fixa - garante quadrado perfeito
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Stack(
          children: [
            // Verificar se é foto do rosto, documento ou encomenda e exibir imagem se capturada
            if (label == 'Foto do Rosto' && _fotoEntrada != null) ...[
              Positioned.fill(
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(_fotoEntrada!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (label == 'Foto do Documento' &&
                _fotoDocumento != null) ...[
              Positioned.fill(
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(_fotoDocumento!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else if (label == 'Foto Encomenda' && _fotoEncomenda != null) ...[
              Positioned.fill(
                child: RepaintBoundary(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: MemoryImage(_fotoEncomenda!),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: getSecondaryTextColor(context), size: 36),
                    const SizedBox(height: 6),
                    Text(label,
                        style:
                            TextStyle(color: getSecondaryTextColor(context))),
                  ],
                ),
              ),
            ],

            // Botao X para remover foto quando houver foto
            if (hasPhoto) ...[
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: removerFoto,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],

            // Texto "Foto Capturada" quando houver foto
            if (hasPhoto) ...[
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Text(
                  'Foto Capturada',
                  style: TextStyle(
                      color: isDarkMode(context)
                          ? Colors.green.shade400
                          : Colors.green.shade600,
                      fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _agendamentosList() {
    return Expanded(
      child: Column(
        children: [
          // área de filtros - seguindo padrão da tela
          Container(
            decoration: BoxDecoration(
              color: getFormGrisColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: getBorderColor(context)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Primeira linha de filtros
                Row(
                  children: [
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        return buildStandardAutocomplete<Map<String, dynamic>>(
                          context: context,
                          labelText: 'Unidade',
                          items: _unidadesList,
                          itemAsString: (option) =>
                              unidadeLabelComMorador(option),
                          selectedItem: _selectedUnidadeAgendamento,
                          onSelected: (value) {
                            setState(() {
                              _selectedUnidadeAgendamento = value;
                              if (_selectedUnidadeAgendamento != null &&
                                  _selectedUnidadeAgendamento!.isNotEmpty) {
                                _autorizanteAgendamentoController.text =
                                    _selectedUnidadeAgendamento!['nome'] ?? '';
                              } else {
                                _autorizanteAgendamentoController.clear();
                              }
                            });
                          },
                          constraints: constraints,
                        );
                      }),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: LayoutBuilder(builder: (context, constraints) {
                        return Autocomplete<Map<String, String>>(
                          initialValue: TextEditingValue(
                            text: _tipoAgendamentoSelecionado != null
                                ? (_tipoAgendamentoSelecionado!['descricao'] ??
                                    '')
                                : '',
                          ),
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return tiposAgendamentoFixos;
                            }
                            return tiposAgendamentoFixos
                                .where((Map<String, String> option) {
                              return (option['descricao'] ?? '')
                                  .toLowerCase()
                                  .contains(
                                      textEditingValue.text.toLowerCase());
                            });
                          },
                          displayStringForOption:
                              (Map<String, String> option) =>
                                  option['descricao'] ?? '',
                          onSelected: (Map<String, String> value) {
                            setState(() {
                              _tipoAgendamentoSelecionado = value;
                            });
                          },
                          fieldViewBuilder: (context, textEditingController,
                              focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: inputDecorationPadrao(context,
                                      hintText: 'Tipo')
                                  .copyWith(
                                suffixIcon: textEditingController
                                        .text.isNotEmpty
                                    ? IconButton(
                                        icon: Icon(Icons.close,
                                            size: 20,
                                            color:
                                                getSecondaryTextColor(context)),
                                        onPressed: () {
                                          textEditingController.clear();
                                          setState(() {
                                            _tipoAgendamentoSelecionado = null;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(8),
                                color: getCardColor(context),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxHeight: 200,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder:
                                        (BuildContext context, int index) {
                                      final Map<String, String> option =
                                          options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: getBorderColor(context)
                                                    .withValues(alpha: 0.5),
                                                width: 0.5,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            option['descricao'] ?? '',
                                            style: TextStyle(
                                                color: getTextColor(context),
                                                fontSize: 12),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Terceira linha: Período (ocupando largura total)
                _buildPeriodFilter(
                  context: context,
                  startDate: _filtroDataInicioSelecionada,
                  endDate: _filtroDataFimSelecionada,
                  onStartDateChanged: (date) =>
                      setState(() => _filtroDataInicioSelecionada = date),
                  onEndDateChanged: (date) =>
                      setState(() => _filtroDataFimSelecionada = date),
                ),
                const SizedBox(height: 12),

                // Quarta linha: Botões de açao
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TransparentIconGroup([
                      IconActionData(
                        icon: Symbols.ink_eraser,
                        tooltip: 'Limpar filtros',
                        color: IconColors.delete(context),
                        onPressed: () {
                          setState(() {
                            _selectedUnidadeAgendamento = null;
                            _tipoAgendamentoSelecionado = null;
                            _filtroDataInicioSelecionada = null;
                            _filtroDataFimSelecionada = null;
                          });
                          _fetchAgendamentos(isFiltro: false);
                        },
                        isLoading: _loadingAgendamentos,
                      ),
                      IconActionData(
                        icon: Symbols.search,
                        tooltip: 'Buscar agendamentos',
                        color: IconColors.search(context),
                        onPressed: () => _fetchAgendamentos(isFiltro: true),
                        isLoading: _loadingAgendamentos,
                      ),
                      IconActionData(
                        icon: Symbols.assignment,
                        tooltip: 'Filtrar',
                        color:
                            isDarkMode(context) ? Colors.white : Colors.black87,
                        onPressed: () {},
                      ),
                    ]),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingAgendamentos
                ? const Center(child: CircularProgressIndicator())
                : _getFilteredAgendamentos().isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _getFilteredAgendamentos().length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final agendamento = _getFilteredAgendamentos()[index];
                          final convidados = _quantidadeConvidados[
                                  agendamento['reserva_id']?.toString()] ??
                              0;
                          return _listItem(
                            leading: Icons.apartment_rounded,
                            title:
                                '${agendamento['espacopublico_ds'] ?? agendamento['unidade'] ?? 'Agendamento'}  Â·  ${agendamento['usuariosolicita_ds'] ?? 'Solicitante'}',
                            subtitle:
                                '${agendamento['unidade_res'] ?? 'Unidade'}',
                            extra: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'De: ${agendamento['dt_reserva_ini'] ?? agendamento['data_inicio'] ?? ''}',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                                Text(
                                  'Até: ${agendamento['dt_reserva_fim'] ?? agendamento['data_fim'] ?? ''}',
                                  style: const TextStyle(color: Colors.blue),
                                ),
                                if (convidados > 0)
                                  Text(
                                    'Convidados: $convidados',
                                    style: const TextStyle(color: Colors.green),
                                  ),
                              ],
                            ),
                            trailing: convidados > 0
                                ? MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () {
                                        final reservaId =
                                            agendamento['reserva_id'];
                                        if (reservaId != null) {
                                          _abrirSidePanelConvidados(
                                            reservaId.toString(),
                                            titulo:
                                                '${agendamento['espacopublico_ds'] ?? 'Agendamento'}\nUnidade: ${agendamento['unidade_res'] ?? 'Ná£o informado'} - Solicitante: ${agendamento['usuariosolicita_ds'] ?? 'Ná£o informado'}',
                                          );
                                        }
                                      },
                                      child: CircleIconWithBadge(
                                        Icons.group,
                                        '$convidados',
                                        color: const Color(0xFF7C4DFF),
                                      ),
                                    ),
                                  )
                                : CircleIconWithBadge(
                                    Icons.group,
                                    '0',
                                    color: const Color(0xFFBDBDBD),
                                  ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredAgendamentos() {
    // No backup, a filtragem é feita via API, não localmente
    // Retorna todos os agendamentos (já ordenados e limitados na API)
    return _agendamentos;
  }

  Widget _unidadesPanel() {
    _tabUnidades ??= 0; // default: Unidade
    return Expanded(
      child: Column(
        children: [
          // Botões de seleçao (Unidade, Veículos, Vagas) - primeiro
          SegmentedTabBar(
            labels: const ['Unidades', 'Veículos', 'Vagas'],
            tooltips: const [
              'Unidades do condomínio',
              'Veículos do condomínio',
              'Vagas do condomínio'
            ],
            selected: _tabUnidades!,
            onChanged: (i) {
              setState(() => _tabUnidades = i);
            },
            color: const Color(0xFF7C4DFF),
          ),

          // área de filtros - abaixo dos botões (somente para Unidade)
          if (_tabUnidades == 0) const SizedBox(height: 12),
          if (_tabUnidades == 0)
            Container(
              decoration: BoxDecoration(
                color: getFormGrisColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: getBorderColor(context)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Campo de busca "Todas as unidades" (agora apenas texto para filtrar cards abaixo)
                  CharacterCounterField(
                    controller: _filtroUnidadeController,
                    labelText: 'Unidades',
                    maxLength: 50,
                    decoration:
                        inputDecorationPadrao(context, hintText: 'Unidades')
                            .copyWith(
                      suffixIcon: _filtroUnidadeController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close,
                                  size: 20,
                                  color: getSecondaryTextColor(context)),
                              onPressed: () {
                                setState(() {
                                  _filtroUnidadeController.clear();
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (value) {
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  // Campo Nome abaixo de "Todas as unidades"
                  // Campo Nome e Botões na mesma linha
                  Row(
                    children: [
                      Expanded(
                        child: CharacterCounterField(
                          controller: _filtroNomeUnidadeController,
                          labelText: 'Nome',
                          maxLength: 50,
                          decoration:
                              inputDecorationPadrao(context, hintText: 'Nome'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TransparentIconGroup([
                        IconActionData(
                          icon: Symbols.ink_eraser,
                          tooltip: 'Limpar filtros',
                          color: IconColors.delete(context),
                          onPressed: () {
                            setState(() {
                              _filtroUnidadeSelecionado = null;
                              _filtroUnidadeController.clear();
                              _filtroNomeUnidadeController.clear();
                            });
                          },
                        ),
                        IconActionData(
                          icon: Symbols.search,
                          tooltip: 'Carregar unidades',
                          color: IconColors.search(context),
                          onPressed: _fetchUnidadesFiltro,
                          isLoading: _loadingUnidadesFiltro,
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

          // Filtros de veículos - abaixo dos botões (somente para Veículos)
          if (_tabUnidades == 1) const SizedBox(height: 12),
          if (_tabUnidades == 1)
            Container(
              decoration: BoxDecoration(
                color: getFormGrisColor(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: getBorderColor(context)),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _filtroPlacaController,
                          decoration: inputDecorationPadrao(context,
                              labelText: 'Placa'),
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 16),
                          onSubmitted: (value) {
                            final v = value.trim().toUpperCase();
                            if (v.length >= 3) {
                              _buscarVeiculoPorPlaca(v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Botões Buscar e Limpar - padrão da aba Vagas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TransparentIconGroup([
                        IconActionData(
                          icon: Symbols.ink_eraser,
                          tooltip: 'Limpar',
                          color: IconColors.delete(context),
                          onPressed: () {
                            setState(() {
                              _filtroPlacaController.clear();
                              _veiculoFiltrado = null;
                            });
                          },
                        ),
                        IconActionData(
                          icon: Symbols.search,
                          tooltip: 'Pesquisar veículo por placa',
                          color: IconColors.search(context),
                          isLoading: _loadingVeiculo,
                          onPressed: () {
                            final v = _filtroPlacaController.text
                                .trim()
                                .toUpperCase();
                            if (v.length >= 3) {
                              _buscarVeiculoPorPlaca(v);
                            }
                          },
                        ),
                      ]),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          Expanded(
            child: _tabUnidades == 0
                ? (_getUnidadesFiltradas().isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _getUnidadesFiltradas().length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final unidade = _getUnidadesFiltradas()[index];
                          final nomeUnidade = unidade['unidade_mostra'] ??
                              unidade['nome'] ??
                              'Unidade';

                          final tipoMorador =
                              (unidade['tipo_morador'] ?? '').toString();
                          final nomeMoradorRaw = unidade['nome_morador'] ??
                              unidade['morador'] ??
                              '';

                          final titulo = nomeMoradorRaw.isNotEmpty
                              ? '$nomeMoradorRaw / $nomeUnidade'
                              : nomeUnidade;

                          final subtitulo = tipoMorador == 'P'
                              ? 'Proprietário'
                              : tipoMorador == 'L'
                                  ? 'Locatário'
                                  : (unidade['info']?.toString() ??
                                      unidade['tipo']?.toString() ??
                                      '');

                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _abrirDetalhesUnidade(unidade),
                              child: _listItem(
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? null
                                    : Colors.white,
                                leadingWidget: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF79009), // Laranja
                                    borderRadius: BorderRadius.circular(36),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.home_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                title: titulo,
                                subtitle: subtitulo,
                              ),
                            ),
                          );
                        },
                      ))
                : _tabUnidades == 1
                    ? Column(
                        children: [
                          if (_veiculoFiltrado != null)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: GestureDetector(
                                onTap: () {
                                  // Buscar unidade associada ao veículo
                                  final aptoId = _veiculoFiltrado!["apto_auto"];
                                  if (aptoId != null) {
                                    final unidade = _unidadesList.firstWhere(
                                      (u) => u['apto_id'] == aptoId,
                                      orElse: () => <String, dynamic>{},
                                    );
                                    if (unidade.isNotEmpty) {
                                      _abrirDetalhesUnidade(unidade);
                                    }
                                  }
                                },
                                child: _listItem(
                                  leading: Icons.directions_car,
                                  title:
                                      '${_veiculoFiltrado!["marca_auto"] ?? '-'} ${_veiculoFiltrado!["modelo_auto"] ?? ''}'
                                          .trim(),
                                  subtitle: () {
                                    final unidade =
                                        _veiculoFiltrado!["unidade"] ?? '';
                                    final bloco = _veiculoFiltrado!["bloco"] ??
                                        _veiculoFiltrado!["torre"] ??
                                        '';
                                    final responsavelFull =
                                        (_veiculoFiltrado!["proprietario"] ??
                                                _veiculoFiltrado!["morador"] ??
                                                '')
                                            .toString();
                                    final responsavel =
                                        responsavelFull.isNotEmpty
                                            ? responsavelFull
                                                .trim()
                                                .split(' ')
                                                .first
                                            : '';

                                    String sub = '';
                                    if (unidade.isNotEmpty) {
                                      sub += 'Unidade $unidade';
                                    }
                                    if (bloco.isNotEmpty) sub += ' - $bloco';
                                    if (responsavel.isNotEmpty) {
                                      sub += ' ($responsavel)';
                                    }
                                    return sub.isEmpty
                                        ? (_veiculoFiltrado!["tipo"] ?? '-')
                                            .toString()
                                        : sub;
                                  }(),
                                  extra: Text(
                                      (_veiculoFiltrado!["cor_auto"] ?? '-')
                                          .toString()),
                                  trailing: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: getSurfaceColor(context),
                                        borderRadius: BorderRadius.circular(6)),
                                    child: Text(
                                        (_veiculoFiltrado!["placa"] ?? '-')
                                            .toString(),
                                        style:
                                            const TextStyle(letterSpacing: 2)),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      )
                    : _vagasPanel(),
          ),
        ],
      ),
    );
  }

  Widget _vagasPanel() {
    return Expanded(
      child: Column(
        children: [
          // Filtros de vagas
          _buildFiltrosVagas(),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingVagas
                ? const Center(child: CircularProgressIndicator())
                : _getVagasFiltradas().isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        itemCount: _getVagasFiltradas().length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, index) {
                          final vaga = _getVagasFiltradas()[index];
                          return GestureDetector(
                            onTap: () {
                              // Só abre tela lateral se não for "Ná£o Associado"
                              final ocupante = vaga['ocupante'] ?? '';
                              if (ocupante != 'Ná£o Associado' &&
                                  ocupante.isNotEmpty) {
                                // Buscar unidade associada á  vaga
                                final aptoId = vaga['apto_id'];
                                if (aptoId != null) {
                                  final unidade = _unidadesList.firstWhere(
                                    (u) => u['apto_id'] == aptoId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (unidade.isNotEmpty) {
                                    _abrirDetalhesUnidade(unidade);
                                  }
                                }
                              }
                            },
                            child: _listItem(
                              leading: Icons.local_parking,
                              title: vaga['vaga_txt'] ?? vaga['vaga'] ?? 'Vaga',
                              titleWidget: Row(
                                children: [
                                  Text(
                                    vaga['vaga_txt'] ?? vaga['vaga'] ?? 'Vaga',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    vaga['statusVaga_Ds'] ?? '',
                                    style: TextStyle(
                                      color: vaga['statusVaga_Ds'] == 'Liberada'
                                          ? Colors.green
                                          : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: vaga['ocupante'] ?? 'Ná£o informado',
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget? _buildFotoAvatarWidget(
      Map<String, dynamic>? userData, String? userId, String userName,
      {bool isPassagem = false}) {
    if (userData == null) return null;
    final fotoRaw = userData['foto'];
    if (fotoRaw == null) return null;

    try {
      String fotoString = fotoRaw.toString();
      if (fotoString.isEmpty) {
        return null;
      }
      if (fotoString.contains(',')) {
        fotoString = fotoString.split(',').last;
      }

      // Usa widget com cache para evitar piscar
      return _CachedBase64ImageWidget(
        key: ValueKey(
            'foto_${userId}_${fotoString.substring(0, fotoString.length > 20 ? 20 : fotoString.length)}'),
        base64String: fotoString,
        userId: userId,
        userName: userName,
        userData: userData,
        isPassagem: isPassagem,
        onTap: (userId != null && userId.isNotEmpty)
            ? () {
                _abrirPainelLateral(_UsuarioDetalhesPanel(
                  userId: userId,
                  userName: userName,
                  userData: userData,
                ));
              }
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  // Widget para cache de imagens base64 (evita piscar)
  static final Map<String, Uint8List> _imageBytesCache = {};

  Widget _CachedBase64ImageWidget({
    Key? key,
    required String base64String,
    String? userId,
    String? userName,
    Map<String, dynamic>? userData,
    required bool isPassagem,
    VoidCallback? onTap,
  }) {
    final cacheKey = 'base64_${base64String.hashCode}';

    // Verifica cache primeiro (evita decodificaçao repetida)
    Uint8List? bytes;
    if (_imageBytesCache.containsKey(cacheKey)) {
      bytes = _imageBytesCache[cacheKey]!;
    } else {
      bytes = _safeBase64Decode(base64String);
      if (bytes != null && bytes.isNotEmpty) {
        _imageBytesCache[cacheKey] = bytes;
      } else {
        return const SizedBox.shrink();
      }
    }

    final fotoWidget = isPassagem
        ? ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              bytes,
              width: 100,
              height: 100,
              fit: BoxFit.cover,
              cacheWidth: 100,
              cacheHeight: 100,
              // Sem fade para evitar piscar
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return child; // Retorna imediatamente sem animaçao
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 100,
                  height: 100,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.person, size: 50),
                );
              },
            ),
          )
        : CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: MemoryImage(bytes),
          );

    return RepaintBoundary(
      key: key,
      child: GestureDetector(
        onTap: onTap,
        child: fotoWidget,
      ),
    );
  }

  // Widget para status de foto do usuário (evita piscar usando cache direto)
  Widget _UserPhotoStatusWidget({
    required String userId,
    required String userName,
    required Map<String, dynamic>? userData,
    required bool useAvulsoHistoricoApi,
    required Future<String> Function(String) onCheckPhoto,
    required void Function(Widget) onOpenPanel,
  }) {
    final cacheKey =
        useAvulsoHistoricoApi ? 'avulso_historico_$userId' : userId;
    final cachedStatus = _userPhotoStatusCache[cacheKey];

    // Se já tem cache, usa diretamente sem FutureBuilder (evita piscar)
    if (cachedStatus != null && cachedStatus != 'loading') {
      return RepaintBoundary(
        key: ValueKey('photo_cached_$cacheKey'),
        child: _buildPhotoStatusIcon(
          status: cachedStatus,
          userId: userId,
          userName: userName,
          userData: userData,
          onOpenPanel: onOpenPanel,
        ),
      );
    }

    // Se não tem cache ou está carregando, usa FutureBuilder apenas uma vez
    return FutureBuilder<String>(
      key: ValueKey('photo_future_$cacheKey'),
      future: onCheckPhoto(userId),
      builder: (context, snapshot) {
        final status = snapshot.data ?? 'loading';
        return RepaintBoundary(
          child: _buildPhotoStatusIcon(
            status: status,
            userId: userId,
            userName: userName,
            userData: userData,
            onOpenPanel: onOpenPanel,
          ),
        );
      },
    );
  }

  Widget _buildPhotoStatusIcon({
    required String status,
    required String userId,
    required String userName,
    required Map<String, dynamic>? userData,
    required void Function(Widget) onOpenPanel,
  }) {
    final isLoading = status == 'loading';

    IconData icon;
    String tooltip;
    Color iconColor;
    VoidCallback? onTap;

    switch (status) {
      case 'has':
        icon = Icons.person;
        tooltip = 'Ver detalhes do usuário';
        iconColor = Colors.white;
        onTap = () async {
          try {
            onOpenPanel(_UsuarioDetalhesPanel(
              userId: userId,
              userName: userName,
              userData: userData,
            ));
          } catch (e) {
            // Erro silencioso
          }
        };
        break;
      case 'none':
        icon = Icons.person_off;
        tooltip = 'Ver detalhes do usuário';
        iconColor = Colors.white;
        onTap = () async {
          onOpenPanel(_UsuarioDetalhesPanel(
            userId: userId,
            userName: userName,
            userData: userData,
          ));
        };
        break;
      default: // loading
        icon = Icons.hourglass_empty;
        tooltip = 'Carregando...';
        iconColor = Colors.grey;
        onTap = () async {
          onOpenPanel(_UsuarioDetalhesPanel(
            userId: userId,
            userName: userName,
            userData: userData,
          ));
        };
    }

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  isLoading ? Colors.grey.shade300 : Colors.orange.shade400,
            ),
            Icon(
              icon,
              color: iconColor,
              size: 20,
            ),
            // ácone de olho para indicar que é clicável quando tem foto
            if (status == 'has')
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Icon(
                    Icons.visibility,
                    color: Colors.white,
                    size: 8,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Helpers
  Widget _listItem({
    IconData? leading,
    Color? leadingColor,
    Widget? leadingWidget,
    String? userId,
    required String title,
    Widget? titleWidget,
    required String subtitle,
    Widget? subtitleWidget,
    String? uniqueKey,
    Widget? trailing,
    Widget? extra,
    bool useAvulsoHistoricoApi = false,
    Map<String, dynamic>? userData,
    bool isPassagem = false,
    Color? backgroundColor,
    Widget? footer,
  }) {
    final fotoAvatar =
        _buildFotoAvatarWidget(userData, userId, title, isPassagem: isPassagem);
    final avatarSize = isPassagem ? 80.0 : 36.0;

    Widget buildAvatar() {
      if (fotoAvatar != null) return fotoAvatar;
      if (userId != null && userId.isNotEmpty) {
        return _UserPhotoStatusWidget(
          userId: userId,
          userName: title,
          userData: userData,
          useAvulsoHistoricoApi: useAvulsoHistoricoApi,
          onCheckPhoto: useAvulsoHistoricoApi
              ? _checkUserPhotoStatusAvulsoHistorico
              : _checkUserPhotoStatus,
          onOpenPanel: _abrirPainelLateral,
        );
      }
      if (leadingWidget != null) return leadingWidget;
      return Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          color: leadingColor ?? Colors.orange.shade400,
          borderRadius: BorderRadius.circular(isPassagem ? 12 : avatarSize),
        ),
        alignment: Alignment.center,
        child: Icon(
          leading ?? Icons.person,
          color: Colors.white,
          size: isPassagem ? 28 : 20,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Se for muito estreito, empilha o trailing
          final isSmall = constraints.maxWidth < 360;

          if (isSmall && trailing != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      buildAvatar(),
                      SizedBox(width: isPassagem ? 14 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleWidget ??
                                Text(title,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: getTextColor(context),
                                        fontWeight: FontWeight.w600)),
                            if (subtitleWidget != null ||
                                subtitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              subtitleWidget ??
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: getSecondaryTextColor(context),
                                    ),
                                  ),
                            ],
                            if (extra != null) ...[
                              const SizedBox(height: 8),
                              extra,
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: trailing,
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer,
                  ],
                ],
              ),
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar Section
              Container(
                width: isPassagem ? 80 : 64, // Standardize width
                height: isPassagem
                    ? 100
                    : null, // Fixed height for passagens to show background
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPassagem
                      ? (isDarkMode(context)
                          ? Colors.grey[850]
                          : Colors.grey[100])
                      : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    bottomLeft: Radius.circular(11),
                  ),
                ),
                child: buildAvatar(),
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      titleWidget ??
                          Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle),
                      ],
                      if (extra != null) ...[
                        const SizedBox(height: 8),
                        extra,
                      ],
                      if (trailing != null) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer,
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  //-----------------------------
  // FUNá‡á•ES DE API
  //-----------------------------

  Future<void> _fetchMarcasECoresVeiculo() async {
    setState(() {
      _loadingMarcas = true;
      _loadingCores = true;
    });
    final result = await ReferenceDataService.fetchMarcasECores();
    if (mounted) {
      setState(() {
        _marcasList = result['marcas'] ?? [];
        _coresList = result['cores'] ?? [];
        _loadingMarcas = false;
        _loadingCores = false;
      });
    }
  }

  Future<void> _fetchVagasAvulso() async {
    setState(() => _loadingVagasAvulso = true);
    final result = await ReferenceDataService.fetchVagasAvulso();
    if (mounted) {
      setState(() {
        _vagasAvulsoList = result;
        _loadingVagasAvulso = false;
      });
    }
  }

  Future<void> _fetchCrachas() async {
    setState(() => _loadingCrachas = true);
    final result = await ReferenceDataService.fetchCrachas();
    if (mounted) {
      setState(() {
        _crachasList = result;
        _loadingCrachas = false;
      });
    }
  }

  Future<void> _fetchUnidadesEncomenda() async {
    setState(() => _loadingUnidadesEncomenda = true);
    final result = await EncomendaFetchService.fetchUnidadesEncomenda();
    if (mounted) {
      setState(() {
        _unidadesEncomendaList = result;
        _loadingUnidadesEncomenda = false;
      });
    }
  }

  Future<void> _fetchTiposEncomenda() async {
    setState(() => _loadingTiposEncomenda = true);
    final result = await EncomendaFetchService.fetchTiposEncomenda();
    if (mounted) {
      setState(() {
        _tiposEncomendaList = result;
        _loadingTiposEncomenda = false;
      });
    }
  }

  Future<void> _fetchLocaisEncomenda() async {
    setState(() => _loadingLocaisEntrega = true);
    final result = await EncomendaFetchService.fetchLocaisEncomenda();
    if (mounted) {
      setState(() {
        _locaisEntregaList = result;
        _loadingLocaisEntrega = false;
      });
    }
  }

  //-----------------------------//
  // Buscar espaá§os sociais da API para filtro de agendamentos
  //-----------------------------//
  Future<void> _fetchEspacosSocial() async {
    setState(() {
      _loadingEspacosSocial = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (condominioId.isEmpty || tokenSessao.isEmpty) {
        setState(() {
          _espacosSocialList = [];
          _loadingEspacosSocial = false;
        });
        return;
      }

      final url =
          Uri.parse('https://socialh.conectcon.net.br/pt-br/espacosociallist');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: json.encode({
          'condominio_id': int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Verificar se "outros" está diretamente na resposta ou dentro de "data"
        List<dynamic> outros = [];
        if (responseData.containsKey('outros')) {
          outros = responseData['outros'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data') &&
            responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('outros')) {
            outros = data['outros'] as List<dynamic>? ?? [];
          }
        }

        // Filtrar apenas itens onde ordem > 1
        final filtrados = outros
            .where((item) {
              final ordemValue = item['ordem'];
              int ordem = 0;
              if (ordemValue is int) {
                ordem = ordemValue;
              } else if (ordemValue is double) {
                ordem = ordemValue.toInt();
              } else if (ordemValue is String) {
                ordem = int.tryParse(ordemValue) ?? 0;
              }
              return ordem > 1;
            })
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // Verificar se existe "social" na resposta e se tem itens
        List<dynamic> social = [];
        if (responseData.containsKey('social')) {
          social = responseData['social'] as List<dynamic>? ?? [];
        } else if (responseData.containsKey('data') &&
            responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('social')) {
            social = data['social'] as List<dynamic>? ?? [];
          }
        }

        // Se houver itens em "social", adicionar opçao "Espaço Social" com flg_reserva: "S"
        if (social.isNotEmpty) {
          final espacoSocial = {
            'ordem': 2,
            'espacopublico_id': 0, // ID especial para espaço social
            'espacopublico_ds': 'Espaço Social',
            'flg_reserva': 'S',
            'icone': 'Celebration',
            'cpo_data': 1,
            'lblBtn_convidados': 'Convidado(s)',
            'max_convidado': 0,
          };
          filtrados.insert(0, espacoSocial); // Inserir no início da lista
        }

        // Adicionar "Recarregamento Elétrico"
        final recargaEletrica = {
          'ordem': 3,
          'espacopublico_id': -1, // Dummy ID para Recarregamento
          'espacopublico_ds': 'Recarregamento Elétrico',
          'flg_reserva': 'S',
          'icone': 'Electric',
          'cpo_data': 1,
          'lblBtn_convidados': 'Convidado(s)',
          'max_convidado': 0,
        };
        filtrados.add(recargaEletrica);

        setState(() {
          _espacosSocialList = filtrados;
          _loadingEspacosSocial = false;
        });
      } else {
        setState(() {
          _espacosSocialList = [];
          _loadingEspacosSocial = false;
        });
      }
    } catch (e) {
      print('Erro ao buscar espaá§os sociais: $e');
      setState(() {
        _espacosSocialList = [];
        _loadingEspacosSocial = false;
      });
    }
  }

  Future<void> _fetchConvidadosAgendamento(String reservaId) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) return;

    final url = Uri.parse(
      ApiConfig.getUrl(
        'dashboard',
        'convidados',
        params: {'reserva_id': reservaId, 'culture': 'pt-br'},
      ),
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convidadosData = data['data'];
        final lista =
            (convidadosData is Map && convidadosData['convidados'] is List)
                ? convidadosData['convidados']
                : [];

        setState(() {
          _quantidadeConvidados[reservaId] = lista.length;
        });
      }
    } catch (e) {
      // Silenciosamente ignora erro
    }
  }

  Future<void> _fetchAgendamentos({bool isFiltro = false}) async {
    setState(() {
      _loadingAgendamentos = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final condominioIdInt = int.tryParse(condominioId) ?? 0;

    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'agendamentos'));
    final payload = <String, dynamic>{};
    payload['condominio_id'] = condominioIdInt;
    payload['status_id'] = 3;

    if (isFiltro) {
      if (_selectedUnidadeAgendamento != null &&
          _selectedUnidadeAgendamento?['apto_id'] != null) {
        payload['apto_id'] = int.tryParse(
              _selectedUnidadeAgendamento?['apto_id']?.toString() ?? '',
            ) ??
            0;
      }
      if (_filtroDataInicioSelecionada != null) {
        payload['data_ini'] = _filtroDataInicioSelecionada!.toIso8601String();
      }
      if (_filtroDataFimSelecionada != null) {
        payload['data_fim'] = _filtroDataFimSelecionada!.toIso8601String();
      }
      if (_tipoAgendamentoSelecionado != null &&
          _tipoAgendamentoSelecionado!['codigo'] != null) {
        payload['tipoAgendamento'] = _tipoAgendamentoSelecionado!['codigo'];
      }
    }

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> ags = List<Map<String, dynamic>>.from(
          data['data'] ?? [],
        );

        // Sempre ordenar por data (mais recente primeiro)
        ags.sort((a, b) {
          final dataA = a['datareserva'] ?? '';
          final dataB = b['datareserva'] ?? '';
          return dataB
              .compareTo(dataA); // Ordem decrescente (mais recente primeiro)
        });

        // Retirado o limite fixo de 3 para exibir resultados dinamicamente

        setState(() {
          _agendamentos = ags;
          // Debug para ver os campos disponíveis nos agendamentos
          if (ags.isNotEmpty) {}
        });

        // Buscar convidados para cada agendamento
        for (final agendamento in ags) {
          final reservaId = agendamento['reserva_id'];
          if (reservaId != null) {
            _fetchConvidadosAgendamento(reservaId.toString());
          }
        }
      } else {
        setState(() {
          _agendamentos = [];
        });
      }
    } catch (e) {
      setState(() {
        _agendamentos = [];
      });
    } finally {
      setState(() {
        _loadingAgendamentos = false;
      });
    }
  }

  Future<void> _buscarCadastroAvulso({bool abrirEdicao = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final condominioId = prefs.getString('condominio_id') ?? '';
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';
    final documento = _documentoController.text.trim();
    if (documento.isEmpty) {
      return;
    }
    setState(() {
      _buscandoCadastroAvulso = true;
    });
    // 1. Chama cadastroavulsolist primeiro
    Map<String, dynamic>? cadastro;
    final urlList = Uri.parse(
      ApiConfig.getEndpoint('dashboard', 'cadastroAvulso'),
    );
    final payloadList = {
      "condominio_id": int.tryParse(condominioId) ?? 0,
      "documento": documento,
    };
    try {
      final responseList = await http.post(
        urlList,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadList),
      );
      if (responseList.statusCode == 200) {
        final data = jsonDecode(responseList.body);
        final lista = data['data']?['lista'] as List?;
        if (lista != null && lista.isNotEmpty) {
          cadastro = lista[0];
        } else {}
      } else {}
    } catch (e) {}
    // 2. Depois chama avulsoselecionado
    final urlSel = Uri.parse(
      ApiConfig.getEndpoint('dashboard', 'avulsoSelecionado'),
    );
    final payloadSel = {
      "condominio_id": int.tryParse(condominioId) ?? 0,
      "documento": documento,
    };
    Map<String, dynamic>? selecionado;
    try {
      final responseSel = await http.post(
        urlSel,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadSel),
      );
      if (responseSel.statusCode == 200) {
        final dataSel = jsonDecode(responseSel.body);
        final listaSel = (dataSel['data']?['selecionado'] as List?);
        if (listaSel != null && listaSel.isNotEmpty) {
          selecionado = listaSel[0] as Map<String, dynamic>;
        } else {}
      } else {}
    } catch (e) {}
    // 3. Se encontrou cadastro, mesmo sem selecionado valido (pois cadastroavulsolist traz dados do usuário)
    if (cadastro != null) {
      setState(() {
        _temCadastroAvulso = true;
        // Prefere dados do selecionado se houver, senão usa do cadastro
        _cadastroAvulso = selecionado != null
            ? {...cadastro!, ...selecionado}
            : {...cadastro!};

        // Tenta obter o ID de qualquer uma das fontes - Lógica robusta
        int idSel = selecionado?['pessoadocumento_id'] ?? 0;
        int idCad = cadastro['pessoadocumento_id'] ?? 0;
        int pId = idSel > 0
            ? idSel
            : idCad; // Se selecionado tem ID > 0, usa ele. Senão usa do cadastro.

        // Atualiza o ID no map final
        if (pId > 0) {
          _cadastroAvulso!['pessoadocumento_id'] = pId;
        }

        // Preenche apenas o nome
        _nomeController.text = cadastro['nome'] ?? '';
      });

      // Lógica de fotos executada FORA do setState
      // Recalcula o ID para ter certeza (variáveis locais ainda acessíveis)
      // Usar pessoacadastro_id para buscar fotos
      int idSelFinal = selecionado?['pessoacadastro_id'] ?? 0;
      int idCadFinal = cadastro['pessoacadastro_id'] ?? 0;
      int pessoaIdFinal = idSelFinal > 0 ? idSelFinal : idCadFinal;

      print(
          '[DEBUG] Resolvendo ID (pessoacadastro_id) para fotos: Sel=$idSelFinal, Cad=$idCadFinal -> Final=$pessoaIdFinal');

      if (pessoaIdFinal > 0) {
        print(
            'ðŸ“¸ [DEBUG] Chamando _buscarFotosAvulso para ID: $pessoaIdFinal');
        _buscarFotosAvulso(pessoaIdFinal);
      } else {
        print('âš ï¸ [DEBUG] Sem ID válido para buscar fotos.');
        setState(() {
          _fotoBase64 = null;
          _fotoDocumentoBase64 = null;
          _fotoRostoEntrada = null;
          _fotoDocumentoEntrada = null;
        });
      }

      if (abrirEdicao) {
        _abrirModalEditarCadastroAvulso();
      }
    } else {
      setState(() {
        _temCadastroAvulso = false;
        _cadastroAvulso = null;
        // Limpar fotos se não encontrou
        _fotoBase64 = null;
        _fotoDocumentoBase64 = null;
        _fotoRostoEntrada = null;
        _fotoDocumentoEntrada = null;
      });
    }
    setState(() {
      _buscandoCadastroAvulso = false;
    });
    if (selecionado != null &&
        selecionado['pessoadocumento_id'] != null &&
        selecionado['pessoadocumento_id'] > 0) {
      _ultimoPessoadocumentoId = selecionado['pessoadocumento_id'];
    }
  }

  Future<void> _buscarFotosAvulso(int pessoaDocumentoId,
      {String tipoUSU = 'AV'}) async {
    // Limpar fotos atuais
    setState(() {
      _fotoBase64 = null;
      _fotoDocumentoBase64 = null;
      _fotoRostoEntrada = null;
      _fotoDocumentoEntrada = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    final url = Uri.parse('https://gate.conectcon.net.br/pt-br/FotoListar');
    print('[DEBUG] URL FotoListar: $url');

    // Funçao interna para buscar por ordem
    Future<void> buscarPorOrdem(int ordem) async {
      try {
        print(
            'Buscando foto ordem $ordem para ID: $pessoaDocumentoId, Tipo: $tipoUSU');

        final Map<String, dynamic> payload = {
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "tipoUSU": tipoUSU,
          "ordem_num": ordem
        };

        if (tipoUSU == 'AG') {
          payload["reservaConvidado_Id"] = pessoaDocumentoId;
        } else {
          payload["pessoacadastro_id"] = pessoaDocumentoId;
        }

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenSessao',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          // A resposta pode vir direta ou dentro de 'data' ou 'lista'
          // Ajustar conforme padrão da API
          String? fotoEncontrada;
          String? fotoUrlEncontrada;

          if (data['data'] is List && (data['data'] as List).isNotEmpty) {
            final item = data['data'][0];
            fotoUrlEncontrada = item['fotourl']?.toString();
            fotoEncontrada =
                item['foto']?.toString() ?? item['fotobase64']?.toString();
          } else if (data['data'] is Map) {
            fotoUrlEncontrada = data['data']['fotourl']?.toString();
            fotoEncontrada = data['data']['foto']?.toString() ??
                data['data']['fotobase64']?.toString();
          } else if (data['foto'] != null) {
            fotoEncontrada = data['foto']?.toString();
          }

          if (fotoUrlEncontrada != null &&
              fotoUrlEncontrada.isNotEmpty &&
              fotoUrlEncontrada != 'null') {
            if (mounted) {
              setState(() {
                if (ordem == 1) {
                  // Para URL, não setamos _fotoBase64 pois não temos o binário
                  _fotoRostoEntrada = fotoUrlEncontrada;
                  print(
                      ' Foto rosto (ordem 1) carregada via URL: $fotoUrlEncontrada');
                } else if (ordem == 2) {
                  _fotoDocumentoEntrada = fotoUrlEncontrada;
                  print(
                      ' Foto documento (ordem 2) carregada via URL: $fotoUrlEncontrada');
                }
              });
            }
          } else if (fotoEncontrada != null && fotoEncontrada.isNotEmpty) {
            final fotoClean = fotoEncontrada
                .replaceFirst('data:image/png;base64,', '')
                .replaceFirst('data:image/jpeg;base64,', '');
            if (mounted) {
              setState(() {
                if (ordem == 1) {
                  _fotoBase64 = fotoClean;
                  _fotoRostoEntrada = 'data:image/png;base64,$fotoClean';
                  print(' Foto rosto (ordem 1) carregada');
                } else if (ordem == 2) {
                  _fotoDocumentoBase64 = fotoClean;
                  _fotoDocumentoEntrada = 'data:image/png;base64,$fotoClean';
                  print(' Foto documento (ordem 2) carregada');
                }
              });
            }
          } else {
            print('âš ï¸ Nenhuma foto encontrada para ordem $ordem');
          }
        } else {
          print('âš ï¸ Erro API FotoListar ($ordem): ${response.statusCode}');
        }
      } catch (e) {
        print('Erro ao buscar foto ordem $ordem: $e');
      }
    }

    // Executar as duas buscas
    await buscarPorOrdem(1);
    await buscarPorOrdem(2);
  }

  // Atualizar cadastro avulso via API editacadastro (chamado quando campos perdem foco)
  Future<void> _atualizarCadastroAvulso() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';
    if (tokenSessao.isEmpty) return;

    final doc = _documentoController.text.trim();
    final nome = _nomeController.text.trim().isNotEmpty
        ? _nomeController.text.trim()
        : '';
    final empresa = _tipoPessoa == 0
        ? _empresaController.text.trim()
        : ''; // Só considerar empresa se for P.Serviá§o
    final autorizante = _autorizanteController.text.trim();
    final placa = _placaController.text.trim();
    final modelo = _modeloController.text.trim();
    final obs = _obsController.text.trim();

    // Sempre atualizar se temos documento (obrigatório)
    if (doc.isEmpty) {
      return;
    }

    _setAtualizandoCadastro(true);

    // RECUPERAR O ID SALVO - se não tem ID, buscar primeiro
    var pessoaDocumentoId =
        _cadastroAvulso?['pessoadocumento_id'] ?? _ultimoPessoadocumentoId ?? 0;

    // Se não tem ID salvo, significa que as APIs anteriores não foram chamadas ainda
    if (pessoaDocumentoId == 0) {
      await _buscarCadastroAvulso();
      // Recarregar o ID após a busca
      pessoaDocumentoId = _cadastroAvulso?['pessoadocumento_id'] ??
          _ultimoPessoadocumentoId ??
          0;
    }

    // ENVIAR APENAS OS CAMPOS ESSENCIAIS PARA editacadastro
    final urlEdit = Uri.parse(
      ApiConfig.getEndpoint('dashboard', 'editarCadastro'),
    );

    // Payload simplificado - apenas campos essenciais
    final payloadEdit = <String, dynamic>{
      "pessoadocumento_id": pessoaDocumentoId,
      "tipodoc": 'R',
      "documento": doc,
      "nome": nome,
      "email": _cadastroAvulso?['email'] ?? '',
      "empresa": empresa,
    };

    try {
      final responseEdit = await http.post(
        urlEdit,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadEdit),
      );

      if (responseEdit.statusCode == 200) {
        final dataEdit = jsonDecode(responseEdit.body);
        final newId =
            dataEdit['data']?['pessoadocumento_id'] ?? pessoaDocumentoId;

        setState(() {
          if (_cadastroAvulso != null) {
            _cadastroAvulso!['pessoadocumento_id'] = newId;
          } else {
            _cadastroAvulso = {
              'pessoadocumento_id': newId,
              'tipodoc': 'R',
            };
          }

          // Atualizar todos os campos
          _cadastroAvulso!['nome'] = nome;
          _cadastroAvulso!['documento'] = doc;
          _cadastroAvulso!['empresa'] = empresa;
          _cadastroAvulso!['autorizante'] = autorizante;
          _cadastroAvulso!['placa'] = placa;
          _cadastroAvulso!['modelo'] = modelo;
          _cadastroAvulso!['obs'] = obs;
          _cadastroAvulso!['vaga_id'] = _selectedVagaAvulso?['vaga_id'] ??
              _selectedVagaAvulso?['id'] ??
              0;
          _cadastroAvulso!['outraident_id'] =
              _selectedCracha?['aviso_id'] ?? _selectedCracha?['id'] ?? 0;
          _cadastroAvulso!['marca_id'] = _selectedMarca?['id'] ?? 0;
          _cadastroAvulso!['cor_id'] = _selectedCor?['id'] ?? 0;

          _ultimoPessoadocumentoId = newId;
          _temCadastroAvulso = true;
          _cadastroBuscado =
              true; // Marca que a busca foi concluída com sucesso
        });
        _setAtualizandoCadastro(false);
      } else {
        _setAtualizandoCadastro(false);
      }
    } catch (e) {
      _setAtualizandoCadastro(false);
    }
  }

  void _abrirModalEditarCadastroAvulso() async {
    // Permitir abrir mesmo sem cadastro para criar novo
    // if (_cadastroAvulso == null) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        final TextEditingController nomeCtrl = TextEditingController(
          text: _cadastroAvulso?['nome'] ?? '',
        );
        final TextEditingController docCtrl = TextEditingController(
          text:
              _cadastroAvulso?['documento'] ?? _documentoController.text.trim(),
        );
        final TextEditingController tipoCtrl = TextEditingController(
          text: _cadastroAvulso?['tipodoc'] ?? '',
        );
        final TextEditingController empresaCtrl = TextEditingController(
          text: _cadastroAvulso?['empresa'] ?? '',
        );
        final TextEditingController emailCtrl = TextEditingController(
          text: _cadastroAvulso?['email'] ?? '',
        );
        final isDark = isDarkMode(context);
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1F2937) : Colors.white,
          title: Text(
            'Alterar Dados',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecorationPadrao(context, hintText: 'Nome'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: docCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration:
                      inputDecorationPadrao(context, hintText: 'Documento'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tipoCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration:
                      inputDecorationPadrao(context, hintText: 'Tipo Doc'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: empresaCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration:
                      inputDecorationPadrao(context, hintText: 'Empresa'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: inputDecorationPadrao(context, hintText: 'Email'),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.white : Colors.grey[700],
                side: BorderSide(
                  color: isDark ? Colors.grey[600]! : Colors.grey[400]!,
                ),
              ),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF12B76A),
                foregroundColor: Colors.white,
              ),
              onPressed: _loadingEditarCadastro
                  ? null
                  : () async {
                      setState(() {
                        _loadingEditarCadastro = true;
                      });

                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final encrypted = prefs.getString('tokensessao_txt');
                        final tokenSessao =
                            (encrypted != null && encrypted.isNotEmpty)
                                ? decryptText(encrypted)
                                : '';
                        final urlEdit = Uri.parse(
                          ApiConfig.getEndpoint('dashboard', 'editarCadastro'),
                        );
                        final payloadEdit = {
                          "pessoadocumento_id":
                              _cadastroAvulso?['pessoadocumento_id'] ??
                                  _ultimoPessoadocumentoId ??
                                  0,
                          "nome": nomeCtrl.text.trim(),
                          "documento": docCtrl.text.trim(),
                          "tipodoc": tipoCtrl.text.trim().isEmpty
                              ? 'R'
                              : tipoCtrl.text.trim(),
                          "empresa": empresaCtrl.text.trim(),
                          "email": emailCtrl.text.trim(),
                        };
                        final responseEdit = await http.post(
                          urlEdit,
                          headers: {
                            'Content-Type': 'application/json',
                            'Authorization': 'Bearer $tokenSessao',
                          },
                          body: jsonEncode(payloadEdit),
                        );
                        if (responseEdit.statusCode == 200) {
                          Navigator.of(context).pop(payloadEdit);
                        } else {
                          FeedbackUtils.showError(
                            context: context,
                            title: 'Erro ao Salvar',
                            message: 'Erro ao salvar cadastro',
                            errorDetails: 'Status: ${responseEdit.statusCode}',
                          );
                        }
                      } catch (e) {
                        FeedbackUtils.showError(
                          context: context,
                          title: 'Erro ao Salvar',
                          message: 'Erro ao salvar cadastro',
                          errorDetails: e.toString(),
                        );
                      } finally {
                        setState(() {
                          _loadingEditarCadastro = false;
                        });
                      }
                    },
              child: _loadingEditarCadastro
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Salvar'),
            ),
          ],
        );
      },
    );
    if (result != null) {
      setState(() {
        _cadastroAvulso = {...?_cadastroAvulso, ...result};
        _autorizanteController.text = _cadastroAvulso?['nome'] ?? '';
        _documentoController.text = _cadastroAvulso?['documento'] ?? '';
      });
    }
  }

  // Criar cadastro avulso automaticamente apenas com documento (nome pode estar vazio)
  Future<void> _criarCadastroAvulsoAutomaticoPorDocumento() async {
    if (_documentoController.text.trim().length < 6) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';
    final doc = _documentoController.text.trim();
    final nome = _nomeController.text.trim().isNotEmpty
        ? _nomeController.text.trim()
        : '';

    // Use o id mais atualizado

    var pessoaDocumentoId =
        _cadastroAvulso?['pessoadocumento_id'] ?? _ultimoPessoadocumentoId ?? 0;
    var pessoaCadastroId = _cadastroAvulso?['pessoa_cadastro_id'] ?? 0;

    // Validar os IDs usando a ção de conversá£o
    final validPessoaDocumentoId = _convertToValidId(pessoaDocumentoId);
    final validPessoaCadastroId = _convertToValidId(pessoaCadastroId);

    // Usa o primeiro ID válido disponível
    var finalId = (validPessoaDocumentoId != null && validPessoaDocumentoId > 0)
        ? validPessoaDocumentoId
        : validPessoaCadastroId;

    // Garantir que o ID seja válido usando a ção de conversá£o
    final validFinalId = _convertToValidId(finalId) ?? 0;

    final urlEdit = Uri.parse(
      ApiConfig.getEndpoint('dashboard', 'editarCadastro'),
    );
    // Payload simplificado - apenas campos essenciais
    final payloadEdit = <String, dynamic>{
      "pessoadocumento_id": validFinalId,
      "tipodoc": 'R',
      "documento": doc,
      "nome": nome,
      "email": _cadastroAvulso?['email'] ?? '',
      "empresa": _empresaController.text.trim(),
    };

    try {
      final responseEdit = await http.post(
        urlEdit,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadEdit),
      );

      if (responseEdit.statusCode == 200) {
        final dataEdit = jsonDecode(responseEdit.body);
        if (dataEdit['data'] != null) {}
        final pessoadocumentoIdResp =
            dataEdit['data']?['pessoadocumento_id'] ?? 0;

        setState(() {
          if (_cadastroAvulso != null) {
            _cadastroAvulso!['pessoadocumento_id'] = pessoadocumentoIdResp;
          } else {
            _cadastroAvulso = {
              'pessoadocumento_id': pessoadocumentoIdResp,
              'nome': nome,
              'documento': doc,
              'empresa': _empresaController.text.trim(),
              'email': '',
              'tipodoc': 'R',
            };
          }
          _ultimoPessoadocumentoId = pessoadocumentoIdResp;
          _temCadastroAvulso = true;
          _cadastroBuscado =
              true; // Marca que a busca foi concluída com sucesso
        });
      }
    } catch (e) {
      // Silenciosamente ignora erro para não atrapalhar UX
    }
  }

  Future<void> _fetchAutorizantes() async {
    final result = await ReferenceDataService.fetchUnidades();
    if (mounted && result.isNotEmpty) {
      setState(() => _unidadesList = result);
    }
  }

  // Buscar passagens do condomínio (sempre mostrar todas)
  Future<void> _fetchHistoricoPassagens({
    DateTime? dataIni,
    DateTime? dataFim,
    String? documento,
  }) async {
    final result = await ReferenceDataService.fetchHistoricoPassagens();
    if (mounted && result.isNotEmpty) {
      setState(() => _historicoBaixa = result);
    }
  }

  // Buscar passagens/histórico por documento usando API passagemhistorico
  Future<void> _buscarPassagensPorDocumento() async {
    if (_documentoController.text.trim().length < 6) return;

    // Buscar últimos 30 dias para ter um histórico relevante
    final hoje = DateTime.now();
    final dataIni = hoje.subtract(const Duration(days: 30));
    final dataFim = hoje;

    await _fetchHistoricoPassagens(
      dataIni: dataIni,
      dataFim: dataFim,
      documento: _documentoController.text.trim(),
    );
  }

  // Widget para filtros de vagas
  Widget _buildFiltrosVagas() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getFormGrisColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  Map<String, dynamic>? selectedVaga;
                  if (_vagasList.isNotEmpty &&
                      _filtroVagasSelecionado != null) {
                    try {
                      selectedVaga = _vagasList.firstWhere(
                        (vaga) =>
                            vaga['vaga_id'].toString() ==
                            _filtroVagasSelecionado,
                      );
                    } catch (_) {}
                  }

                  return buildStandardAutocomplete<Map<String, dynamic>>(
                    key: ValueKey(_filtroVagasSelecionado),
                    context: context,
                    labelText: 'Vagas',
                    items: _vagasList,
                    itemAsString: (option) =>
                        (option['vaga_txt'] ?? 'Vaga ${option['vaga_id']}')
                            .toString(),
                    selectedItem: selectedVaga,
                    onSelected: (value) {
                      setState(() {
                        _filtroVagasSelecionado =
                            value != null ? value['vaga_id'].toString() : null;
                      });
                    },
                    constraints: constraints,
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TransparentIconGroup([
                IconActionData(
                  icon: Symbols.ink_eraser,
                  tooltip: 'Limpar',
                  color: IconColors.delete(context),
                  onPressed: () {
                    setState(() {
                      _filtroVagasSelecionado = null;
                      _filtroVagaController.clear();
                    });
                  },
                ),
                IconActionData(
                  icon: Symbols.search,
                  tooltip: 'Pesquisar',
                  color: IconColors.search(context),
                  onPressed: () {},
                ),
              ]),
            ],
          ),
        ],
      ),
    );
  }

  // Widget para filtros de unidades
  Widget _buildFiltrosUnidades() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getFormGrisColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtro de Nome da Unidade - movido para baixo
        ],
      ),
    );
  }

  //-----------------------------//
  // Widget para filtros de entrada
  //-----------------------------//
  Widget _buildFiltrosEntrada1x() {
    // Se minimizado, não renderizar nada
    if (_filtroEntradaMinimizado) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getFormGrisColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented control removido - agora está no topo do painel

          // Campos baseados no tipo selecionado
          if (_tipoFiltroEntrada == 0) ...[
            // Modo Avulso: Documento e Nome
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroDocumentoEntradaController,
                    labelText:
                        _tipoFiltroEntrada == 0 ? 'Documento' : 'Documento',
                    maxLength: 14,
                    decoration: _getInputDecorationComErro(
                      context,
                      _tipoFiltroEntrada == 0 ? 'Documento' : 'Documento',
                      'documento_entrada',
                      _erroDocumentoEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      setState(() {
                        // Remove erro quando o usuário digita
                        if (_erroDocumentoEntrada && value.trim().isNotEmpty) {
                          _erroDocumentoEntrada = false;
                        }
                        // Se documento está preenchido, remove obrigatoriedade do nome
                        if (value.trim().isNotEmpty &&
                            _tipoFiltroEntrada == 0) {
                          _erroNomeEntrada = false;
                        }
                      });
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                          _erroNomeEntrada = false;
                          _filtroEntradaMinimizado = false;
                        });
                        _buscarEntradasFiltradas();
                      } else {
                        setState(() {
                          _erroDocumentoEntrada = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroNomeEntradaController,
                    labelText: 'Nome e Sobrenome',
                    maxLength: 50,
                    decoration: _getInputDecorationComErro(
                      context,
                      'Nome e Sobrenome',
                      'nome',
                      _erroNomeEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      // Remove erro quando o usuário digita
                      if (_erroNomeEntrada && value.trim().isNotEmpty) {
                        setState(() {
                          _erroNomeEntrada = false;
                        });
                      }
                      if (value.trim().isNotEmpty && _tipoFiltroEntrada == 0) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                        });
                      }
                    },
                    onSubmitted: (value) {
                      final documento =
                          _filtroDocumentoEntradaController.text.trim();
                      if (documento.isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                          _erroNomeEntrada = false;
                          _filtroEntradaMinimizado = false;
                        });
                        _buscarEntradasFiltradas();
                      } else {
                        setState(() {
                          _erroDocumentoEntrada = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar filtros',
                    color: IconColors.delete(context),
                    onPressed: () {
                      _filtroDocumentoEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _mostrarFormEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _convidadosResultados.clear();
                        _cardsExpandidos.clear();
                      });
                      _fecharPainelLateral();
                    },
                  ),
                  // Removida condicional: botão Buscar (lupa) deve sempre aparecer antes de Novo Cadastro
                  IconActionData(
                    icon: Symbols.search,
                    tooltip: 'Buscar visitante',
                    color: IconColors.search(context),
                    onPressed: () {
                      final documento =
                          _filtroDocumentoEntradaController.text.trim();
                      final nome = _filtroNomeEntradaController.text.trim();

                      if (_tipoFiltroEntrada == 0) {
                        // Modo Avulso: pelo menos um campo deve estar preenchido
                        if (documento.isEmpty && nome.isEmpty) {
                          setState(() {
                            _erroDocumentoEntrada = true;
                            _erroNomeEntrada = true;
                          });
                          return;
                        }
                      }

                      // Remove erros se campos está£o preenchidos e expande filtro
                      setState(() {
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _filtroEntradaMinimizado =
                            false; // Expandir ao buscar visitante
                      });
                      _buscarEntradasFiltradas();
                    },
                    isLoading: _loadingBuscaEntrada,
                  ),
                  IconActionData(
                    icon: Symbols.person_add,
                    tooltip: 'Novo Cadastro',
                    color: IconColors.play(context),
                    onPressed: () {
                      // Limpar campos e abrir formulário de novo cadastro
                      _filtroDocumentoEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _mostrarFormEntrada = true;
                        _isNovoUsuario = true;
                        _isAgendamento = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _convidadosResultados.clear();
                      });
                    },
                  ),
                ]),
              ],
            ),
          ] else ...[
            // Modo Agendamentos: Documento, Nome, Unidade, Período
            // Primeira linha: Documento (linha inteira para evitar truncamento)
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroDocumentoEntradaController,
                    labelText: 'Documento',
                    maxLength: 14,
                    decoration: _getInputDecorationComErro(
                      context,
                      'Documento',
                      'documento_entrada',
                      _erroDocumentoEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      if (_erroDocumentoEntrada && value.trim().isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                        });
                      }
                    },
                    onSubmitted: (_) {
                      final temData = _filtroDataInicioEntrada != null ||
                          _filtroDataFimEntrada != null;

                      if (!temData) {
                        setState(() {
                          _erroDataEntrada = true;
                        });
                        return;
                      }

                      setState(() {
                        _erroDataEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                      });

                      final espacosSelecionados =
                          _espacosSocialList.where((espaco) {
                        final id = espaco['espacopublico_id'] as int? ?? 0;
                        return _espacosSociaisSelecionadosFiltro[id] == true;
                      }).toList();

                      final espacosParaBusca = espacosSelecionados.isNotEmpty
                          ? espacosSelecionados
                          : _espacosSocialList;

                      _buscarAgendamentosEntradaFiltrados(
                          espacosSelecionados: espacosParaBusca);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Segunda linha: Nome e Sobrenome (linha inteira)
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroNomeEntradaController,
                    labelText: 'Nome e Sobrenome',
                    maxLength: 50,
                    decoration: _getInputDecoration(
                        context, 'Nome e Sobrenome', 'nome'),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onSubmitted: (_) {
                      final temData = _filtroDataInicioEntrada != null ||
                          _filtroDataFimEntrada != null;

                      if (!temData) {
                        setState(() {
                          _erroDataEntrada = true;
                        });
                        return;
                      }

                      setState(() {
                        _erroDataEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                      });

                      final espacosSelecionados =
                          _espacosSocialList.where((espaco) {
                        final id = espaco['espacopublico_id'] as int? ?? 0;
                        return _espacosSociaisSelecionadosFiltro[id] == true;
                      }).toList();

                      final espacosParaBusca = espacosSelecionados.isNotEmpty
                          ? espacosSelecionados
                          : _espacosSocialList;

                      _buscarAgendamentosEntradaFiltrados(
                          espacosSelecionados: espacosParaBusca);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Terceira linha: Unidade
            Row(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return buildStandardAutocomplete<Map<String, dynamic>>(
                      key: ValueKey(_unidadeFiltroAplicada),
                      context: context,
                      labelText: 'Unidade',
                      items: _unidadesList,
                      itemAsString: (option) => unidadeLabelComMorador(option),
                      selectedItem: _unidadeFiltroSelecionada,
                      onSelected: (value) {
                        setState(() {
                          _unidadeFiltroSelecionada = value;
                          _unidadeFiltroAplicada =
                              value != null ? value['apto_id'] : null;
                        });
                      },
                      constraints: constraints,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Terceira linha: Período (ocupando largura total)
            _buildPeriodFilter(
              context: context,
              startDate: _filtroDataInicioEntrada,
              endDate: _filtroDataFimEntrada,
              hintText: 'período *',
              temErro: _erroDataEntrada,
              onStartDateChanged: (date) {
                setState(() {
                  _filtroDataInicioEntrada = date;
                  if (date != null) {
                    _erroDataEntrada = false;
                  }
                });
              },
              onEndDateChanged: (date) {
                setState(() {
                  _filtroDataFimEntrada = date;
                  if (date != null) {
                    _erroDataEntrada = false;
                  }
                });
              },
            ),
            const SizedBox(height: 12),

            // Quarta linha: Botões de Açao
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar filtros',
                    color: IconColors.delete(context),
                    onPressed: () {
                      _filtroDocumentoEntradaController.clear();
                      _filtroUnidadeEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _filtroDataEntrada = null;
                        _filtroDataInicioEntrada = null;
                        _filtroDataFimEntrada = null;
                        _unidadeFiltroSelecionada = null;
                        _unidadeFiltroAplicada = null;
                        _espacoSocialSelecionado = null;
                        _mostrarFormEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _erroDataEntrada = false;
                        _convidadosResultados.clear();
                        _cardsExpandidos.clear();
                      });
                      _fecharPainelLateral();
                    },
                    isOpaque: false,
                  ),
                  IconActionData(
                    icon: Symbols.search,
                    tooltip: 'Pesquisar convidados',
                    color: IconColors.search(context),
                    onPressed: () {
                      if (_filtroEntradaMinimizado) {
                        setState(() {
                          _filtroEntradaMinimizado = false;
                        });
                      } else {
                        // Se ná£o minimizado, realiza a busca com os filtros atuais
                        final espacosSelecionados =
                            _espacosSocialList.where((espaco) {
                          final id = espaco['espacopublico_id'] as int? ?? 0;
                          return _espacosSociaisSelecionadosFiltro[id] == true;
                        }).toList();
                        final espacosParaBusca = espacosSelecionados.isNotEmpty
                            ? espacosSelecionados
                            : _espacosSocialList;
                        _buscarAgendamentosEntradaFiltrados(
                            espacosSelecionados: espacosParaBusca);
                      }
                    },
                    isLoading: _loadingBuscaAgendamentos,
                  ),
                  // Botá£o Filtros (antiga seta)
                  IconActionData(
                    icon: _agendamentoTiposFiltroExpandido
                        ? Symbols.assignment_turned_in
                        : Symbols.assignment,
                    tooltip: 'Tipos de Agendamento',
                    onPressed: () {
                      setState(() {
                        _agendamentoTiposFiltroExpandido =
                            !_agendamentoTiposFiltroExpandido;
                      });
                    },
                    color: _agendamentoTiposFiltroExpandido
                        ? const Color(0xFF00C853)
                        : (isDarkMode(context) ? Colors.white : Colors.black87),
                  ),
                ]),
              ],
            ),
            // 2. Painel de Filtros de Agendamento Expandido (com ANIMAá‡ão)
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: FadeTransition(
                    opacity: animation,
                    child: child,
                  ),
                );
              },
              child: _agendamentoTiposFiltroExpandido
                  ? Column(
                      key: const ValueKey('expanded_filter'),
                      children: [
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDarkMode(context)
                                ? const Color(0xFF374151)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(40),
                            border: Border.all(
                                color: getBorderColor(context)
                                    .withValues(alpha: 0.2)),
                          ),
                          child: _buildCardsTiposAgendamentoContent(
                              transparent: true, isFullWidth: false),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(key: ValueKey('collapsed_filter')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFiltrosEntrada() {
    // Se minimizado, não renderizar nada
    if (_filtroEntradaMinimizado) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getFormGrisColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented control removido - agora está no topo do painel

          // Campos baseados no tipo selecionado
          if (_tipoFiltroEntrada == 0) ...[
            // Modo Avulso: Documento e Nome
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroDocumentoEntradaController,
                    labelText:
                        _tipoFiltroEntrada == 0 ? 'Documento' : 'Documento',
                    maxLength: 14,
                    decoration: _getInputDecorationComErro(
                      context,
                      _tipoFiltroEntrada == 0 ? 'Documento' : 'Documento',
                      'documento_entrada',
                      _erroDocumentoEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      setState(() {
                        // Remove erro quando o usuário digita
                        if (_erroDocumentoEntrada && value.trim().isNotEmpty) {
                          _erroDocumentoEntrada = false;
                        }
                        // Se documento está preenchido, remove obrigatoriedade do nome
                        if (value.trim().isNotEmpty &&
                            _tipoFiltroEntrada == 0) {
                          _erroNomeEntrada = false;
                        }
                      });
                    },
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                          _erroNomeEntrada = false;
                          _filtroEntradaMinimizado = false;
                        });
                        _buscarEntradasFiltradas();
                      } else {
                        setState(() {
                          _erroDocumentoEntrada = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroNomeEntradaController,
                    labelText: 'Nome e Sobrenome',
                    maxLength: 50,
                    decoration: _getInputDecorationComErro(
                      context,
                      'Nome e Sobrenome',
                      'nome',
                      _erroNomeEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      // Remove erro quando o usuário digita
                      if (_erroNomeEntrada && value.trim().isNotEmpty) {
                        setState(() {
                          _erroNomeEntrada = false;
                        });
                      }
                      if (value.trim().isNotEmpty && _tipoFiltroEntrada == 0) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                        });
                      }
                    },
                    onSubmitted: (value) {
                      final documento =
                          _filtroDocumentoEntradaController.text.trim();
                      if (documento.isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                          _erroNomeEntrada = false;
                          _filtroEntradaMinimizado = false;
                        });
                        _buscarEntradasFiltradas();
                      } else {
                        setState(() {
                          _erroDocumentoEntrada = true;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar filtros',
                    color: IconColors.delete(context),
                    onPressed: () {
                      _filtroDocumentoEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _mostrarFormEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _convidadosResultados.clear();
                        _cardsExpandidos.clear();
                      });
                      _fecharPainelLateral();
                    },
                  ),
                  // Removida condicional: botão Buscar (lupa) deve sempre aparecer antes de Novo Cadastro
                  IconActionData(
                    icon: Symbols.search,
                    tooltip: 'Buscar visitante',
                    color: IconColors.search(context),
                    onPressed: () {
                      final documento =
                          _filtroDocumentoEntradaController.text.trim();
                      final nome = _filtroNomeEntradaController.text.trim();

                      if (_tipoFiltroEntrada == 0) {
                        // Modo Avulso: pelo menos um campo deve estar preenchido
                        if (documento.isEmpty && nome.isEmpty) {
                          setState(() {
                            _erroDocumentoEntrada = true;
                            _erroNomeEntrada = true;
                          });
                          return;
                        }
                      }

                      // Remove erros se campos estão preenchidos e expande filtro
                      setState(() {
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _filtroEntradaMinimizado =
                            false; // Expandir ao buscar visitante
                      });
                      _buscarEntradasFiltradas();
                    },
                    isLoading: _loadingBuscaEntrada,
                  ),
                  IconActionData(
                    icon: Symbols.person_add,
                    tooltip: 'Novo Cadastro',
                    color: IconColors.play(context),
                    onPressed: () {
                      // Limpar campos e abrir formulário de novo cadastro
                      _filtroDocumentoEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _mostrarFormEntrada = true;
                        _isNovoUsuario = true;
                        _isAgendamento = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _convidadosResultados.clear();
                      });
                    },
                  ),
                ]),
              ],
            ),
          ] else ...[
            // Modo Agendamentos: Documento, Nome, Unidade, Período
            // Primeira linha: Documento (linha inteira para evitar truncamento)
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroDocumentoEntradaController,
                    labelText: 'Documento',
                    maxLength: 14,
                    decoration: _getInputDecorationComErro(
                      context,
                      'Documento',
                      'documento_entrada',
                      _erroDocumentoEntrada,
                    ),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onChanged: (value) {
                      if (_erroDocumentoEntrada && value.trim().isNotEmpty) {
                        setState(() {
                          _erroDocumentoEntrada = false;
                        });
                      }
                    },
                    onSubmitted: (_) {
                      final temData = _filtroDataInicioEntrada != null ||
                          _filtroDataFimEntrada != null;

                      if (!temData) {
                        setState(() {
                          _erroDataEntrada = true;
                        });
                        return;
                      }

                      setState(() {
                        _erroDataEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                      });

                      final espacosSelecionados =
                          _espacosSocialList.where((espaco) {
                        final id = espaco['espacopublico_id'] as int? ?? 0;
                        return _espacosSociaisSelecionadosFiltro[id] == true;
                      }).toList();

                      final espacosParaBusca = espacosSelecionados.isNotEmpty
                          ? espacosSelecionados
                          : _espacosSocialList;

                      _buscarAgendamentosEntradaFiltrados(
                          espacosSelecionados: espacosParaBusca);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Segunda linha: Nome e Sobrenome (linha inteira)
            Row(
              children: [
                Expanded(
                  child: CharacterCounterField(
                    controller: _filtroNomeEntradaController,
                    labelText: 'Nome e Sobrenome',
                    maxLength: 50,
                    decoration: _getInputDecoration(
                        context, 'Nome e Sobrenome', 'nome'),
                    enableInteractiveSelection: true,
                    readOnly: false,
                    onSubmitted: (_) {
                      final temData = _filtroDataInicioEntrada != null ||
                          _filtroDataFimEntrada != null;

                      if (!temData) {
                        setState(() {
                          _erroDataEntrada = true;
                        });
                        return;
                      }

                      setState(() {
                        _erroDataEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                      });

                      final espacosSelecionados =
                          _espacosSocialList.where((espaco) {
                        final id = espaco['espacopublico_id'] as int? ?? 0;
                        return _espacosSociaisSelecionadosFiltro[id] == true;
                      }).toList();

                      final espacosParaBusca = espacosSelecionados.isNotEmpty
                          ? espacosSelecionados
                          : _espacosSocialList;

                      _buscarAgendamentosEntradaFiltrados(
                          espacosSelecionados: espacosParaBusca);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Terceira linha: Unidade
            Row(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    return buildStandardAutocomplete<Map<String, dynamic>>(
                      key: ValueKey(_unidadeFiltroAplicada),
                      context: context,
                      labelText: 'Unidade',
                      items: _unidadesList,
                      itemAsString: (option) => unidadeLabelComMorador(option),
                      selectedItem: _unidadeFiltroSelecionada,
                      onSelected: (value) {
                        setState(() {
                          _unidadeFiltroSelecionada = value;
                          _unidadeFiltroAplicada =
                              value != null ? value['apto_id'] : null;
                        });
                      },
                      constraints: constraints,
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Terceira linha: Período (ocupando largura total)
            _buildPeriodFilter(
              context: context,
              startDate: _filtroDataInicioEntrada,
              endDate: _filtroDataFimEntrada,
              hintText: 'período *',
              temErro: _erroDataEntrada,
              onStartDateChanged: (date) {
                setState(() {
                  _filtroDataInicioEntrada = date;
                  if (date != null) {
                    _erroDataEntrada = false;
                  }
                });
              },
              onEndDateChanged: (date) {
                setState(() {
                  _filtroDataFimEntrada = date;
                  if (date != null) {
                    _erroDataEntrada = false;
                  }
                });
              },
            ),

            // 2. Painel de Filtros de Agendamento (Sempre visível)
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDarkMode(context)
                    ? const Color(0xFF374151)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: getBorderColor(context).withValues(alpha: 0.2)),
              ),
              child: _buildCardsTiposAgendamentoContent(
                  transparent: true, isFullWidth: false),
            ),

            const SizedBox(height: 12),

            // Quarta linha: Botões de Açao
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar filtros',
                    color: IconColors.delete(context),
                    onPressed: () {
                      _filtroDocumentoEntradaController.clear();
                      _filtroUnidadeEntradaController.clear();
                      _filtroNomeEntradaController.clear();
                      setState(() {
                        _filtroDataEntrada = null;
                        _filtroDataInicioEntrada = null;
                        _filtroDataFimEntrada = null;
                        _unidadeFiltroSelecionada = null;
                        _unidadeFiltroAplicada = null;
                        _espacoSocialSelecionado = null;
                        _mostrarFormEntrada = false;
                        _erroDocumentoEntrada = false;
                        _erroNomeEntrada = false;
                        _erroDataEntrada = false;
                        _convidadosResultados.clear();
                        _cardsExpandidos.clear();
                      });
                      _fecharPainelLateral();
                    },
                    isOpaque: false,
                  ),
                  IconActionData(
                    icon: Symbols.search,
                    tooltip: 'Pesquisar convidados',
                    color: IconColors.search(context),
                    onPressed: () {
                      if (_filtroEntradaMinimizado) {
                        setState(() {
                          _filtroEntradaMinimizado = false;
                        });
                      } else {
                        // Se não minimizado, realiza a busca com os filtros atuais
                        final espacosSelecionados =
                            _espacosSocialList.where((espaco) {
                          final id = espaco['espacopublico_id'] as int? ?? 0;
                          return _espacosSociaisSelecionadosFiltro[id] == true;
                        }).toList();
                        final espacosParaBusca = espacosSelecionados.isNotEmpty
                            ? espacosSelecionados
                            : _espacosSocialList;
                        _buscarAgendamentosEntradaFiltrados(
                            espacosSelecionados: espacosParaBusca);
                      }
                    },
                    isLoading: _loadingBuscaAgendamentos,
                  ),
                ]),
              ],
            ),
          ],
        ],
      ),
    );
  }

  //-----------------------------//
  // Funçao auxiliar para obter ícone baseado no nome
  //-----------------------------//
  IconData _getIconData(String? icone) {
    switch (icone) {
      case 'Add Home Work':
        return Symbols.home_work;
      case 'Truck':
        return Symbols.local_shipping;
      case 'Id Card Alt':
        return Symbols.badge;
      case 'Tools':
        return Symbols.construction;
      case 'Emoji People Rounded':
        return Symbols.emoji_people;
      case 'Event':
        return Symbols.event_note;
      case 'Users':
        return Symbols.groups;
      case 'Home':
        return Symbols.home;
      case 'Celebration':
        return Symbols.celebration;
      case 'Electric':
        return Symbols.electric_car;
      default:
        return Symbols.event;
    }
  }

  //-----------------------------//
  // Buscar espaá§os sociais para o filtro (usa a mesma ção que busca da API)
  //-----------------------------//
  Future<void> _buscarEspacosSociaisParaFiltro() async {
    // Usar a mesma ção que busca da API (todos os itens de "outros" com ordem > 1)
    await _fetchEspacosSocial();

    // Inicializar todas as seleá§ões como true (marcadas por padrão)
    setState(() {
      _espacosSociaisSelecionadosFiltro.clear();
      for (final espaco in _espacosSocialList) {
        final id = espaco['espacopublico_id'] as int? ?? 0;
        _espacosSociaisSelecionadosFiltro[id] = true;
      }
    });
  }

  Widget _buildCardsTiposAgendamentoContent(
      {bool transparent = false, bool isFullWidth = false}) {
    if (_loadingEspacosSocial) {
      return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Center(child: CircularProgressIndicator()));
    }

    if (_espacosSocialList.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Center(child: Text('Sem tipos disponíveis')),
      );
    }

    final List<Widget> items = [];

    final isDark = isDarkMode(context);

    for (int i = 0; i < _espacosSocialList.length; i++) {
      final espaco = _espacosSocialList[i];

      final id = espaco['espacopublico_id'] as int? ?? 0;

      var descricao = espaco['espacopublico_ds'] as String? ?? '';

      descricao = descricao.replaceAll('Temporária', 'Temporaria');

      final icone = espaco['icone'] as String?;

      final isSelected = _espacosSociaisSelecionadosFiltro[id] ?? false;

      Widget itemContent = InkWell(
        onTap: () {
          setState(() {
            _espacosSociaisSelecionadosFiltro[id] = !isSelected;
          });
        },
        borderRadius: BorderRadius.circular(40),
        child: Tooltip(
          message: descricao,
          child: Container(
            alignment: Alignment.centerLeft,
            child: Stack(
              alignment: Alignment.centerLeft,
              clipBehavior: Clip.none,
              children: [
                Icon(
                  _getIconData(icone),

                  size: 26, // Reduzi levemente para caber melhor na altura 48

                  color: isSelected
                      ? const Color(0xFF2E74FF)
                      : (isDark ? Colors.white70 : Colors.grey.shade600),
                ),
                if (isSelected)
                  const Positioned(
                    top: 6,
                    right: -4,
                    child: Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Color(0xFF2E74FF),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );

      if (isFullWidth) {
        items.add(Expanded(child: itemContent));
      } else {
        items.add(SizedBox(width: 42, child: itemContent));
      }
    }

    return Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: items,
    );
  }

  double _computeFabLeft() {
    final box = context.findRenderObject() as RenderBox?;
    final stackW = box?.size.width ?? MediaQuery.of(context).size.width;
    final panelW = (stackW - 40) / 4;
    final fabLeft = (panelW / 2) - 125 + 20 - 25;
    return fabLeft < 0 ? 0 : fabLeft;
  }

  // Widget para filtros do histórico
  Widget _buildFiltrosHistorico() {
    return RepaintBoundary(
      key: const ValueKey('filtros_historico_passagens'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getFormGrisColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Primeira linha: Nome e Documento
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('filtro_nome_historico'),
                    controller: _filtroNomeHistoricoController,
                    inputFormatters: [LengthLimitingTextInputFormatter(50)],
                    decoration:
                        _getInputDecoration(context, 'Nome', 'nome_historico'),
                    enableInteractiveSelection: true,
                    readOnly: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('filtro_documento_historico'),
                    controller: _filtroDocumentoHistoricoController,
                    inputFormatters: [LengthLimitingTextInputFormatter(14)],
                    decoration: _getInputDecoration(
                        context, 'Documento', 'documento_historico'),
                    enableInteractiveSelection: true,
                    readOnly: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Segunda linha: Unidade e Placa
            Row(
              children: [
                Expanded(
                  child: LayoutBuilder(builder: (context, constraints) {
                    Map<String, dynamic>? selectedUnidade;
                    if (_filtroUnidadeHistoricoController.text.isNotEmpty) {
                      try {
                        selectedUnidade = _unidadesList.firstWhere(
                          (u) =>
                              unidadeLabelComMorador(u) ==
                              _filtroUnidadeHistoricoController.text,
                        );
                      } catch (_) {}
                    }
                    return buildStandardAutocomplete<Map<String, dynamic>>(
                      context: context,
                      labelText: 'Unidade',
                      items: _unidadesList,
                      itemAsString: (option) => unidadeLabelComMorador(option),
                      selectedItem: selectedUnidade,
                      onSelected: (value) {
                        setState(() {
                          _filtroUnidadeHistoricoController.text = value != null
                              ? unidadeLabelComMorador(value)
                              : '';
                        });
                      },
                      constraints: constraints,
                    );
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const ValueKey('filtro_placa_historico'),
                    controller: _filtroPlacaHistoricoController,
                    decoration: _getInputDecoration(context, 'Placa', 'placa'),
                    enableInteractiveSelection: true,
                    readOnly: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Terceira linha: Período (ocupando largura total)
            _buildPeriodFilter(
              context: context,
              startDate: _filtroDataInicioHistorico,
              endDate: _filtroDataFimHistorico,
              onStartDateChanged: (date) =>
                  setState(() => _filtroDataInicioHistorico = date),
              onEndDateChanged: (date) =>
                  setState(() => _filtroDataFimHistorico = date),
            ),
            const SizedBox(height: 12),

            // Quarta linha: Botões de açao
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar filtros',
                    color: IconColors.delete(context),
                    onPressed: () {
                      _filtroNomeHistoricoController.clear();
                      _filtroDocumentoHistoricoController.clear();
                      _filtroPlacaHistoricoController.clear();
                      _filtroUnidadeHistoricoController.clear();
                      setState(() {
                        _filtroDataInicioHistorico = null;
                        _filtroDataFimHistorico = null;
                        _mostrarRecentes = false;
                      });
                    },
                  ),
                  IconActionData(
                    icon: _mostrarRecentes ? Symbols.history : Symbols.search,
                    tooltip: _mostrarRecentes
                        ? 'Mostrar recentes'
                        : 'Buscar passagens',
                    color: _mostrarRecentes ? null : IconColors.search(context),
                    onPressed: () async {
                      if (_mostrarRecentes) {
                        await _buscarPassagensRecentes();
                      } else {
                        await _buscarHistoricoFiltrado();
                      }

                      setState(() {
                        _mostrarRecentes = !_mostrarRecentes;
                      });
                    },
                    isLoading: _loadingHistorico,
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Funçao para filtrar vagas por ID específico
  List<Map<String, dynamic>> _getVagasFiltradas() {
    // Requisito: Ná£o listar sem pesquisar
    if (_filtroVagasSelecionado == null || _filtroVagasSelecionado!.isEmpty) {
      return [];
    }

    return _vagasList.where((vaga) {
      final vagaId = vaga['vaga_id'].toString();
      return vagaId == _filtroVagasSelecionado;
    }).toList();
  }

  // Verifica se está usando histórico (quando filtros estão ativos)
  bool _isUsingHistorico() {
    return _filtroNomeHistoricoController.text.trim().isNotEmpty ||
        _filtroDocumentoHistoricoController.text.trim().isNotEmpty ||
        _filtroPlacaHistoricoController.text.trim().isNotEmpty ||
        _filtroUnidadeHistoricoController.text.trim().isNotEmpty ||
        _filtroDataInicioHistorico != null ||
        _filtroDataFimHistorico != null;
  }

  // Retorna o loading apropriado baseado nos filtros
  bool _getPassagensLoading() {
    return _isUsingHistorico() ? _loadingHistorico : _loadingPassagens;
  }

  //-----------------------------//
  // Retorna a lista apropriada baseado nos filtros (até 5 passagens)
  //-----------------------------//
  List<Map<String, dynamic>> _getPassagensList() {
    List<Map<String, dynamic>> lista;

    if (_isUsingHistorico()) {
      lista = _historicoFiltrado;
      print('📋 _getPassagensList: Usando histórico (${lista.length} items)');
    } else {
      // Usar as passagens do SignalR
      lista = _passagens;
    }

    // Ordenar por data (mais recentes primeiro) e limitar a 5
    final listaOrdenada = List<Map<String, dynamic>>.from(lista);
    listaOrdenada.sort((a, b) {
      final dataA = _parseDataPassagem(a);
      final dataB = _parseDataPassagem(b);
      // Ordem decrescente: data mais recente (maior) vem primeiro
      // sort(a, b): negativo = a antes, positivo = b antes
      // Se B > A (B mais recente), queremos B antes de A
      // Como sort compara (a, b), se a=A e b=B, queremos b antes de a = retorno positivo
      // B.compareTo(A): se B > A retorna positivo = b antes de a ✓
      return dataB
          .compareTo(dataA); // Para ordem decrescente (mais recente primeiro)
    });

    // Retornar até 5 passagens mais recentes (já ordenadas - mais recente primeiro)
    final result = listaOrdenada.take(5).toList();
    return result;
  }

  // Funçao para carregar unidades para filtro
  Future<void> _fetchUnidadesFiltro() async {
    setState(() => _loadingUnidadesFiltro = true);
    final result = await ReferenceDataService.fetchUnidadesFiltro(
      nome: _filtroNomeUnidadeController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _unidadesFiltroList = result;
        _unidadesList = result;
        _loadingUnidadesFiltro = false;
      });
    }
  }

  // Funçao para filtrar unidades por seleçao
  List<Map<String, dynamic>> _getUnidadesFiltradas() {
    final filtroUnidade = _filtroUnidadeController.text.trim();
    final filtroNome = _filtroNomeUnidadeController.text.trim();

    // Requisito: Ná£o listar sem pesquisar
    if (filtroUnidade.isEmpty && filtroNome.isEmpty) {
      return [];
    }

    // Filtrar por torre/unidade baseado na seleçao
    return _unidadesList.where((unidade) {
      bool matchesUnidade = true;
      if (filtroUnidade.isNotEmpty) {
        final unidadeTexto =
            unidade['unidade_mostra']?.toString().toLowerCase() ?? '';
        final moradorTexto =
            (unidade['nome_morador'] ?? unidade['morador'] ?? '')
                .toString()
                .toLowerCase();
        final busca = filtroUnidade.toLowerCase();
        matchesUnidade =
            unidadeTexto.contains(busca) || moradorTexto.contains(busca);
      }

      bool matchesNome = true;
      if (_filtroNomeUnidadeController.text.trim().isNotEmpty) {
        final nomeMorador =
            (unidade['nome_morador'] ?? unidade['morador'] ?? '')
                .toString()
                .toLowerCase();
        final filtroNome =
            _filtroNomeUnidadeController.text.trim().toLowerCase();
        matchesNome = nomeMorador.contains(filtroNome);
      }

      return matchesUnidade && matchesNome;
    }).toList();
  }

  // Buscar passagens recentes usando API passagem
  Future<void> _buscarPassagensRecentes() async {
    setState(() {
      _loadingHistorico = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'passagem'));

    final payload = {
      "condominio_id": int.tryParse(condominioId) ?? 0,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final passagensRecentes =
              List<Map<String, dynamic>>.from(data['data'] ?? []);

          setState(() {
            _historicoFiltrado = passagensRecentes;
            _loadingHistorico = false;
          });
        } else {
          setState(() {
            _historicoFiltrado = [];
            _loadingHistorico = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historicoFiltrado = [];
          _loadingHistorico = false;
        });
      }
    }
  }

  // Buscar histórico filtrado usando API passagemhistorico
  Future<void> _buscarHistoricoFiltrado() async {
    setState(() {
      _loadingHistorico = true;
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

      final url =
          Uri.parse('https://gate.conectcon.net.br/pt-br/passagemhistorico');

      // Usar data atual por padrão, ou filtro se selecionado
      final hoje = DateTime.now();
      final dataIni = _filtroDataInicioHistorico ?? hoje;
      final dataFim = _filtroDataFimHistorico ?? hoje;

      final payload = {
        "apto_id": 0,
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "dt_fim":
            '${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')} 23:59:59', // Data atual ou filtro (23:59:59)
        "dt_ini":
            '${dataIni.year}-${dataIni.month.toString().padLeft(2, '0')}-${dataIni.day.toString().padLeft(2, '0')} 00:00:00', // Data atual ou filtro (00:00:00)
        "nome": _filtroNomeHistoricoController.text.trim(),
        "pessoaveiculo": _filtroDocumentoHistoricoController.text.trim(),
        "placa": _filtroPlacaHistoricoController.text.trim(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final historico = List<Map<String, dynamic>>.from(data['data'] ?? []);

          setState(() {
            _historicoFiltrado = historico;
            _loadingHistorico = false;
          });
        } else {
          setState(() {
            _historicoFiltrado = [];
            _loadingHistorico = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _historicoFiltrado = [];
          _loadingHistorico = false;
        });
      }
    }
  }

  // Enriquecer dados de registros AV com informaá§ões do cadastro avulso
  Future<void> _enriquecerDadosAvulsos(
      List<Map<String, dynamic>> passagens) async {
    // Verificar se há registros AV
    final registrosAV = passagens.where((p) => p['tipo'] == 'AV').toList();
    if (registrosAV.isEmpty) {
      return;
    }

    // Sempre usar o condominio_id atual (SignalR > SharedPreferences)
    final condominioIdAtual = await getCondominioIdAtual();

    // Para cada registro AV, tentar buscar informaá§ões do cadastro avulso
    for (final passagem in registrosAV) {
      final documento = passagem['documento']?.toString() ??
          passagem['pessoaveiculo']?.toString() ??
          '';
      if (documento.isEmpty) continue;

      try {
        final prefs = await SharedPreferences.getInstance();
        final encrypted = prefs.getString('tokensessao_txt');
        final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
            ? decryptText(encrypted)
            : '';

        if (tokenSessao.isEmpty) continue;

        // Chamar cadastroavulsolist
        final urlList = Uri.parse(
          ApiConfig.getEndpoint('dashboard', 'cadastroAvulso'),
        );
        final payloadList = {
          "condominio_id": condominioIdAtual,
          "documento": documento,
        };

        final responseList = await http.post(
          urlList,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenSessao',
          },
          body: jsonEncode(payloadList),
        );

        if (responseList.statusCode == 200) {
          final data = jsonDecode(responseList.body);
          final lista = data['data']?['lista'] as List?;
          if (lista != null && lista.isNotEmpty) {
            final cadastroAvulso = lista[0] as Map<String, dynamic>;

            // Enriquecer a passagem com dados do cadastro avulso
            passagem.addAll({
              'nome': cadastroAvulso['nome'] ?? passagem['nome'],
              'telefone': cadastroAvulso['telefone'],
              'email': cadastroAvulso['email'],
              'empresa': cadastroAvulso['empresa'],
              'autorizante': cadastroAvulso['autorizante'],
              // Adicionar outros campos relevantes
            });
          }
        }
      } catch (e) {}
    }
  }

  // Buscar saídas filtradas usando API passagemhistorico com filtros aplicados
  Future<void> _buscarSaidasFiltradas() async {
    setState(() {
      _loadingSaidasList = true;
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

      final url =
          Uri.parse('https://gate.conectcon.net.br/pt-br/passagemhistorico');

      // Usar data atual por padrão, ou filtro se selecionado
      final hoje = DateTime.now();
      final dataIni = _filtroDataInicioSaidas ?? hoje;
      final dataFim = _filtroDataFimSaidas ?? hoje;

      final payload = {
        "apto_id": 0,
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "dt_fim":
            '${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')} 23:59:59', // Data atual ou filtro (23:59:59)
        "dt_ini":
            '${dataIni.year}-${dataIni.month.toString().padLeft(2, '0')}-${dataIni.day.toString().padLeft(2, '0')} 00:00:00', // Data atual ou filtro (00:00:00)
        "nome": _filtroNomeSaidasController.text.trim(),
        "pessoaveiculo": _filtroDocumentoSaidasController.text.trim(),
        "placa": _filtroPlacaSaidasController.text.trim(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final saidasFiltradas =
            List<Map<String, dynamic>>.from(data['data'] ?? []);

        // Mostrar todas as passagens, mesmo as que já têm saída registrada
        // Enriquecer dados das passagens com informaá§ões das unidades
        final passagensEnriquecidas =
            _enriquecerPassagensComDadosUnidade(saidasFiltradas);

        // Se há filtros aplicados, tentar enriquecer dados AV com informaá§ões do cadastro avulso
        if (_filtroDocumentoSaidasController.text.trim().isNotEmpty ||
            _filtroNomeSaidasController.text.trim().isNotEmpty) {
          await _enriquecerDadosAvulsos(passagensEnriquecidas);
        }

        setState(() {
          _todasPassagens = passagensEnriquecidas;
          _loadingSaidasList = false;
        });
      } else {
        setState(() {
          _todasPassagens = [];
          _loadingSaidasList = false;
        });
      }
    } catch (e) {
      setState(() {
        _todasPassagens = [];
        _loadingSaidasList = false;
      });
    }
  }

  // Buscar saídas usando API passagemhistorico (similar ao backup)
  Future<void> _buscarSaidasPorDocumento() async {
    if (_documentoController.text.trim().length < 6) return;

    // Buscar últimos 30 dias para ter um histórico relevante de saídas
    final hoje = DateTime.now();
    final dataIni = hoje.subtract(const Duration(days: 30));
    final dataFim = hoje;

    await _fetchHistoricoPassagens(
      dataIni: dataIni,
      dataFim: dataFim,
      documento: _documentoController.text.trim(),
    );

    // Filtrar apenas as saídas (registros com data de saída)
    setState(() {
      // Saídas sá£o filtradas dinamicamente quando necessário
    });
  }

  Future<void> _buscarEntradasFiltradas() async {
    setState(() {
      _loadingBuscaEntrada = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (condominioId.isEmpty) {
        setState(() {
          _loadingBuscaEntrada = false;
        });
        return;
      }

      if (tokenSessao.isEmpty) {
        setState(() {
          _loadingBuscaEntrada = false;
        });
        return;
      }

      // Preparar pará¢metros da requisiçao
      // Para visitantes, usar período se disponível, senão usar data única (início = fim = data atual)
      final DateTime dataInicio;
      final DateTime dataFim;

      // Se houver período selecionado, usar período
      if (_filtroDataInicioEntrada != null || _filtroDataFimEntrada != null) {
        dataInicio = _filtroDataInicioEntrada ?? DateTime.now();
        dataFim = _filtroDataFimEntrada ?? DateTime.now();
      } else {
        // Senão, usar data única (se disponível) ou data atual
        final DateTime dataPadrao = _filtroDataEntrada ?? DateTime.now();
        dataInicio = dataPadrao;
        dataFim = dataPadrao;
      }

      final documentoFiltro = _filtroDocumentoEntradaController.text.trim();

      final Map<String, dynamic> params = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'apto_id': _unidadeFiltroAplicada ??
            0, // Usar unidade_id selecionada no filtro
        'nome': _filtroNomeEntradaController.text.trim(),
        'documento': documentoFiltro,
        'dt_ini': null,
        'dt_fim': null,
        'tipoagendamento': 'S,H,M,A,',
      };

      // Armazenar documento usado no filtro para destaque
      _documentoFiltroAplicado =
          documentoFiltro.isNotEmpty ? documentoFiltro : null;

      // Sempre usar buscaentrada para encontrar pai/filho, depois convidadolist para montar lista
      final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'buscaentrada'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: json.encode(params),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Sempre processar resposta do buscaentrada (formato original)
        List<Map<String, dynamic>> resultados =
            List<Map<String, dynamic>>.from(responseData['data'] ?? []);

        if (resultados.isNotEmpty) {}

        setState(() {
          _resultadosBuscaEntrada = resultados;
          _loadingBuscaEntrada = false;
          // Só mostra form se não há resultados E não é caso de avulso (que será tratado separadamente)
          _mostrarFormEntrada =
              false; // Será definido posteriormente baseado na lógica
        });

        // Para múltiplos resultados, agrupar por reserva_id e buscar convidadolist para cada reserva
        if (resultados.isNotEmpty) {
          print(
              '[DEBUG] Agrupando ${resultados.length} resultado(s) por reserva_id');
          await _processarResultadosBuscaEntrada(resultados);
        } else {
          // Verificar se foram aplicados filtros de unidade e/ou data/período
          final temFiltroUnidade =
              _unidadeFiltroAplicada != null && _unidadeFiltroAplicada! > 0;
          final temFiltroData = _filtroDataEntrada != null;
          final temFiltroPeriodo =
              _filtroDataInicioEntrada != null || _filtroDataFimEntrada != null;
          final temFiltroDocumento = _documentoFiltroAplicado != null &&
              _documentoFiltroAplicado!.isNotEmpty;

          print('[DEBUG] Verificando filtros aplicados:');
          print(
              '[DEBUG] temFiltroUnidade: $temFiltroUnidade (unidade: $_unidadeFiltroAplicada)');
          print(
              '[DEBUG] temFiltroData: $temFiltroData (data: $_filtroDataEntrada)');
          print(
              '[DEBUG] temFiltroPeriodo: $temFiltroPeriodo (início: $_filtroDataInicioEntrada, fim: $_filtroDataFimEntrada)');
          print(
              '[DEBUG] temFiltroDocumento: $temFiltroDocumento (documento: $_documentoFiltroAplicado)');

          // Se aplicou filtros de unidade e/ou data/período (com ou sem documento), mostrar mensagem "visitante não encontrado"
          if (temFiltroUnidade || temFiltroData || temFiltroPeriodo) {
            print(
                '[DEBUG] Filtros aplicados mas nenhum visitante encontrado - mostrando mensagem');
            _mostrarMensagemAgendamentoNaoEncontrado();
          } else {
            // Quando não há filtros específicos (apenas busca geral), abrir diretamente o formulário vazio para novo usuário
            print(
                '[DEBUG] Nenhum filtro específico aplicado - abrindo formulário vazio para novo usuário');
            // Limpar formulário para novo cadastro
            _limparFormulario();
            // Marcar que é novo usuário e preencher documento pesquisado
            setState(() {
              _isNovoUsuario = true;
              _mostrarFormEntrada = true; // Mostrar formulário diretamente
              // Em agendamentos, não minimizar filtro ao abrir novo usuário - só minimiza quando selecionar usuário
              if (_tipoFiltroEntrada == 1) {
                _filtroEntradaMinimizado =
                    false; // Manter filtro visível em agendamentos
              } else {
                _filtroEntradaMinimizado =
                    true; // Em Avulso, minimizar normalmente
              }
              // Preencher documento pesquisado
              if (_documentoFiltroAplicado != null &&
                  _documentoFiltroAplicado!.isNotEmpty) {
                _documentoController.text = _documentoFiltroAplicado!;
                print(
                    ' Documento preenchido para novo usuário: $_documentoFiltroAplicado');
              }
            });
          }
        }
      } else {
        print('Erro na busca de entradas: ${response.statusCode}');
        setState(() {
          _resultadosBuscaEntrada = [];
          _loadingBuscaEntrada = false;
          _mostrarFormEntrada = true;
          // No modo Avulso, não minimizar o filtro
          if (_tipoFiltroEntrada == 0) {
            _filtroEntradaMinimizado =
                false; // Manter filtro visível no modo Avulso
          }
        });
      }
    } catch (e) {
      print('Erro ao buscar entradas: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _resultadosBuscaEntrada = [];
        _loadingBuscaEntrada = false;
        _mostrarFormEntrada = true;
        // No modo Avulso, não minimizar o filtro
        if (_tipoFiltroEntrada == 0) {
          _filtroEntradaMinimizado =
              false; // Manter filtro visível no modo Avulso
        }
      });
    }
  }

  //-----------------------------//
  // Buscar espaá§os sociais da API para modal de seleçao
  //-----------------------------//
  Future<List<Map<String, dynamic>>> _buscarEspacosSociaisParaModal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (condominioId.isEmpty || tokenSessao.isEmpty) {
        return [];
      }

      final url =
          Uri.parse('https://socialh.conectcon.net.br/pt-br/espacosociallist');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: json.encode({
          'condominio_id': int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print(' Resposta completa da API: $responseData');
        print(' Chaves na resposta: ${responseData.keys.toList()}');

        // Verificar se "outros" está diretamente na resposta ou dentro de "data"
        List<dynamic> outros = [];
        if (responseData.containsKey('outros')) {
          outros = responseData['outros'] as List<dynamic>? ?? [];
          print(
              ' Encontrado "outros" diretamente na resposta: ${outros.length} itens');
        } else if (responseData.containsKey('data') &&
            responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('outros')) {
            outros = data['outros'] as List<dynamic>? ?? [];
            print(
                ' Encontrado "outros" dentro de "data": ${outros.length} itens');
          }
        } else if (responseData.containsKey('data') &&
            responseData['data'] is List) {
          // Se data é uma lista, pode ser que a resposta seja diferente
          print(' "data" é uma lista, não um mapa');
        }

        print(' Total de itens em "outros": ${outros.length}');
        if (outros.isNotEmpty) {
          print(' Primeiro item de "outros": ${outros.first}');
        }

        // Filtrar apenas itens onde ordem > 1
        final filtrados = outros
            .where((item) {
              // Tentar converter ordem de diferentes tipos possíveis
              final ordemValue = item['ordem'];
              int ordem = 0;
              if (ordemValue is int) {
                ordem = ordemValue;
              } else if (ordemValue is double) {
                ordem = ordemValue.toInt();
              } else if (ordemValue is String) {
                ordem = int.tryParse(ordemValue) ?? 0;
              }

              final passaFiltro = ordem > 1;
              final descricao =
                  item['espacopublico_ds'] as String? ?? 'Sem descriçao';
              print(
                  '[DEBUG] Item ordem=$ordem (tipo original: ${ordemValue.runtimeType}), passaFiltro=$passaFiltro: $descricao');
              return passaFiltro;
            })
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        // Verificar se existe "social" na resposta e se tem itens
        List<dynamic> social = [];
        if (responseData.containsKey('social')) {
          social = responseData['social'] as List<dynamic>? ?? [];
          print(' Encontrado "social" na resposta: ${social.length} itens');
        } else if (responseData.containsKey('data') &&
            responseData['data'] is Map) {
          final data = responseData['data'] as Map<String, dynamic>;
          if (data.containsKey('social')) {
            social = data['social'] as List<dynamic>? ?? [];
            print(
                '[DEBUG] Encontrado "social" dentro de "data": ${social.length} itens');
          }
        }

        // Se houver itens em "social", adicionar opçao "Espaço Social" com flg_reserva: "S"
        if (social.isNotEmpty) {
          final espacoSocial = {
            'ordem': 2,
            'espacopublico_id': 0, // ID especial para espaço social
            'espacopublico_ds': 'Espaço Social',
            'flg_reserva': 'S',
            'icone': 'Event',
            'cpo_data': 1,
            'lblBtn_convidados': 'Convidado(s)',
            'max_convidado': 0,
          };
          filtrados.insert(0, espacoSocial); // Inserir no início da lista
          print(
              '[DEBUG] Adicionado "Espaço Social" com flg_reserva: "S" (${social.length} item(ns) em social)');
        } else {
          print(
              '[DEBUG] Nenhum item em "social", não adicionando opçao "Espaço Social"');
        }

        print(' Espaá§os sociais encontrados após filtro: ${filtrados.length}');
        return filtrados;
      } else {
        print('Erro ao buscar espaá§os sociais: ${response.statusCode}');
        return [];
      }
    } catch (e) {
      print('Erro ao buscar espaá§os sociais: $e');
      return [];
    }
  }

  //-----------------------------//
  // Modal de seleçao de espaá§os sociais
  //-----------------------------//
  Future<List<Map<String, dynamic>>?> _abrirModalSelecaoEspacosSociais() async {
    final espacos = await _buscarEspacosSociaisParaModal();

    if (!mounted) return null;

    if (espacos.isEmpty) {
      FeedbackUtils.showError(
        context: context,
        title: 'Atençao',
        message: 'Nenhum espaço social encontrado',
      );
      return null;
    }

    // Criar mapa de seleçao (todos marcados por padrão)
    final Map<int, bool> selecoes = {};
    for (final espaco in espacos) {
      final id = espaco['espacopublico_id'] as int? ?? 0;
      // Incluir também o ID 0 (espaço social especial)
      selecoes[id] = true; // Todos vêm marcados
    }

    final idsSelecionados = await showDialog<List<int>>(
      context: context,
      builder: (context) => _ModalSelecaoEspacosSociais(
        espacos: espacos,
        selecoesIniciais: selecoes,
      ),
    );

    if (idsSelecionados == null || idsSelecionados.isEmpty) {
      return null;
    }

    // Retornar os espaá§os completos selecionados
    return espacos.where((espaco) {
      final id = espaco['espacopublico_id'] as int? ?? 0;
      return idsSelecionados.contains(id);
    }).toList();
  }

  // Buscar agendamentos filtrados usando a mesma API buscaentrada com período
  Future<void> _buscarAgendamentosEntradaFiltrados(
      {List<Map<String, dynamic>>? espacosSelecionados}) async {
    print('ðŸ“… [DEBUG] _buscarAgendamentosEntradaFiltrados() chamada');

    setState(() {
      _loadingBuscaAgendamentos = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      print('ðŸ“… [DEBUG] encryptedCondominioId: $encryptedCondominioId');
      print('ðŸ“… [DEBUG] encryptedToken: $encryptedToken');

      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
      print('ðŸ“… [DEBUG] condominioId: $condominioId');
      print(
          'ðŸ“… [DEBUG] tokenSessao: ${tokenSessao.isNotEmpty ? "presente" : "ausente"}');

      if (condominioId.isEmpty) {
        print('ðŸ“… [DEBUG] condominioId vazio, cancelando busca');
        return;
      }

      if (tokenSessao.isEmpty) {
        print('ðŸ“… [DEBUG] tokenSessao vazio, cancelando busca');
        return;
      }

      // Preparar pará¢metros da requisiçao com período
      // Usar período selecionado ou data atual como padrão
      final DateTime dataInicio = _filtroDataInicioEntrada ?? DateTime.now();
      final DateTime dataFim = _filtroDataFimEntrada ?? DateTime.now();
      final documentoFiltro = _filtroDocumentoEntradaController.text.trim();
      print(
          'ðŸ“… [DEBUG] Período usado: ${dataInicio.toIso8601String()}Z até ${dataFim.toIso8601String()}Z');

      final Map<String, dynamic> params = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'apto_id': _unidadeFiltroAplicada ??
            0, // Usar unidade_id selecionada no filtro
        'nome': _filtroNomeEntradaController.text.trim(),
        'documento': documentoFiltro,
        'dt_ini': '${dataInicio.toIso8601String()}Z',
        'dt_fim': '${dataFim.toIso8601String()}Z',
        'tipo':
            'AG', // Forá§ar busca apenas de agendamentos (AG), não visitantes (AV)
      };

      // Adicionar espaá§os sociais selecionados no modal
      // Formatar como "M, A, H," usando os valores de flg_reserva
      if (espacosSelecionados != null && espacosSelecionados.isNotEmpty) {
        final flgReservas = espacosSelecionados
            .map((espaco) => espaco['flg_reserva'] as String? ?? '')
            .where((flg) => flg.isNotEmpty)
            .toList();

        if (flgReservas.isNotEmpty) {
          // Formatar como "S,H,M,A," (sem espaá§o)
          params['tipoagendamento'] = '${flgReservas.join(',')},';
          print(' Espaá§os sociais selecionados (flg_reserva): $flgReservas');
          print(' tipoagendamento formatado: ${params['tipoagendamento']}');
        }
      } else if (_espacoSocialSelecionado != null) {
        // Fallback para o filtro antigo se não houver seleçao no modal
        final espacoSocialCodigo = _espacoSocialSelecionado!['codigo'] ??
            _espacoSocialSelecionado!['id'];
        if (espacoSocialCodigo != null) {
          params['tipoagendamento'] = '${espacoSocialCodigo.toString()},';
        }
        print(
            ' Espaço social selecionado para filtro de agendamentos: ${_espacoSocialSelecionado!['descricao']} (código: $espacoSocialCodigo)');
      }

      // Armazenar documento usado no filtro para destaque
      _documentoFiltroAplicado =
          documentoFiltro.isNotEmpty ? documentoFiltro : null;

      print('ðŸ“… [DEBUG] Pará¢metros da busca de agendamento: $params');
      print('ðŸ“… [DEBUG] apto_id usado: ${_unidadeFiltroAplicada ?? 0}');

      // Sempre usar buscaentrada para encontrar pai/filho, depois convidadolist para montar lista
      final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'buscaentrada'));
      print('ðŸ“… [DEBUG] URL da API: $url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: json.encode(params),
      );

      print('ðŸ“… [DEBUG] Status da resposta: ${response.statusCode}');
      print('ðŸ“… [DEBUG] Corpo da resposta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        // Sempre processar resposta do buscaentrada (formato original)
        List<Map<String, dynamic>> resultados =
            List<Map<String, dynamic>>.from(responseData['data'] ?? []);

        print('ðŸ“… [DEBUG] Resultados encontrados: ${resultados.length}');
        if (resultados.isNotEmpty) {
          print('ðŸ“… [DEBUG] Primeiro resultado completo: ${resultados[0]}');
          print(
              'ðŸ“… [DEBUG] Campos disponíveis no primeiro resultado: ${resultados[0].keys.toList()}');
        }

        // Filtrar apenas agendamentos (AG) antes de processar no modo Agendamento
        final resultadosAgendamentos =
            resultados.where((r) => r['tipo']?.toString() == 'AG').toList();
        print(
            'ðŸ“… [DEBUG] Resultados filtrados para agendamentos: ${resultadosAgendamentos.length} de ${resultados.length}');

        setState(() {
          _resultadosBuscaEntrada =
              resultadosAgendamentos; // Armazenar apenas agendamentos
          _mostrarFormEntrada = false;
        });

        // Para múltiplos resultados, agrupar por reserva_id e buscar convidadolist para cada reserva
        if (resultadosAgendamentos.isNotEmpty) {
          print(
              'ðŸ“… [DEBUG] Agrupando ${resultadosAgendamentos.length} agendamento(s) por reserva_id');
          await _processarResultadosBuscaEntrada(resultadosAgendamentos,
              apenasAgendamentos: true);
        } else {
          // Verificar se foram aplicados filtros de unidade e/ou período
          final temFiltroUnidade =
              _unidadeFiltroAplicada != null && _unidadeFiltroAplicada! > 0;
          final temFiltroPeriodo =
              _filtroDataInicioEntrada != null || _filtroDataFimEntrada != null;
          final temFiltroDocumento = _documentoFiltroAplicado != null &&
              _documentoFiltroAplicado!.isNotEmpty;

          print('ðŸ“… [DEBUG] Verificando filtros aplicados:');
          print(
              'ðŸ“… [DEBUG] temFiltroUnidade: $temFiltroUnidade (unidade: $_unidadeFiltroAplicada)');
          print(
              'ðŸ“… [DEBUG] temFiltroPeriodo: $temFiltroPeriodo (início: $_filtroDataInicioEntrada, fim: $_filtroDataFimEntrada)');
          print(
              'ðŸ“… [DEBUG] temFiltroDocumento: $temFiltroDocumento (documento: $_documentoFiltroAplicado)');

          // Se aplicou filtros de unidade e/ou período (com ou sem documento), mostrar mensagem "agendamento não encontrado"
          if (temFiltroUnidade || temFiltroPeriodo) {
            print(
                'ðŸ“… [DEBUG] Filtros aplicados mas nenhum agendamento encontrado - mostrando mensagem');
            _mostrarMensagemAgendamentoNaoEncontrado();
          } else {
            // Quando não há filtros específicos (apenas busca geral), abrir diretamente o formulário vazio para novo usuário
            print(
                'ðŸ“… [DEBUG] Nenhum filtro específico aplicado - abrindo formulário vazio para novo usuário');
            // Limpar formulário para novo cadastro
            _limparFormulario();
            // Marcar que é novo usuário e preencher documento pesquisado
            setState(() {
              _isNovoUsuario = true;
              _mostrarFormEntrada = true; // Mostrar formulário diretamente
              // Em agendamentos, não minimizar filtro ao abrir novo usuário - só minimiza quando selecionar usuário
              if (_tipoFiltroEntrada == 1) {
                _filtroEntradaMinimizado =
                    false; // Manter filtro visível em agendamentos
              } else {
                _filtroEntradaMinimizado =
                    true; // Em Avulso, minimizar normalmente
              }
              // Preencher documento pesquisado
              if (_documentoFiltroAplicado != null &&
                  _documentoFiltroAplicado!.isNotEmpty) {
                _documentoController.text = _documentoFiltroAplicado!;
                print(
                    ' Documento preenchido para novo usuário: $_documentoFiltroAplicado');
              }
            });
          }
        }
      } else {
        print('Erro na busca de agendamentos: ${response.statusCode}');
        setState(() {
          _resultadosBuscaEntrada = [];
          _mostrarFormEntrada = true;
          // No modo Avulso, não minimizar o filtro
          if (_tipoFiltroEntrada == 0) {
            _filtroEntradaMinimizado =
                false; // Manter filtro visível no modo Avulso
          }
        });
      }
    } catch (e) {
      print('Erro ao buscar agendamentos: $e');
      print('Stack trace: ${StackTrace.current}');
      setState(() {
        _resultadosBuscaEntrada = [];
        _mostrarFormEntrada = true;
        // No modo Avulso, não minimizar o filtro
        if (_tipoFiltroEntrada == 0) {
          _filtroEntradaMinimizado =
              false; // Manter filtro visível no modo Avulso
        }
      });
    } finally {
      setState(() {
        _loadingBuscaAgendamentos = false;
      });
    }
  }

  Future<void> _processarResultadosBuscaEntrada(
      List<Map<String, dynamic>> resultados,
      {bool apenasAgendamentos = false}) async {
    print(
        '[DEBUG] _processarResultadosBuscaEntrada() chamada com ${resultados.length} resultados (apenasAgendamentos: $apenasAgendamentos)');

    // Mapear resultados da buscaentrada diretamente para o formato esperado pelos cards
    final List<Map<String, dynamic>> listaFormatada = resultados.map((res) {
      final tipoBusca = res['tipo']?.toString() ?? 'AG'; // AG ou AV
      final idFilho = int.tryParse(res['id_filho']?.toString() ?? '0') ?? 0;

      final map = Map<String, dynamic>.from(res);

      // Determinar o tipo do card
      if (tipoBusca == 'AV') {
        map['tipo'] = 'AV';
      } else if (idFilho == 0) {
        map['tipo'] = 'AG_EMPTY';
      } else {
        map['tipo'] = 'AG';
      }

      // Compatibilidade de campos (mapeando campos do buscaentrada para os nomes usados no card)
      map['convidado_txt'] = res['nome'] ?? '';
      map['documento_txt'] = res['documento'] ?? '';
      map['reserva_tipo_txt'] = res['destino'] ?? 'Agendamento';
      map['reserva_dt_ini'] = res['dt_ini'] ?? '';
      map['reserva_dt_fim'] = res['dt_fim'] ?? '';
      map['unidade_mostra'] =
          res['apto'] ?? res['unidade'] ?? ''; // buscaentrada retorna 'apto'
      map['unidade'] =
          res['apto'] ?? res['unidade'] ?? ''; // Garantir compatibilidade
      map['unidade_id'] =
          res['apto_id'] ?? res['unidade_id']; // buscaentrada retorna 'apto_id'
      map['reservaconvidado_id'] = res['id_filho'];
      map['reserva_id'] = res['id_pai'];
      map['link_foto'] = res[
          'link_foto']; // Preservar explicitamente o link da foto de buscaentrada
      map['foto'] = (res['link_foto'] != null &&
              res['link_foto'].toString().isNotEmpty &&
              res['link_foto'].toString() != 'null')
          ? res['link_foto'].toString()
          : (res['foto_id']?.toString() ??
              res['foto']
                  ?.toString()); // buscaentrada pode trazer link_foto, foto_id ou foto

      // Garantir mapeamento de entrada/saída para o dashboard identificar se pessoa já está "dentro"
      map['entrada'] = res['dt_entrada'] ??
          res['entrada'] ??
          res['data_entrada'] ??
          res['dt_ini'] ??
          '';
      map['saida'] = res['dt_saida'] ??
          res['saida'] ??
          res['data_saida'] ??
          res['dt_fim'] ??
          '';

      // Marcar origem para isolamento de abas: 0 = Avulso, 1 = Agendamento
      map['origem_tab'] = apenasAgendamentos ? 1 : 0;

      return map;
    }).toList();

    setState(() {
      _convidadosResultados = listaFormatada;
      _convidadosReserva =
          listaFormatada; // Sincronizar para o painel lateral também usar

      if (apenasAgendamentos) {
        _loadingBuscaAgendamentos = false;
      } else {
        _loadingBuscaEntrada = false;
      }

      // Se houver resultados, não mostrar formulário vazio
      if (listaFormatada.isNotEmpty) {
        _mostrarFormEntrada = false;
      }
    });

    print(
        'Exibindo total de ${listaFormatada.length} resultados do buscaentrada inline');
  }

  // Busca detalhes completos de um convidado específico via convidadolist
  Future<Map<String, dynamic>?> _obterConvidadoCompleto(
      int reservaId, int reservaConvidadoId) async {
    print(
        '[DEBUG] _obterConvidadoCompleto: reserva $reservaId, convidado $reservaConvidadoId');
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        print('[DEBUG] Token vazio');
        return null;
      }

      final url = Uri.parse(
          '${ApiConfig.socialhUrl}/convidadolist?reserva_id=$reservaId&culture=pt-br');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        List<dynamic> lista = [];
        Map<String, dynamic> resData = {};

        if (responseData is Map && responseData['data'] is Map) {
          resData = responseData['data'] as Map<String, dynamic>;
          if (resData['convidados'] is List) {
            lista = resData['convidados'] as List;
          }
        } else if (responseData is Map && responseData['data'] is List) {
          lista = responseData['data'] as List;
        } else if (responseData is List) {
          lista = responseData;
        }

        if (lista.isNotEmpty) {
          final convidado = lista.firstWhere(
            (c) {
              final id = (c['reservaconvidado_id'] ?? c['id'] ?? '').toString();
              return id == reservaConvidadoId.toString();
            },
            orElse: () => null,
          );

          if (convidado != null) {
            final map = Map<String, dynamic>.from(convidado);
            // Preservar informaá§ões da reserva se disponíveis no container
            map['reserva_tipo_txt'] = resData['destino'] ??
                resData['reserva_tipo_txt'] ??
                'Agendamento';
            map['reserva_dt_ini'] = resData['dt_ini'] ?? '';
            map['reserva_dt_fim'] = resData['dt_fim'] ?? '';
            print(' Convidado completo obtido: ${map['nome']}');
            return map;
          } else {
            print(
                '[DEBUG] Convidado $reservaConvidadoId não encontrado na lista da reserva $reservaId');
          }
        }
      } else {
        print('[DEBUG] Erro API convidadolist: ${response.statusCode}');
      }
    } catch (e) {
      print('[DEBUG] Erro em _obterConvidadoCompleto: $e');
    }
    return null;
  }

  Future<void> _executarSaida(Map<String, dynamic> dadosConvidado) async {
    // Tentar encontrar a passagem correspondente em _todasPassagens pelo documento
    final documento = dadosConvidado['documento']?.toString() ??
        dadosConvidado['cpf']?.toString() ??
        dadosConvidado['rg']?.toString() ??
        '';

    if (documento.isNotEmpty && _todasPassagens.isNotEmpty) {
      // Buscar passagem ativa (com entrada mas sem saída) pelo documento
      final passagem = _todasPassagens.cast<Map<String, dynamic>>().firstWhere(
        (p) {
          final docPassagem = (p['documento'] ?? p['cpf'] ?? '').toString();
          final temSaida =
              (p['dt_saida'] ?? p['saida'] ?? '').toString().isNotEmpty;
          return docPassagem == documento && !temSaida;
        },
        orElse: () => <String, dynamic>{},
      );

      if (passagem.isNotEmpty) {
        await _registrarSaida(passagem, saidaAgora: true);
        return;
      }
    }

    // Se tem passagem_id direto nos dados
    final passagemId =
        dadosConvidado['passagem_id'] ?? dadosConvidado['avulsopassagem_id'];
    if (passagemId != null) {
      final passagemMap = Map<String, dynamic>.from(dadosConvidado);
      passagemMap['id'] = passagemId;
      await _registrarSaida(passagemMap, saidaAgora: true);
      return;
    }

    // Fallback: usar registrarEntradaSaidaGlobal para convidados de reserva
    final reservaId = dadosConvidado['reserva_id']?.toString() ??
        dadosConvidado['id_pai']?.toString();
    final reservaconvidadoId =
        dadosConvidado['reservaconvidado_id']?.toString() ??
            dadosConvidado['id_filho']?.toString() ??
            dadosConvidado['sequencia']?.toString() ??
            dadosConvidado['id']?.toString();

    if (reservaId == null || reservaconvidadoId == null) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'IDs do convidado não encontrados',
      );
      return;
    }

    try {
      final saidaSucesso = await registrarEntradaSaidaGlobal(
        reservaId,
        reservaconvidadoId,
        false,
      );

      if (saidaSucesso) {
        print(' Saída registrada com sucesso');
        if (mounted) {
          FeedbackUtils.showSuccess(
            context: context,
            title: 'Saída Registrada',
            message: 'Saída registrada com sucesso!',
          );
        }

        // Atualizar apenas o card específico na lista existente
        print(' Atualizando card específico após saída...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Atualizar o card específico na lista _convidadosReserva
        setState(() {
          for (int i = 0; i < _convidadosReserva.length; i++) {
            final convidado = _convidadosReserva[i];
            final convidadoId = convidado['reservaconvidado_id']?.toString() ??
                convidado['sequencia']?.toString() ??
                convidado['id']?.toString();

            if (convidadoId == reservaconvidadoId) {
              // Atualizar data/hora de saída com formataçao correta
              final agora = DateTime.now();
              final dataFormatada =
                  '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}:${agora.second.toString().padLeft(2, '0')}';

              _convidadosReserva[i]['saida'] = dataFormatada;
              _convidadosReserva[i]['dt_saida'] = dataFormatada;
              print(
                  ' Card atualizado: ${convidado['convidado_txt'] ?? convidado['nome']} com saída em $dataFormatada');
              break;
            }
          }
        });

        // Reabrir o painel com a lista atualizada
        if (_convidadosReserva.isNotEmpty) {
          _abrirPainelConvidados(_convidadosReserva);
          print(
              ' Painel lateral atualizado com ${_convidadosReserva.length} convidados');
        }
      } else {
        print('[DEBUG] Falha ao registrar saída');
      }
    } catch (e) {
      print('[DEBUG] Erro na saída: $e');
    }
  }

  Future<void> _executarEntrada(Map<String, dynamic> dadosConvidado) async {
    print(
        'ðŸŸ¢ [DEBUG] Executando entrada para convidado: ${dadosConvidado['nome'] ?? dadosConvidado['convidado_txt']}');

    // Extrair IDs necessários
    final reservaId = dadosConvidado['reserva_id']?.toString() ??
        dadosConvidado['id_pai']?.toString();
    final reservaconvidadoId =
        dadosConvidado['reservaconvidado_id']?.toString() ??
            dadosConvidado['id_filho']?.toString() ??
            dadosConvidado['sequencia']?.toString() ??
            dadosConvidado['id']?.toString();

    if (reservaId == null || reservaconvidadoId == null) {
      print('[DEBUG] IDs necessários não encontrados para entrada');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'IDs do convidado não encontrados',
      );
      return;
    }

    try {
      print('ðŸŸ¢ [DEBUG] Registrando entrada (E)...');
      final entradaSucesso = await registrarEntradaSaidaGlobal(
        reservaId,
        reservaconvidadoId,
        true, // true para entrada
      );

      if (entradaSucesso) {
        print(' Entrada registrada com sucesso');
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Entrada Registrada',
          message: 'Entrada registrada com sucesso!',
        );
        await _limparFormularioEntrada();
      } else {
        print('[DEBUG] Falha ao registrar entrada');
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Erro ao registrar entrada',
        );
      }
    } catch (e) {
      print('[DEBUG] Erro na entrada: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro na Entrada',
        message: 'Erro na entrada',
        errorDetails: e.toString(),
      );
    }
  }

  void _abrirPainelConvidados(List<Map<String, dynamic>> convidados) {
    print('_abrirPainelConvidados CHAMADA com ${convidados.length} itens');

    // Atualizar a lista de convidados
    setState(() {
      _convidadosReserva = convidados;
      // Em agendamentos, não minimizar filtro ao abrir painel - só minimiza quando selecionar usuário
      if (_tipoFiltroEntrada == 1) {
        _filtroEntradaMinimizado =
            false; // Manter filtro visível em agendamentos até selecionar usuário
      } else {
        _filtroEntradaMinimizado = true; // Em Avulso, minimizar normalmente
      }
    });

    if (convidados.isEmpty) {
      print('ERRO: Lista de convidados vazia!');
      return;
    }

    final painel = Builder(
      builder: (builderContext) {
        // Forá§ar leitura do tema para garantir reconstruçao quando mudar
        final _ = Theme.of(builderContext);
        return Container(
          width: MediaQuery.of(builderContext).size.width * 0.4,
          color: getBackgroundColor(builderContext),
          child: Column(
            children: [
              // Header do painel
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                        color: getBorderColor(builderContext), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people,
                        color: getTextColor(builderContext), size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Convidados Encontrados',
                        style: TextStyle(
                          color: getTextColor(builderContext),
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        // Se o formulário já está aberto e preenchido (usuário selecionado), manter aberto
                        final formJaAbertoEPreenchido = _mostrarFormEntrada &&
                            (_selectedConvidadoId != null ||
                                _documentoController.text.trim().isNotEmpty ||
                                _nomeController.text.trim().isNotEmpty);

                        setState(() {
                          // Só fechar formulário se não houver usuário selecionado
                          if (!formJaAbertoEPreenchido) {
                            _mostrarFormEntrada = false;
                          }
                          _convidadosReserva = [];
                        });
                        _fecharPainelLateral();
                      },
                      icon: Icon(Icons.close,
                          color: getTextColor(builderContext)),
                      tooltip: 'Fechar',
                    ),
                  ],
                ),
              ),

              // Lista de convidados
              Expanded(
                child: convidados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.people_outline,
                                size: 64,
                                color: getSecondaryTextColor(builderContext)),
                            const SizedBox(height: 16),
                            Text(
                              'Sem convidados registrados',
                              style: TextStyle(
                                color: getSecondaryTextColor(builderContext),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'A API convidadolist retornou lista vazia',
                              style: TextStyle(
                                color: getSecondaryTextColor(builderContext),
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _convidadosReserva.length,
                        itemBuilder: (itemContext, index) {
                          final convidado = _convidadosReserva[index];
                          final nome = convidado['nome'] ??
                              convidado['convidado_txt'] ??
                              'Nome não informado';
                          final documento = convidado['documento'] ??
                              convidado['documento_txt'] ??
                              '';
                          final unidade = convidado['unidade'] ??
                              convidado['unidade_mostra'] ??
                              '';

                          // Verificar status de entrada/saída
                          // Verificar status de entrada/saída
                          final entradaStr = (convidado['entrada'] ??
                                  convidado['dt_entrada'] ??
                                  '')
                              .toString();
                          final saidaStr = (convidado['saida'] ??
                                  convidado['dt_saida'] ??
                                  '')
                              .toString();

                          bool jaDeuEntrada = entradaStr.isNotEmpty;
                          bool jaDeuSaida = saidaStr.isNotEmpty;
                          bool foiEntradaDiaAnterior = false;

                          // Lógica de Data: Apenas identificar se é dia anterior, SEM alterar as flags originais
                          if (jaDeuEntrada) {
                            // Basta verificar entrada para saber a data
                            try {
                              // [Extraçao da Data - Mantida igual]
                              String dataEntrada = '';
                              if (entradaStr.contains(' ')) {
                                dataEntrada = entradaStr.split(' ')[0];
                              } else if (entradaStr.length >= 10) {
                                dataEntrada = entradaStr.substring(0, 10);
                                if (dataEntrada.contains('-')) {
                                  final partes = dataEntrada.split('-');
                                  if (partes.length == 3) {
                                    dataEntrada =
                                        '${partes[2]}/${partes[1]}/${partes[0]}';
                                  }
                                }
                              }
                              dataEntrada = dataEntrada.trim();

                              final agora = DateTime.now();
                              final hojeStr =
                                  '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}';

                              bool dataDiferente = false;
                              try {
                                if (dataEntrada.isNotEmpty) {
                                  final partes = dataEntrada.split('/');
                                  if (partes.length == 3) {
                                    final d = int.tryParse(partes[0]) ?? 0;
                                    final m = int.tryParse(partes[1]) ?? 0;
                                    final y = int.tryParse(partes[2]) ?? 0;

                                    if (d > 0 && m > 0 && y > 0) {
                                      final entradaDt = DateTime(y, m, d);
                                      final hojeDt = DateTime(
                                          agora.year, agora.month, agora.day);

                                      if (entradaDt.year == hojeDt.year &&
                                          entradaDt.month == hojeDt.month &&
                                          entradaDt.day == hojeDt.day) {
                                        dataDiferente = false;
                                      } else {
                                        dataDiferente = true;
                                      }
                                    } else {
                                      dataDiferente = dataEntrada != hojeStr;
                                    }
                                  } else {
                                    dataDiferente = dataEntrada != hojeStr;
                                  }
                                }
                              } catch (e) {
                                dataDiferente = dataEntrada != hojeStr;
                              }

                              if (dataDiferente) {
                                foiEntradaDiaAnterior = true;
                                // Não resetamos jaDeuEntrada aqui, pois precisamos dele true para mostrar o botá£o Editar
                              }
                            } catch (e) {
                              print('Erro ao analisar data: $e');
                            }
                          }

                          // Ajuste flag temporária para caso de entrada antiga nao finalizada (comportamento de reset visual)
                          // Se entrou ontem e não saiu, tratamos como se precisasse de nova entrada?
                          // O usuario disse: "hoje é dia 14 ele é nova entrada e tem o editar"
                          // Vamos assumir que se foi dia anterior, SEMPRE permite nova entrada direta.

                          // Formatar data/hora da entrada para exibiçao
                          String entradaFormatada = '';
                          if (jaDeuEntrada) {
                            try {
                              final partes = entradaStr.split(' ');
                              if (partes.length >= 2) {
                                final dataPartes = partes[0].split('/');
                                final horaPartes = partes[1].split(':');
                                if (dataPartes.length == 3 &&
                                    horaPartes.length >= 2) {
                                  final dia = dataPartes[0].padLeft(2, '0');
                                  final mes = dataPartes[1].padLeft(2, '0');
                                  final ano = dataPartes[2];
                                  final hora = horaPartes[0].padLeft(2, '0');
                                  final minuto = horaPartes[1].padLeft(2, '0');
                                  entradaFormatada =
                                      '$dia/$mes/$ano á s $hora:$minuto';
                                }
                              }
                            } catch (e) {
                              entradaFormatada = entradaStr;
                            }
                          }

                          // Cor da borda baseada no status (ajustada para considerar dia anterior como "neutro/verde")
                          Color borderColor = getBorderColor(itemContext);
                          if (jaDeuEntrada &&
                              !jaDeuSaida &&
                              !foiEntradaDiaAnterior) {
                            borderColor = Colors.orange; // Dentro (Hoje)
                          } else if (jaDeuEntrada &&
                              (jaDeuSaida || foiEntradaDiaAnterior)) {
                            borderColor = Colors
                                .green; // Histórico (Entrou e Saiu Hoje OU Entrou dia anterior)
                            // Nota: Se entrou dia anterior e Não saiu, visualmente ficará verde (histórico) e botá£o Nova Entrada aparecerá.
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: getCardColor(itemContext),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: borderColor, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header com nome e botá£o
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        nome,
                                        style: TextStyle(
                                          color: getTextColor(itemContext),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TransparentIconGroup([
                                      // CASO 1: NUNCA ENTROU (entrada == "")
                                      if (!jaDeuEntrada) ...[
                                        // Apenas botá£o Entrada (Abre Form)
                                        IconActionData(
                                          icon: Icons.login,
                                          color: Colors.green,
                                          tooltip: 'Entrada', // "Entrada"
                                          onPressed: () =>
                                              _selecionarConvidadoParaEntrada(
                                                  convidado),
                                        ),
                                      ]

                                      // CASO 2: DENTRO HOJE (Entrou hoje, não saiu)
                                      else if (jaDeuEntrada &&
                                          !jaDeuSaida &&
                                          !foiEntradaDiaAnterior) ...[
                                        // Editar + Saída
                                        IconActionData(
                                          icon: Icons.edit,
                                          tooltip: 'Editar',
                                          onPressed: () =>
                                              _selecionarConvidadoParaEntrada(
                                                  convidado),
                                        ),
                                        IconActionData(
                                          icon: Icons.exit_to_app,
                                          color: Colors.red,
                                          tooltip: 'Saída',
                                          onPressed: () =>
                                              _executarSaida(convidado),
                                        ),
                                      ]

                                      // CASO 3: HISTá“RICO (Entrou e Saiu Hoje OU Entrou dia anterior)
                                      else ...[
                                        // Editar + Açao Direta (Nova Entrada / Entrada)
                                        IconActionData(
                                          icon: Icons.edit,
                                          tooltip: 'Editar',
                                          onPressed: () =>
                                              _selecionarConvidadoParaEntrada(
                                                  convidado),
                                        ),
                                        IconActionData(
                                          icon: Icons.login,
                                          color: Colors.green,
                                          tooltip: foiEntradaDiaAnterior
                                              ? 'Nova Entrada'
                                              : 'Entrada',
                                          // API Direta (não abre form)
                                          onPressed: () =>
                                              _novaEntrada(convidado),
                                        ),
                                      ]
                                    ]),
                                  ],
                                ),

                                const SizedBox(height: 8),

                                // Documento
                                if (documento.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.badge,
                                          size: 16,
                                          color: getSecondaryTextColor(
                                              itemContext)),
                                      const SizedBox(width: 6),
                                      Text(
                                        documento,
                                        style: TextStyle(
                                          color: getSecondaryTextColor(
                                              itemContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                // Unidade
                                if (unidade.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      Icon(Icons.location_on,
                                          size: 16,
                                          color: getSecondaryTextColor(
                                              itemContext)),
                                      const SizedBox(width: 6),
                                      Text(
                                        unidade,
                                        style: TextStyle(
                                          color: getSecondaryTextColor(
                                              itemContext),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],

                                // Status de entrada/saída
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: jaDeuEntrada && !jaDeuSaida
                                        ? Colors.orange.withValues(alpha: 0.1)
                                        : jaDeuEntrada && jaDeuSaida
                                            ? Colors.green
                                                .withValues(alpha: 0.1)
                                            : Colors.blue
                                                .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        jaDeuEntrada && !jaDeuSaida
                                            ? Icons.access_time
                                            : jaDeuEntrada && jaDeuSaida
                                                ? Icons.check_circle
                                                : Icons.schedule,
                                        size: 14,
                                        color: jaDeuEntrada && !jaDeuSaida
                                            ? Colors.orange
                                            : jaDeuEntrada && jaDeuSaida
                                                ? Colors.green
                                                : Colors.blue,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        jaDeuEntrada && !jaDeuSaida
                                            ? 'Entrada realizada $entradaFormatada'
                                            : jaDeuEntrada && jaDeuSaida
                                                ? 'Entrada/Saída completa'
                                                : 'Pode entrar',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: jaDeuEntrada && !jaDeuSaida
                                              ? Colors.orange
                                              : jaDeuEntrada && jaDeuSaida
                                                  ? Colors.green
                                                  : Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );

    print('Chamando _abrirPainelLateral com painel Container...');
    _abrirPainelLateral(painel);
    print('_abrirPainelLateral executado');
  }

  void _mostrarMensagemEntradaJaRealizada(
      [Map<String, dynamic>? dados, bool mostrarBotaoNovaEntrada = false]) {
    // Se não passar dados, usa os dados atuais (para compatibilidade)
    final entradaData = dados ?? {}; // Dados vazios se não informado
    final entradaStr =
        (entradaData['entrada'] ?? entradaData['dt_entrada'] ?? '').toString();
    final saidaStr =
        (entradaData['saida'] ?? entradaData['dt_saida'] ?? '').toString();
    final nomeUsuario =
        entradaData['nome'] ?? entradaData['convidado_txt'] ?? 'Usuário';
    final saidaVazia = saidaStr.isEmpty;

    // Tentar formatar a data e hora da entrada
    String dataFormatada = entradaStr;
    if (entradaStr.isNotEmpty) {
      try {
        // Assumindo formato dd/MM/yyyy HH:mm:ss
        final partes = entradaStr.split(' ');
        if (partes.length >= 2) {
          // Tem data e hora
          final dataPartes = partes[0].split('/');
          final horaPartes = partes[1].split(':');
          if (dataPartes.length == 3 && horaPartes.length >= 2) {
            final dia = dataPartes[0].padLeft(2, '0');
            final mes = dataPartes[1].padLeft(2, '0');
            final ano = dataPartes[2];
            final hora = horaPartes[0].padLeft(2, '0');
            final minuto = horaPartes[1].padLeft(2, '0');
            final segundo =
                horaPartes.length >= 3 ? horaPartes[2].padLeft(2, '0') : '00';
            dataFormatada = '$dia/$mes/$ano á s $hora:$minuto:$segundo';
          }
        } else if (partes.length == 1) {
          // Só tem data
          final dataPartes = partes[0].split('/');
          if (dataPartes.length == 3) {
            final dia = dataPartes[0].padLeft(2, '0');
            final mes = dataPartes[1].padLeft(2, '0');
            final ano = dataPartes[2];
            dataFormatada = '$dia/$mes/$ano';
          }
        }
      } catch (e) {
        print('[DEBUG] Erro ao formatar data/hora da entrada: $e');
        dataFormatada = entradaStr; // Manter original se der erro
      }
    }

    final painel = Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                saidaVazia ? 'Nova Entrada Disponível' : 'Entrada já realizada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: saidaVazia ? Colors.blue : Colors.orange,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _mostrarFormEntrada = false;
                  });
                  _fecharPainelLateral();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            saidaVazia
                ? 'Entrada realizada dia $dataFormatada, dar nova entrada ou saída'
                : '$nomeUsuario já deu entrada no dia $dataFormatada.\n\nPara registrar uma nova entrada, primeiro deve dar saída.',
            style: TextStyle(
              fontSize: 12,
              color: getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Card com informaá§ões do usuário
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: getBorderColor(context)),
            ),
            child: Column(
              children: [
                // Nome do usuário
                Text(
                  nomeUsuario,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                // Data da entrada
                Text(
                  'Entrada: $dataFormatada',
                  style: TextStyle(
                    fontSize: 12,
                    color: getSecondaryTextColor(context),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
          Align(
            alignment: Alignment.center,
            child: TransparentIconGroup([
              IconActionData(
                icon: Icons.local_shipping,
                tooltip: 'Nova entrada',
                onPressed: () {
                  _fecharPainelLateral();
                  _novaEntrada(entradaData);
                },
              ),
              IconActionData(
                icon: Icons.close,
                tooltip: 'Saída',
                onPressed: () {
                  _fecharPainelLateral();
                  _executarSaida(entradaData);
                },
              ),
            ]),
          ),
        ],
      ),
    );

    _abrirPainelLateral(painel);
  }

  Future<void> _novaEntrada(Map<String, dynamic> dadosConvidado) async {
    print(
        ' _novaEntrada: Iniciando API Call direta (Sem Form, Sem Saída Duplicada)');

    // Extrair IDs necessários (cópia da lógica robusta anterior)
    final reservaId = dadosConvidado['reserva_id']?.toString() ??
        dadosConvidado['id_pai']?.toString();
    final reservaconvidadoId =
        dadosConvidado['reservaconvidado_id']?.toString() ??
            dadosConvidado['id_filho']?.toString() ??
            dadosConvidado['sequencia']?.toString() ??
            dadosConvidado['id']?.toString();

    if (reservaId == null || reservaconvidadoId == null) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'IDs do convidado não encontrados',
      );
      return;
    }

    try {
      // Registrar entrada (E) diretamente
      final isAvulso = dadosConvidado['tipo'] == 'AV';
      bool entradaSucesso = false;

      if (isAvulso) {
        // Para AV, usar a lógica de registro de entrada avulso
        // Primeiro preencher os campos para garantir que a API tenha o que precisa
        _preencherCamposEntrada(dadosConvidado);
        await _registrarEntradaAvulso();
        // feedback e fechamento já sá£o tratados em _registrarEntradaAvulso
        return;
      } else {
        // AG (Agendamento): registrar entrada (E) diretamente
        entradaSucesso = await registrarEntradaSaidaGlobal(
          reservaId,
          reservaconvidadoId,
          true, // true para entrada
        );
      }
      if (entradaSucesso) {
        print(' Nova entrada registrada com sucesso');
        if (mounted) {
          FeedbackUtils.showSuccess(
            context: context,
            title: 'Entrada Registrada',
            message: 'Nova entrada registrada com sucesso!',
          );
        }

        // Atualizar apenas o card específico na lista existente
        print(' Atualizando card específico após nova entrada...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Atualizar o card específico na lista _convidadosReserva
        setState(() {
          for (int i = 0; i < _convidadosReserva.length; i++) {
            final convidado = _convidadosReserva[i];
            final convidadoId = convidado['reservaconvidado_id']?.toString() ??
                convidado['sequencia']?.toString() ??
                convidado['id']?.toString();

            if (convidadoId == reservaconvidadoId) {
              // Atualizar data/hora de entrada com formataçao correta (limpar saída)
              final agora = DateTime.now();
              final dataFormatada =
                  '${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year} ${agora.hour.toString().padLeft(2, '0')}:${agora.minute.toString().padLeft(2, '0')}:${agora.second.toString().padLeft(2, '0')}';

              _convidadosReserva[i]['entrada'] = dataFormatada;
              _convidadosReserva[i]['dt_entrada'] = dataFormatada;
              _convidadosReserva[i]['saida'] = null;
              _convidadosReserva[i]['dt_saida'] = null;
              print(
                  ' Card atualizado: ${convidado['convidado_txt'] ?? convidado['nome']} com entrada em $dataFormatada');
              break;
            }
          }
        });

        // Reabrir o painel com a lista atualizada
        if (_convidadosReserva.isNotEmpty) {
          _abrirPainelConvidados(_convidadosReserva);
          print(
              ' Painel lateral atualizado com ${_convidadosReserva.length} convidados');
        }
      } else {
        print('[DEBUG] Falha ao registrar nova entrada');
      }
    } catch (e) {
      print('[DEBUG] Erro na nova entrada: $e');
    }
  }

  void _mostrarMensagemAgendamentoNaoEncontrado() {
    final painel = Container(
      width: MediaQuery.of(context).size.width * 0.48,
      padding: const EdgeInsets.all(24),
      child: Card(
        elevation: 8,
        shadowColor: Colors.blue.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.blue.shade50.withValues(alpha: 0.3),
              ],
            ),
          ),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com ícone e título
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.event_busy,
                          color: Colors.blue.shade700,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Agendamento não encontrado',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade800,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            'Sem resultados para os filtros aplicados',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: Colors.grey.shade400,
                      size: 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _mostrarFormEntrada = false;
                      });
                      _fecharPainelLateral();
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.grey.shade100,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ácone principal
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.search_off,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
              ),

              const SizedBox(height: 24),

              // Mensagem
              Text(
                'Ops! Ná£o encontramos nenhum agendamento para os filtros aplicados.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: Colors.blue.shade600,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Verifique se a unidade e data está£o corretas, ou tente uma busca mais ampla.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botá£o
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    // Fechar painel
                    _fecharPainelLateral();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    shadowColor: Colors.blue.shade200,
                  ),
                  child: const Text(
                    'Entendi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    _abrirPainelLateral(painel);
  }

  void _abrirPainelNovoUsuarioAvulso() {
    final painel = Container(
      width: MediaQuery.of(context).size.width * 0.4,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Usuário não encontrado',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _mostrarFormEntrada = false;
                  });
                  _fecharPainelLateral();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Ná£o foi encontrado nenhum usuário com os critérios informados.',
            style: TextStyle(
              fontSize: 12,
              color: getTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Fechar painel primeiro
              _fecharPainelLateral();
              // Depois abrir form de entrada para cadastro avulso
              setState(() {
                _mostrarFormEntrada = true;
                _isNovoUsuario = true;
                // Em agendamentos, não minimizar filtro ao abrir novo usuário - só minimiza quando selecionar usuário
                if (_tipoFiltroEntrada == 1) {
                  _filtroEntradaMinimizado =
                      false; // Manter filtro visível em agendamentos
                } else {
                  _filtroEntradaMinimizado =
                      true; // Em Avulso, minimizar normalmente
                }
                // Preencher documento pesquisado no formulário
                if (_documentoFiltroAplicado != null &&
                    _documentoFiltroAplicado!.isNotEmpty) {
                  _documentoController.text = _documentoFiltroAplicado!;
                  print(
                      ' CPF preenchido automaticamente: $_documentoFiltroAplicado');
                }
              });
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Novo Usuário'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    _abrirPainelLateral(painel);
  }

  Future<void> _buscarConvidadosGeral() async {
    setState(() {
      _loadingBuscaEntrada = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        print('[DEBUG] Token vazio, não é possível buscar convidados');
        setState(() {
          _loadingBuscaEntrada = false;
        });
        return;
      }

      // Construir URL com filtros aplicados
      String urlParams = 'culture=pt-br';

      // Adicionar filtros aplicados
      if (_unidadeFiltroAplicada != null && _unidadeFiltroAplicada! > 0) {
        urlParams += '&apto_id=$_unidadeFiltroAplicada';
      }

      if (_filtroNomeEntradaController.text.trim().isNotEmpty) {
        urlParams += '&nome=${_filtroNomeEntradaController.text.trim()}';
      }

      if (_documentoFiltroAplicado != null &&
          _documentoFiltroAplicado!.isNotEmpty) {
        urlParams += '&documento=$_documentoFiltroAplicado';
      }

      final url = Uri.parse('${ApiConfig.socialhUrl}/convidadolist?$urlParams');
      print('[DEBUG] Buscando convidados geral com filtros');
      print('[DEBUG] URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      print('[DEBUG] Status resposta convidados: ${response.statusCode}');
      print('[DEBUG] Corpo resposta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('[DEBUG] Response completo: $responseData');

        // Tentar diferentes formatos de resposta
        List<Map<String, dynamic>> convidados = [];

        if (responseData['data'] is List) {
          convidados = List<Map<String, dynamic>>.from(responseData['data']);
        } else if (responseData['data'] is Map &&
            responseData['data']['convidados'] is List) {
          convidados = List<Map<String, dynamic>>.from(
              responseData['data']['convidados']);
        } else if (responseData is List) {
          convidados = List<Map<String, dynamic>>.from(responseData);
        }

        // Mostrar todos os convidados da reserva - a lógica de entrada/saída será aplicada na exibiçao
        print(
            '[DEBUG] Convidados retornados da API (antes de filtros): ${convidados.length}');

        // Filtro adicional por documento quando aplicado
        if (_documentoFiltroAplicado != null &&
            _documentoFiltroAplicado!.isNotEmpty) {
          final docAlvo =
              _documentoFiltroAplicado!.replaceAll(RegExp(r'\D'), '');
          convidados = convidados.where((c) {
            final doc = (c['documento'] ?? c['documento_txt'] ?? '')
                .toString()
                .replaceAll(RegExp(r'\D'), '');
            return doc.isNotEmpty && doc == docAlvo;
          }).toList();
          print(
              '[DEBUG] Aplicado filtro por documento. Restaram ${convidados.length} item(s).');
        }

        print('[DEBUG] Convidados encontrados: ${convidados.length}');
        print(
            '[DEBUG] Primeiro convidado (se existir): ${convidados.isNotEmpty ? convidados[0] : 'nenhum'}');

        setState(() {
          _convidadosReserva =
              convidados; // Usar a mesma variável para compatibilidade
          _loadingBuscaEntrada = false;
        });

        // Verificar se há apenas um convidado e se já deu entrada
        if (convidados.length == 1) {
          final convidado = convidados[0];
          final entradaStr =
              (convidado['entrada'] ?? convidado['dt_entrada'] ?? '')
                  .toString();
          final saidaStr = (convidado['saida'] ??
                  convidado['dt_saida'] ??
                  convidado['data_saida'] ??
                  convidado['saida_data'] ??
                  '')
              .toString();
          final jaDeuEntrada = entradaStr.isNotEmpty;
          final jaDeuSaida = saidaStr.isNotEmpty;

          print('[DEBUG] Verificando status do convidado único:');
          print('[DEBUG] entradaStr: "$entradaStr"');
          print('[DEBUG] saidaStr: "$saidaStr"');
          print('[DEBUG] jaDeuEntrada: $jaDeuEntrada, jaDeuSaida: $jaDeuSaida');

          if (jaDeuEntrada && !jaDeuSaida) {
            // Já deu entrada mas não deu saída - abrir painel com card único no padrão de Passagens
            print(
                '[DEBUG] Convidado já deu entrada - abrindo painel com card único no padrão de Passagens');
            _abrirPainelConvidados([convidado]);
            return;
          } else {
            print(
                '[DEBUG] Convidado pode dar entrada - continuando normalmente');
          }
        }

        // Abrir painel lateral com os resultados de convidadolist
        print(
            'Abrindo painel lateral com ${convidados.length} resultados de convidadolist');

        final painel = _ResultadosBuscaEntradaPanel(
          resultados: [], // Ná£o usar resultados de buscaentrada
          convidadosReserva: convidados, // Usar resultados de convidadolist
          reservaSelecionada: null, // Ná£o há reserva específica
          documentoFiltroAplicado: _documentoFiltroAplicado,
          onSelecionar: _selecionarEntrada,
          onSelecionarConvidado: _selecionarConvidadoReserva,
          onFechar: () {
            // Se o formulário já está aberto e preenchido (usuário selecionado), manter aberto
            final formJaAbertoEPreenchido = _mostrarFormEntrada &&
                (_selectedConvidadoId != null ||
                    _documentoController.text.trim().isNotEmpty ||
                    _nomeController.text.trim().isNotEmpty);

            setState(() {
              // Só fechar formulário se não houver usuário selecionado
              if (!formJaAbertoEPreenchido) {
                _mostrarFormEntrada = false;
              }
              _reservaSelecionada = null;
              _convidadosReserva = [];
              // Ná£o limpar _selectedConvidadoId se o formulário está aberto
              if (!formJaAbertoEPreenchido) {
                _selectedConvidadoId = null;
              }
              _filtrarReservaconvidadoId = null;
            });
            _fecharPainelLateral();
          },
        );

        print('Painel criado: ${painel.runtimeType}');
        _abrirPainelLateral(painel);
      } else {
        print(
            '[DEBUG] Erro ao buscar convidados geral: ${response.statusCode}');
        setState(() {
          _convidadosReserva = [];
          _loadingBuscaEntrada = false;
        });
      }
    } catch (e) {
      print('[DEBUG] Erro ao buscar convidados geral: $e');
      setState(() {
        _convidadosReserva = [];
        _loadingBuscaEntrada = false;
      });
    }
  }

  Future<void> _buscarConvidadosReserva(int reservaId,
      {bool mostrarTodos = false}) async {
    setState(() {
      _loadingBuscaEntrada = true;
      // Se mostrarTodos = true, limpar o filtro de convidado específico
      if (mostrarTodos) {
        _filtrarReservaconvidadoId = null;
        if (_reservaSelecionada != null) {
          _reservaSelecionada!.remove('reservaconvidado_id');
          _reservaSelecionada!.remove('id_filho');
          _reservaSelecionada!.remove('sequencia');
        }
      }
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        print('[DEBUG] Token vazio, não é possível buscar convidados');
        setState(() {
          _loadingBuscaEntrada = false;
        });
        return;
      }

      final url = Uri.parse(
          '${ApiConfig.socialhUrl}/convidadolist?reserva_id=$reservaId&culture=pt-br');
      print('[DEBUG] Buscando convidados da reserva: $reservaId');
      print('[DEBUG] URL: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      print('[DEBUG] Status resposta convidados: ${response.statusCode}');
      print('[DEBUG] Corpo resposta: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        print('[DEBUG] Response completo: $responseData');

        // Tentar diferentes formatos de resposta
        List<Map<String, dynamic>> convidados = [];

        if (responseData['data'] is List) {
          convidados = List<Map<String, dynamic>>.from(responseData['data']);
        } else if (responseData['data'] is Map &&
            responseData['data']['convidados'] is List) {
          convidados = List<Map<String, dynamic>>.from(
              responseData['data']['convidados']);
        } else if (responseData is List) {
          convidados = List<Map<String, dynamic>>.from(responseData);
        }

        // Mostrar TODOS os convidados (incluindo os que já deram entrada)
        // Ná£o filtrar mais - mostrar todos para permitir ver histórico de entradas

        print(
            '[DEBUG] _buscarConvidadosReserva: mostrarTodos=$mostrarTodos, _filtrarReservaconvidadoId=$_filtrarReservaconvidadoId, convidados.length=${convidados.length}');

        // Filtro adicional: mostrar apenas o convidado chamado (id filho), quando disponível
        // EXCETO quando mostrarTodos = true (usado após entrada/saída para mostrar todos os cards)
        if (!mostrarTodos &&
            _filtrarReservaconvidadoId != null &&
            _filtrarReservaconvidadoId!.isNotEmpty) {
          final alvoId = _filtrarReservaconvidadoId!;
          convidados = convidados.where((c) {
            final idC =
                (c['reservaconvidado_id'] ?? c['sequencia'] ?? c['id'] ?? '')
                    .toString();
            return idC == alvoId;
          }).toList();
          print(
              '[DEBUG] Aplicado filtro por reservaconvidado_id=$alvoId. Restaram ${convidados.length} item(s).');
          if (convidados.isEmpty) {
            print(
                '[DEBUG] AVISO: Nenhum convidado encontrado com ID $alvoId. Verificar se o ID está correto.');
          }
        } else {
          // Quando não há filtro específico de convidado, mostrar todos os convidados da reserva
          // Isso acontece quando estamos processando múltiplos resultados do buscaentrada
          print(
              '[DEBUG] Nenhum filtro específico aplicado - mostrando todos os convidados da reserva $reservaId');

          // Ainda podemos aplicar filtro por documento se foi especificado na busca
          if (_documentoFiltroAplicado != null &&
              _documentoFiltroAplicado!.isNotEmpty) {
            print(
                '[DEBUG] Aplicando filtro adicional por documento: $_documentoFiltroAplicado');
            final docAlvo =
                _documentoFiltroAplicado!.replaceAll(RegExp(r'\D'), '');
            final convidadosOriginais =
                List<Map<String, dynamic>>.from(convidados);
            convidados = convidados.where((c) {
              final doc = (c['documento'] ?? c['documento_txt'] ?? '')
                  .toString()
                  .replaceAll(RegExp(r'\D'), '');
              return doc.isNotEmpty && doc == docAlvo;
            }).toList();
            print(
                '[DEBUG] Aplicado filtro por documento. Restaram ${convidados.length} de ${convidadosOriginais.length} item(s).');
          }
        }

        // Filtro adicional por unidade quando aplicado no filtro de entrada
        if (_unidadeFiltroAplicada != null && _unidadeFiltroAplicada! > 0) {
          final unidadeId = _unidadeFiltroAplicada!;
          convidados = convidados.where((c) {
            final aptoId = c['apto_id'] ?? c['unidade_id'] ?? 0;
            return aptoId == unidadeId;
          }).toList();
          print(
              ' Aplicado filtro por unidade apto_id=$unidadeId. Restaram ${convidados.length} item(s).');
        }

        print('[DEBUG] Convidados encontrados: ${convidados.length}');
        print(
            '[DEBUG] Primeiro convidado (se existir): ${convidados.isNotEmpty ? convidados[0] : 'nenhum'}');

        setState(() {
          _convidadosReserva = convidados;
          _loadingBuscaEntrada = false;
        });

        // Verificar se há apenas um convidado e se já deu entrada
        if (convidados.length == 1) {
          final convidado = convidados[0];
          final entradaStr =
              (convidado['entrada'] ?? convidado['dt_entrada'] ?? '')
                  .toString();
          final saidaStr = (convidado['saida'] ??
                  convidado['dt_saida'] ??
                  convidado['data_saida'] ??
                  convidado['saida_data'] ??
                  '')
              .toString();
          final jaDeuEntrada = entradaStr.isNotEmpty;
          final jaDeuSaida = saidaStr.isNotEmpty;

          print('[DEBUG] Verificando status do convidado único:');
          print('[DEBUG] entradaStr: "$entradaStr"');
          print('[DEBUG] saidaStr: "$saidaStr"');
          print('[DEBUG] jaDeuEntrada: $jaDeuEntrada, jaDeuSaida: $jaDeuSaida');
          print('[DEBUG] Todos os campos do convidado: $convidado');

          if (jaDeuEntrada && !jaDeuSaida) {
            // Já deu entrada mas não deu saída - mostrar mensagem com botá£o nova entrada
            print(
                '[DEBUG] Convidado já deu entrada - mostrando mensagem com botá£o nova entrada');
            _mostrarMensagemEntradaJaRealizada(convidado, true);
            return;
          } else {
            print(
                '[DEBUG] Convidado pode dar entrada - continuando normalmente');
          }
        }

        // Abrir painel normal com os convidados
        print('Abrindo painel lateral com ${convidados.length} convidados');
        print('Reserva ID: $reservaId');

        final painel = _PainelSelecaoConvidados(
          titulo: 'Selecionar Convidado',
          convidados: convidados,
          reservaId: reservaId.toString(),
          onSelecionar: (convidado) {
            // Apenas preencher form, manter painel aberto
            _selecionarConvidadoParaEntrada(convidado);
          },
          onAtualizar: () => _buscarConvidadosReserva(reservaId),
          onFechar: () {
            // Se o formulário já está aberto e preenchido (usuário selecionado), manter aberto
            final formJaAbertoEPreenchido = _mostrarFormEntrada &&
                (_selectedConvidadoId != null ||
                    _documentoController.text.trim().isNotEmpty ||
                    _nomeController.text.trim().isNotEmpty);

            setState(() {
              // Só fechar formulário se não houver usuário selecionado
              if (!formJaAbertoEPreenchido) {
                _mostrarFormEntrada = false;
              }
              _reservaSelecionada = null;
              _convidadosReserva = [];
              // Ná£o limpar _selectedConvidadoId se o formulário está aberto
              if (!formJaAbertoEPreenchido) {
                _selectedConvidadoId = null;
              }
              _filtrarReservaconvidadoId = null;
            });
            _fecharPainelLateral();
          },
        );

        print('Painel criado: ${painel.runtimeType}');
        _abrirPainelLateral(painel);
      } else {
        print('Erro ao buscar convidados: ${response.statusCode}');
        // Mesmo com erro, abrir painel com lista vazia para mostrar mensagem
        setState(() {
          _convidadosReserva = [];
          _loadingBuscaEntrada = false;
        });

        print('Abrindo painel lateral mesmo com erro (lista vazia)');
        _abrirPainelLateral(
          _PainelSelecaoConvidados(
            titulo: 'Selecionar Convidado',
            convidados: [],
            reservaId: reservaId.toString(),
            onSelecionar: (convidado) {
              _selecionarConvidadoParaEntrada(convidado);
            },
            onAtualizar: () => _buscarConvidadosReserva(reservaId),
            onFechar: () {
              setState(() {
                _mostrarFormEntrada = false;
                _reservaSelecionada = null;
                _convidadosReserva = [];
                _selectedConvidadoId = null;
                _filtrarReservaconvidadoId = null;
              });
              _fecharPainelLateral();
            },
          ),
        );
      }
    } catch (e) {
      print('Erro ao buscar convidados da reserva: $e');
      // Mesmo com erro de exception, abrir painel com lista vazia
      setState(() {
        _convidadosReserva = [];
        _loadingBuscaEntrada = false;
      });

      print('Abrindo painel lateral mesmo com exception (lista vazia)');
      _abrirPainelLateral(
        _PainelSelecaoConvidados(
          titulo: 'Selecionar Convidado',
          convidados: [],
          reservaId: reservaId.toString(),
          onSelecionar: (convidado) {
            _selecionarConvidadoParaEntrada(convidado);
          },
          onAtualizar: () => _buscarConvidadosReserva(reservaId),
          onFechar: () {
            setState(() {
              _mostrarFormEntrada = false;
              _reservaSelecionada = null;
              _convidadosReserva = [];
              _selectedConvidadoId = null;
              _filtrarReservaconvidadoId = null;
            });
            _fecharPainelLateral();
          },
        ),
      );
    }
  }

  void _selecionarEntrada(Map<String, dynamic> entrada) {
    print(
        '[DEBUG] _selecionarEntrada chamada com: tipo=${entrada['tipo']}, id_pai=${entrada['id_pai']}');

    // Para AV: verificar entrada na buscaentrada (como era antes)
    if (entrada['tipo'] == 'AV') {
      final entradaStr = (entrada['entrada'] ??
              entrada['dt_entrada'] ??
              entrada['dt_ini'] ??
              '')
          .toString();
      final saidaStr =
          (entrada['saida'] ?? entrada['dt_saida'] ?? entrada['dt_fim'] ?? '')
              .toString();
      final jaDeuEntrada = entradaStr.isNotEmpty;
      final jaDeuSaida = saidaStr.isNotEmpty;

      print('[DEBUG] Verificando entrada AV em _selecionarEntrada:');
      print('[DEBUG] entradaStr: "$entradaStr"');
      print('[DEBUG] saidaStr: "$saidaStr"');
      print('[DEBUG] jaDeuEntrada: $jaDeuEntrada, jaDeuSaida: $jaDeuSaida');

      if (jaDeuEntrada && !jaDeuSaida) {
        // Já deu entrada mas não deu saída - abrir painel com card único no padrão de Passagens
        print(
            '[DEBUG] Usuário AV já deu entrada - abrindo painel com card único no padrão de Passagens');
        _abrirPainelConvidados([entrada]);
        return;
      }
    }

    // Pode dar entrada - preencher campos e mostrar form
    _preencherCamposEntrada(entrada);

    // Verificar se é um agendamento (só se for tipo AG, nunca AV)
    final isAgendamento = entrada['tipo'] == 'AG';
    final isAvulso = entrada['tipo'] == 'AV';
    final unidadeAgendamento = entrada['unidade']?.toString() ??
        entrada['unidade_res']?.toString() ??
        entrada['apto']?.toString() ??
        entrada['apto_id']?.toString() ??
        '';

    setState(() {
      _mostrarFormEntrada = true;
      _isNovoUsuario = false; // Ná£o é novo usuário
      // Só marcar como agendamento se for tipo AG e estiver no modo Avulso
      // AV sempre é tratado como entrada avulso, nunca como agendamento
      _isAgendamento = isAgendamento && _tipoFiltroEntrada == 0 && !isAvulso;
      _unidadeAgendamento = _isAgendamento ? unidadeAgendamento : null;
      // Limpar reserva selecionada se for AV (AV não tem reserva)
      if (isAvulso) {
        _reservaSelecionada = null;
      }
      // Em agendamentos, não minimizar filtro ao encontrar usuário - só minimiza quando selecionar usuário
      // Em Avulso, minimizar normalmente
      if (_tipoFiltroEntrada == 1) {
        _filtroEntradaMinimizado =
            false; // Manter filtro visível em agendamentos até selecionar usuário
      } else {
        _filtroEntradaMinimizado = true; // Em Avulso, minimizar normalmente
      }
    });

    // Se for AG e tiver id_pai, buscar os convidados da reserva (a verificaçao de entrada será feita lá)
    // AV nunca deve buscar convidados, pois não tem reserva
    if (entrada['tipo'] == 'AG' && entrada['id_pai'] != null && !isAvulso) {
      print(
          '[DEBUG] Selecionada reserva AG com id_pai: ${entrada['id_pai']}, buscando convidados...');
      setState(() {
        _reservaSelecionada = entrada;
        // Capturar possível id do convidado (filho) para filtrar a lista
        _filtrarReservaconvidadoId =
            entrada['reservaconvidado_id']?.toString() ??
                entrada['id_filho']?.toString() ??
                entrada['sequencia']?.toString() ??
                entrada['id']?.toString() ?? // Campo 'id' como fallback
                _filtrarReservaconvidadoId;
      });
      print('[DEBUG] Dados da entrada selecionada: $entrada');
      if (_filtrarReservaconvidadoId != null) {
        print(
            '[DEBUG] Filtrando convidado filho ID: $_filtrarReservaconvidadoId');
      } else {
        print(
            'âš ï¸ [DEBUG] AVISO: Nenhum ID de filho encontrado para filtrar a lista de convidados');
      }
      _buscarConvidadosReserva(entrada['id_pai']);
    } else {
      // Para tipo AV: sempre tratar como entrada avulso, nunca como agendamento
      if (entrada['tipo'] == 'AV') {
        print(
            '[DEBUG] Selecionada entrada AV - carregando dados do cadastro avulso (NUNCA como agendamento)');
        // Garantir que não está marcado como agendamento
        setState(() {
          _isAgendamento = false;
          _reservaSelecionada = null;
        });
        // Carregar dados do cadastro avulso via APIs
        _carregarCadastroAvulsoParaEntrada(entrada);
      } else {
        // Para outros tipos sem id_pai: apenas preencher form com dados recebidos
        print(
            '[DEBUG] Selecionada entrada ${entrada['tipo']} - apenas preenchendo formulário');
      }
    }
  }

  // Carregar dados do cadastro avulso quando selecionar entrada AV
  Future<void> _carregarCadastroAvulsoParaEntrada(
      Map<String, dynamic> entrada) async {
    print(
        '[DEBUG] _carregarCadastroAvulsoParaEntrada chamado com entrada: $entrada');

    final documento = entrada['documento'] ?? entrada['documento_txt'] ?? '';
    if (documento.isEmpty) {
      print(
          'âš ï¸ [DEBUG] Documento vazio na entrada AV, não é possível carregar cadastro');
      return;
    }

    // Preencher o documento no controller para as APIs funcionarem
    _documentoController.text = documento;

    final prefs = await SharedPreferences.getInstance();
    final condominioId = prefs.getString('condominio_id') ?? '';
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    if (tokenSessao.isEmpty || condominioId.isEmpty) {
      print('âš ï¸ [DEBUG] Token ou condomínio não disponíveis');
      return;
    }

    try {
      // 1. Chamar cadastroavulslist (API cadastroAvulso)
      print('[DEBUG] Chamando cadastroavulslist para documento: $documento');
      final urlList = Uri.parse(
        ApiConfig.getEndpoint('dashboard', 'cadastroAvulso'),
      );
      final payloadList = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "documento": documento,
      };

      final responseList = await http.post(
        urlList,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadList),
      );

      Map<String, dynamic>? cadastro;
      if (responseList.statusCode == 200) {
        final data = jsonDecode(responseList.body);
        final lista = data['data']?['lista'] as List?;
        if (lista != null && lista.isNotEmpty) {
          cadastro = lista[0];
          print('[DEBUG] Cadastro encontrado via cadastroavulslist: $cadastro');
          print(
              '[DEBUG] Campos disponíveis no cadastro: ${cadastro?.keys.toList()}');
        }
      }

      // 2. Chamar avulsoselecionado
      print('[DEBUG] Chamando avulsoselecionado para documento: $documento');
      final urlSel = Uri.parse(
        ApiConfig.getEndpoint('dashboard', 'avulsoSelecionado'),
      );
      final payloadSel = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "documento": documento,
      };

      Map<String, dynamic>? selecionado;
      final responseSel = await http.post(
        urlSel,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payloadSel),
      );

      if (responseSel.statusCode == 200) {
        final dataSel = jsonDecode(responseSel.body);
        final listaSel = (dataSel['data']?['selecionado'] as List?);
        if (listaSel != null && listaSel.isNotEmpty) {
          selecionado = listaSel[0] as Map<String, dynamic>;
          print(
              '[DEBUG] Selecionado encontrado via avulsoselecionado: $selecionado');
          print(
              '[DEBUG] Campos disponíveis no selecionado: ${selecionado.keys.toList()}');
        }
      }

      // 3. Se encontrou dados, atualizar o cadastro avulso
      if (cadastro != null || selecionado != null) {
        setState(() {
          _temCadastroAvulso = true;
          _cadastroAvulso = selecionado != null
              ? {...(cadastro ?? {}), ...selecionado}
              : {...(cadastro ?? {})};

          // Salvar o ID do documento
          if (selecionado != null &&
              selecionado['pessoadocumento_id'] != null) {
            _cadastroAvulso!['pessoadocumento_id'] =
                selecionado['pessoadocumento_id'];
            _ultimoPessoadocumentoId = selecionado['pessoadocumento_id'];
          }

          // Preencher campos adicionais do form com dados do cadastro
          if (cadastro != null) {
            _nomeController.text = cadastro['nome'] ?? _nomeController.text;
            _empresaController.text =
                cadastro['empresa'] ?? _empresaController.text;
            _autorizanteController.text =
                cadastro['autorizante'] ?? _autorizanteController.text;
            _placaController.text = cadastro['placa'] ?? _placaController.text;
            _modeloController.text =
                cadastro['modelo'] ?? _modeloController.text;
            _obsController.text = cadastro['obs'] ?? _obsController.text;

            // Preencher unidade (apto_id)
            final aptoId = cadastro['apto_id'] ?? cadastro['unidade_id'];
            if (aptoId != null) {
              // Procurar a unidade correspondente na lista de unidades
              final unidadeEncontrada = _unidadesList.firstWhere(
                (unidade) =>
                    unidade['apto_id'] == aptoId || unidade['id'] == aptoId,
                orElse: () => {},
              );
              if (unidadeEncontrada.isNotEmpty) {
                _selectedUnidade = unidadeEncontrada;
                print(
                    ' Unidade preenchida automaticamente: ${unidadeEncontrada['unidade_mostra'] ?? unidadeEncontrada['nome']}');
              }
            }
          }
        });

        // Lógica para carregar fotos após setState
        // Usar pessoacadastro_id para buscar fotos
        int idSel = selecionado?['pessoacadastro_id'] ?? 0;
        int idCad = cadastro?['pessoacadastro_id'] ?? 0;
        int pId = idSel > 0 ? idSel : idCad;

        print(
            '[DEBUG-CARREGAR] Tentando carregar fotos (pessoacadastro_id). ID Sel: $idSel, ID Cad: $idCad, Final: $pId');

        if (pId > 0) {
          _buscarFotosAvulso(pId);
        } else {
          print(
              'âš ï¸ [DEBUG-CARREGAR] Sem ID válido para buscar fotos na entrada.');
          setState(() {
            _fotoBase64 = null;
            _fotoDocumentoBase64 = null;
            _fotoRostoEntrada = null;
            _fotoDocumentoEntrada = null;
          });
        }

        print(' Cadastro AV carregado com sucesso para entrada');
      } else {
        print(
            'âš ï¸ [DEBUG] Nenhum cadastro encontrado para o documento AV: $documento');
      }
    } catch (e) {
      print('[DEBUG] Erro ao carregar cadastro AV: $e');
    }
  }

  Future<void> _selecionarConvidadoParaEntrada(
      Map<String, dynamic> convidado) async {
    // Debug detalhado dos dados do convidado
    print(
        'ðŸŽ¯ Convidado selecionado para entrada: ${convidado['nome'] ?? convidado['convidado_txt']}');
    print('ðŸŽ¯ Dados básicos do buscaentrada: $convidado');

    // Mover os dados para um mapa mutável que pode ser enriquecido
    Map<String, dynamic> dadosCompletos = Map<String, dynamic>.from(convidado);

    // Verificar o tipo do convidado (AV ou AG)
    final tipoConvidado = convidado['tipo']?.toString() ?? '';
    final isAvulso = tipoConvidado == 'AV';
    final isAgendamentoComFilho = tipoConvidado == 'AG';

    // Se for um agendamento com filho, buscar dados completos via convidadolist
    if (isAgendamentoComFilho) {
      final idFilho = int.tryParse(
              convidado['reservaconvidado_id']?.toString() ??
                  convidado['id_filho']?.toString() ??
                  '0') ??
          0;
      final idPai = int.tryParse(convidado['reserva_id']?.toString() ??
              convidado['id_pai']?.toString() ??
              '0') ??
          0;

      if (idFilho > 0 && idPai > 0) {
        print(
            '[DEBUG] Buscando detalhes completos via convidadolist (Pai: $idPai, Filho: $idFilho)...');
        final completo = await _obterConvidadoCompleto(idPai, idFilho);
        if (completo != null) {
          print(' Detalhes completos obtidos: ${completo['nome']}');
          // Enriquecer os dados (mas manter o ID do pai se necessário)
          dadosCompletos.addAll(completo);
          // Garantir mapeamento de campos que podem ter nomes diferentes
          dadosCompletos['nome'] = completo['nome'] ??
              completo['convidado_txt'] ??
              dadosCompletos['nome'];
          dadosCompletos['documento'] = completo['documento'] ??
              completo['documento_txt'] ??
              dadosCompletos['documento'];
        }
      }
    }

    // Configurar reserva selecionada para entrada (só se não for AV)
    if (!isAvulso) {
      final reservaIdVal =
          dadosCompletos['reserva_id'] ?? dadosCompletos['id_pai'];
      _reservaSelecionada = {
        'id_pai': reservaIdVal,
        'tipo': tipoConvidado.isNotEmpty ? tipoConvidado : 'AG',
        'nome': dadosCompletos['nome'] ?? dadosCompletos['convidado_txt'],
        'documento':
            dadosCompletos['documento'] ?? dadosCompletos['documento_txt'],
      };
      // For AG_EMPTY, explicitly set selected reserva ID
      _selectedReservaId = reservaIdVal?.toString();
    } else {
      // Para AV, não definir reserva selecionada (AV não tem reserva)
      _reservaSelecionada = null;
      print('ðŸŽ¯ [DEBUG] Convidado é AV - não definindo reserva selecionada');
    }

    // Definir ID do convidado selecionado (null para AG_EMPTY)
    _selectedConvidadoId = (tipoConvidado == 'AG_EMPTY')
        ? null
        : dadosCompletos['reservaconvidado_id']?.toString() ??
            dadosCompletos['sequencia']?.toString();

    // Se já não foi definido acima pela reserva
    if (_selectedReservaId == null || _selectedReservaId!.isEmpty) {
      _selectedReservaId = dadosCompletos['reserva_id']?.toString() ??
          dadosCompletos['agendamento_id']?.toString();
    }

    print('[DEBUG] _selectedConvidadoId definido: $_selectedConvidadoId');
    print('[DEBUG] _selectedReservaId definido: $_selectedReservaId');

    // Preencher campos do form
    _preencherCamposEntrada(dadosCompletos);

    // Carregar foto do convidado automaticamente usando a nova API FotoListar

    // Determinar se é AG ou AV para fotos
    // Se estiver na tab agendamentos (_tipoFiltroEntrada == 1) é AG sempre
    // Se o tipo no objeto for AG, é AG sempre
    final tipoRaw = dadosCompletos['tipo']?.toString();
    final isTipoAG = _tipoFiltroEntrada == 1 || tipoRaw == 'AG';
    final tipoParaFoto = isTipoAG ? 'AG' : 'AV';

    int fotoId = 0;
    if (isTipoAG) {
      // Para AG, o ID é reservaconvidado_id
      final resId = dadosCompletos['reservaconvidado_id']?.toString() ??
          dadosCompletos['id']?.toString();
      fotoId = int.tryParse(resId ?? '0') ?? 0;
    } else {
      // Para AV, tentar obter ID de várias fontes, priorizando pessoacadastro_id
      final avulsoId = dadosCompletos['pessoacadastro_id']?.toString() ??
          dadosCompletos['pessoadocumento_id']?.toString() ??
          dadosCompletos['reservaconvidado_id']?.toString() ??
          dadosCompletos['sequencia']?.toString() ??
          dadosCompletos['id']?.toString();
      fotoId = int.tryParse(avulsoId ?? '0') ?? 0;
    }

    if (fotoId > 0) {
      print(
          'ðŸ“¸ [DEBUG] Chamando _buscarFotosAvulso para ID: $fotoId, Tipo: $tipoParaFoto');
      _buscarFotosAvulso(fotoId, tipoUSU: tipoParaFoto);
    } else if (!isTipoAG && isAvulso && _documentoController.text.isNotEmpty) {
      // Fallback para Avulso sem ID
      print(
          'ðŸ“¸ [DEBUG] ID não encontrado no objeto, buscando cadastro completo via Documento (Avulso)');
      _buscarCadastroAvulso();
    }
    // Verificar se é um agendamento (só se não for AV)
    final ehAgendamento = !isAvulso;

    // Se for agendamento e estiver na aba Avulso (ou tipo 0), mudar para a aba Agendamentos
    if (ehAgendamento && _tabAvulsoAgendamentosSaidas == 0) {
      setState(() {
        _tabAvulsoAgendamentosSaidas = 1;
        _tipoFiltroEntrada = 1;

        // Carregar espaá§os sociais se necessário (mesma lógica do segmented)
        if (_espacosSocialList.isEmpty && !_loadingEspacosSocial) {
          _buscarEspacosSociaisParaFiltro();
        }
      });
    }

    final unidadeAgendamento = _reservaSelecionada?['unidade']?.toString() ??
        _reservaSelecionada?['unidade_res']?.toString() ??
        dadosCompletos['unidade']?.toString() ??
        dadosCompletos['unidade_res']?.toString() ??
        '';

    // Mostrar form de entrada
    setState(() {
      _mostrarFormEntrada = true;
      // Minimizar filtros quando selecionar convidado (tanto Avulso quanto Agendamentos)
      _filtroEntradaMinimizado = true;
      // Define se é agendamento para o formulário
      _isAgendamento = ehAgendamento;
      _unidadeAgendamento = _isAgendamento ? unidadeAgendamento : null;
    });

    // Fechar painel lateral após selecionar convidado
    fecharPainelLateralGlobal();
    print('ðŸšª Painel lateral fechado após seleçao do convidado');

    print(' Form de entrada preenchido com dados do convidado');
  }

  Future<void> _carregarFotoConvidado(Map<String, dynamic> convidado) async {
    final reservaconvidadoId = convidado['reservaconvidado_id']?.toString() ??
        convidado['sequencia']?.toString();

    if (reservaconvidadoId == null || reservaconvidadoId.isEmpty) {
      print(
          'âš ï¸ Ná£o foi possível carregar foto: ID do convidado não encontrado');
      return;
    }

    try {
      print('ðŸ“¸ Carregando foto do convidado: $reservaconvidadoId');

      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final url = Uri.parse('${ApiConfig.gateUrl}/foto');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'reservaconvidado_id': reservaconvidadoId,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        String? fotoBase64;
        final data = responseData['data'];
        if (data is Map) {
          fotoBase64 = (data['fotobase64'] ?? data['fotoBase64'])?.toString();
        } else if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            fotoBase64 =
                (first['fotobase64'] ?? first['fotoBase64'])?.toString();
          }
        } else {
          // Fallback caso venha fora de 'data'
          fotoBase64 =
              (responseData['fotobase64'] ?? responseData['fotoBase64'])
                  ?.toString();
        }

        if (fotoBase64 != null && fotoBase64.isNotEmpty) {
          print('ðŸ“¸ Foto carregada com sucesso');
          // Formatar como data URL completa para compatibilidade com fotos tiradas pela câmera
          final dataUrl = 'data:image/jpeg;base64,$fotoBase64';
          setState(() {
            _fotoRostoEntrada = dataUrl;
          });
        } else {
          print('ðŸ“¸ Convidado não possui foto');
        }
      } else {
        print('Erro ao carregar foto: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar foto do convidado: $e');
    }
  }

  void _selecionarConvidadoReserva(Map<String, dynamic> convidado) {
    // Preencher campos com dados do convidado
    print('[DEBUG] Selecionado convidado: ${convidado['nome']}');
    _selectedConvidadoId = convidado['reservaconvidado_id']?.toString();
    _preencherCamposEntrada(convidado);
    // Minimizar filtro ao selecionar convidado
    setState(() {
      // No modo Avulso, não minimizar o filtro
      if (_tipoFiltroEntrada == 0) {
        _filtroEntradaMinimizado =
            false; // Manter filtro visível no modo Avulso
      } else {
        _filtroEntradaMinimizado = true; // Minimizar apenas em agendamentos
      }
    });
    // Manter painel aberto para seleçao de outros convidados
    // Form será mostrado, mas painel permanece aberto
  }

  // Helpers para comparaçao exata de unidade (número e bloco/torre)
  String _normalizeTorre(String value) {
    return value
        .toLowerCase()
        .replaceAll('torre', '')
        .replaceAll('bloco', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeNumero(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'\s+'), '').trim();
  }

  void _preencherCamposEntrada(Map<String, dynamic> dados) {
    print(' Preenchendo campos do form com dados: $dados');

    setState(() {
      // Campos básicos
      _documentoController.text =
          dados['documento'] ?? dados['documento_txt'] ?? '';
      _nomeController.text = dados['nome'] ?? dados['convidado_txt'] ?? '';

      // Email (se disponível)
      if (dados['email'] != null || dados['email_txt'] != null) {
        // Se houver um campo de email no form principal, preencher aqui
        // Por enquanto, não há campo de email no form principal
      }

      // Empresa (se disponível)
      if (dados['empresa'] != null || dados['empresa_txt'] != null) {
        _empresaController.text =
            dados['empresa'] ?? dados['empresa_txt'] ?? '';
      }

      // Tipo de documento (se disponível)
      if (dados['tipodoc'] != null || dados['tipodoc_txt'] != null) {
        final tipoDoc = dados['tipodoc'] ?? dados['tipodoc_txt'];
        if (tipoDoc != null) {
          // Se houver um campo de tipo de documento no form principal, preencher aqui
          // Por enquanto, não há campo de tipo de documento no form principal
        }
      }

      // Autorizante (se disponível)
      if (dados['autorizante'] != null || dados['autorizante_txt'] != null) {
        _autorizanteController.text =
            dados['autorizante'] ?? dados['autorizante_txt'] ?? '';
      }

      // CRECI (se disponível)
      if (dados['creci'] != null || dados['creci_txt'] != null) {
        // Se houver um campo CRECI no form principal, preencher aqui
        // Por enquanto, não há campo CRECI no form principal
      }

      // Data de saída (se disponível - para agendamentos com data específica)
      if (dados['dt_saida'] != null ||
          dados['data_saida'] != null ||
          dados['periodo'] != null) {
        // Preferir o fim do período, se existir no formato: "dd/MM/yyyy HH:mm:ss até dd/MM/yyyy HH:mm:ss"
        if (dados['periodo'] != null) {
          final periodo = dados['periodo'].toString();
          // Capturar a última data/hora do período
          final regex =
              RegExp(r'(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2}):(\d{2})');
          final matches = regex.allMatches(periodo).toList();
          if (matches.isNotEmpty) {
            final m = matches.last;
            final dia = int.parse(m.group(1)!);
            final mes = int.parse(m.group(2)!);
            final ano = int.parse(m.group(3)!);
            final hora = int.parse(m.group(4)!);
            final minuto = int.parse(m.group(5)!);
            final segundo = int.parse(m.group(6)!);
            final dt = DateTime(ano, mes, dia, hora, minuto, segundo);
            _dataFimSelecionada = dt;
            _horaFimSelecionada = TimeOfDay(hour: hora, minute: minuto);
            // Texto no mesmo formato do input
            _dataFimController.text =
                '${dia.toString().padLeft(2, '0')}/${mes.toString().padLeft(2, '0')}/$ano ${hora.toString().padLeft(2, '0')}:${minuto.toString().padLeft(2, '0')}:${segundo.toString().padLeft(2, '0')}';
          }
        } else {
          // Fallback simples para dt_saida/data_saida já formatados
          final saidaStr =
              (dados['dt_saida'] ?? dados['data_saida'])?.toString();
          if (saidaStr != null && saidaStr.isNotEmpty) {
            _dataFimController.text = saidaStr;
          }
        }
      }

      // Unidade (se disponível) - apenas para agendamentos, não para avulsos
      if (dados['unidade'] != null && _reservaSelecionada != null) {
        // Valor retornado pela API pode ser string "24 - Torre B" ou um id/numero
        final valorUnidade = dados['unidade'];
        print(' Unidade recebida nos dados (AG): "$valorUnidade"');

        Map<String, dynamic> unidadeEncontrada = <String, dynamic>{};

        // 1) Tentar match direto por rótulo visível
        if (valorUnidade is String && valorUnidade.trim().isNotEmpty) {
          final alvo = valorUnidade.trim().toLowerCase();

          unidadeEncontrada = _unidadesList.firstWhere(
            (unidade) {
              final labelSimples = unidadeLabelSimples(unidade).toLowerCase();
              final mostra =
                  (unidade['unidade_mostra'] ?? '').toString().toLowerCase();
              final nome = (unidade['nome'] ?? '').toString().toLowerCase();
              final descricao =
                  (unidade['descricao'] ?? '').toString().toLowerCase();
              return labelSimples == alvo ||
                  mostra == alvo ||
                  nome == alvo ||
                  descricao == alvo;
            },
            orElse: () => <String, dynamic>{},
          );

          // 2) Se não achar, tentar decompor "numero - torre"
          if (unidadeEncontrada.isEmpty) {
            final m =
                RegExp(r'^\s*(.+?)\s*-\s*(.+)\s*$').firstMatch(valorUnidade);
            if (m != null) {
              final numeroTxt = _normalizeNumero(m.group(1)!.trim());
              final torreTxt = _normalizeTorre(m.group(2)!.trim());
              unidadeEncontrada = _unidadesList.firstWhere(
                (unidade) {
                  final numero = _normalizeNumero(
                      (unidade['unidade'] ?? unidade['numero'] ?? '')
                          .toString());
                  final torre = _normalizeTorre(
                      (unidade['torre'] ?? (unidade['bloco'] ?? ''))
                          .toString());
                  // Match EXATO de número e torre/bloco
                  final cond1 = numero.isNotEmpty && numero == numeroTxt;
                  final cond2 = torreTxt.isEmpty ||
                      (torre.isNotEmpty && torre == torreTxt);
                  return cond1 && cond2;
                },
                orElse: () => <String, dynamic>{},
              );
            }
          }
        }

        // 3) Se veio número/id, tentar por campos numéricos
        if (unidadeEncontrada.isEmpty) {
          unidadeEncontrada = _unidadesList.firstWhere(
            (unidade) =>
                unidade['id'] == valorUnidade ||
                unidade['unidade_id'] == valorUnidade ||
                unidade['numero'] == valorUnidade ||
                unidade['unidade'] == valorUnidade,
            orElse: () => <String, dynamic>{},
          );
        }

        if (unidadeEncontrada.isNotEmpty) {
          _selectedUnidade = unidadeEncontrada;
          // Para agendamento: preencher autorizante automaticamente a partir da unidade
          if ((_reservaSelecionada != null) &&
              _autorizanteController.text.trim().isEmpty) {
            final autorizanteAuto = (unidadeEncontrada['nome'] ??
                    unidadeEncontrada['unidade_mostra'] ??
                    unidadeEncontrada['titulo_txt'] ??
                    '')
                .toString();
            if (autorizanteAuto.isNotEmpty) {
              _autorizanteController.text = autorizanteAuto;
            }
          }
        }
      }

      // Veículo e placa (se disponíveis)
      if (dados['veiculo'] != null || dados['marca_auto'] != null) {
        _modeloController.text = dados['veiculo'] ?? dados['marca_auto'] ?? '';
      }
      if (dados['placa'] != null || dados['placa_auto'] != null) {
        _placaController.text = dados['placa'] ?? dados['placa_auto'] ?? '';
      }

      // Vaga (se disponível)
      if (dados['vaga'] != null || dados['vaga_auto'] != null) {
        // _vagaController.text = dados['vaga'] ?? dados['vaga_auto']; // Se existir
      }

      // Marca do veículo (se disponível) - só carregar se realmente houver dados válidos
      if ((dados['marca_auto'] != null &&
              dados['marca_auto'].toString().trim().isNotEmpty) ||
          (dados['marca_id'] != null && dados['marca_id'] != 0)) {
        final marcaId = dados['marca_id'] ?? dados['marca_auto'];
        // Procurar marca na lista e selecionar
        final marcaEncontrada = _marcasList.firstWhere(
          (marca) =>
              marca['id'] == marcaId ||
              marca['marca_id'] == marcaId ||
              marca['descricao']?.toLowerCase() ==
                  dados['marca_auto']?.toString().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (marcaEncontrada.isNotEmpty) {
          _selectedMarca = marcaEncontrada;
        } else {
          _selectedMarca = null; // Limpar se não encontrar
        }
      } else {
        _selectedMarca = null; // Limpar se não houver dados
      }

      // Cor do veículo (se disponível) - só carregar se realmente houver dados válidos
      if ((dados['cor_auto'] != null &&
              dados['cor_auto'].toString().trim().isNotEmpty) ||
          (dados['cor_id'] != null && dados['cor_id'] != 0)) {
        final corId = dados['cor_id'] ?? dados['cor_auto'];
        // Procurar cor na lista e selecionar
        final corEncontrada = _coresList.firstWhere(
          (cor) =>
              cor['id'] == corId ||
              cor['cor_id'] == corId ||
              cor['descricao']?.toLowerCase() ==
                  dados['cor_auto']?.toString().toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (corEncontrada.isNotEmpty) {
          _selectedCor = corEncontrada;
        } else {
          _selectedCor = null; // Limpar se não encontrar
        }
      } else {
        _selectedCor = null; // Limpar se não houver dados
      }

      // Tipo de pessoa
      if (_reservaSelecionada != null) {
        // á‰ de agendamento (locaçao), sempre Visitante
        _tipoPessoa = 1; // Visitante
      } else {
        // á‰ direto, verificar tipo
        if (dados['tipo'] == 'AV') {
          _tipoPessoa = 1; // Visitante
        } else {
          _tipoPessoa = 0; // P. Serviá§o
        }
      }

      // Limpar campos de fotos (será carregada automaticamente)
      _fotoRostoEntrada = null;
      _fotoDocumentoEntrada = null;

      // Mostrar form
      _mostrarFormEntrada = true;
      // No modo Avulso, não minimizar o filtro ao preencher campos
      if (_tipoFiltroEntrada == 0) {
        _filtroEntradaMinimizado =
            false; // Manter filtro visível no modo Avulso
      }
    });
    print(
        ' Campos preenchidos: Doc=${_documentoController.text}, Nome=${_nomeController.text}, Empresa=${_empresaController.text}, Autorizante=${_autorizanteController.text}, TipoPessoa=${_tipoPessoa == 0 ? "P.Serviá§o" : "Visitante"}');
  }

  void _removerConvidadoAposEntrada(String reservaConvidadoId) {
    // Ná£o remover localmente - a API convidadolist já retorna apenas convites pendentes
    // (onde "entrada": "" está vazio)
    print(
        'Convidado $reservaConvidadoId removido da lista via API convidadolist');
  }

  Future<void> _fetchPassagens() async {
    // Funçao mantida para compatibilidade, mas não é mais usada da mesma forma
    // A lógica de saídas foi removida do topo
    {
      setState(() {
        _loadingSaidasList = true;
      });

      // Buscar histórico usando API passagemhistorico
      // Por padrão usa data atual (00:00 até 23:59), só altera se houver filtro de período
      try {
        final prefs = await SharedPreferences.getInstance();
        final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
        final tokenSessao =
            (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

        final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
        final condominioId = (encryptedCondominioId.isNotEmpty)
            ? decryptText(encryptedCondominioId)
            : '';

        // Usar data atual por padrão, ou filtro se selecionado
        final hoje = DateTime.now();
        final dataIni = _filtroDataInicioSaidas ?? hoje;
        final dataFim = _filtroDataFimSaidas ?? hoje;

        final url =
            Uri.parse('https://gate.conectcon.net.br/pt-br/passagemhistorico');

        final payload = {
          "apto_id": 0,
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "dt_fim":
              '${dataFim.year}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')} 23:59:59', // Data atual ou filtro (23:59:59)
          "dt_ini":
              '${dataIni.year}-${dataIni.month.toString().padLeft(2, '0')}-${dataIni.day.toString().padLeft(2, '0')} 00:00:00', // Data atual ou filtro (00:00:00)
          "nome": "",
          "pessoaveiculo": "",
          "placa": "",
        };

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenSessao',
          },
          body: jsonEncode(payload),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final historicoPassagens =
              List<Map<String, dynamic>>.from(data['data'] ?? []);

          // Mostrar todas as passagens, mesmo as que já têm saída registrada
          // Enriquecer dados das passagens com informaá§ões das unidades
          final passagensEnriquecidas =
              _enriquecerPassagensComDadosUnidade(historicoPassagens);

          // Tentar enriquecer dados AV com informaá§ões do cadastro avulso
          await _enriquecerDadosAvulsos(passagensEnriquecidas);

          setState(() {
            _todasPassagens = passagensEnriquecidas;
            _loadingSaidasList = false;
          });
        } else {
          setState(() {
            _todasPassagens = [];
            _loadingSaidasList = false;
          });
        }
      } catch (e) {
        print('Erro ao buscar saídas: $e');
        setState(() {
          _todasPassagens = [];
          _loadingSaidasList = false;
        });
      }
      return;
    }

    // Para passagens (não saídas), usar apenas dados do SignalR
    // Ná£o fazer chamada de API - os dados vêm do SignalR
    setState(() {
      _loadingPassagens = false; // SignalR já carregou os dados
    });

    // Se não há dados do SignalR ainda, apenas aguardar
    if (_todasPassagens.isEmpty && _passagens.isEmpty) {
      print('ðŸ“¡ Aguardando dados do SignalR...');
      return;
    }

    return;
  }

  // Funçao para enriquecer dados das passagens com informaá§ões das unidades
  List<Map<String, dynamic>> _enriquecerPassagensComDadosUnidade(
      List<Map<String, dynamic>> passagens) {
    return passagens.map((passagem) {
      final passagemCopia = Map<String, dynamic>.from(passagem);

      // Tentar encontrar unidade correspondente pelos campos disponíveis
      // Primeiro tentar por unidade_id, depois por numero/torre
      Map<String, dynamic>? unidadeEncontrada;

      // Procurar por unidade_id direto
      if (passagem['unidade_id'] != null) {
        unidadeEncontrada = _unidadesList.firstWhere(
          (unidade) =>
              unidade['id'] == passagem['unidade_id'] ||
              unidade['unidade_id'] == passagem['unidade_id'],
          orElse: () => <String, dynamic>{},
        );
      }

      // Se não encontrou por ID, tentar por torre + numero
      if (unidadeEncontrada == null || unidadeEncontrada.isEmpty) {
        final torrePassagem = passagem['torre']?.toString();
        final numeroPassagem = passagem['numero']?.toString();

        if (torrePassagem != null && numeroPassagem != null) {
          unidadeEncontrada = _unidadesList.firstWhere(
            (unidade) {
              final unidadeMostra = unidade['unidade_mostra']?.toString() ?? '';
              return unidadeMostra.contains(torrePassagem) &&
                  unidadeMostra.contains(numeroPassagem);
            },
            orElse: () => <String, dynamic>{},
          );
        }
      }

      // Se encontrou unidade, adicionar informaá§ões
      if (unidadeEncontrada != null && unidadeEncontrada.isNotEmpty) {
        // Adicionar tipo do morador
        if (unidadeEncontrada['tipo_morador'] != null) {
          passagemCopia['tipo_morador'] = unidadeEncontrada['tipo_morador'];
        }

        // Adicionar nome do morador se não existir
        if ((passagem['nome'] == null || passagem['nome'].toString().isEmpty) &&
            unidadeEncontrada['nome_morador'] != null) {
          passagemCopia['nome'] = unidadeEncontrada['nome_morador'];
        }

        // Garantir que torre e numero está£o corretos
        if (unidadeEncontrada['torre'] != null) {
          passagemCopia['torre'] = unidadeEncontrada['torre'];
        }
        if (unidadeEncontrada['numero'] != null) {
          passagemCopia['numero'] = unidadeEncontrada['numero'];
        }

        // Adicionar informaá§ões adicionais se disponíveis
        if (unidadeEncontrada['tipo'] != null) {
          passagemCopia['tipo_unidade'] = unidadeEncontrada['tipo'];
        }
      }

      return passagemCopia;
    }).toList();
  }

  //-----------------------------//
  // Parsear data da passagem para ordenaçao
  //-----------------------------//
  DateTime _parseDataPassagem(Map<String, dynamic> passagem) {
    try {
      final dataStr = passagem['data']?.toString() ??
          passagem['dt_ini']?.toString() ??
          passagem['data_entrada']?.toString() ??
          passagem['dt']?.toString() ??
          '';

      if (dataStr.isEmpty) {
        // Retornar data muito antiga para que apareá§a no final da lista
        return DateTime(1970);
      }

      // Tentar diferentes formatos de data
      try {
        // Formato: "2024-11-10 14:30:00" ou "17/11/2025 12:03:55"
        if (dataStr.contains(' ')) {
          final parts = dataStr.split(' ');
          String datePart = parts[0];
          String timePart = parts[1];

          // Verificar se é formato brasileiro DD/MM/YYYY
          if (datePart.contains('/')) {
            final dateParts = datePart.split('/');
            if (dateParts.length == 3) {
              // DD/MM/YYYY
              final day = int.parse(dateParts[0]);
              final month = int.parse(dateParts[1]);
              final year = int.parse(dateParts[2]);

              final timeParts = timePart.split(':');
              if (timeParts.length >= 2) {
                return DateTime(
                  year,
                  month,
                  day,
                  int.parse(timeParts[0]),
                  int.parse(timeParts[1]),
                  timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
                );
              }
            }
          }
          // Formato: YYYY-MM-DD
          else if (datePart.contains('-')) {
            final dateParts = datePart.split('-');
            final timeParts = timePart.split(':');

            if (dateParts.length == 3 && timeParts.length >= 2) {
              return DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
                int.parse(timeParts[0]),
                int.parse(timeParts[1]),
                timeParts.length > 2 ? int.parse(timeParts[2]) : 0,
              );
            }
          }
        }

        // Formato ISO ou outros formatos padrão
        try {
          return DateTime.parse(dataStr);
        } catch (_) {
          // Tentar formato brasileiro sem hora: DD/MM/YYYY
          if (dataStr.contains('/')) {
            final parts = dataStr.split('/');
            if (parts.length == 3) {
              return DateTime(
                int.parse(parts[2]), // ano
                int.parse(parts[1]), // mês
                int.parse(parts[0]), // dia
              );
            }
          }
        }

        return DateTime(1970);
      } catch (_) {
        return DateTime(1970);
      }
    } catch (e) {
      return DateTime(1970);
    }
  }

  //-----------------------------//
  // Atualizar passagem do usuário via API
  //-----------------------------//
  Future<void> _atualizarPassagemUsuario(dynamic userId) async {
    try {
      // Converter userId para int se necessário
      int? idInt;
      if (userId is int) {
        idInt = userId;
      } else if (userId is String) {
        idInt = int.tryParse(userId);
      } else {
        return;
      }

      if (idInt == null || idInt <= 0) {
        return;
      }

      // Verificar se já foi atualizado para evitar chamadas duplicadas
      if (_passagensAtualizadas.contains(idInt)) {
        return;
      }

      // Marcar como atualizado antes de chamar a API (evitar chamadas simultá¢neas)
      _passagensAtualizadas.add(idInt);

      // Obter token descriptografado
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        _passagensAtualizadas.remove(idInt); // Remover do set se erro no token
        return;
      }

      // Chamar API passagemusuarioupd
      final url =
          Uri.parse(ApiConfig.getEndpoint('dashboard', 'passagemUsuarioUpd'));

      final payload = {
        "id": idInt,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200) {
        // Se erro, remover do set para tentar novamente depois
        _passagensAtualizadas.remove(idInt);
      }
    } catch (e) {
      // Em caso de erro, remover do set para permitir nova tentativa
      try {
        int? idInt;
        if (userId is int) {
          idInt = userId;
        } else if (userId is String) {
          idInt = int.tryParse(userId);
        }
        if (idInt != null) {
          _passagensAtualizadas.remove(idInt);
        }
      } catch (_) {
        // Ignorar erro ao remover
      }
    }
  }

  // Funçao auxiliar para formatar o tipo de visita/morador
  String _getTipoFormatado(Map<String, dynamic> passagem) {
    // Primeiro tenta usar o tipo_morador enriquecido da unidade
    final tipoMorador = passagem['tipo_morador'];
    if (tipoMorador == 'P') {
      return 'Proprietário';
    } else if (tipoMorador == 'L') {
      return 'Locatário';
    }

    // Se não tem tipo_morador, usa o tipo original da passagem
    final tipoOriginal = passagem['tipo']?.toString();
    if (tipoOriginal != null && tipoOriginal.isNotEmpty) {
      return tipoOriginal;
    }

    // Fallback
    return 'Visitante';
  }

  // Funçao auxiliar para limpar tags HTML da mensagem
  String _limparMensagemHtml(String mensagem) {
    if (mensagem.isEmpty) return '';

    // Remover tags HTML básicas
    String limpa = mensagem
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove todas as tags HTML
        .replaceAll('&nbsp;', ' ') // Remove &nbsp;
        .replaceAll('&lt;', '<') // Converte entidades HTML
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('\r\n', ' ') // Remove quebras de linha
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ')
        .trim();

    // Limitar tamanho se for muito longo
    if (limpa.length > 100) {
      limpa = '${limpa.substring(0, 97)}...';
    }

    return limpa;
  }

  void _limparFormulario() {
    setState(() {
      _documentoController.clear();
      _nomeController.clear();
      _autorizanteController.clear();
      // Empresa só é limpa se for P.Serviá§o
      if (_tipoPessoa == 0) {
        _empresaController.clear();
      }
      _placaController.clear();
      _modeloController.clear();
      _obsController.clear();
      _selectedUnidade = null;
      _selectedMarca = null;
      _selectedCor = null;
      _selectedVagaAvulso = null;
      _selectedCracha = null;
      _cadastroAvulso = null;
      _ultimoPessoadocumentoId = null;
      _fotoBase64 = null;
      _fotoEntrada = null;
      _fotoDocumento = null;
      _fotoDocumentoBase64 = null;
      _fotoRostoEntrada = null;
      _fotoDocumentoEntrada = null;
      _dataFimSelecionada = null;
      _horaFimSelecionada = null;
      _dataFimController.clear();
      _temCadastroAvulso = false;
      _selectedConvidadoId = null; // Limpar ID do convidado selecionado
      _isAgendamento = false; // Resetar flag de agendamento
      _unidadeAgendamento = null; // Resetar unidade do agendamento
      _filtrarReservaconvidadoId = null; // Limpar filtro por convidado (filho)
      _mostrarErrosVisuais = false; // Resetar erros visuais
    });

    // Forá§ar refresh da UI e mostrar confirmaçao
    Future.delayed(const Duration(milliseconds: 50), () {
      setState(() {});
    });
  }

  Future<void> _salvarDados() async {
    // Verificar campos obrigatórios
    setState(() {
      _mostrarErrosVisuais = true;
    });

    final documento = _documentoController.text.trim();
    final nome = _nomeController.text.trim();
    final autorizante = _autorizanteController.text.trim();

    // Validaá§ões obrigatórias básicas
    if (documento.isEmpty || nome.isEmpty || autorizante.isEmpty) {
      FeedbackUtils.showError(
        context: context,
        title: 'Campos Obrigatórios',
        message:
            'Por favor, preencha todos os campos obrigatórios (Nome, Documento, Autorizante)',
      );
      return;
    }

    setState(() {
      _loadingRegistroEntrada = true;
    });

    try {
      // Lógica diferente para AG vs AV
      final isAvulso = _reservaSelecionada == null ||
          (_reservaSelecionada != null && _reservaSelecionada!['tipo'] == 'AV');

      if (_reservaSelecionada != null && !isAvulso) {
        // AG (Agendamento): usar convidadoupd SEM movimento
        await _registrarEntradaAgendamento(realizarMovimento: false);
      } else {
        // AV (Avulso): Registrar entrada/movimento (já inclui atualizaçao de cadastro se necessário)
        await _registrarEntradaAvulso();
      }
    } catch (e) {
      print('Erro ao salvar: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Salvar',
        message: 'Erro ao salvar dados',
        errorDetails: e.toString(),
      );
    } finally {
      setState(() {
        _loadingRegistroEntrada = false;
      });
    }
  }

  void _fecharFormulario() {
    setState(() {
      _mostrarFormEntrada = false;
      _reservaSelecionada = null;
      _selectedConvidadoId = null;
      _filtrarReservaconvidadoId = null;
      _fotoRostoEntrada = null;
      _fotoDocumentoEntrada = null;
      _isNovoUsuario = false; // Resetar flag de novo usuário
      // Limpar vaga e campos de veículo ao fechar formulário
      _selectedVagaAvulso = null;
      _placaController.clear();
      _modeloController.clear();
      _selectedMarca = null;
      _selectedCor = null;
      // Limpar marca e cor do cadastro avulso se existir
      if (_cadastroAvulso != null) {
        _cadastroAvulso!.remove('marca_id');
        _cadastroAvulso!.remove('marca_auto');
        _cadastroAvulso!.remove('cor_id');
        _cadastroAvulso!.remove('cor_auto');
      }
      // Expandir filtros ao fechar formulário
      _filtroEntradaMinimizado = false;
    });
  }

  void _limparFiltrosEFecharFormulario() {
    // Limpar filtros do topo
    _filtroDocumentoEntradaController.clear();
    _filtroNomeEntradaController.clear();
    _filtroUnidadeEntradaController.clear();
    _unidadeFiltroSelecionada = null;
    _unidadeFiltroAplicada = null;
    _espacoSocialSelecionado = null;

    // Limpar data do filtro
    setState(() {
      _filtroDataEntrada = null;
      // Mostrar filtros novamente após finalizar cadastro
      _filtroEntradaMinimizado = false; // Mostrar filtros novamente
    });

    // Limpar formulário completamente
    _limparFormulario();

    // Resetar flags de novo usuário e agendamento
    _isNovoUsuario = false;
    _isAgendamento = false;
    _unidadeAgendamento = null;

    // Fechar formulário
    _fecharFormulario();

    // Fechar painel lateral se estiver aberto
    _fecharPainelLateral();

    print(
        'ðŸ§¹ [DEBUG] Filtros do topo limpos, formulário limpo e fechado após registro de entrada');
  }

  Future<void> _registrarEntradaAgendamento(
      {bool realizarMovimento = true}) async {
    if (_selectedConvidadoId == null || _selectedConvidadoId!.isEmpty) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'ID do convidado não encontrado',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Token de sessá£o não encontrado',
        );
        return;
      }

      final condominioId = await getCondominioIdAtual();
      final usuarioId = await ApiConfig.getUsuarioId();

      // Preparar dados do formulário
      final documento = _documentoController.text.trim();
      final nome = _nomeController.text.trim();
      final autorizante = _autorizanteController.text.trim();
      final empresa = _empresaController.text.trim();
      final placa = _placaController.text.trim();
      final modelo = _modeloController.text.trim();

      // Converter IDs para int
      final reservaIdInt = int.tryParse(_selectedReservaId ?? '0') ?? 0;
      final reservaconvidadoIdInt =
          int.tryParse(_selectedConvidadoId ?? '0') ?? 0;

      final payload = {
        'reserva_id': reservaIdInt,
        'reservaconvidado_id': reservaconvidadoIdInt,
        'convidado_txt': nome,
        'email_txt': '',
        'tipodoc_txt': '',
        'documento_txt': documento,
        'empresa_txt': empresa,
        'autorizante_txt': autorizante,
        'creci_txt': '',
        'quant_pessoas': 1,
        'placa': placa,
        'veiculo_txt': modelo,
        'id_acesso': '',
        'excluir': 'N',
        'vaga_flg': _selectedVagaAvulso != null ? 'S' : 'N',
      };

      // Adicionar foto do rosto como fotoBase64 (opcional aqui, pois pode ser salvo sem foto)
      if (_fotoRostoEntrada != null && _fotoRostoEntrada!.isNotEmpty) {
        String fotoBase64 = _fotoRostoEntrada!;
        if (!fotoBase64.startsWith('http')) {
          if (fotoBase64.contains(',')) {
            fotoBase64 = fotoBase64.split(',').last;
          }
          if (fotoBase64.length > 100) {
            payload['fotoBase64'] = fotoBase64;
          }
        }
      }

      // Chamar API convidadoupd
      final url = Uri.parse(
        ApiConfig.getEndpoint('convidados', 'atualizar'),
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 200) {
          if (!realizarMovimento) {
            // Se for apenas salvar, finalizar aqui
            _limparFiltrosEFecharFormulario();
            FeedbackUtils.showSuccess(
              context: context,
              title: 'Salvo',
              message: 'Dados do convidado atualizados com sucesso!',
            );
            return;
          }

          // Agora chamar convidadomov para registrar a entrada
          final urlMover = Uri.parse(
            ApiConfig.getEndpoint('convidados', 'mover'),
          );

          await Future.delayed(const Duration(seconds: 2));
          final now = DateTime.now();
          final formattedDate =
              '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

          final payloadMover = {
            'condominio_id': int.tryParse(condominioId.toString()) ?? 0,
            'origem': 'E', // E = Entrada
            'tipo': 'A', // A = Agendamento
            'reserva_id': reservaIdInt,
            'reservaconvidado_id': reservaconvidadoIdInt,
            'usuario_registro': int.tryParse(usuarioId.toString()) ?? 0,
            'dt_entrada': formattedDate,
          };

          final responseMover = await http.post(
            urlMover,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao',
            },
            body: jsonEncode(payloadMover),
          );

          if (responseMover.statusCode == 200) {
            final dataMover = jsonDecode(responseMover.body);
            if (dataMover['status'] == 200) {
              // Sucesso completo
              await Future.delayed(const Duration(milliseconds: 500));
              _limparFiltrosEFecharFormulario();

              // Atualizar listas
              if (_tipoFiltroEntrada == 1) {
                await _fetchAgendamentos();
              }
              if (_reservaSelecionada != null) {
                final rId = _reservaSelecionada!['id_pai']?.toString() ?? '';
                if (rId.isNotEmpty) {
                  await _buscarConvidadosReserva(int.tryParse(rId) ?? 0,
                      mostrarTodos: true);
                  _abrirPainelConvidados(_convidadosReserva);
                }
              }
            } else {
              FeedbackUtils.showError(
                context: context,
                title: 'Erro na Movimentaçao',
                message: dataMover['message'] ??
                    'Erro desconhecido ao registrar entrada',
              );
            }
          } else {
            FeedbackUtils.showError(
              context: context,
              title: 'Erro HTTP',
              message: 'Erro ao conectar com servidor de movimentaçao',
            );
          }
        } else {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro na Atualizaçao',
            message: data['message'] ?? 'Erro desconhecido ao atualizar dados',
          );
        }
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro HTTP',
          message: 'Erro ao conectar com servidor de atualizaçao',
        );
      }
    } catch (e) {
      print('Erro em _registrarEntradaAgendamento: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Ocorreu um erro inesperado',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _registrarEntradaAvulso() async {
    final documento = _documentoController.text.trim();
    final nome = _nomeController.text.trim();
    final empresa = _empresaController.text.trim();

    // Sempre use o id mais atualizado
    dynamic pessoadocumentoId =
        _cadastroAvulso?['pessoadocumento_id'] ?? _ultimoPessoadocumentoId ?? 0;

    // Captura também o pessoacadastro_id (necessário para registrar foto)
    dynamic pessoaCadastroId = _cadastroAvulso?['pessoacadastro_id'] ?? 0;

    final doc = documento;
    // Se não tem id, criar cadastro antes
    if (pessoadocumentoId == 0) {
      // Tenta buscar novamente o id do último selecionado
      await _buscarCadastroAvulso();
      pessoadocumentoId = _cadastroAvulso?['pessoadocumento_id'] ??
          _ultimoPessoadocumentoId ??
          0;
      pessoaCadastroId = _cadastroAvulso?['pessoacadastro_id'] ?? 0;

      if (pessoadocumentoId == 0) {
        // Só chama editacadastro se realmente não houver id
        final prefs = await SharedPreferences.getInstance();
        final encrypted = prefs.getString('tokensessao_txt');
        final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
            ? decryptText(encrypted)
            : '';
        final urlEdit = Uri.parse(
          ApiConfig.getEndpoint('dashboard', 'editarCadastro'),
        );
        final payloadEdit = {
          "pessoadocumento_id": 0,
          "nome": _nomeController.text.trim(),
          "documento": doc,
          "tipodoc": (_cadastroAvulso?['tipodoc'] ?? '').isEmpty
              ? 'R'
              : _cadastroAvulso?['tipodoc'],
          "empresa": _empresaController.text.trim(),
          "email": _cadastroAvulso?['email'] ?? '',
        };
        final responseEdit = await http.post(
          urlEdit,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenSessao',
          },
          body: jsonEncode(payloadEdit),
        );
        if (!mounted) return;
        if (responseEdit.statusCode == 200) {
          final dataEdit = jsonDecode(responseEdit.body);
          pessoadocumentoId = dataEdit['data']?['pessoadocumento_id'] ?? 0;
          // Atualiza também o pessoacadastro_id vindo da resposta
          pessoaCadastroId = dataEdit['data']?['pessoacadastro_id'] ?? 0;

          setState(() {
            if (_cadastroAvulso != null) {
              _cadastroAvulso!['pessoadocumento_id'] = pessoadocumentoId;
              _cadastroAvulso!['pessoacadastro_id'] = pessoaCadastroId;
            }
            _ultimoPessoadocumentoId = pessoadocumentoId;
          });
        } else {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro no Cadastro',
            message: 'Entre em contato com o suporte do sistema.',
            errorDetails: 'Erro ao criar cadastro avulso!',
          );
          return;
        }
      }
    }

    // Preparar dados para envio
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url =
        Uri.parse(ApiConfig.getEndpoint('dashboard', 'registroEntradaAvulso'));

    // No cadastro, definir tipovisita:
    String tipovisita = 'V';
    if (_tipoPessoa == 0) {
      tipovisita = 'P';
    }

    // Garantir que o ID seja um número válido
    final validPessoadocumentoId = _convertToValidId(pessoadocumentoId) ?? 0;
    // Garantir ID válido para cadastro também
    final validPessoaCadastroId = _convertToValidId(pessoaCadastroId) ?? 0;

    final payload = {
      "condominio_id": int.tryParse(condominioId) ?? 0,
      "pessoadocumento_id": validPessoadocumentoId,
      "documento": documento,
      "nome": _nomeController.text.trim(),
      "entradacadastro_id": 0,
      "apto_id": _selectedUnidade?['apto_id'] ?? 0,
      "autorizante": _autorizanteController.text,
      "tipovisita": tipovisita,
      "leitor_id": 0,
      "outraident_id":
          _selectedCracha?['aviso_id'] ?? _selectedCracha?['id'] ?? 0,
      "vaga_id":
          _selectedVagaAvulso?['vaga_id'] ?? _selectedVagaAvulso?['id'] ?? 0,
      "marca_id": _selectedMarca?['marca_id'] ?? _selectedMarca?['id'] ?? 0,
      "cor_id": _selectedCor?['cor_id'] ?? _selectedCor?['id'] ?? 0,
      "placa": _placaController.text.trim(),
      "modelo": _modeloController.text.trim(),
      "flg_garagem": '',
      "dt_fim": _dataFimSelecionada != null && _horaFimSelecionada != null
          ? '${_dataFimSelecionada!.day.toString().padLeft(2, '0')}/${_dataFimSelecionada!.month.toString().padLeft(2, '0')}/${_dataFimSelecionada!.year} ${_horaFimSelecionada!.hour.toString().padLeft(2, '0')}:${_horaFimSelecionada!.minute.toString().padLeft(2, '0')}:00'
          : '',
      "observacao": _obsController.text,
    };

    // Adicionar empresa apenas se for P.Serviá§o
    if (_tipoPessoa == 0 && empresa.isNotEmpty) {
      payload["empresa"] = empresa;
    }

    // Adicionar fotos base64 ao payload
    String fotoRosto = '';
    if (_fotoRostoEntrada != null && _fotoRostoEntrada!.isNotEmpty) {
      fotoRosto = _fotoRostoEntrada!;
    } else if (_fotoEntrada != null) {
      fotoRosto = base64Encode(_fotoEntrada!);
    } else if (_fotoBase64 != null && _fotoBase64!.isNotEmpty) {
      fotoRosto = _fotoBase64!;
    }
    String fotoDoc = '';
    if (_fotoDocumentoEntrada != null && _fotoDocumentoEntrada!.isNotEmpty) {
      fotoDoc = _fotoDocumentoEntrada!;
    } else if (_fotoDocumento != null) {
      fotoDoc = base64Encode(_fotoDocumento!);
    } else if (_fotoDocumentoBase64 != null &&
        _fotoDocumentoBase64!.isNotEmpty) {
      fotoDoc = _fotoDocumentoBase64!;
    }
    // Remover prefixo data:image se existir
    if (fotoRosto.contains(',')) fotoRosto = fotoRosto.split(',').last;
    if (fotoDoc.contains(',')) fotoDoc = fotoDoc.split(',').last;
    payload["fotobase64_1"] = fotoRosto;
    payload["fotobase64_2"] = fotoDoc;

    String? rostoParaEnviar;
    String? docParaEnviar;

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Registrar fotos separadamente
        // Agora suporta reenvio de fotos (mesmo se for URL) e novas fotos (Base64)
        if (_fotoRostoEntrada != null ||
            _fotoDocumentoBase64 != null ||
            _fotoBase64 != null ||
            _fotoDocumentoEntrada != null) {
          final urlFoto = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');

          // Funçao auxiliar local para enviar foto
          Future<void> enviarFoto(String? fotoSource, int ordem) async {
            if (fotoSource == null || fotoSource.isEmpty) return;

            String fotoParaEnviar = '';

            // Verifica se é URL
            if (fotoSource.startsWith('http')) {
              print(
                  'ðŸ“¸ Baixando foto URL para reenvio (Ordem $ordem): $fotoSource');
              try {
                final responseImg = await http.get(Uri.parse(fotoSource));
                if (responseImg.statusCode == 200) {
                  fotoParaEnviar = base64Encode(responseImg.bodyBytes);
                } else {
                  print(
                      'âš ï¸ Falha ao baixar imagem da URL: ${responseImg.statusCode}');
                  return; // Abortar se não conseguir baixar
                }
              } catch (e) {
                print('Erro ao baixar imagem para reenvio: $e');
                return;
              }
            } else {
              // Já é Base64 ou caminho local (assumindo Base64 se não for http)
              fotoParaEnviar = fotoSource;
            }

            // Limpeza final do base64
            final fotoClean = fotoParaEnviar.contains(',')
                ? fotoParaEnviar.split(',').last
                : fotoParaEnviar;

            try {
              // Usar pessoacadastro_id, não pessoadocumento_id
              final payloadFoto = {
                "condominio_id": int.tryParse(condominioId) ?? 0,
                "tipoUSU": "USU",
                "ordem_num": ordem,
                "pessoacadastro_id": validPessoaCadastroId,
                "foto": fotoClean,
              };

              print(
                  'Enviando foto (Ordem: $ordem) para CADASTRO ID: $validPessoaCadastroId');

              await http.post(
                urlFoto,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $tokenSessao',
                },
                body: jsonEncode(payloadFoto),
              );
            } catch (e) {
              print('Erro ao enviar foto ordem $ordem: $e');
            }
          }

          // Enviar Rosto (Ordem 1) - Prioriza _fotoBase64 (novo), senão usa _fotoRostoEntrada (pode ser URL)
          rostoParaEnviar = (_fotoBase64 != null && _fotoBase64!.isNotEmpty)
              ? _fotoBase64
              : _fotoRostoEntrada;
          if (rostoParaEnviar != null) {
            await enviarFoto(rostoParaEnviar, 1);
          }

          // Enviar Documento (Ordem 2) - Prioriza _fotoDocumentoBase64 (novo), senão usa _fotoDocumentoEntrada (pode ser URL)
          docParaEnviar =
              (_fotoDocumentoBase64 != null && _fotoDocumentoBase64!.isNotEmpty)
                  ? _fotoDocumentoBase64
                  : _fotoDocumentoEntrada;
          if (docParaEnviar != null) {
            await enviarFoto(docParaEnviar, 2);
          }
        }
        // Mostrar mensagem de sucesso
        final isAbaAvulso = _tipoFiltroEntrada == 0;

        FeedbackUtils.showSuccess(
          context: context,
          title:
              isAbaAvulso ? 'Entrada Avulsa Registrada' : 'Entrada Registrada',
          message: isAbaAvulso
              ? 'Entrada avulsa registrada com sucesso!'
              : 'Nova entrada registrada com sucesso!',
          triggerKey: _panelEntradaSaidasKey,
        );

        // Sucesso - Preparar card para exibir nos resultados antes de limpar
        final now = DateTime.now();
        final formattedNow =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

        final novoConvidado = {
          'id': validPessoadocumentoId,
          'pessoadocumento_id': validPessoadocumentoId,
          'pessoacadastro_id': validPessoaCadastroId,
          'nome': _nomeController.text.trim(),
          'convidado_txt': _nomeController.text.trim(),
          'documento': documento,
          'documento_txt': documento,
          'unidade': _selectedUnidade?['unidade_mostra'] ??
              _selectedUnidade?['nome'] ??
              '',
          'unidade_mostra': _selectedUnidade?['unidade_mostra'] ??
              _selectedUnidade?['nome'] ??
              '',
          'entrada': formattedNow,
          'dt_entrada': formattedNow,
          'tipo': _tipoFiltroEntrada == 0 ? 'AV' : 'AG',
          'origem_tab': _tabAvulsoAgendamentosSaidas,
          'placa': _placaController.text.trim(),
          'modelo': _modeloController.text.trim(),
          'foto': rostoParaEnviar,
          'link_foto': rostoParaEnviar,
        };

        setState(() {
          // Adicionar ao histórico geral para visibilidade imediata
          _todasPassagens.insert(0, Map<String, dynamic>.from(novoConvidado));
        });

        // Limpar tudo e fechar formulário
        await _limparFormularioEntrada();
      } else {
        if (!mounted) return;
        // Erro
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Registrar',
          message: 'Erro ao registrar entrada avulsa',
          errorDetails: 'Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showError(
        context: context,
        title: 'Erro de Conexá£o',
        message: 'Erro de conexá£o',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _tirarFotoRosto() async {
    try {
      // Usar a nova modal de captura facial com contexto global
      final globalContext = _dashboardContext ?? context;
      final photoDataUrl = await showDialog<String>(
        context: globalContext,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => const FacialCaptureModal(isFrontal: true),
      );

      if (photoDataUrl != null && photoDataUrl.isNotEmpty) {
        await _processarFotoCapturadaRosto(photoDataUrl);
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Capturar',
        message: 'Erro ao capturar foto',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _tirarFotoDocumento() async {
    // Bloquear foto de documento em AG (agendamento)
    if (_reservaSelecionada != null) {
      FeedbackUtils.showError(
        context: context,
        title: 'Aviso',
        message: 'Para agendamentos não é necessário foto do documento.',
      );
      return;
    }
    // Em AVULSO, exigir foto do rosto antes
    if (_fotoRostoEntrada == null) {
      FeedbackUtils.showError(
        context: context,
        title: 'Foto Obrigatória',
        message: 'Tire a foto do rosto antes de tirar a foto do documento.',
      );
      return;
    }
    print(' BOTão DOCUMENTO CLICADO!');
    try {
      print(
          ' Iniciando _tirarFotoDocumento() - contexto válido: ${context != null}');

      // Usar a nova modal de captura facial (sem overlay facial) com contexto global
      final globalContext = _dashboardContext ?? context;
      final photoDataUrl = await showDialog<String>(
        context: globalContext,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => const FacialCaptureModal(isFrontal: false),
      );

      if (photoDataUrl != null && photoDataUrl.isNotEmpty) {
        print(' Foto documento capturada, processando...');
        await _processarFotoCapturadaDocumento(photoDataUrl);
      }
      print(' Camera overlay chamado para documento (usando câmera frontal)');
    } catch (e, stackTrace) {
      print('Erro em _tirarFotoDocumento: $e');
      print('StackTrace: $stackTrace');
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Capturar',
          message: 'Erro ao capturar foto',
          errorDetails: e.toString(),
        );
      }
    }
  }

  void _abrirCameraOverlay({
    required CameraFrameType frameType,
    required bool isFrontal,
    required Function(String) onPhotoTaken,
  }) {
    print(' _abrirCameraOverlay (Modal Centralizado) chamado');

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.9), // Backdrop opaco
      builder: (BuildContext dialogContext) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(dialogContext).size.width * 0.8,
              height: MediaQuery.of(dialogContext).size.height * 0.85,
              constraints: const BoxConstraints(maxWidth: 800, maxHeight: 900),
              decoration: BoxDecoration(
                color: Theme.of(dialogContext).brightness == Brightness.dark
                    ? const Color(0xFF1F2937)
                    : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: CameraSidePanelWidget(
                  frameType: frameType,
                  isFrontal: isFrontal,
                  onPhotoTaken: (photo) {
                    Navigator.of(dialogContext).pop();
                    onPhotoTaken(photo);
                  },
                  onCancel: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _processarFotoCapturadaRosto(String dataUrl) async {
    try {
      if (dataUrl.isEmpty || !dataUrl.contains(',')) {
        return;
      }

      // Converter dataUrl para bytes
      final base64Data = dataUrl.split(',').last;
      if (base64Data.isEmpty) {
        return;
      }

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) {
        return;
      }

      setState(() {
        _fotoEntrada = bytes;
        _fotoBase64 = base64Data;
        _fotoRostoEntrada = dataUrl; // Armazenar foto completa para exibiçao
      });

      // Removido: modal de sucesso após capturar rosto

      // Removido: modal perguntando se deseja tirar foto do documento
      // O usuário pode tirar a foto do documento manualmente se desejar
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Processar',
        message: 'Erro ao processar foto',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _processarFotoCapturadaDocumento(String dataUrl) async {
    try {
      if (dataUrl.isEmpty || !dataUrl.contains(',')) {
        return;
      }

      // Converter dataUrl para bytes
      final base64Data = dataUrl.split(',').last;
      if (base64Data.isEmpty) {
        return;
      }

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) {
        return;
      }

      setState(() {
        _fotoDocumento = bytes;
        _fotoDocumentoBase64 = base64Data;
        _fotoDocumentoEntrada =
            dataUrl; // Armazenar foto completa para exibiçao
      });

      // Removido: modal de sucesso após capturar documento
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Processar',
        message: 'Erro ao processar foto',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _enviarEncomenda() async {
    print('=== INICIANDO ENVIO DE ENCOMENDA ===');

    setState(() {
      _loadingEnviarEncomenda = true;
    });

    try {
      // Verificar se temos ao menos uma unidade selecionada
      if (_selectedUnidadesEncomenda.isEmpty) {
        print('ERRO: Nenhuma unidade selecionada');
        FeedbackUtils.showError(
          context: context,
          title: 'Seleção Obrigatória',
          message: 'Selecione ao menos uma unidade!',
        );
        setState(() {
          _loadingEnviarEncomenda = false;
        });
        return;
      }

      // Verificar se temos tipo selecionado
      if (_tipoEncomendaSelecionado == null) {
        print('ERRO: Tipo de encomenda não selecionado');
        FeedbackUtils.showError(
          context: context,
          title: 'Seleçao Obrigatória',
          message: 'Selecione o tipo da encomenda!',
        );
        setState(() {
          _loadingEnviarEncomenda = false;
        });
        return;
      }

      print('Unidade selecionada: $_selectedUnidadeEncomenda');
      print('Tipo selecionado: $_tipoEncomendaSelecionado');

      final testeSemFoto = false; // Mude para true para testar sem foto

      if (testeSemFoto && _fotoEncomenda == null) {
        print('TESTE: Enviando encomenda sem foto...');
        await _registrarEncomendaTeste();
      } else {
        // Chamar a ção de registro usando API do backup
        await _registrarEncomenda();
      }
    } catch (e) {
      print('Erro ao enviar encomenda: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Enviar',
        message: 'Erro ao enviar encomenda',
        errorDetails: e.toString(),
      );
    } finally {
      setState(() {
        _loadingEnviarEncomenda = false;
      });
    }
  }

  // Funçao de teste para enviar encomenda sem foto
  Future<void> _registrarEncomendaTeste() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';
    final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
    final usuarioId =
        (encryptedUsuarioId.isNotEmpty) ? decryptText(encryptedUsuarioId) : '';
    final usuariodeId = int.tryParse(usuarioId) ?? 0;
    final usuarioparaId = _selectedUnidadeEncomenda != null
        ? _selectedUnidadeEncomenda['usuario_id']?.toString() ?? ''
        : '';
    final tipoSelecionado = _tipoEncomendaSelecionado != null
        ? _tipoEncomendaSelecionado!['descricao'] ?? ''
        : '';
    final machineIP = await _getMachineIP();

    print('=== TESTE ENVIO ENCOMENDA SEM FOTO ===');
    print('usuariodeId: $usuariodeId');
    print('usuarioparaId: "$usuarioparaId"');
    print('tipoSelecionado: "$tipoSelecionado"');
    print('machineIP: "$machineIP"');

    final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'registrar'));
    final payload = {
      "usuariode_id": usuariodeId,
      "usuariopara": usuarioparaId,
      "avisocategoria_id": 21,
      "sms_flg": "N",
      "titulo": "Entrega de encomenda",
      "texto": tipoSelecionado,
      "codigobarra": _codigoBarrasEncomendaController.text,
      "depara_id": _identificacaoInternaEncomendaController.text.trim(),
      "ip": machineIP,
      "fotobase64": "", // SEM FOTO PARA TESTE
    };

    print('Payload teste: $payload');

    try {
      print('Fazendo requisiçao POST para encomendaregistrar (teste)...');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200) {
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Encomenda Enviada',
          message: 'Encomenda de teste enviada com sucesso!',
        );
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro no Teste',
          message: 'Erro no teste',
          errorDetails: 'Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      print('Erro na requisiçao: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro na Requisiçao',
        message: 'Erro na requisiçao de teste',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _fetchVeiculos() async {
    setState(() => _loadingVeiculos = true);
    final result = await ReferenceDataService.fetchVeiculos();
    if (mounted) {
      setState(() {
        _veiculosList = result;
        _loadingVeiculos = false;
      });
    }
  }

  Future<void> _fetchVagas() async {
    setState(() => _loadingVagas = true);
    final result = await ReferenceDataService.fetchVagas();
    if (mounted) {
      setState(() {
        _vagasList = result;
        _loadingVagas = false;
      });
    }
  }

  Future<void> _fetchEntregas() async {
    setState(() => _loadingEntregas = true);
    final result = await ReferenceDataService.fetchEntregas();
    if (mounted) {
      setState(() {
        _entregasListOriginal = result.take(10).toList();
        _entregasList = List.from(_entregasListOriginal);
        _loadingEntregas = false;
      });
    }
  }

  // Funçao para verificar se usuário tem foto (sem carregar imagem)
  Future<String> _checkUserPhotoStatus(String userId) async {
    // Retorna imediatamente se já tem cache (evita piscar)
    if (_userPhotoStatusCache.containsKey(userId)) {
      final cached = _userPhotoStatusCache[userId]!;
      if (cached != 'loading') {
        return cached;
      }
    }

    // Se já está carregando, retorna loading sem fazer setState
    if (_userPhotoStatusLoading.containsKey(userId) &&
        _userPhotoStatusLoading[userId] == true) {
      return 'loading';
    }

    // Marca como carregando sem setState para evitar rebuild
    _userPhotoStatusLoading[userId] = true;

    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url = Uri.parse(
        'https://social.conectcon.net.br/pt-br/unidadefoto?id=$userId&tipo=USU');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'pessoacadastro_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' [_UsuarioDetalhesPanel] API response data: $data');
        final imageUrl =
            data['data']?['fotobase64'] ?? data['fotobase64'] ?? '';
        print(
            ' [_UsuarioDetalhesPanel] Extracted fotobase64: ${imageUrl.length} chars');
        final status = imageUrl.isNotEmpty ? 'has' : 'none';
        // Atualiza cache sem setState para evitar rebuild desnecessário
        _userPhotoStatusCache[userId] = status;
        _userPhotoStatusLoading[userId] = false;
        return status;
      } else {
        _userPhotoStatusCache[userId] = 'none';
        _userPhotoStatusLoading[userId] = false;
        return 'none';
      }
    } catch (e) {
      _userPhotoStatusCache[userId] = 'none';
      _userPhotoStatusLoading[userId] = false;
      return 'none';
    }
  }

  // Método específico para avulso e histórico usando API "foto"
  Future<String> _checkUserPhotoStatusAvulsoHistorico(String userId) async {
    final cacheKey = 'avulso_historico_$userId';
    // Retorna imediatamente se já tem cache (evita piscar)
    if (_userPhotoStatusCache.containsKey(cacheKey)) {
      final cached = _userPhotoStatusCache[cacheKey]!;
      if (cached != 'loading') {
        return cached;
      }
    }

    // Se já está carregando, retorna loading sem fazer setState
    if (_userPhotoStatusLoading.containsKey(cacheKey) &&
        _userPhotoStatusLoading[cacheKey] == true) {
      return 'loading';
    }

    // Marca como carregando sem setState para evitar rebuild
    _userPhotoStatusLoading[cacheKey] = true;

    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url = Uri.parse('https://gate.conectcon.net.br/pt-br/foto');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'pessoacadastro_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' [_UsuarioDetalhesPanel] API response data: $data');
        final imageUrl =
            data['data']?['fotobase64'] ?? data['fotobase64'] ?? '';
        print(
            ' [_UsuarioDetalhesPanel] Extracted fotobase64: ${imageUrl.length} chars');
        final status = imageUrl.isNotEmpty ? 'has' : 'none';
        // Atualiza cache sem setState para evitar rebuild desnecessário
        _userPhotoStatusCache[cacheKey] = status;
        _userPhotoStatusLoading[cacheKey] = false;
        return status;
      } else {
        _userPhotoStatusCache[cacheKey] = 'none';
        _userPhotoStatusLoading[cacheKey] = false;
        return 'none';
      }
    } catch (e) {
      _userPhotoStatusCache[cacheKey] = 'none';
      _userPhotoStatusLoading[cacheKey] = false;
      return 'none';
    }
  }

  // Funçao para carregar foto completa do usuário (apenas quando solicitado)
  // Método específico para avulso e histórico usando API "foto"
  Future<String?> _loadUserPhotoAvulsoHistorico(String userId) async {
    final cacheKey = 'avulso_historico_$userId';
    if (_userPhotosCache.containsKey(cacheKey)) {
      return _userPhotosCache[cacheKey];
    }

    if (_userPhotosLoading.containsKey(cacheKey) &&
        _userPhotosLoading[cacheKey] == true) {
      return null; // Já carregando
    }

    setState(() {
      _userPhotosLoading[cacheKey] = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url = Uri.parse('https://gate.conectcon.net.br/pt-br/foto');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'pessoacadastro_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' [_UsuarioDetalhesPanel] API response data: $data');
        final imageUrl =
            data['data']?['fotobase64'] ?? data['fotobase64'] ?? '';
        print(
            ' [_UsuarioDetalhesPanel] Extracted fotobase64: ${imageUrl.length} chars');
        setState(() {
          _userPhotosCache[cacheKey] = imageUrl;
        });
        return imageUrl;
      } else {
        setState(() {
          _userPhotosCache[cacheKey] = '';
        });
        return '';
      }
    } catch (e) {
      setState(() {
        _userPhotosCache[cacheKey] = '';
      });
      return '';
    } finally {
      setState(() {
        _userPhotosLoading[cacheKey] = false;
      });
    }
  }

  // Modal para exibir foto do usuário
  void _showUserPhotoModal(BuildContext context, String photoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Foto do Usuário',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getBorderColor(context)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(
                              Icons.broken_image,
                              size: 48,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Componente reutilizável para filtro de período (datas)
  Widget _buildPeriodFilter({
    required BuildContext context,
    required DateTime? startDate,
    required DateTime? endDate,
    required Function(DateTime?) onStartDateChanged,
    required Function(DateTime?) onEndDateChanged,
    String? hintText,
    bool? temErro,
  }) {
    return InlinePeriodPicker(
      startDate: startDate,
      endDate: endDate,
      onClear: () {
        onStartDateChanged(null);
        onEndDateChanged(null);
      },
      onRangeSelected: (start, end) {
        onStartDateChanged(start);
        onEndDateChanged(end);
      },
    );
  }

  // Formatar exibiçao do período
  String _formatPeriodDisplay(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return 'Período';
    }

    final startStr =
        startDate != null ? _formatarDataParaDisplay(startDate) : '';
    final endStr = endDate != null ? _formatarDataParaDisplay(endDate) : '';

    if (startDate != null && endDate != null) {
      return '$startStr até $endStr';
    } else if (startDate != null) {
      return 'A partir de $startStr';
    } else {
      return 'Até $endStr';
    }
  }

  // Date Range Picker estilo ShadCalendar com Time Picker integrado
  Future<void> _showDateRangeTimePicker(
    BuildContext context,
    DateTime? currentStartDate,
    DateTime? currentEndDate,
    Function(DateTime?) onStartDateChanged,
    Function(DateTime?) onEndDateChanged,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return RangeCalendarDialog(
          onRangeSelected: (startDate, endDate) => _onRangeSelected(
            context,
            startDate,
            endDate,
            onStartDateChanged,
            onEndDateChanged,
          ),
        );
      },
    );
  }

  Future<void> _onRangeSelected(
    BuildContext context,
    DateTime startDate,
    DateTime endDate,
    Function(DateTime?) onStartDateChanged,
    Function(DateTime?) onEndDateChanged,
  ) async {
    // Define automaticamente: início 00:00:00 e fim 23:59:59 (sem seleçao de horário)
    final finalStartDate = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
      0, // 00:00
      0, // minutos
      0, // segundos
    );

    final finalEndDate = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
      23, // 23:00
      59, // minutos
      59, // segundos
    );

    onStartDateChanged(finalStartDate);
    onEndDateChanged(finalEndDate);
  }

  // Time Picker auxiliar
  Future<TimeOfDay?> _showTimePicker(
      BuildContext context, String title, DateTime? currentDate) async {
    return await showTimePicker(
      context: context,
      initialTime: currentDate != null
          ? TimeOfDay(hour: currentDate.hour, minute: currentDate.minute)
          : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF1E40AF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            timePickerTheme: const TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Colors.black,
              dialHandColor: Color(0xFF1E40AF),
              dialBackgroundColor: Color(0xFFF3F4F6),
            ),
          ),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data:
                  MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
              child: child!,
            ),
          ),
        );
      },
    );
  }

  // Helper para formatar data
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

  Future<void> _fetchHistoricos() async {
    setState(() => _loadingHistoricoEncomendas = true);

    final payload = <String, dynamic>{};
    if (_filtroEntregues) {
      payload['statusentrega'] = 123;
    } else {
      payload['statusvaga'] = 1;
    }
    payload['unidade'] = _filtroNomeEntregaController.text.trim();
    payload['codigobarra'] = _filtroCodigoBarrasEntregaController.text.trim();
    payload['depara_id'] = _identificacaoInternaEntregaController.text.trim();
    if (_filtroDataInicioEntrega != null) {
      payload['data_ini'] = _filtroDataInicioEntrega!.toIso8601String();
    }
    if (_filtroDataFimEntrega != null) {
      payload['data_fim'] = _filtroDataFimEntrega!.toIso8601String();
    }

    final result =
        await EncomendaFetchService.fetchHistoricos(payload: payload);
    if (mounted) {
      setState(() {
        _historicoEncomendasListOriginal = result;
        _historicoEncomendasList = List.from(result);
        _loadingHistoricoEncomendas = false;
      });
    }
  }

  void _aplicarFiltroEntregas() {
    setState(() {
      _loadingHistoricoEncomendas = true;
    });

    final termo = _filtroNomeEntregaController.text.trim().toLowerCase();
    final codigo =
        _filtroCodigoBarrasEntregaController.text.trim().toLowerCase();

    final filtradas = _historicoEncomendasListOriginal.where((item) {
      // 1. Filtro por Unidade/Nome
      if (termo.isNotEmpty) {
        final unidade = (item['unidade'] ?? '').toString().toLowerCase();
        final nome = (item['nome'] ?? '').toString().toLowerCase();
        if (!unidade.contains(termo) && !nome.contains(termo)) return false;
      }

      // 2. Filtro por Código de Barras / ID Interno
      if (codigo.isNotEmpty) {
        final cBarras = (item['codigobarra'] ?? '').toString().toLowerCase();
        final internalId = (item['depara_id'] ?? '').toString().toLowerCase();
        if (!cBarras.contains(codigo) && !internalId.contains(codigo)) {
          return false;
        }
      }

      return true;
    }).toList();

    setState(() {
      _historicoEncomendasList = filtradas;
      _loadingHistoricoEncomendas = false;
    });
  }

  Future<void> _filtrarEncomendasPorUnidade(String unidade) async {
    setState(() {
      _loadingHistoricoEncomendas = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      if (condominioId.isEmpty) {
        setState(() {
          _loadingEntregas = false;
        });
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'lista'));
      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "unidade": unidade
      };

      print('DEBUG - Filtrando encomendas por unidade: $payload');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final encomendasFiltradas = List<Map<String, dynamic>>.from(
          data['data']?['lista'] ?? data['lista'] ?? [],
        );

        print(
            'API retornou ${encomendasFiltradas.length} encomendas para unidade $unidade');

        // Filtrar adicionalmente no cliente para garantir que só mostra da unidade certa
        final encomendasUnidadeCorreta = encomendasFiltradas.where((item) {
          final unidadeItem = (item['unidade'] ?? '').toString();
          // Verificar se a unidade do item contém o número filtrado
          return unidadeItem.contains(unidade) ||
              unidadeItem.startsWith(unidade);
        }).toList();

        print(
            'Após filtro cliente: ${encomendasUnidadeCorreta.length} encomendas para unidade $unidade');

        setState(() {
          _entregasListOriginal = encomendasUnidadeCorreta;
          _entregasList = List.from(_entregasListOriginal);
          _historicoEncomendasList = encomendasUnidadeCorreta;
        });

        print(
            'Encomendas filtradas por unidade $unidade: ${_entregasList.length}');
      } else {
        print('Erro ao filtrar encomendas por unidade: ${response.statusCode}');
        // Fallback para filtro local se a API falhar
        final entregasFiltradas = _entregasListOriginal.where((item) {
          final unidadeItem = (item['unidade'] ?? '').toString().toLowerCase();
          return unidadeItem.startsWith(unidade.toLowerCase());
        }).toList();

        setState(() {
          _entregasList = entregasFiltradas;
          _historicoEncomendasList = entregasFiltradas;
        });
      }
    } catch (e) {
      print('Erro ao filtrar encomendas por unidade: $e');
      // Fallback para filtro local se der erro
      final entregasFiltradas = _entregasListOriginal.where((item) {
        final unidadeItem = (item['unidade'] ?? '').toString().toLowerCase();
        return unidadeItem.startsWith(unidade.toLowerCase());
      }).toList();

      setState(() {
        _entregasList = entregasFiltradas;
        _historicoEncomendasList = entregasFiltradas;
      });
    } finally {
      setState(() {
        _loadingHistoricoEncomendas = false;
      });
    }
  }

  Future<void> _filtrarEncomendasPorCodigoBarras() async {
    final codigo = _filtroCodigoBarrasEntregaController.text.trim();
    if (codigo.isEmpty) {
      _fetchEntregas();
      return;
    }

    setState(() {
      _loadingHistoricoEncomendas = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      if (condominioId.isEmpty) {
        setState(() => _loadingHistoricoEncomendas = false);
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'lista'));
      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "codigobarra": codigo,
        "depara_id": _identificacaoInternaEntregaController.text.trim(),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lista = List<Map<String, dynamic>>.from(
          data['data']?['lista'] ?? data['lista'] ?? [],
        );

        setState(() {
          _entregasListOriginal = lista;
          _entregasList = List.from(lista);
          _historicoEncomendasList = List.from(lista);
        });
      } else {
        setState(() {
          _entregasListOriginal = [];
          _entregasList = [];
          _historicoEncomendasList = [];
        });
      }
    } catch (e) {
      setState(() {
        _entregasListOriginal = [];
        _entregasList = [];
        _historicoEncomendasList = [];
      });
    } finally {
      setState(() => _loadingHistoricoEncomendas = false);
    }
  }

  void _mostrarOpcoesSaida(Map<String, dynamic> passagem) {
    // Expandir card ao invés de abrir modal
    final passagemId =
        passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? '';
    final uniqueKey = 'saida_$passagemId';

    setState(() {
      if (_cardsExpandidos.contains(uniqueKey)) {
        _cardsExpandidos.remove(uniqueKey);
      } else {
        // Fechar outros cards expandidos de saídas
        _cardsExpandidos.removeWhere((key) => key.startsWith('saida_'));
        _cardsExpandidos.add(uniqueKey);
      }
    });
  }

  Future<void> _selecionarHorarioSaida(Map<String, dynamic> passagem) async {
    DateTime? dataSelecionada;
    TimeOfDay? horaSelecionada;

    // Primeiro: selecionar data
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime(2030),
      locale: const Locale('pt', 'BR'),
    );

    if (pickedDate != null) {
      dataSelecionada = pickedDate;

      // Segundo: selecionar hora
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (BuildContext context, Widget? child) {
          return Theme(
            data: Theme.of(context).copyWith(
              timePickerTheme: TimePickerThemeData(
                backgroundColor: getBackgroundColor(context),
                hourMinuteTextColor: getTextColor(context),
                dialHandColor: const Color(0xFF684F8E),
                dialBackgroundColor: getCardColor(context),
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        horaSelecionada = pickedTime;

        // Combinar data e hora
        final DateTime dataHoraSaida = DateTime(
          dataSelecionada.year,
          dataSelecionada.month,
          dataSelecionada.day,
          horaSelecionada.hour,
          horaSelecionada.minute,
        );

        // Registrar saída com data/hora selecionada
        _registrarSaida(passagem, dataHoraSaida: dataHoraSaida);
      }
    }
  }

  Future<void> _registrarSaida(Map<String, dynamic> passagem,
      {bool saidaAgora = false, DateTime? dataHoraSaida}) async {
    final passagemId =
        passagem['id']?.toString() ?? passagem['passagem_id']?.toString() ?? '';

    // Adicionar loading state
    setState(() {
      _loadingSaidas.add(passagemId);
    });

    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) {
      setState(() {
        _loadingSaidas.remove(passagemId);
      });
      return;
    }

    // Usar o endpoint do backup: baixaManual
    final url = Uri.parse(ApiConfig.getEndpoint('dashboard', 'baixaManual'));

    // Usar data/hora fornecida ou data/hora atual
    final saidaDateTime = dataHoraSaida ?? DateTime.now();
    final dtSaida =
        "${saidaDateTime.day.toString().padLeft(2, '0')}-${saidaDateTime.month.toString().padLeft(2, '0')}-${saidaDateTime.year.toString().padLeft(4, '0')} ${saidaDateTime.hour.toString().padLeft(2, '0')}:${saidaDateTime.minute.toString().padLeft(2, '0')}:${saidaDateTime.second.toString().padLeft(2, '0')}";

    final payload = {
      "avulsopassagem_id": passagem['id'] ?? passagem['passagem_id'] ?? 0,
      "leitor_id_saida": 0,
      "dt_saida": dtSaida,
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Fechar card expandido e remover loading
        final uniqueKey = 'saida_$passagemId';
        setState(() {
          _cardsExpandidos.remove(uniqueKey);
          _loadingSaidas.remove(passagemId);
        });

        // Mostrar feedback de sucesso
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Saída Registrada',
          message: 'Saída registrada com sucesso!',
        );

        // Recarregar lista de saídas para garantir atualização
        await _buscarSaidasFiltradas();

        // Limpar formulário de entrada após saída (como no backup)
        await _limparFormularioEntrada();
      } else {
        // Remover loading state
        setState(() {
          _loadingSaidas.remove(passagemId);
        });

        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Registrar',
          message: 'Erro ao registrar saída',
          errorDetails: 'Status: ${response.statusCode}\n${response.body}',
        );
      }
    } catch (e) {
      // Remover loading state
      setState(() {
        _loadingSaidas.remove(passagemId);
      });

      FeedbackUtils.showError(
        context: context,
        title: 'Erro de Conexá£o',
        message: 'Erro ao conectar',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _limparFormularioEntrada() async {
    setState(() {
      _documentoController.clear();
      _nomeController.clear();
      _autorizanteController.clear();
      _empresaController.clear();
      _placaController.clear();
      _modeloController.clear();
      _obsController.clear();
      _dataFimController.clear();
      _selectedUnidade = null;
      _selectedCor = null;
      _selectedVagaAvulso = null;
      _selectedCracha = null;
      _cadastroAvulso = null;
      _fotoBase64 = null;
      _fotoEntrada = null;
      _fotoDocumento = null;
      _fotoDocumentoBase64 = null;
      _temCadastroAvulso = false;
      _mostrarErrosVisuais = false;
      _dataFimSelecionada = null;
      _horaFimSelecionada = null;
      // Fechar formulário, resultados e restaurar filtro visível
      _mostrarFormEntrada = false;
      _filtroEntradaMinimizado = false;
      _convidadosResultados = [];
      _resultadosBuscaEntrada = [];
      _reservaSelecionada = null;
      _isAgendamento = false;
      _isNovoUsuario = false;
      _filtroDocumentoEntradaController.clear();
      _filtroNomeEntradaController.clear();
    });
  }

  // Widget para item da lista com checkbox (modo auto baixa)
  Widget _listItemComCheckbox({
    required Map<String, dynamic> passagem,
    required int index,
    required bool isSelected,
    required Function(bool) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFFF79009).withValues(alpha: 0.1)
            : getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFF79009) : getBorderColor(context),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: ListTile(
        leading: Checkbox(
          value: isSelected,
          onChanged: (value) => onChanged(value ?? false),
          activeColor: const Color(0xFFF79009),
        ),
        title: Text(
          '${passagem['nome'] ?? 'Visitante'}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                '${_getTipoFormatado(passagem)} Â· ${passagem['destino'] ?? 'Torre Unidade'}'),
            // Documento (se existir)
            if (passagem['documento'] != null &&
                passagem['documento'].toString().isNotEmpty) ...[
              Text(
                'Doc: ${passagem['documento']}',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
            Text(
              'Entrada: ${passagem['dt_ini'] ?? ''}',
              style: const TextStyle(color: Colors.green),
            ),
            if (passagem['placa'] != null &&
                passagem['placa'].toString().isNotEmpty)
              Text(
                'Veículo: ${passagem['placa']}',
                style: const TextStyle(color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }

  // Executar baixa em lote para múltiplas passagens
  Future<void> _executarBaixaEmLote() async {
    if (_itensSelecionados.isEmpty) return;

    final passagensSelecionadas = _itensSelecionados
        .map((index) {
          final todasFiltradas = _getTodasPassagensFiltradas();
          return index < todasFiltradas.length ? todasFiltradas[index] : null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();

    if (passagensSelecionadas.isEmpty) return;

    int sucessos = 0;
    int erros = 0;

    setState(() {
      _loadingPassagens = true;
    });

    // Processar cada passagem selecionada
    for (final passagem in passagensSelecionadas) {
      try {
        await _registrarSaida(passagem);
        sucessos++;
      } catch (e) {
        erros++;
      }
    }

    setState(() {
      _loadingPassagens = false;
      _itensSelecionados.clear();
      _modoAutoBaixa = false;
    });

    // Mostrar resultado
    String mensagem = '';
    if (sucessos > 0 && erros == 0) {
      mensagem =
          'Baixa em lote realizada com sucesso! $sucessos item(s) processado(s).';
    } else if (sucessos > 0 && erros > 0) {
      mensagem = 'Baixa em lote parcial: $sucessos sucesso(s), $erros erro(s).';
    } else {
      mensagem = 'Erro na baixa em lote: $erros erro(s).';
    }

    if (sucessos > 0) {
      FeedbackUtils.showSuccess(
        context: context,
        title: 'Baixa em Lote',
        message: mensagem,
      );
    } else {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro na Baixa',
        message: mensagem,
      );
    }

    // Recarregar dados
    // await _fetchPassagens(); // Desativado - passagens vêm do SignalR
  }

  Future<void> _abrirModalConvidados(String reservaId) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) return;

    final url = Uri.parse(
      ApiConfig.getUrl(
        'dashboard',
        'convidados',
        params: {'reserva_id': reservaId, 'culture': 'pt-br'},
      ),
    );

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convidadosData = data['data'];
        final lista =
            (convidadosData is Map && convidadosData['convidados'] is List)
                ? convidadosData['convidados']
                : [];

        // Mostrar painel lateral usando OverlayEntry (sem barreira)
        _abrirPainelLateral(
          _ConvidadosModal(
            reservaId: reservaId,
            convidados: List<Map<String, dynamic>>.from(lista),
          ),
        );
      }
    } catch (e) {
      // Silenciosamente ignora erro
    }
  }

  // Painel lateral 50% com convidados do agendamento
  Future<void> _abrirSidePanelConvidados(String reservaId,
      {required String titulo}) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) return;

    final url = Uri.parse(
      ApiConfig.getUrl(
        'dashboard',
        'convidados',
        params: {'reserva_id': reservaId, 'culture': 'pt-br'},
      ),
    );

    List<Map<String, dynamic>> convidados = [];
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convidadosData = data['data'];
        final lista =
            (convidadosData is Map && convidadosData['convidados'] is List)
                ? convidadosData['convidados']
                : [];
        convidados = List<Map<String, dynamic>>.from(lista);
      }
    } catch (_) {}

    // Mostrar painel lateral usando OverlayEntry (sem barreira)
    _abrirPainelLateral(
      _LocacaoTemporariaPanel(
          titulo: titulo, convidados: convidados, reservaId: reservaId),
    );
  }

  // Funçao para fechar painel lateral
  void _fecharPainelLateral() {
    setState(() {
      _isSidePanelOpen = false;
      // Esperar a animação terminar antes de limpar o widget
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isSidePanelOpen) {
          setState(() {
            _sidePanelCurrentWidget = null;
            _currentSidePanelWidth = 0;
          });
        }
      });
    });

    // Remover painel atual
    _painelLateralOverlay?.remove();
    _painelLateralOverlay = null;

    // Verificar se há um painel anterior para restaurar (caso de câmera sobre outro painel)
    if (_painelAnteriorOverlay != null) {
      _painelLateralOverlay = _painelAnteriorOverlay;
      fecharPainelLateralGlobal = _fecharPainelAnteriorFunction ?? (() {});
      _painelAnteriorOverlay = null;
      _fecharPainelAnteriorFunction = null;
    } else {
      // Nenhum painel anterior, restaurar funá§ões padrão
      fecharPainelLateralGlobal = () {};
    }
  }

  // Painel anterior para voltar
  Widget? _painelAnterior;

  // Funçao para voltar ao painel anterior
  void _voltarPainelAnterior() {
    if (_painelAnterior != null) {
      _abrirPainelLateral(_painelAnterior!);
      // Ná£o limpa _painelAnterior aqui, pois pode ser usado novamente
      // _painelAnterior será sobrescrito quando um novo painel for aberto
    } else {
      // Se não há painel anterior, simplesmente fecha o painel atual
      _fecharPainelLateral();
    }
  }

  // Funçao para abrir detalhes da unidade
  Future<void> _abrirUnidadeList(Map<String, dynamic> unidade) async {
    print(
        'Abrindo unidadelist para unidade: ${unidade['unidade_mostra'] ?? unidade['nome']}');

    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '0';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) {
      print('Token de sessá£o não encontrado');
      return;
    }

    try {
      final url = Uri.parse('https://gate.conectcon.net.br/pt-br/unidadelist');
      final aptoId = unidade['apto_id'] ?? unidade['id'];

      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "apto_id": aptoId,
      };

      print('ðŸ“¡ Fazendo requisiçao para unidadelist: $payload');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(' unidadelist retornou sucesso: ${data['data']}');

        // Aqui você pode processar os dados retornados da API
        // Por enquanto apenas logamos o sucesso
        final listaUnidades = data['data']?['lista'] ?? [];
        print('Unidades encontradas: ${listaUnidades.length}');

        // TODO: Implementar exibiçao ou navegaçao baseada nos dados retornados
      } else {
        print(
            'Erro na API unidadelist: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao chamar unidadelist: $e');
    }
  }

  void _abrirDetalhesUnidade(Map<String, dynamic> unidade) async {
    print(
        'ðŸ”“ _abrirDetalhesUnidade: _permissaoAcessoPessoas = $_permissaoAcessoPessoas');
    // Quando abrimos a unidade, ela se torna o painel "raiz", então limpamos o painel anterior
    _painelAnterior = null;

    // Obter o condominio_id das SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '0'; // fallback

    // Adicionar condominio_id á  unidade
    final unidadeComCondominio = {
      ...unidade,
      'condominio_id': condominioId,
    };

    _abrirPainelLateral(
      UnidadeDetalheScreen(
        onClose: _fecharPainelLateral,
        unidade: unidadeComCondominio,
        permissaoAcessoPessoas: _permissaoAcessoPessoas,
        onBackToParent: _voltarPainelAnterior,
        onOpenPanel: (Widget painel, {VoidCallback? onClose}) {
          // Salva a unidade atual como painel anterior antes de abrir qualquer sub-painel
          _painelAnterior = UnidadeDetalheScreen(
            onClose: _fecharPainelLateral,
            unidade: unidadeComCondominio,
            permissaoAcessoPessoas: _permissaoAcessoPessoas,
            onBackToParent: _voltarPainelAnterior,
            onOpenPanel: (Widget p, {VoidCallback? onClose}) =>
                _abrirPainelLateral(p),
          );

          // Abre o painel solicitado (página de registro)
          _abrirPainelLateral(painel);
        },
      ),
    );
  }

  // Funçao para abrir tela de seleçao de pessoa

  // Funçao para registrar entrega de encomenda
  Future<void> _registrarEntregaEncomenda(
    Map<String, dynamic> encomenda, {
    required bool usarToken,
    required String token,
    Uint8List? fotoMorador,
    Uint8List? fotoEncomenda,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'entrega'));

    // Preparar dados da entrega
    final avisoId = encomenda['aviso_id'] ??
        encomenda['avisoentrega_id'] ??
        encomenda['id'];
    final tokenTratado = usarToken ? token : '';

    final payload = {
      "avisoentrega_id": avisoId,
      "statusentrega_id": 123,
      "retiradoPor": "Sistema",
      "entreguePor": "Encomendas",
      "tokenRetirou": tokenTratado,
      "mensagem": "Entrega realizada via sistema",
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final itemKey = (encomenda['aviso_id'] ??
                encomenda['avisoentrega_id'] ??
                encomenda['id'])
            .toString();

        // Validação de Token conforme PRD (erro == 1)
        if (responseData['erro'] == 1) {
          if (mounted) {
            FeedbackUtils.showError(
              context: context,
              title: 'Token Inválido',
              message:
                  responseData['message'] ?? 'O token informado não é válido.',
            );
          }
          return;
        }

        // Upload de novas fotos se houver
        final int? protocoloId = int.tryParse(avisoId.toString());
        if (protocoloId != null) {
          if (fotoMorador != null) {
            final usuarioparaId =
                (encomenda['usuario_id'] ?? encomenda['usuario_para_id'] ?? 0);
            await _uploadFotoEntregaPessoa(
                usuarioparaId.toString(), fotoMorador);
          }
          if (fotoEncomenda != null) {
            await _uploadFotoEncomenda(protocoloId, fotoEncomenda);
          }
        }

        if (mounted) {
          setState(() {
            _itemFeedbackMessages[itemKey] = 'Entregue com sucesso';
          });
        }
        _fecharPainelLateral();

        // Aguardar 3 segundos para mostrar a mensagem e depois sumir o card
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _itemFeedbackMessages.remove(itemKey);
              _historicoEncomendasList.removeWhere((item) =>
                  (item['aviso_id'] ?? item['avisoentrega_id'] ?? item['id'])
                      .toString() ==
                  itemKey);
              _entregasList.removeWhere((item) =>
                  (item['aviso_id'] ?? item['avisoentrega_id'] ?? item['id'])
                      .toString() ==
                  itemKey);
            });
          }
        });
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Registrar',
          message: 'Erro ao registrar entrega',
          errorDetails: 'Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Registrar',
        message: 'Erro ao registrar entrega',
        errorDetails: e.toString(),
      );
    }
  }

  // Funçao para carregar fotos da entrega
  void _carregarFotosEntrega(Map<String, dynamic> encomenda) {
    // Extrair IDs necessários
    // Prioritizar avisoentrega_id para busca de imagem, conforme solicitado pelo usuário
    final protocolo = encomenda['protocolo']?.toString() ??
        encomenda['avisoentrega_id']?.toString() ??
        encomenda['id']?.toString() ??
        '';

    final protocoloId = int.tryParse(protocolo) ?? 0;
    final userId = encomenda['usuarioPara_Id'] ??
        encomenda['usuario_id'] ??
        encomenda['usuario_para_id'] ??
        0;

    // Limpar fotos anteriores
    _fotoFacialEntrega = null;
    _fotoEncomendaEntrega = null;

    // Carregar foto do usuário (morador)
    if (userId > 0) {
      _getUserPhoto(userId).then((fotoBase64) {
        if (fotoBase64 != null && fotoBase64.isNotEmpty && mounted) {
          try {
            final fotoBytes = base64Decode(fotoBase64);
            setState(() {
              _fotoFacialEntrega = fotoBytes;
            });
          } catch (e) {
            // Ignora erro de decodificaçao
          }
        }
      });
    }

    // Carregar foto da encomenda
    if (protocoloId > 0) {
      _getEncomendaPhoto(protocoloId).then((fotoBase64) {
        if (fotoBase64 != null && fotoBase64.isNotEmpty && mounted) {
          try {
            final fotoBytes = base64Decode(fotoBase64);
            setState(() {
              _fotoEncomendaEntrega = fotoBytes;
            });
          } catch (e) {
            // Ignora erro de decodificaçao
          }
        }
      });
    }
  }

  // Busca a foto do usuário (morador) por userId. Retorna base64 ou null.
  Future<String?> _getUserPhoto(dynamic userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
      if (tokenSessao.isEmpty) return null;

      // URL atualizada para unidadefoto (POST)
      final url = Uri.parse(
          'https://socialh.conectcon.net.br/pt-br/unidadefoto?id=$userId&tipo=USU');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'pessoacadastro_id': userId.toString(),
        }),
      );

      if (response.statusCode == 200) {
        // Se a resposta for imagem direta, converter para base64
        if (response.headers['content-type']?.startsWith('image/') ?? false) {
          return base64Encode(response.bodyBytes);
        }

        // Se for JSON, tentar extrair conforme padrão
        final responseData = jsonDecode(response.body);

        // 1. Tentar extrair URL se presente
        String? fotoUrl = (responseData['url'] ??
                responseData['imageUrl'] ??
                responseData['imagem'] ??
                responseData['data']?['url'])
            ?.toString();

        if (fotoUrl != null && fotoUrl.isNotEmpty && fotoUrl != 'null') {
          try {
            final imgResponse = await http.get(Uri.parse(fotoUrl));
            if (imgResponse.statusCode == 200) {
              return base64Encode(imgResponse.bodyBytes);
            }
          } catch (_) {}
        }

        // 2. Fallback para base64
        final data = responseData['data'];
        String? fotoBase64;
        if (data is Map) {
          fotoBase64 =
              (data['fotobase64'] ?? data['fotoBase64'] ?? data['foto_base64'])
                  ?.toString();
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          fotoBase64 = (data.first['fotobase64'] ??
                  data.first['fotoBase64'] ??
                  data.first['foto_base64'])
              ?.toString();
        } else {
          fotoBase64 = (responseData['fotobase64'] ??
                  responseData['fotoBase64'] ??
                  responseData['foto_base64'])
              ?.toString();
        }

        if (fotoBase64 != null &&
            fotoBase64.isNotEmpty &&
            fotoBase64 != 'null') {
          if (fotoBase64.contains(',')) {
            fotoBase64 = fotoBase64.split(',').last;
          }
          return fotoBase64;
        }
      }
    } catch (_) {}
    return null;
  }

  // Busca a foto da encomenda por protocoloId. Retorna base64 ou null.
  Future<String?> _getEncomendaPhoto(int protocoloId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
      if (tokenSessao.isEmpty) return null;

      final condominioId = await ApiConfig.getCondominioId();
      // URL atualizada para encomendaimagem (GET)
      final url = Uri.parse(
          'https://gate.conectcon.net.br/pt-br/encomendaimagem?id=$protocoloId&index=1&condominio_id=$condominioId');

      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        // Se a resposta for imagem direta, converter para base64
        if (response.headers['content-type']?.startsWith('image/') ?? false) {
          return base64Encode(response.bodyBytes);
        }

        final responseData = jsonDecode(response.body);

        // 1. Tentar extrair URL se presente (conforme reportado recentemente pelo usuário)
        String? fotoUrl = (responseData['url'] ??
                responseData['imageUrl'] ??
                responseData['imagem'] ??
                responseData['data']?['url'])
            ?.toString();

        if (fotoUrl != null && fotoUrl.isNotEmpty && fotoUrl != 'null') {
          try {
            final imgResponse = await http.get(Uri.parse(fotoUrl));
            if (imgResponse.statusCode == 200) {
              return base64Encode(imgResponse.bodyBytes);
            }
          } catch (e) {
            print('Erro ao carregar imagem externa de encomenda: $e');
          }
        }

        // 2. Fallback para base64 nos campos tradicionais
        final data = responseData['data'];
        String? fotoBase64;
        if (data is Map) {
          fotoBase64 =
              (data['fotobase64'] ?? data['fotoBase64'] ?? data['foto_base64'])
                  ?.toString();
        } else if (data is List && data.isNotEmpty && data.first is Map) {
          fotoBase64 = (data.first['fotobase64'] ??
                  data.first['fotoBase64'] ??
                  data.first['foto_base64'])
              ?.toString();
        } else {
          fotoBase64 = (responseData['fotobase64'] ??
                  responseData['fotoBase64'] ??
                  responseData['foto_base64'])
              ?.toString();
        }

        if (fotoBase64 != null &&
            fotoBase64.isNotEmpty &&
            fotoBase64 != 'null') {
          if (fotoBase64.contains(',')) {
            fotoBase64 = fotoBase64.split(',').last;
          }
          return fotoBase64;
        }
      }
    } catch (_) {}
    return null;
  }

  // Funçao para reenviar entrega
  Future<void> _reenviarEntrega(Map<String, dynamic> entrega) async {
    final avisoId = entrega['avisoentrega_id'] ?? entrega['aviso_id'];
    if (avisoId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';

    final url = Uri.parse(
      ApiConfig.getEndpoint('encomendas', 'reenvioEntrega'),
    );
    final payload = {"id": avisoId};

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      final itemKey = avisoId.toString();

      if (response.statusCode == 200) {
        setState(() {
          _itemFeedbackMessages[itemKey] = 'Reenviado com sucesso';
        });

        // Limpar após 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _itemFeedbackMessages.remove(itemKey);
            });
          }
        });
      } else {
        setState(() {
          _itemFeedbackMessages[itemKey] =
              'Erro ao reenviar: ${response.statusCode}';
        });
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            setState(() {
              _itemFeedbackMessages.remove(itemKey);
            });
          }
        });
      }
    } catch (e) {
      final itemKey = avisoId.toString();
      setState(() {
        _itemFeedbackMessages[itemKey] = 'Erro: $e';
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _itemFeedbackMessages.remove(itemKey);
          });
        }
      });
    }
  }

  // Funçao para abrir painel lateral usando Overlay
  void _abrirPainelLateral(Widget painel) {
    print('_abrirPainelLateral chamado com painel: ${painel.runtimeType}');

    // Obter contexto - usar o contexto armazenado se disponível
    final ctx = _dashboardContext;
    if (ctx == null || !mounted) {
      print('Contexto do Dashboard não disponível para abrir painel lateral');
      return;
    }

    // Verificar se é um painel de câmera sendo aberto sobre outro painel
    final bool isCameraPanel = painel is CameraSidePanelWidget;

    // Se for câmera e já houver um painel, salvar o estado anterior
    if (isCameraPanel && _painelLateralOverlay != null) {
      _painelAnteriorOverlay = _painelLateralOverlay;
      _fecharPainelAnteriorFunction = fecharPainelLateralGlobal;
    } else if (!isCameraPanel) {
      // Para painéis normais, fechar qualquer painel anterior
      _fecharPainelLateral();
    }

    _painelLateralOverlay = OverlayEntry(
      builder: (context) {
        // Detectar tema atual dinamicamente
        final Brightness brightness = Theme.of(context).brightness;
        final bool isDark = brightness == Brightness.dark;
        final Color backgroundColor = isDark ? Colors.black : Colors.white;
        final Color borderColor =
            isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);

        final screenWidth = MediaQuery.of(context).size.width;

        // Espaço ocupado pela sidebar (largura 70 + margens dinâmicas)
        // marginH = (screenWidth * 0.018).clamp(8.0, 20.0);
        final double sidebarMargin = (screenWidth * 0.018).clamp(8.0, 20.0);
        final double sidebarRightBoundary =
            sidebarMargin + 70.0 + 10.0; // +10 de folga

        double panelWidth;

        // Mesma lógica do SidePanelManager
        if (screenWidth < 768) {
          panelWidth = screenWidth * 0.9;
        } else if (screenWidth < 1200) {
          panelWidth = screenWidth * 0.6;
        } else {
          panelWidth = screenWidth * 0.48;
        }

        // Ajuste CRÍTICO: Se a largura do painel for sobrepor a sidebar em telas não tão grandes (até 1440px), limitamos
        double leftPos = screenWidth - panelWidth;
        if (leftPos < sidebarRightBoundary && screenWidth < 1440) {
          panelWidth =
              screenWidth - sidebarRightBoundary - 10; // Garantir folga
        }

        return AnimatedPositioned(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          right: 0,
          top: 0,
          bottom: 0,
          width: panelWidth,
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              border: Border(
                left: BorderSide(
                  color: borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: painel,
            ),
          ),
        );
      },
    );

    // Definir ção global para fechar o painel atual
    fecharPainelLateralGlobal = () => _fecharPainelLateral();
    // Definir ção global para abrir (sempre abre sobre o atual)
    abrirPainelLateralGlobal = (Widget painel) => _abrirPainelLateral(painel);

    // Inserir overlay usando o contexto armazenado
    try {
      Overlay.of(ctx).insert(_painelLateralOverlay!);
      print(' Overlay inserido com sucesso');
    } catch (e) {
      print('Erro ao inserir overlay: $e');
    }
  }

  // Funçao para abrir date range picker
  Future<void> _abrirDateRangePicker(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 7)),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7C4DFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filtroDataInicioSelecionada = picked.start;
        _filtroDataFimSelecionada = picked.end;
      });
    }
  }

  // Funá§ões para aá§ões das entregas
  Future<void> _visualizarFotoEncomenda(Map<String, dynamic> entrega) async {
    // Implementar visualizaçao da foto da encomenda
    // TODO: Implementar modal com foto da encomenda
  }

  Future<void> _marcarComoEntregue(Map<String, dynamic> entrega) async {
    // Implementar marcaçao como entregue
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro de Autenticaçao',
          message: 'Token de sessá£o inválido',
        );
        return;
      }

      final url =
          Uri.parse(ApiConfig.getEndpoint('entregas', 'marcar-entregue'));
      final payload = {
        'entrega_id': entrega['id'],
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final itemKey = entrega['id']?.toString() ??
            entrega['avisoentrega_id']?.toString() ??
            '';
        setState(() {
          _itemFeedbackMessages[itemKey] = 'Realizado com sucesso';
        });

        // Limpar após 3 segundos
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _itemFeedbackMessages.remove(itemKey);
            });
          }
        });
        await _fetchEntregas(); // Recarregar lista
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Erro ao marcar como entregue',
          errorDetails: 'Status: ${response.statusCode}',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro de Conexá£o',
        message: 'Erro ao conectar com servidor',
        errorDetails: e.toString(),
      );
    }
  }

  void _mostrarDetalhesEntrega(Map<String, dynamic> entrega) {
    _abrirPainelLateral(
      _DetalhesEntregaPanel(
        entrega: entrega,
        onClose: () => fecharPainelLateralGlobal(),
      ),
    );
  }

  void _visualizarPdfEncomenda(Map<String, dynamic> entrega) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gerando PDF...')),
    );

    try {
      final pdfBytes = await DeliveryPdfService().generateDeliveryPdf(entrega);
      final id = entrega['id'] ??
          entrega['avisoentrega_id'] ??
          DateTime.now().millisecondsSinceEpoch;
      final fileName = 'Comprovante_Entrega_$id.pdf';

      if (!mounted) return;

      final path = await downloadFile(pdfBytes, fileName);

      if (!mounted) return;

      if (path != null) {
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Sucesso',
          message: 'PDF salvo em: $path',
        );
      }
      // For web, downloadFile returns null but handles download automatically
    } catch (e) {
      if (!mounted) return;
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Erro ao gerar PDF: $e',
      );
    }
  }

  Widget _buildCancelInlineForm(Map<String, dynamic> entrega, String itemKey) {
    final ctrl =
        _cancelMsgCtrls.putIfAbsent(itemKey, () => TextEditingController());
    final loading = _cancelLoading.contains(itemKey);
    final isDark = isDarkMode(context);
    final bool podeConfirmar = !loading && ctrl.text.trim().isNotEmpty;
    final Color textColor = getTextColor(context);
    final Color subtleText = getSecondaryTextColor(context);
    final Color borderColor =
        isDark ? Colors.grey.shade700 : Colors.grey.shade300;
    final Color confirmColor = const Color(0xFF28A745);

    return Padding(
      key: ValueKey('cancel_form_$itemKey'),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: 1, color: borderColor),
          const SizedBox(height: 12),
          Text(
            'Motivo do cancelamento',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            enabled: !loading,
            onChanged: (_) => setState(() {}),
            minLines: 1,
            maxLines: 3,
            decoration: inputDecorationPadrao(
              context,
              hintText: 'Descreva o motivo',
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TransparentIconGroup([
              IconActionData(
                icon: Icons.arrow_back,
                tooltip: 'Voltar',
                color: subtleText,
                onPressed: loading
                    ? null
                    : () => setState(() => _cancellingItemId = null),
              ),
              IconActionData(
                icon: Icons.check,
                tooltip: 'Confirmar cancelamento',
                color: confirmColor,
                isLoading: loading,
                onPressed: podeConfirmar
                    ? () => _confirmarCancelamento(entrega)
                    : null,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  void _cancelarEntrega(Map<String, dynamic> entrega) {
    final avisoId =
        entrega['avisoentrega_id'] ?? entrega['aviso_id'] ?? entrega['id'];
    if (avisoId == null) return;
    final itemKey = avisoId.toString();

    setState(() {
      if (_cancellingItemId == itemKey) {
        _cancellingItemId = null;
      } else {
        _cancellingItemId = itemKey;
        _cancelMsgCtrls.putIfAbsent(itemKey, () => TextEditingController());
      }
    });
  }

  Future<void> _confirmarCancelamento(Map<String, dynamic> entrega) async {
    final avisoId =
        entrega['avisoentrega_id'] ?? entrega['aviso_id'] ?? entrega['id'];
    if (avisoId == null) return;
    final itemKey = avisoId.toString();
    final ctrl = _cancelMsgCtrls[itemKey];
    final mensagem = ctrl?.text.trim() ?? '';
    if (mensagem.isEmpty) return;

    setState(() => _cancelLoading.add(itemKey));

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro de Autenticação',
          message: 'Token de sessão inválido',
        );
        return;
      }

      final entreguePor = await ApiConfig.getUsuarioNome();

      final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'entrega'));
      final payload = {
        'avisoentrega_id': avisoId,
        'statusentrega_id': 125,
        'retiradoPor': 'Sistema',
        'entreguePor': entreguePor,
        'tokenRetirou': '',
        'mensagem': mensagem,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        ctrl?.dispose();
        _cancelMsgCtrls.remove(itemKey);
        setState(() {
          _cancellingItemId = null;
          _itemFeedbackMessages[itemKey] = 'Cancelado com sucesso';
        });

        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _itemFeedbackMessages.remove(itemKey);
            });
          }
        });
        await _fetchEntregas();
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Erro ao cancelar entrega',
          errorDetails:
              'Status: ${response.statusCode}\nResposta: ${response.body}',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro de Conexão',
        message: 'Erro ao conectar com servidor',
        errorDetails: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _cancelLoading.remove(itemKey));
      }
    }
  }

  // Funçao para capturar foto de encomenda no painel de encomendas
  Future<void> _tirarFotoEncomenda() async {
    setState(() {
      _loadingFotoEncomenda = true;
    });

    try {
      if (mounted) {
        setState(() {
          _loadingFotoEncomenda = false;
        });
      }

      final globalContext = _dashboardContext ?? context;
      final result = await showDialog<String>(
        context: globalContext,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => const FacialCaptureModal(
          isFrontal: false,
          title: 'Capturar foto da encomenda',
          isQuadrado: true,
        ),
      );

      if (result != null) {
        await _processarFotoCapturadaEncomenda(result);
      }
    } catch (e) {
      setState(() {
        _loadingFotoEncomenda = false;
      });
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Capturar',
        message: 'Erro ao capturar foto',
        errorDetails: e.toString(),
      );
    }
  }

  // Processar foto capturada de encomenda
  Future<void> _processarFotoCapturadaEncomenda(String dataUrl) async {
    try {
      if (dataUrl.isEmpty || !dataUrl.contains(',')) {
        return;
      }

      // Converter dataUrl para bytes
      final base64Data = dataUrl.split(',').last;
      if (base64Data.isEmpty) {
        return;
      }

      final bytes = base64Decode(base64Data);
      if (bytes.isEmpty) {
        return;
      }

      setState(() {
        _fotoEncomenda = bytes;
      });

      FeedbackUtils.showSuccess(
        context: context,
        title: 'Foto Capturada',
        message: 'Foto da encomenda capturada com sucesso!',
      );
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Processar',
        message: 'Erro ao processar foto',
        errorDetails: e.toString(),
      );
    } finally {
      setState(() {
        _loadingFotoEncomenda = false;
      });
    }
  }

  void _limparFormularioEncomenda() {
    setState(() {
      _selectedUnidadesEncomenda = [];
      _selectedUnidadeEncomenda = null;
      _tipoEncomendaSelecionado = null;
      _localEntregaSelecionado = null;
      _fotoEncomenda = null;
      _fotoEncomendaEntrega = null;
      _loadingFotoEncomenda = false;
      _codigoBarrasEncomendaController.clear();
      _identificacaoInternaEncomendaController.clear();
      _observacaoEncomendaController.clear();
    });
  }

  /// Gera identificação interna aleatória de 6 dígitos
  String _gerarIdentificacaoInterna() {
    final random = Random();
    return (random.nextInt(900000) + 100000).toString(); // 100000-999999
  }

  /// Imprime etiqueta via browser print (impressora térmica Zebra)
  void _imprimirEtiquetaEncomenda({
    required String identificacaoInterna,
    required String torre,
    required String unidade,
  }) {
    // Gerar código de barras Code128 em SVG
    final barcodeSvg = _gerarBarcodeSvg(identificacaoInterna);

    final conteudoHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
  @page {
    margin: 2mm;
    size: 80mm auto;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: Arial, Helvetica, sans-serif;
    width: 76mm;
    padding: 3mm;
    text-align: center;
  }
  .id-interna {
    font-size: 28px;
    font-weight: bold;
    letter-spacing: 4px;
    margin-bottom: 4px;
  }
  .torre-unidade {
    font-size: 20px;
    font-weight: bold;
    margin-bottom: 6px;
    border-top: 1px solid #000;
    border-bottom: 1px solid #000;
    padding: 4px 0;
  }
  .barcode-container {
    margin: 4px auto;
  }
  .barcode-container svg {
    width: 60mm;
    height: 18mm;
  }
  .label-id {
    font-size: 10px;
    color: #555;
    margin-bottom: 2px;
  }
</style>
</head>
<body>
  <div class="label-id">IDENTIFICAÇÃO INTERNA</div>
  <div class="id-interna">$identificacaoInterna</div>
  <div class="torre-unidade">$torre - $unidade</div>
  <div class="barcode-container">$barcodeSvg</div>
</body>
</html>
''';

    // Criar Blob URL com o HTML e abrir para impressão
    final blob = html.Blob([conteudoHtml], 'text/html');
    final blobUrl = html.Url.createObjectUrlFromBlob(blob);

    final printWindow = html.window.open(blobUrl, '_blank');

    // Aguardar renderização antes de imprimir
    Future.delayed(const Duration(milliseconds: 500), () {
      // Usar JS interop via dart:html para chamar print na janela
      (printWindow as dynamic).print();
      // Fechar janela e revogar URL após impressão
      Future.delayed(const Duration(seconds: 2), () {
        (printWindow as dynamic).close();
        html.Url.revokeObjectUrl(blobUrl);
      });
    });
  }

  /// Gera SVG de código de barras Code128B
  String _gerarBarcodeSvg(String texto) {
    // Code128B encoding
    const code128B = <String, List<int>>{
      ' ': [2, 1, 2, 2, 2, 2],
      '!': [2, 2, 2, 1, 2, 2],
      '"': [2, 2, 2, 2, 2, 1],
      '#': [1, 2, 1, 2, 2, 3],
      '\$': [1, 2, 1, 3, 2, 2],
      '%': [1, 3, 1, 2, 2, 2],
      '&': [1, 2, 2, 2, 1, 3],
      "'": [1, 2, 2, 3, 1, 2],
      '(': [1, 3, 2, 2, 1, 2],
      ')': [2, 2, 1, 2, 1, 3],
      '*': [2, 2, 1, 3, 1, 2],
      '+': [2, 3, 1, 2, 1, 2],
      ',': [1, 1, 2, 2, 3, 2],
      '-': [1, 2, 2, 1, 3, 2],
      '.': [1, 2, 2, 2, 3, 1],
      '/': [1, 1, 3, 2, 2, 2],
      '0': [1, 2, 3, 1, 2, 2],
      '1': [1, 2, 3, 2, 2, 1],
      '2': [2, 2, 3, 2, 1, 1],
      '3': [2, 2, 1, 1, 3, 2],
      '4': [2, 2, 1, 2, 3, 1],
      '5': [2, 1, 3, 2, 1, 2],
      '6': [2, 2, 3, 1, 1, 2],
      '7': [3, 1, 2, 1, 3, 1],
      '8': [3, 1, 1, 2, 2, 2],
      '9': [3, 2, 1, 1, 2, 2],
      ':': [3, 2, 1, 2, 2, 1],
      ';': [3, 1, 2, 2, 1, 2],
      '<': [3, 2, 2, 1, 1, 2],
      '=': [3, 2, 2, 2, 1, 1],
      '>': [2, 1, 2, 1, 2, 3],
      '?': [2, 1, 2, 3, 2, 1],
      '@': [2, 3, 2, 1, 2, 1],
      'A': [1, 1, 1, 3, 2, 3],
      'B': [1, 3, 1, 1, 2, 3],
      'C': [1, 3, 1, 3, 2, 1],
      'D': [1, 1, 2, 3, 2, 3],
      'E': [1, 3, 2, 1, 2, 3],
      'F': [1, 3, 2, 3, 2, 1],
      'G': [2, 1, 1, 3, 2, 3],
      'H': [2, 3, 1, 1, 2, 3],
      'I': [2, 3, 1, 3, 2, 1],
      'J': [1, 1, 2, 3, 3, 2],
      'K': [1, 3, 2, 1, 3, 2],
      'L': [1, 3, 2, 3, 3, 0],
      'M': [1, 1, 3, 2, 2, 3],
      'N': [1, 3, 3, 2, 2, 1],
      'O': [1, 3, 3, 2, 2, 1],
      'P': [2, 1, 3, 2, 2, 3],
      'Q': [2, 3, 3, 2, 2, 1],
      'R': [2, 1, 2, 3, 3, 2],
      'S': [3, 3, 1, 1, 2, 2],
      'T': [3, 3, 1, 2, 2, 1],
      'U': [3, 3, 2, 1, 1, 2],
      'V': [3, 3, 2, 2, 1, 1],
      'W': [3, 1, 3, 1, 2, 2],
      'X': [3, 2, 3, 1, 2, 1],
      'Y': [3, 2, 3, 2, 1, 1],
      'Z': [1, 2, 1, 1, 2, 3],
    };

    // Abordagem simplificada: gerar barras usando padrão visual
    // Para números de 6 dígitos, usar Code128B
    final startCode = [2, 1, 1, 2, 3, 2]; // Start Code B (valor 104)
    final stopCode = [2, 3, 3, 1, 1, 1, 2]; // Stop

    List<List<int>> patterns = [startCode];
    int checksum = 104;

    for (int i = 0; i < texto.length; i++) {
      final char = texto[i];
      final valor = char.codeUnitAt(0) - 32;
      final key = char;
      if (code128B.containsKey(key)) {
        patterns.add(code128B[key]!);
      } else {
        // Fallback para '0'
        patterns.add(code128B['0']!);
      }
      checksum += valor * (i + 1);
    }

    // Checksum
    final checksumVal = checksum % 103;
    // Mapear checksum para padrão (simplificado - usar tabela)
    final checksumChar =
        checksumVal + 32 < 127 ? String.fromCharCode(checksumVal + 32) : ' ';
    if (code128B.containsKey(checksumChar)) {
      patterns.add(code128B[checksumChar]!);
    }
    patterns.add(stopCode);

    // Gerar SVG
    final buffer = StringBuffer();
    double x = 0;
    const barWidth = 1.5;

    for (final pattern in patterns) {
      bool isBar = true;
      for (final width in pattern) {
        if (isBar) {
          buffer.write(
              '<rect x="$x" y="0" width="${width * barWidth}" height="60" fill="black"/>');
        }
        x += width * barWidth;
        isBar = !isBar;
      }
    }

    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $x 60" preserveAspectRatio="xMidYMid meet">$buffer</svg>';
  }

  // Funçao para enviar encomenda usando API do backup
  Future<void> _registrarEncomenda() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString('tokensessao_txt');
    final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
        ? decryptText(encrypted)
        : '';
    final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
    final usuarioId =
        (encryptedUsuarioId.isNotEmpty) ? decryptText(encryptedUsuarioId) : '';
    final usuariodeId = int.tryParse(usuarioId) ?? 0;
    final tipoSelecionado = _tipoEncomendaSelecionado != null
        ? _tipoEncomendaSelecionado!['descricao'] ?? ''
        : '';
    final fotoBase64 =
        _fotoEncomenda != null ? base64Encode(_fotoEncomenda!) : '';
    final machineIP = await _getMachineIP();
    final condominioIdRaw = await ApiConfig.getCondominioId();
    final condominioId = int.tryParse(condominioIdRaw) ?? 0;
    final identificacaoInterna =
        _identificacaoInternaEncomendaController.text.trim();

    final url = Uri.parse(ApiConfig.getEndpoint('encomendas', 'registrar'));

    // Enviar para cada unidade selecionada (multiselect)
    int sucessos = 0;
    int? lastProtocoloId;
    Uint8List? fotoParaUpload = _fotoEncomendaEntrega;

    for (final unidade in _selectedUnidadesEncomenda) {
      final usuarioparaId = unidade['usuario_id']?.toString() ?? '';
      final payload = {
        "condominio_id": condominioId,
        "usuariode_id": usuariodeId,
        "usuariopara": usuarioparaId,
        "avisocategoria_id": 21,
        "sms_flg": "N",
        "titulo": "Entrega de encomenda",
        "texto": tipoSelecionado,
        "local": (_localEntregaSelecionado != null)
            ? (_localEntregaSelecionado!["descricao"]?.toString() ?? "")
            : "",
        "codigobarra": _codigoBarrasEncomendaController.text,
        "depara_id": identificacaoInterna,
        "ip": machineIP,
        "fotobase64": fotoBase64,
      };

      print('Payload (unidade ${unidade['usuario_id']}): $payload');

      try {
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $tokenSessao',
          },
          body: jsonEncode(payload),
        );

        print('Status Code: ${response.statusCode}');
        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          int? protocoloId;
          if (responseData['protocolo'] != null) {
            protocoloId = int.tryParse(responseData['protocolo'].toString());
          } else if (responseData['id'] != null) {
            protocoloId = int.tryParse(responseData['id'].toString());
          }
          lastProtocoloId = protocoloId;
          sucessos++;
        }
      } catch (e) {
        print('Erro ao registrar para unidade ${unidade['usuario_id']}: $e');
      }
    } // fim loop unidades

    // Upload da foto (uma vez, após enviar para todas as unidades)
    if (lastProtocoloId != null && fotoParaUpload != null) {
      await _uploadFotoEncomenda(lastProtocoloId, fotoParaUpload);
    }

    if (sucessos > 0) {
      // Limpar formulário
      _limparFormularioEncomenda();

      setState(() {
        _feedbackMessageRegistroEncomenda = sucessos == 1
            ? 'Encomenda registrada com sucesso!'
            : '$sucessos encomendas registradas com sucesso!';
      });

      // Limpar mensagem após 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _feedbackMessageRegistroEncomenda = '';
          });
        }
      });

      // Recarregar lista de entregas
      await _fetchEntregas();
    } else {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Registrar',
        message: 'Não foi possível registrar a encomenda.',
      );
    }
  }

  Future<void> _uploadFotoEntregaPessoa(
      String usuarioId, Uint8List fotoBytes) async {
    await EncomendaFetchService.uploadFotoPessoa(usuarioId, fotoBytes);
  }

  Future<void> _uploadFotoEncomenda(
      int protocoloId, Uint8List fotoBytes) async {
    await EncomendaFetchService.uploadFotoEncomenda(protocoloId, fotoBytes);
  }

  // Obter IP da máquina
  Future<String> _getMachineIP() async {
    try {
      if (kIsWeb) {
        final response = await http.get(
          Uri.parse('https://api.ipify.org'),
        );
        if (response.statusCode == 200) {
          return response.body.trim();
        }
      }
      return '127.0.0.1';
    } catch (e) {
      return '127.0.0.1';
    }
  }
  // Widget para grupo de ícones transparentes (autobaixa e pesquisar)
}

// Painel simples para seleçao de convidados (apenas para entrada)

// Painel lateral Locaçao Temporária (simplificado, sem dependências externas)

// Funá§ões auxiliares para agendamentos
bool _convidadoTemFoto(Map<String, dynamic> convidado) {
  // Verificar se o convidado tem foto (pode ser determinado por algum campo na API)
  // Por enquanto, assumimos que se tem reservaconvidado_id, pode ter foto
  return convidado['reservaconvidado_id'] != null;
}

Future<void> _mostrarFotoConvidado(
    Map<String, dynamic> convidado, BuildContext context) async {
  // Buscar foto do convidado via API
  String? fotoBase64;
  try {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

    final url = Uri.parse('${ApiConfig.gateUrl}/foto');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $tokenSessao',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'reservaconvidado_id': convidado['reservaconvidado_id'],
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['fotobase64'] != null) {
        fotoBase64 = responseData['fotobase64'];
      } else if (responseData['data'] != null &&
          responseData['data']['fotobase64'] != null) {
        fotoBase64 = responseData['data']['fotobase64'];
      } else if (responseData['data'] != null &&
          responseData['data']['foto'] != null) {
        fotoBase64 = responseData['data']['foto'];
      } else if (responseData['foto'] != null) {
        fotoBase64 = responseData['foto'];
      }
    }
  } catch (e) {
    print('Erro ao buscar foto do convidado: $e');
  }

  // Mostrar dialog com a foto
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(
            'Foto de ${convidado['nome'] ?? convidado['convidado_txt'] ?? 'Convidado'}'),
        content: fotoBase64 != null
            ? () {
                final bytes = _safeBase64Decode(fotoBase64);
                if (bytes != null) {
                  return Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: MemoryImage(bytes),
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                }
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 80,
                    color: Colors.grey,
                  ),
                );
              }()
            : Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person,
                  size: 80,
                  color: Colors.grey,
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fechar'),
          ),
        ],
      );
    },
  );
}

// Funçao auxiliar para atualizar facial (sem estado de loading, pois pode ser chamada de diferentes contextos)
Future<void> _atualizarFacialGlobal(
    Map<String, dynamic> convidado, BuildContext context) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

    final condominioId = await ApiConfig.getCondominioId();

    final payload = {
      'condominio_id':
          convidado['condominio_id'] ?? int.tryParse(condominioId) ?? 0,
      'id': convidado['reservaconvidado_id'] ?? convidado['sequencia'] ?? 0,
      'tiporegra': 459,
      'tipoequipamento_id': 1126,
    };

    final url = Uri.parse('${ApiConfig.gateUrl}/dispositivoatualizacao');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $tokenSessao',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode == 200) {
      FeedbackUtils.showSuccess(
        context: context,
        title: 'Sucesso',
        message: 'Atualizaçao facial realizada com sucesso!',
      );
    } else {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Erro na atualizaçao facial',
      );
    }
  } catch (e) {
    FeedbackUtils.showError(
      context: context,
      title: 'Erro',
      message: 'Erro: $e',
    );
  }
}

// Seletor customizado de tipo documento com lista interna

// Painel lateral para entrada de convidado

// Painel lateral para ediçao de convidado

// Widget stateful para câmera com vídeo ao vivo

// Widget personalizado para exibir vídeo HTML

//-----------------------------//
// Modal de seleçao de espaá§os sociais
//-----------------------------//

// Modal de convidados

// Lista fixa de tipos de agendamento
const List<Map<String, String>> tiposAgendamentoFixos = [
  {'descricao': 'Locaçao Temporária', 'codigo': 'H'},
  {'descricao': 'Visitante', 'codigo': 'A'},
  {'descricao': 'Prestador', 'codigo': 'P'},
  {'descricao': 'Espaá§o', 'codigo': 'S'},
  {'descricao': 'Reforma', 'codigo': 'R'},
  {'descricao': 'Mudaná§a', 'codigo': 'M'},
];

// Helper para mostrar unidade de forma simples
String unidadeLabelSimples(Map<String, dynamic> unidade) {
  final numero = (unidade['unidade'] ?? '').toString();
  final predio = (unidade['predio'] ?? '').toString();

  // Formatar prédio corretamente: se for apenas uma letra, adicionar "Torre"
  String predioFormatado = predio;
  if (predio.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(predio)) {
    predioFormatado = 'Torre ${predio.toUpperCase()}';
    print(' Prédio formatado: "$predio" -> "$predioFormatado"');
  } else if (predio.isNotEmpty && !predio.toLowerCase().startsWith('torre')) {
    // Se não comeá§a com "torre", adicionar
    predioFormatado = 'Torre $predio';
    print(' Prédio formatado: "$predio" -> "$predioFormatado"');
  }

  if (numero.isNotEmpty && predio.isNotEmpty) {
    final resultado = '$numero - $predioFormatado';
    print(' Unidade formatada: $resultado');
    return resultado;
  } else if (numero.isNotEmpty) {
    return numero;
  }

  final unidadeMostra =
      (unidade['unidade_mostra'] ?? unidade['titulo_txt'] ?? '').toString();

  // Aplicar a mesma formataçao na unidade_mostra se for apenas uma letra
  String unidadeMostraFormatada = unidadeMostra;
  if (unidadeMostra.length == 1 &&
      RegExp(r'^[a-zA-Z]$').hasMatch(unidadeMostra)) {
    unidadeMostraFormatada = 'Torre ${unidadeMostra.toUpperCase()}';
    print(
        ' Unidade mostra formatada: "$unidadeMostra" -> "$unidadeMostraFormatada"');
  }

  // Truncar texto muito longo para evitar problemas de layout em telas menores
  if (unidadeMostraFormatada.length > 20) {
    return '${unidadeMostraFormatada.substring(0, 17)}...';
  }

  return unidadeMostraFormatada;
}

// Helper para mostrar "Torre <letra> - Nome do morador" quando possível
String unidadeLabelComMorador(Map<String, dynamic> unidade) {
  final numero = (unidade['unidade'] ?? '').toString();
  final predio = (unidade['predio'] ?? unidade['torre'] ?? '').toString();
  String torreFmt = '';
  if (predio.isNotEmpty) {
    if (predio.length == 1 && RegExp(r'^[a-zA-Z]$').hasMatch(predio)) {
      torreFmt = 'Torre ${predio.toUpperCase()}';
    } else if (!predio.toLowerCase().startsWith('torre')) {
      torreFmt = 'Torre $predio';
    } else {
      torreFmt = predio;
    }
  }

  final nome = (unidade['nome_morador'] ??
          unidade['morador'] ??
          unidade['pessoa'] ??
          unidade['nome'] ??
          '')
      .toString();

  // Formato: "Nome / Número - Torre" (ex: "Alessandro / 11 - Torre A")
  final unidadePart = numero.isNotEmpty && torreFmt.isNotEmpty
      ? '$numero - $torreFmt'
      : numero.isNotEmpty
          ? numero
          : torreFmt;

  if (nome.isNotEmpty && unidadePart.isNotEmpty) {
    return '$nome / $unidadePart';
  }
  if (nome.isNotEmpty) return nome;
  if (unidadePart.isNotEmpty) return unidadePart;

  return unidadeLabelSimples(unidade);
}

// Helper para decodificar base64 com seguraná§a (evita ImageCodecException)
Uint8List? _safeBase64Decode(String? base64String) {
  if (base64String == null || base64String.isEmpty) {
    return null;
  }

  try {
    // Remove prefixo data:image se existir
    String cleanBase64 = base64String;
    if (base64String.startsWith('data:image')) {
      final parts = base64String.split(',');
      if (parts.length > 1) {
        cleanBase64 = parts[1];
      }
    }

    // Remove espaá§os em branco
    cleanBase64 = cleanBase64.trim();

    // Valida se é uma string base64 válida
    if (cleanBase64.isEmpty ||
        !RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(cleanBase64)) {
      return null;
    }

    // Tenta decodificar
    final decoded = base64Decode(cleanBase64);

    // Verifica se o resultado tem tamanho mínimo razoável para uma imagem
    // (pelo menos 100 bytes para evitar dados corrompidos)
    if (decoded.isEmpty || decoded.length < 100) {
      return null;
    }

    // Verifica se os primeiros bytes correspondem a um formato de imagem válido
    // JPEG: FF D8 FF
    // PNG: 89 50 4E 47
    // GIF: 47 49 46
    if (decoded.length >= 3) {
      final isJPEG =
          decoded[0] == 0xFF && decoded[1] == 0xD8 && decoded[2] == 0xFF;
      final isPNG = decoded.length >= 4 &&
          decoded[0] == 0x89 &&
          decoded[1] == 0x50 &&
          decoded[2] == 0x4E &&
          decoded[3] == 0x47;
      final isGIF =
          decoded[0] == 0x47 && decoded[1] == 0x49 && decoded[2] == 0x46;

      if (!isJPEG && !isPNG && !isGIF) {
        // Ná£o é um formato de imagem reconhecido
        return null;
      }
    }

    return decoded;
  } catch (e) {
    // Retorna null se houver erro na decodificaçao
    return null;
  }
}

// === FUNá‡ão HELPER PARA CONVERTER E VALIDAR IDs ===
int? _convertToValidId(dynamic value) {
  if (value == null) {
    return null;
  }

  int? id;
  if (value is int) {
    id = value;
  } else if (value is double) {
    id = value.toInt();
  } else if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      id = parsed;
    } else {}
  } else if (value is num) {
    id = value.toInt();
  } else {}

  return (id != null && id > 0) ? id : null;
}

// Widget do painel lateral para resultados da busca de entradas

// Painel lateral para exibir detalhes da encomenda entregue
