import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/theme/icon_colors.dart';
import '../../core/services/feedback_utils.dart';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../core/config/api_config.dart';
import '../../core/utils/ui_standards.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/custom_imput.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../shared/widgets/inline_feedback.dart';
import '../../shared/widgets/inline_period_picker.dart';

// Utilizando padrões globais (isDarkMode, getBackgroundColor, etc) do dashboard ou ui_standards

// Grupo de ícones transparentes genérico
Widget _buildTransparentIconGroup(
    BuildContext context, List<Map<String, dynamic>> actions) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final iconColor = isDark ? Colors.white : Colors.black;
  final dividerColor = iconColor.withValues(alpha: 0.3);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: dividerColor.withValues(alpha: 0.15), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(actions.length * 2 - 1, (index) {
        if (index % 2 == 0) {
          // Ícone
          final actionIndex = index ~/ 2;
          final action = actions[actionIndex];
          return _buildGroupedIcon(
            action['icon'] as IconData,
            action['color'] as Color? ?? iconColor,
            action['onPressed'] as VoidCallback?,
            action['tooltip'] as String,
            isLoading: action['isLoading'] as bool? ?? false,
            key: action['key'] as Key?,
          );
        } else {
          // Divisor
          return _buildDivider(dividerColor);
        }
      }),
    ),
  );
}

Widget _buildGroupedIcon(
    IconData icon, Color color, VoidCallback? onPressed, String tooltip,
    {bool isLoading = false,
    bool isOpaque = false,
    double? iconSize,
    Key? key}) {
  final tooltipMessage = isOpaque ? '$tooltip (desabilitado)' : tooltip;

  return Tooltip(
    key: key,
    message: tooltipMessage,
    preferBelow: false,
    enableFeedback: true,
    waitDuration: isOpaque
        ? const Duration(milliseconds: 100)
        : const Duration(milliseconds: 300),
    decoration: BoxDecoration(
      color: isOpaque ? Colors.grey.shade800 : const Color(0xFF10133E),
      borderRadius: BorderRadius.circular(8),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    textStyle: const TextStyle(
      color: Colors.white,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    child: MouseRegion(
      cursor: isLoading
          ? SystemMouseCursors.basic
          : (onPressed == null || isOpaque
              ? SystemMouseCursors.forbidden
              : SystemMouseCursors.click),
      child: GestureDetector(
        onTap: (isLoading || isOpaque) ? null : onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: isOpaque
              ? BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                )
              : null,
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(
                  icon,
                  color: isLoading
                      ? color.withValues(alpha: 0.5)
                      : (isOpaque ? color.withValues(alpha: 0.35) : color),
                  size: iconSize ?? (isOpaque ? 24 : 28),
                ),
        ),
      ),
    ),
  );
}

Widget _buildDivider(Color color) {
  return Container(
    width: 1,
    height: 28,
    color: color,
  );
}

// Componente RangeCalendarDialog estilo ShadCalendar
class RangeCalendarDialog extends StatefulWidget {
  final Function(DateTime startDate, DateTime endDate) onRangeSelected;

  const RangeCalendarDialog({
    super.key,
    required this.onRangeSelected,
  });

  @override
  State<RangeCalendarDialog> createState() => _RangeCalendarDialogState();
}

class _RangeCalendarDialogState extends State<RangeCalendarDialog> {
  DateTimeRange? selectedRange;
  final DateTime _focusedDay = DateTime.now();
  final DateTime _firstDay = DateTime(2020);
  final DateTime _lastDay = DateTime.now().add(const Duration(days: 90));

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selecionar Período',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400, // Menos pesado
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CalendarDatePicker2(
                config: CalendarDatePicker2Config(
                  calendarType: CalendarDatePicker2Type.range,
                  firstDate: _firstDay,
                  lastDate: _lastDay,
                  currentDate: DateTime.now(),
                  selectedDayHighlightColor: const Color(0xFF684F8E),
                  dayTextStyle: const TextStyle(fontSize: 14),
                  weekdayLabelTextStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.black54,
                  ),
                  controlsTextStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  yearTextStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: selectedRange != null
                    ? [selectedRange!.start, selectedRange!.end]
                    : [],
                onValueChanged: (dates) {
                  if (dates.length == 2) {
                    setState(() {
                      selectedRange = DateTimeRange(
                        start: dates[0],
                        end: dates[1],
                      );
                    });
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: selectedRange != null
                      ? () {
                          widget.onRangeSelected(
                              selectedRange!.start, selectedRange!.end);
                          Navigator.of(context).pop();
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ChavesModal extends StatefulWidget {
  final VoidCallback onClose;
  const ChavesModal({super.key, required this.onClose});

  @override
  State<ChavesModal> createState() => _ChavesModalState();
}

class _ChavesModalState extends State<ChavesModal> {
// Utilizando padrões globais (isDarkMode, getBackgroundColor, etc) de ui_standards

  // Controllers
  final _chaveController = TextEditingController();
  final _unidadeController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _filtroChaveController = TextEditingController();
  final _filtroUnidadeController = TextEditingController();

  // Estados
  bool _loading = false;
  bool _loadingHistorico = false;
  DateTime? _dataInicioDevolvidos;
  DateTime? _dataFimDevolvidos;
  int _quantidadeDevolver = 0; // 👇 ADICIONE ESTA LINHA

  // Dados
  List<Map<String, dynamic>> _chavesDisponiveis = [];
  List<Map<String, dynamic>> _unidades = [];
  List<Map<String, dynamic>> _historico = [];
  Map<String, dynamic>? _chaveSelecionada;
  Map<String, dynamic>? _unidadeSelecionada;
  Map<String, dynamic>? _moradorSelecionado;
  String _selectedTab = 'devolver';

  // Variáveis para controle da devolução inline
  int? _expandedReservaId;
  Map<String, dynamic>? _reservaEmProcesso;
  bool _isDevolucaoOutraPessoa = false;
  Map<String, dynamic>? _pessoaOutraDevolucao;

  // Key para feedback contextual
  final GlobalKey _registrarChaveKey = GlobalKey();
  String? _feedbackMessage;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();
    _carregarChavesDisponiveis();
    _carregarUnidades();
    _carregarHistorico(statusId: 3); // Carregar chaves com status 3 por padrão
    _carregarChavesParaDevolver();
  }

  @override
  void dispose() {
    _chaveController.dispose();
    _unidadeController.dispose();
    _observacaoController.dispose();
    _filtroChaveController.dispose();
    _filtroUnidadeController.dispose();
    super.dispose();
  }

  Future<void> _carregarChavesDisponiveis() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'disponiveis')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body:
            jsonEncode({'condominio_id': condominioId, 'flg_disponivel': 'S'}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _chavesDisponiveis =
              List<Map<String, dynamic>>.from(data['data'] ?? []);
        });
        print('Chaves disponíveis: ${_chavesDisponiveis.length}');
      }
    } catch (e) {
      print('Erro ao carregar chaves: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _carregarUnidades() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'unidades')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({'condominio_id': condominioId, "aba": "UN"}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _unidades =
              List<Map<String, dynamic>>.from(data['data']['unidades'] ?? []);
        });
        print('Unidades carregadas: ${_unidades.length}');
      }
    } catch (e) {
      print('Erro ao carregar unidades: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _carregarHistorico(
      {String? dtIni, String? dtFim, int? statusId}) async {
    setState(() => _loadingHistorico = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      // Formatar data atual se não fornecida
      final now = DateTime.now();
      final dataAtual =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      final payload = {
        'apto_id': -1,
        'condominio_id': int.parse(condominioId),
        'dt_fim': dtFim ?? dataAtual,
        'dt_ini': dtIni ?? dataAtual,
        'espacopublico_id': -1,
        'status_id': statusId ?? 3, // 3 para status padrão
      };

      print('DEBUG - API chavehistorico payload: ${jsonEncode(payload)}');

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'historico')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _historico = List<Map<String, dynamic>>.from(data['data'] ?? []);
          // 👇 ADICIONE ESTA VALIDAÇÃO AQUI
          if (statusId == 3 || statusId == null) {
            _quantidadeDevolver = _historico.length;
          }
        });
      } else {
        print('Erro ao carregar histórico: ${response.statusCode}');
      }
    } catch (e) {
      print('Erro ao carregar histórico: $e');
    } finally {
      setState(() => _loadingHistorico = false);
    }
  }

  Future<void> _carregarHistoricoDevolvidos() async {
    if (_dataInicioDevolvidos == null || _dataFimDevolvidos == null) {
      // Se não há datas definidas, carrega com status 4 (devolvidas) sem filtro de data
      await _carregarHistorico(statusId: 4);
      return;
    }

    // Formatar datas para o formato esperado pela API
    final dtIni =
        '${_dataInicioDevolvidos!.day.toString().padLeft(2, '0')}/${_dataInicioDevolvidos!.month.toString().padLeft(2, '0')}/${_dataInicioDevolvidos!.year}';
    final dtFim =
        '${_dataFimDevolvidos!.day.toString().padLeft(2, '0')}/${_dataFimDevolvidos!.month.toString().padLeft(2, '0')}/${_dataFimDevolvidos!.year}';

    await _carregarHistorico(dtIni: dtIni, dtFim: dtFim, statusId: 4);
  }

  // Função para listar chaves a serem devolvidas
  Future<void> _carregarChavesParaDevolver() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';
      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'disponiveis')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'condominio_id': condominioId,
          'flg_disponivel': 'N',
        }),
      );
      if (response.statusCode == 200) {
        // Data loaded but not used
      }
    } catch (e) {
      print('Erro ao carregar chaves para devolução: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String> _getPublicIp() async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.getExternalUrl('ipCheck')}?format=json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['ip'] ?? '';
      }
    } catch (e) {
      print('Erro ao obter IP: $e');
    }
    return '';
  }

  Future<void> _registrarEntrega() async {
    if (_chaveSelecionada == null || _unidadeSelecionada == null) {
      setState(() {
        _feedbackMessage = 'Selecione uma chave e uma unidade';
        _feedbackColor = Colors.red;
      });
      return;
    }
    setState(() {
      _loading = true;
      _feedbackMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
      final usuarioId = (encryptedUsuarioId.isNotEmpty)
          ? decryptText(encryptedUsuarioId)
          : '';
      final usuarioReservaId = _unidadeSelecionada?['usuario_id'];
      final ip = await _getPublicIp();
      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'registrarEntrega')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'espacopublico_id': _chaveSelecionada!['id'],
          'StatusReserva_Id': 3,
          'usuarioreserva_id': usuarioReservaId,
          'usuariosolicita_id': usuarioId,
          'Dt_Reserva_Ini': DateTime.now().toIso8601String(),
          'Dt_Reserva_Fim': DateTime.now().toIso8601String(),
          'motivo_convite': _observacaoController.text.isNotEmpty
              ? _observacaoController.text
              : 'Entrega de chave',
          'IP': ip
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _feedbackMessage = 'Chave registrada com sucesso!';
          _feedbackColor = Colors.green;
        });
        _limparFormulario();
        _carregarChavesDisponiveis();
        _carregarHistorico();
        _carregarChavesParaDevolver();
      } else {
        setState(() {
          _feedbackMessage = 'Erro ao registrar chave';
          _feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      print('Erro ao registrar entrega: $e');
      setState(() {
        _feedbackMessage = 'Erro de conexão com o servidor';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _iniciarDevolucao(Map<String, dynamic> item) async {
    // Se já estiver expandido, fecha
    if (_expandedReservaId == item['reserva_id']) {
      setState(() {
        _expandedReservaId = null;
        _reservaEmProcesso = null;
        _isDevolucaoOutraPessoa = false;
        _pessoaOutraDevolucao = null;
      });
      return;
    }

    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      // Buscar dados da reserva
      final responseHistorico = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'historico')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          'condominio_id': int.parse(condominioId),
        }),
      );

      if (responseHistorico.statusCode == 200) {
        final dataHistorico = jsonDecode(responseHistorico.body);
        final historico =
            List<Map<String, dynamic>>.from(dataHistorico['data'] ?? []);

        // Encontrar a reserva específica
        final reservaHistorico = historico.firstWhere(
          (hItem) => hItem['reserva_id'] == item['reserva_id'],
          orElse: () => {},
        );

        if (reservaHistorico.isNotEmpty) {
          setState(() {
            _expandedReservaId = item['reserva_id'];
            _reservaEmProcesso = {
              'reservaId': reservaHistorico['reserva_id'],
              'retiradoPorId': reservaHistorico['retirado_porId'],
              'convidadoTxt': item['nome_quem_retirou'] ?? '',
            };
            _isDevolucaoOutraPessoa = false;
            _pessoaOutraDevolucao = null;
          });
        } else {
          FeedbackUtils.showError(
            context: context,
            title: 'Reserva Não Encontrada',
            message: 'Reserva não encontrada no histórico',
          );
        }
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Buscar',
          message: 'Erro ao buscar histórico da chave',
          errorDetails: 'Status: ${responseHistorico.statusCode}',
        );
      }
    } catch (e) {
      print('Erro ao buscar dados da reserva: $e');
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Processar',
        message: 'Erro ao processar devolução',
        errorDetails: e.toString(),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _executarDevolucao(
      int reservaId, int usuarioReservaId, String convidadoTxt) async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      // Formatar data no formato dd/mm/yyyy hh:mm
      final now = DateTime.now();
      final dataFormatada =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      final payload = {
        'condominio_id': int.parse(condominioId),
        'reserva_id': reservaId,
        'usuarioReserva_Id': usuarioReservaId,
        'dt_Reserva_Fim': dataFormatada,
        'convidado_txt': convidadoTxt,
        'usuarioCancela_Id': null,
        'statusReserva_Id': 4,
      };

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('chaves', 'registrarDevolucao')),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _feedbackMessage = 'Chave devolvida com sucesso!';
          _feedbackColor = Colors.green;
        });
        _carregarHistorico();
        _carregarChavesParaDevolver();
      } else {
        setState(() {
          _feedbackMessage = 'Erro ao devolver chave';
          _feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      print('Erro ao devolver chave: $e');
      setState(() {
        _feedbackMessage = 'Erro de conexão ao devolver';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _limparFormulario() {
    _chaveController.clear();
    _unidadeController.clear();
    _observacaoController.clear();
    _chaveSelecionada = null;
    _unidadeSelecionada = null;
  }

  @override
  Widget build(BuildContext context) {
    // ADICIONADO: Detectar se é uma tela de celular
    final isMobile = MediaQuery.of(context).size.width < 800;

    return Container(
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
      child: Column(
        children: [
          ScreenHeader(
            icon: Icons.vpn_key,
            title: 'Chaves',
            onClose: widget.onClose,
          ),
          Expanded(
            child: isMobile
                // 📱 NO MOBILE: Usa Scroll e remove os Expanded
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildNovaChavePanel(), // Sem Expanded
                        const SizedBox(height: 16),
                        _buildHistoricoPanel(
                            isMobile: true), // Sem Expanded e passa flag
                      ],
                    ),
                  )
                // 💻 NO DESKTOP: Mantém lado a lado e com Expanded
                : Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildNovaChavePanel()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildHistoricoPanel(isMobile: false)),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovaChavePanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border.all(color: getBorderColor(context), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_key, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('Nova Chave', style: AppTextStyles.title(context)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: _chaveSelecionada != null
                    ? (_chaveSelecionada!['chave_ds'] ??
                        _chaveSelecionada!['nome'] ??
                        '')
                    : '',
              ),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _chavesDisponiveis;
                }
                return _chavesDisponiveis.where((Map<String, dynamic> option) {
                  final label =
                      (option['chave_ds'] ?? option['nome'] ?? '').toString();
                  return label
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) =>
                  (option['chave_ds'] ?? option['nome'] ?? '').toString(),
              onSelected: (Map<String, dynamic> value) {
                setState(() {
                  _chaveSelecionada = value;
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return CharacterCounterField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  maxLength: 50,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Chave',
                  ).copyWith(
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _chaveSelecionada = null;
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
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> option =
                              options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
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
                                (option['chave_ds'] ??
                                        option['nome'] ??
                                        'Sem nome')
                                    .toString(),
                                style: TextStyle(color: getTextColor(context)),
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
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: _unidadeSelecionada != null
                    ? (_unidadeSelecionada!['unidade_mostra'] ?? '')
                    : '',
              ),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _unidades;
                }
                return _unidades.where((Map<String, dynamic> option) {
                  return (option['unidade_mostra'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) =>
                  (option['unidade_mostra'] ?? '').toString(),
              onSelected: (Map<String, dynamic> value) {
                setState(() {
                  _unidadeSelecionada = value;
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return CharacterCounterField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  maxLength: 50,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Pessoa',
                  ).copyWith(
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _unidadeSelecionada = null;
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
                        itemBuilder: (BuildContext context, int index) {
                          final Map<String, dynamic> option =
                              options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.all(16.0),
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
                                (option['unidade_mostra'] ?? 'Sem unidade')
                                    .toString(),
                                style: TextStyle(color: getTextColor(context)),
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
          const SizedBox(height: 12),
          CustomInput(
            hintText: 'Observação',
            maxLines: 4,
            maxLength: 200,
            controller: _observacaoController,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            // ADICIONADO: Scroll horizontal para proteger os botões no mobile
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _buildTransparentIconGroup(
                context,
                [
                  {
                    'icon': Symbols.ink_eraser,
                    'color': IconColors.delete(context),
                    'tooltip': 'Limpar formulário',
                    'onPressed': _limparFormulario,
                  },
                  {
                    'key': _registrarChaveKey,
                    'icon': Symbols.send,
                    'color': Colors.green,
                    'tooltip': 'Registrar entrega',
                    'onPressed': _registrarEntrega,
                    'isLoading': _loading,
                  },
                ],
              ),
            ),
          ),
          InlineFeedbackWidget(
            message: _feedbackMessage,
            color: _feedbackColor,
          ),
        ],
      ),
    );
  }

// Modificado para aceitar o parâmetro isMobile
  Widget _buildHistoricoPanel({bool isMobile = false}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border.all(color: getBorderColor(context), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // No mobile, a Column não pode ter tamanho ilimitado
        mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.history, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text('Histórico', style: AppTextStyles.title(context)),
              ],
            ),
          ),
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1F2937)
                  : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 'devolver');
                      _carregarHistorico(statusId: 3);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 'devolver'
                            ? const Color(0xFF684F8E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTab == 'devolver'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Devolver',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _selectedTab == 'devolver'
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                          // SÓ MOSTRA O BADGE SE TIVER MAIS DE 0
                          if (_quantidadeDevolver > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _selectedTab == 'devolver'
                                    ? Colors.white
                                    : const Color(0xFF684F8E).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_quantidadeDevolver',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedTab == 'devolver'
                                      ? const Color(0xFF684F8E)
                                      : const Color(0xFF684F8E),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedTab = 'devolvidos');
                      _carregarHistoricoDevolvidos();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: _selectedTab == 'devolvidos'
                            ? const Color(0xFF684F8E)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: _selectedTab == 'devolvidos'
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Histórico',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _selectedTab == 'devolvidos'
                              ? Colors.white
                              : const Color(0xFF6B7280),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (_selectedTab == 'devolvidos') ...[
            InlinePeriodPicker(
              startDate: _dataInicioDevolvidos,
              endDate: _dataFimDevolvidos,
              onClear: () => setState(() {
                _dataInicioDevolvidos = null;
                _dataFimDevolvidos = null;
              }),
              onRangeSelected: (start, end) {
                setState(() {
                  _dataInicioDevolvidos = start;
                  _dataFimDevolvidos = end;
                });
                _carregarHistoricoDevolvidos();
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.end, // Alinha os botões à direita
              children: [
                _buildTransparentIconGroup(
                  context,
                  [
                    {
                      'icon': Icons.search,
                      'color': IconColors.search(context),
                      'tooltip': 'Buscar',
                      'onPressed': () {
                        _carregarHistoricoDevolvidos();
                      },
                    },
                    {
                      'icon': Symbols.ink_eraser,
                      'color': IconColors.delete(context),
                      'tooltip': 'Limpar filtros',
                      'onPressed': () {
                        setState(() {
                          _dataInicioDevolvidos = null;
                          _dataFimDevolvidos = null;
                        });
                        _carregarHistoricoDevolvidos();
                      },
                    },
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          // LÓGICA DA LISTA RESPONSIVA:
          if (isMobile)
            _loadingHistorico
                ? const Center(
                    child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator()))
                : _historico.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        shrinkWrap: true, // Importante no mobile
                        physics:
                            const NeverScrollableScrollPhysics(), // Scroll do pai
                        itemCount: _historico.length,
                        itemBuilder: _buildHistoricoItem,
                      )
          else
            Expanded(
              child: _loadingHistorico
                  ? const Center(child: CircularProgressIndicator())
                  : _historico.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: _historico.length,
                          itemBuilder: _buildHistoricoItem,
                        ),
            ),
        ],
      ),
    );
  }

  // Método auxiliar extraído para não repetir código do estado vazio
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key_off, size: 48, color: getSecondaryTextColor(context)),
          const SizedBox(height: 8),
          Text('Sem registros de chaves',
              style: TextStyle(
                  color: getSecondaryTextColor(context), fontSize: 14)),
        ],
      ),
    );
  }

  // Método auxiliar extraído para construir o item da lista
  Widget _buildHistoricoItem(BuildContext context, int index) {
    final item = _historico[index];

    if (_selectedTab == 'devolver') {
      final retiradoPor = item['retirado_por'] ?? '';
      final partes = retiradoPor.split(' - ');
      final nomeUnidade = partes.length > 0 ? partes[0] : '';
      final dataHora = partes.length > 1 ? partes[1] : '';
      final observacao = (item['obs'] ?? '').toString();
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(context), width: 1),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dataHora.isNotEmpty
                            ? dataHora
                            : (item['dt_retirada'] ?? 'Data não informada'),
                        style: TextStyle(
                            fontSize: 11,
                            color: getSecondaryTextColor(context),
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item['chave_ds'] ??
                            item['chave'] ??
                            'Chave não informada',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nomeUnidade,
                        style: TextStyle(
                          fontSize: 12,
                          color: getSecondaryTextColor(context),
                        ),
                      ),
                      // 👇 ADICIONE O TEXTO DA OBSERVAÇÃO AQUI
                      if (observacao.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Obs: $observacao',
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: getSecondaryTextColor(context),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _iniciarDevolucao(item),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                      color: _expandedReservaId == item['reserva_id']
                          ? Colors.grey.shade100
                          : Colors.transparent,
                    ),
                    child: Icon(
                      _expandedReservaId == item['reserva_id']
                          ? Icons.keyboard_arrow_up
                          : Icons.check,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            if (_expandedReservaId == item['reserva_id']) ...[
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: _isDevolucaoOutraPessoa
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selecione o morador que está devolvendo:',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: getTextColor(context)),
                          ),
                          const SizedBox(height: 12),
                          LayoutBuilder(builder: (context, constraints) {
                            return Autocomplete<Map<String, dynamic>>(
                              initialValue: TextEditingValue(
                                text: _pessoaOutraDevolucao != null
                                    ? (_pessoaOutraDevolucao![
                                            'unidade_mostra'] ??
                                        '')
                                    : '',
                              ),
                              optionsBuilder:
                                  (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _unidades;
                                }
                                return _unidades
                                    .where((Map<String, dynamic> option) {
                                  return (option['unidade_mostra'] ?? '')
                                      .toString()
                                      .toLowerCase()
                                      .contains(
                                          textEditingValue.text.toLowerCase());
                                });
                              },
                              displayStringForOption:
                                  (Map<String, dynamic> option) =>
                                      (option['unidade_mostra'] ?? '')
                                          .toString(),
                              onSelected: (Map<String, dynamic> value) {
                                setState(() {
                                  _pessoaOutraDevolucao = value;
                                });
                              },
                              fieldViewBuilder: (context, textEditingController,
                                  focusNode, onFieldSubmitted) {
                                return CharacterCounterField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  maxLength: 50,
                                  decoration: InputDecoration(
                                    labelText: 'Buscar morador',
                                    filled: true,
                                    fillColor: getCardColor(context),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: getBorderColor(context)),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                          color: getBorderColor(context)),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: const BorderSide(
                                          color: Color(0xFF684F8E)),
                                    ),
                                    suffixIcon: textEditingController
                                            .text.isNotEmpty
                                        ? IconButton(
                                            icon: Icon(Icons.close,
                                                size: 20,
                                                color: getSecondaryTextColor(
                                                    context)),
                                            onPressed: () {
                                              textEditingController.clear();
                                              setState(() {
                                                _pessoaOutraDevolucao = null;
                                              });
                                            },
                                          )
                                        : null,
                                  ),
                                );
                              },
                              optionsViewBuilder:
                                  (context, onSelected, options) {
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
                                          final Map<String, dynamic> option =
                                              options.elementAt(index);
                                          return InkWell(
                                            onTap: () => onSelected(option),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color:
                                                        getBorderColor(context)
                                                            .withValues(
                                                                alpha: 0.5),
                                                    width: 0.5,
                                                  ),
                                                ),
                                              ),
                                              child: Text(
                                                (option['unidade_mostra'] ??
                                                        'Sem unidade')
                                                    .toString(),
                                                style: TextStyle(
                                                    color:
                                                        getTextColor(context)),
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
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isDevolucaoOutraPessoa = false;
                                          _pessoaOutraDevolucao = null;
                                        });
                                      },
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(40)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Text('Cancelar',
                                            style: TextStyle(
                                                color: getTextColor(context))),
                                      ),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 24,
                                        color: Colors.grey.shade300),
                                    InkWell(
                                      onTap: () {
                                        if (_pessoaOutraDevolucao == null) {
                                          FeedbackUtils.showError(
                                            context: context,
                                            title: 'Atenção',
                                            message: 'Selecione um morador.',
                                          );
                                        } else {
                                          _executarDevolucao(
                                            _reservaEmProcesso!['reservaId'],
                                            _pessoaOutraDevolucao![
                                                'usuario_id'],
                                            _reservaEmProcesso!['convidadoTxt'],
                                          );
                                        }
                                      },
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(40)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Text(
                                          'Devolver',
                                          style: TextStyle(
                                              color: Color(0xFF684F8E),
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Esta chave está sendo devolvida por outra pessoa?',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: getTextColor(context)),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(40),
                                  border: Border.all(
                                      color: Colors.grey.shade300, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        _executarDevolucao(
                                          _reservaEmProcesso!['reservaId'],
                                          _reservaEmProcesso!['retiradoPorId'],
                                          _reservaEmProcesso!['convidadoTxt'],
                                        );
                                      },
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(40)),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Text('Não',
                                            style: TextStyle(
                                                color: getTextColor(context))),
                                      ),
                                    ),
                                    Container(
                                        width: 1,
                                        height: 24,
                                        color: Colors.grey.shade300),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _isDevolucaoOutraPessoa = true;
                                        });
                                      },
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              right: Radius.circular(40)),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        child: Text(
                                          'Sim',
                                          style: TextStyle(
                                              color: Color(0xFF684F8E),
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ],
        ),
      );
    } else {
      // Layout histórico para "Devolvidos"
      final retiradoPor = item['retirado_por'] ?? '';
      final partes = retiradoPor.split(' - ');
      final nomeUnidade = partes.length > 0 ? partes[0] : '';
      final dataHora = partes.length > 1 ? partes[1] : '';

      final devolvidoPor = item['devolvido_por'] ?? '';
      String devolveuNome = 'Não informado';
      String devolveuDataHora = '';

// 👇 1. ADICIONE A LEITURA DA OBSERVAÇÃO AQUI
      final observacao = (item['obs'] ?? '').toString();

      if (devolvidoPor.isNotEmpty) {
        final partes = devolvidoPor.split(' - ');
        if (partes.length >= 2) {
          final nomeEData = partes[1].split(' às ');
          if (nomeEData.length >= 2) {
            devolveuNome = nomeEData[0].trim();
            devolveuDataHora = nomeEData[1].trim();
          }
        }
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey.shade700
                  : const Color(0xFFD1D5DB),
              width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['chave_ds'] ?? item['chave'] ?? 'Chave não informada',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: getTextColor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Pegou: $nomeUnidade',
              style: TextStyle(
                  fontSize: 12, color: getSecondaryTextColor(context)),
            ),
            if (devolveuNome != 'Não informado') ...[
              const SizedBox(height: 2),
              Text(
                'Devolveu: $devolveuNome',
                style: TextStyle(
                    fontSize: 12, color: getSecondaryTextColor(context)),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Ret: ${dataHora.isNotEmpty ? dataHora : (item['dt_retirada'] ?? '-')}',
              style: TextStyle(
                  fontSize: 11,
                  color: getSecondaryTextColor(context),
                  fontWeight: FontWeight.w500),
            ),
            if (devolveuDataHora.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Dev: $devolveuDataHora',
                style: TextStyle(
                    fontSize: 11,
                    color: getSecondaryTextColor(context),
                    fontWeight: FontWeight.w500),
              ),
            ],
            // 👇 2. ADICIONE A EXIBIÇÃO DA OBSERVAÇÃO AQUI NO FINAL
            if (observacao.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Obs: $observacao',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: getSecondaryTextColor(context),
                ),
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildPeriodFilter({
    required BuildContext context,
    required DateTime? startDate,
    required DateTime? endDate,
    required Function(DateTime?) onStartDateChanged,
    required Function(DateTime?) onEndDateChanged,
    required Function() onRangeSelected,
  }) {
    return InkWell(
      onTap: () => _showDateRangeTimePicker(context, startDate, endDate,
          onStartDateChanged, onEndDateChanged, onRangeSelected),
      child: InputDecorator(
        isEmpty: startDate == null && endDate == null,
        decoration: inputDecorationPadrao(
          context,
          hintText: (startDate == null && endDate == null)
              ? 'Selecionar período'
              : null,
          labelText: (startDate != null || endDate != null) ? 'Período' : null,
        ),
        child: Text(
          _formatPeriodDisplay(startDate, endDate),
          style: TextStyle(
            fontSize: 14,
            color: getTextColor(context),
            overflow: TextOverflow.ellipsis,
          ),
          maxLines: 1,
        ),
      ),
    );
  }

  String _formatPeriodDisplay(DateTime? startDate, DateTime? endDate) {
    if (startDate == null && endDate == null) {
      return '';
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

  String _formatarDataParaDisplay(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  Future<void> _showDateRangeTimePicker(
    BuildContext context,
    DateTime? currentStartDate,
    DateTime? currentEndDate,
    Function(DateTime?) onStartDateChanged,
    Function(DateTime?) onEndDateChanged,
    Function() onRangeSelected,
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
            onRangeSelected,
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
    Function() onRangeSelected,
  ) async {
    onStartDateChanged(startDate);
    onEndDateChanged(endDate);
    onRangeSelected();
  }
}
