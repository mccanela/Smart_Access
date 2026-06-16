import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
// Import removed
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/theme/icon_colors.dart';
import '../../shared/widgets/screen_header.dart';
import '../../core/utils/ui_standards.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html show window;
import '../../shared/widgets/character_counter_field.dart';
import '../../shared/widgets/custom_imput.dart';
import '../../shared/widgets/inline_period_picker.dart';

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
  late DateTimeRange selectedRange;
  DateTime _focusedDay = DateTime.now();
  final DateTime _firstDay = DateTime(2020);
  final DateTime _lastDay = DateTime.now().add(const Duration(days: 90));

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    selectedRange = DateTimeRange(
      start: DateTime(today.year, today.month, today.day),
      end: DateTime(today.year, today.month, today.day),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: getBackgroundColor(context),
      child: Container(
        width: 400,
        height: 500,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Selecionar Período',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: getTextColor(context),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: getTextColor(context)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCalendar(),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: getSurfaceColor(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Período: ${selectedRange.start.day.toString().padLeft(2, '0')}/${selectedRange.start.month.toString().padLeft(2, '0')} até ${selectedRange.end.day.toString().padLeft(2, '0')}/${selectedRange.end.month.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: getSecondaryTextColor(context),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      color: CupertinoColors.label.resolveFrom(context),
                      fontSize: 16,
                    ),
                  ),
                ),
                CupertinoButton.filled(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onRangeSelected(
                        selectedRange.start, selectedRange.end);
                  },
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  borderRadius: BorderRadius.circular(8),
                  child: const Text(
                    'Confirmar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendar() {
    return Column(
      children: [
        // Header com mês/ano
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left, color: getTextColor(context)),
              onPressed: () {
                setState(() {
                  _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month - 1);
                });
              },
            ),
            Text(
              '${_getMonthName(_focusedDay.month)} ${_focusedDay.year}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: getTextColor(context),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right, color: getTextColor(context)),
              onPressed: () {
                setState(() {
                  _focusedDay =
                      DateTime(_focusedDay.year, _focusedDay.month + 1);
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Dias da semana
        Row(
          children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          color: getSecondaryTextColor(context),
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),

        // Grid do calendário
        Expanded(
          child: _buildCalendarGrid(),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday;

    final daysInMonth = lastDayOfMonth.day;
    final totalCells = 42; // 6 semanas x 7 dias

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.2,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        final dayOffset = index - (firstDayOfWeek - 1);
        final day = dayOffset + 1;

        if (dayOffset < 0 || day > daysInMonth) {
          return const SizedBox.shrink();
        }

        final currentDate = DateTime(_focusedDay.year, _focusedDay.month, day);
        final isSelected = _isDateInRange(currentDate);
        final isStart = selectedRange.start == currentDate;
        final isEnd = selectedRange.end == currentDate;
        final isToday = _isToday(currentDate);
        final isInRange = _isDateInRange(currentDate) && !isStart && !isEnd;

        return GestureDetector(
          onTap: () => _onDateSelected(currentDate),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isStart || isEnd
                  ? const Color(0xFF1E40AF)
                  : isInRange
                      ? const Color(0xFF1E40AF).withValues(alpha: 0.1)
                      : isToday
                          ? const Color(0xFF1E40AF).withValues(alpha: 0.2)
                          : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: const Color(0xFF1E40AF), width: 1)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  color: isStart || isEnd
                      ? Colors.white
                      : isInRange
                          ? const Color(0xFF1E40AF)
                          : isToday
                              ? const Color(0xFF1E40AF)
                              : getTextColor(context),
                  fontWeight: isStart || isEnd || isToday
                      ? FontWeight.w500
                      : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onDateSelected(DateTime date) {
    setState(() {
      if (selectedRange.start == selectedRange.end) {
        // Segunda seleção - definir fim do range
        if (date.isBefore(selectedRange.start)) {
          selectedRange = DateTimeRange(start: date, end: selectedRange.start);
        } else {
          selectedRange = DateTimeRange(start: selectedRange.start, end: date);
        }
      } else {
        // Nova seleção - reset
        selectedRange = DateTimeRange(start: date, end: date);
      }
    });
  }

  bool _isDateInRange(DateTime date) {
    return date.isAtSameMomentAs(selectedRange.start) ||
        date.isAtSameMomentAs(selectedRange.end) ||
        (date.isAfter(selectedRange.start) && date.isBefore(selectedRange.end));
  }

  bool _isToday(DateTime date) {
    final today = DateTime.now();
    return date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;
  }

  String _getMonthName(int month) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro'
    ];
    return months[month - 1];
  }
}

class TurnosScreen extends StatefulWidget {
  final VoidCallback onClose;
  const TurnosScreen({super.key, required this.onClose});

  @override
  State<TurnosScreen> createState() => _TurnosScreenState();
}

class _TurnosScreenState extends State<TurnosScreen> {
  // Funções auxiliares para cores adaptáveis ao tema
  Color getCardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color.fromARGB(255, 40, 40, 40)
        : Colors.white;
  }

  Color getTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color getSecondaryTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.white70
        : Colors.black87;
  }

  Color getBorderColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.grey[600]!
        : const Color(0xFFE5E7EB);
  }

  Color getBackgroundColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? Colors.black
        : Colors.white;
  }

  final _observacaoController = TextEditingController();
  DateTime? _dataInicio;
  DateTime? _dataFim;

  // Variáveis para controle de estado
  bool _loadingHistorico = false;
  bool _loadingRegistro = false;
  List<Map<String, dynamic>> _usuariosTurno = [];
  List<Map<String, dynamic>> _historicoTurnos = [];
  Map<String, dynamic>? _usuarioEntrando;
  String _nomeUsuarioLogado = 'Carregando...';
  Timer? _timer;
  String _currentTimeOnly = '';

  // Confirmation state
  bool _confirmingTurno = false;
  bool _saiuOutroHorario = false;

  DateTime _horarioSelecionado = DateTime.now();

  // Keys para feedback contextual
  final GlobalKey _registrarTurnoKey = GlobalKey();
  final GlobalKey _confirmarLoginKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _carregarUsuarioLogado();
    _carregarUsuarios();
    _updateTime();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (timer) => _updateTime());
  }

  @override
  void dispose() {
    _observacaoController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTimeOnly =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    });
  }

  Future<void> _carregarUsuarioLogado() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Tentar diferentes chaves possíveis
      String? encryptedUsuarioNome = prefs.getString('usuario_nome');
      if (encryptedUsuarioNome == null || encryptedUsuarioNome.isEmpty) {
        encryptedUsuarioNome = prefs.getString('nome_usuario');
      }
      if (encryptedUsuarioNome == null || encryptedUsuarioNome.isEmpty) {
        encryptedUsuarioNome = prefs.getString('usuario_nome_txt');
      }

      if (encryptedUsuarioNome != null && encryptedUsuarioNome.isNotEmpty) {
        try {
          final nome = decryptText(encryptedUsuarioNome);
          if (nome.isNotEmpty) {
            if (mounted) {
              setState(() {
                _nomeUsuarioLogado = nome;
              });
            }
            return;
          }
        } catch (e) {
          print('Erro ao descriptografar nome: $e');
        }
      }

      // Se não encontrou no storage, tentar buscar da API
      try {
        final condominioId = await ApiConfig.getCondominioId();
        final prefs = await SharedPreferences.getInstance();
        final encryptedToken = prefs.getString('tokensessao_txt');
        final tokenSessao =
            (encryptedToken != null && encryptedToken.isNotEmpty)
                ? decryptText(encryptedToken)
                : '';
        final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
        final usuarioId = (encryptedUsuarioId.isNotEmpty)
            ? decryptText(encryptedUsuarioId)
            : '';

        if (tokenSessao.isNotEmpty && usuarioId.isNotEmpty) {
          // Tentar buscar dados do usuário da API
          final url = Uri.parse(ApiConfig.getEndpoint('turnos', 'usuario'));
          final payload = {
            "condominio_id": int.parse(condominioId),
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
            if (data['status'] == 200 && data['data'] != null) {
              final usuarios = data['data']['listausuario'] ?? data['data'];
              if (usuarios is List && usuarios.isNotEmpty) {
                // Procurar o usuário logado na lista
                try {
                  final usuarioLogado = usuarios.firstWhere(
                    (u) => u['usuario_id']?.toString() == usuarioId,
                  );
                  final nome = usuarioLogado['nome']?.toString() ??
                      usuarioLogado['nome_txt']?.toString() ??
                      usuarioLogado['usuario_nome']?.toString() ??
                      '';
                  if (nome.isNotEmpty) {
                    // Salvar no storage para próxima vez
                    final encryptedNome = encryptText(nome);
                    await prefs.setString('usuario_nome', encryptedNome);
                    if (mounted) {
                      setState(() {
                        _nomeUsuarioLogado = nome;
                      });
                    }
                    return;
                  }
                } catch (e) {
                  // Usuário não encontrado na lista - continuar para tentar outras formas
                }
              }
            }
          }
        }
      } catch (e) {
        print('Erro ao buscar nome da API: $e');
      }

      // Se ainda não encontrou, usar método padrão
      final nome = await ApiConfig.getUsuarioNome();
      if (mounted) {
        setState(() {
          _nomeUsuarioLogado =
              nome.isNotEmpty ? nome : 'Usuário não identificado';
        });
      }
    } catch (e) {
      print('Erro ao carregar usuário logado: $e');
      if (mounted) {
        setState(() {
          _nomeUsuarioLogado = 'Usuário não identificado';
        });
      }
    }
  }

  Future<void> _carregarUsuarios() async {
    // Carregando usuários

    try {
      final condominioId = await ApiConfig.getCondominioId();

      // Obter token descriptografado diretamente
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

      final url = Uri.parse(ApiConfig.getEndpoint('turnos', 'usuario'));
      final payload = {
        "condominio_id": int.parse(condominioId),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          final usuarios = data['data']['listausuario'] ?? data['data'];

          if (usuarios is List) {
            setState(() {
              _usuariosTurno = List<Map<String, dynamic>>.from(usuarios);
            });
          } else if (usuarios is Map) {
            final listaUsuarios =
                usuarios.values.whereType<Map<String, dynamic>>().toList();
            if (listaUsuarios.isNotEmpty) {
              setState(() {
                _usuariosTurno = listaUsuarios;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar usuários: $e');
    } finally {
      // Usuários carregados
    }
  }

  Future<void> _carregarHistorico() async {
    setState(() {
      _loadingHistorico = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();

      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

      final dataInicio = _dataInicio ?? DateTime.now();
      final dataFim = _dataFim ?? DateTime.now();

      final url = Uri.parse(ApiConfig.getEndpoint('turnos', 'lista'));
      final payload = {
        "condominio_id": int.parse(condominioId),
        "data":
            "${dataInicio.year.toString().padLeft(4, '0')}-${dataInicio.month.toString().padLeft(2, '0')}-${dataInicio.day.toString().padLeft(2, '0')}",
        "data_fim":
            "${dataFim.year.toString().padLeft(4, '0')}-${dataFim.month.toString().padLeft(2, '0')}-${dataFim.day.toString().padLeft(2, '0')}",
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['status'] == 200 && data['data'] != null) {
          final historico = data['data']['turno'] ?? data['data'];

          if (historico is List) {
            setState(() {
              _historicoTurnos = List<Map<String, dynamic>>.from(historico);
            });
          } else if (historico is Map) {
            final listaHistorico =
                historico.values.whereType<Map<String, dynamic>>().toList();
            if (listaHistorico.isNotEmpty) {
              setState(() {
                _historicoTurnos = listaHistorico;
              });
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao carregar histórico: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingHistorico = false;
        });
      }
    }
  }

  Future<String> _getMachineIP() async {
    try {
      if (kIsWeb) {
        final response =
            await http.get(Uri.parse(ApiConfig.getExternalUrl('ipCheck')));
        if (response.statusCode == 200) {
          return response.body.trim();
        }
      } else {
        final interfaces = await NetworkInterface.list();
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4 &&
                !addr.address.startsWith('127.') &&
                !addr.address.startsWith('192.168.') &&
                !addr.address.startsWith('10.')) {
              return addr.address;
            }
          }
        }
        for (var interface in interfaces) {
          for (var addr in interface.addresses) {
            if (addr.type == InternetAddressType.IPv4) {
              return addr.address;
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao obter IP: $e');
    }
    return '127.0.0.1';
  }

  Future<void> _iniciarConfirmacaoTurno() async {
    if (_usuarioEntrando == null) {
      FeedbackUtils.showError(
        context: context,
        title: 'Seleção Obrigatória',
        message: 'Selecione um usuário para entrar',
      );
      return;
    }

    setState(() {
      _confirmingTurno = true;
      _saiuOutroHorario = false;

      _horarioSelecionado = DateTime.now();
    });
  }

  void _cancelarConfirmacao() {
    setState(() {
      _confirmingTurno = false;
    });
  }

  Future<void> _executarRegistroTurno(DateTime dataRegistro,
      {bool logout = true}) async {
    setState(() {
      _loadingRegistro = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();
      final usuarioId = await ApiConfig.getUsuarioId();

      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';

      final machineIP = await _getMachineIP();

      final dataFormatada =
          "${dataRegistro.day.toString().padLeft(2, '0')}/${dataRegistro.month.toString().padLeft(2, '0')}/${dataRegistro.year} ${dataRegistro.hour.toString().padLeft(2, '0')}:${dataRegistro.minute.toString().padLeft(2, '0')}";

      final url = Uri.parse(ApiConfig.getEndpoint('turnos', 'novoAtendimento'));
      final payload = {
        "sac_id": 0,
        "condominio_id": int.parse(condominioId),
        "categoriasac_id": 34,
        "statussac_id": 114,
        "canal_id": 496,
        "titulo_txt": "Troca de Turno",
        "local_txt": _observacaoController.text.trim(),
        "dt_ocorrencia": dataFormatada,
        "prioridade_num": 0,
        "nota_num": 0,
        "flg_mostra": "S",
        "id_terceiro": "",
        "usuario_solicita": int.parse(usuarioId),
        "usuario_atende": _usuarioEntrando!['usuario_id'],
        "usuario_reclamado": 0,
        "usuario_interacao": int.parse(usuarioId),
        "mensagem_txt": _observacaoController.text.trim(),
        "observacao": _observacaoController.text.trim(),
        "ip": machineIP,
        "subject": ""
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true ||
            data['status'] == 200 ||
            data['message']?.toString().contains('sucesso') == true) {
          if (mounted) {
            // Salvar observação se houver
            final prefs = await SharedPreferences.getInstance();
            final observacao = _observacaoController.text.trim();

            if (observacao.isNotEmpty) {
              final encryptedObservacao = encryptText(observacao);
              await prefs.setString(
                  'turno_pendente_observacao', encryptedObservacao);
            }

            FeedbackUtils.showSuccess(
              context: context,
              title: 'Turno Registrado',
              message: logout
                  ? 'Turno registrado com sucesso. Você será deslogado...'
                  : 'Turno registrado com sucesso.',
              triggerKey: logout ? _confirmarLoginKey : _registrarTurnoKey,
            );

            if (!logout) {
              if (kIsWeb) {
                // Simula um Ctrl+F5 (Refresh)
                html.window.location.reload();
              } else {
                if (mounted) {
                  Navigator.of(context).pop(); // Fechar a modal
                }
              }
              return;
            }

            // Aguardar um pouco antes de deslogar
            await Future.delayed(const Duration(seconds: 2));

            // Deslogar o usuário - limpar todos os dados
            if (mounted) {
              final prefs = await SharedPreferences.getInstance();

              // Obter token descriptografado para matar a sessão na API
              final encryptedToken = prefs.getString('tokensessao_txt');
              final tokenSessao =
                  (encryptedToken != null && encryptedToken.isNotEmpty)
                      ? decryptText(encryptedToken)
                      : '';

              // Matar a sessão na API se tiver token
              if (tokenSessao.isNotEmpty) {
                try {
                  final url =
                      Uri.parse(ApiConfig.getEndpoint('auth', 'deleteSession'));
                  await http.post(
                    url,
                    headers: {
                      'Content-Type': 'application/json',
                      'Authorization': 'Bearer $tokenSessao',
                    },
                  );
                } catch (e) {
                  // Erro ao matar sessão na API
                }
              }

              // Limpar todos os dados de sessão
              await prefs.remove('tokensessao_txt');
              await prefs.remove('usuario_id');
              await prefs.remove('condominio_id');
              await prefs.remove('usuario_nome');
              await prefs.remove('usuario_email');
              await prefs.remove('condominio_nome');

              if (kIsWeb) {
                // No web, recarregar a página completamente
                // Não precisamos verificar mounted aqui pois window.location é global
                html.window.location.reload();
              } else {
                // No mobile, usar Navigator
                if (mounted) {
                  Navigator.of(context).pop(); // Fechar a modal
                  Navigator.of(context, rootNavigator: true)
                      .pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                }
              }
            }
          }
        } else {
          if (mounted) {
            FeedbackUtils.showError(
              context: context,
              title: 'Erro ao Registrar',
              message: 'Erro ao registrar turno',
              errorDetails: data['message'] ?? 'Erro desconhecido',
            );
          }
        }
      } else {
        if (mounted) {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro ao Registrar',
            message: 'Erro ao registrar turno',
            errorDetails: 'Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Registrar',
          message: 'Erro ao registrar turno',
          errorDetails: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingRegistro = false;
        });
      }
    }
  }

  void _limparFormulario() {
    _usuarioEntrando = null;
    _observacaoController.clear();
  }

  @override
  Widget build(BuildContext context) {
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
            icon: Icons.access_time,
            title: 'Turnos',
            onClose: widget.onClose,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildNovoTurnoPanel()),
                  const SizedBox(width: 24),
                  Expanded(child: _buildHistoricoPanel()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNovoTurnoPanel() {
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
              const Icon(Icons.swap_horiz, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('Troca de Turno', style: AppTextStyles.title(context)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.person_outline,
                  color: getSecondaryTextColor(context), size: 18),
              const SizedBox(width: 12),
              Text(
                'Operador Logado: $_nomeUsuarioLogado',
                style: TextStyle(
                    color: getSecondaryTextColor(context), fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: _usuarioEntrando != null
                    ? (_usuarioEntrando?['nome'] ?? 'Usuário')
                    : '',
              ),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _usuariosTurno;
                }
                return _usuariosTurno.where((Map<String, dynamic> option) {
                  return (option['nome'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) =>
                  option['nome'] ?? 'Usuário',
              onSelected: (Map<String, dynamic> value) {
                setState(() {
                  _usuarioEntrando = value;
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return CharacterCounterField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Selecione um usuário',
                  ).copyWith(
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _usuarioEntrando = null;
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
                                (option['nome'] ?? 'Usuário').toString(),
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
            controller: _observacaoController,
            maxLines: 4,
          ),
          const SizedBox(height: 24),
          Align(
            alignment: Alignment.centerRight,
            child: _confirmingTurno
                ? Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF684F8E).withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color:
                              const Color(0xFF684F8E).withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.assignment_turned_in_outlined,
                                color: const Color(0xFF684F8E), size: 22),
                            const SizedBox(width: 8),
                            Text(
                              "Confirmação de Troca",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: getTextColor(context),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Radio: Current Time
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF684F8E),
                          title: Text(
                            "Estou ciente de que o registro será efetuado com o horário: $_currentTimeOnly",
                            style: TextStyle(
                              color: getTextColor(context),
                              fontSize: 13,
                              fontWeight: !_saiuOutroHorario
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          value: false,
                          groupValue: _saiuOutroHorario,
                          onChanged: (value) {
                            setState(() {
                              _saiuOutroHorario = value!;
                              _horarioSelecionado = DateTime.now();
                            });
                          },
                        ),

                        // Radio: Custom Time
                        RadioListTile<bool>(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color(0xFF684F8E),
                          title: Text(
                            "Selecionar outro horário",
                            style: TextStyle(
                              color: getTextColor(context),
                              fontSize: 13,
                              fontWeight: _saiuOutroHorario
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          value: true,
                          groupValue: _saiuOutroHorario,
                          onChanged: (value) {
                            setState(() {
                              _saiuOutroHorario = value!;
                            });
                          },
                        ),

                        // Time Picker
                        if (_saiuOutroHorario)
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 16, right: 16, bottom: 16),
                            child: InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: TimeOfDay.fromDateTime(
                                      _horarioSelecionado),
                                );
                                if (time != null) {
                                  final now = DateTime.now();
                                  setState(() {
                                    _horarioSelecionado = DateTime(
                                      now.year,
                                      now.month,
                                      now.day,
                                      time.hour,
                                      time.minute,
                                    );
                                  });
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: getCardColor(context),
                                  border: Border.all(
                                      color: const Color(0xFF684F8E), width: 1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.access_time,
                                        color: Color(0xFF684F8E), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Horário: ${_horarioSelecionado.hour.toString().padLeft(2, '0')}:${_horarioSelecionado.minute.toString().padLeft(2, '0')}",
                                      style: const TextStyle(
                                        color: Color(0xFF684F8E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.edit,
                                        color: Colors.grey, size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),

                        // Buttons
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildTransparentIconGroup(
                            context,
                            [
                              {
                                'icon': Icons.close,
                                'color': IconColors.delete(context),
                                'tooltip': 'Cancelar',
                                'onPressed': _cancelarConfirmacao,
                              },
                              {
                                'key': _registrarTurnoKey,
                                'icon': Icons.check,
                                'color': Colors.green,
                                'tooltip': 'Confirmar',
                                'onPressed': () => _executarRegistroTurno(
                                    _saiuOutroHorario
                                        ? _horarioSelecionado
                                        : DateTime.now(),
                                    logout: false),
                                'isLoading': _loadingRegistro,
                              },
                              {
                                'key': _confirmarLoginKey,
                                'icon': Icons.logout,
                                'color': const Color(0xFF684F8E),
                                'tooltip': 'Confirmar e fazer novo login',
                                'onPressed': () => _executarRegistroTurno(
                                    _saiuOutroHorario
                                        ? _horarioSelecionado
                                        : DateTime.now(),
                                    logout: true),
                                'isLoading': _loadingRegistro,
                              },
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : _buildTransparentIconGroup(
                    context,
                    [
                      {
                        'icon': Symbols.ink_eraser,
                        'color': IconColors.delete(context),
                        'tooltip': 'Limpar formulário',
                        'onPressed': () {
                          setState(() {
                            _dataInicio = null;
                            _dataFim = null;
                            _observacaoController.clear();
                            _usuarioEntrando = null;
                          });
                        },
                        'isLoading': false,
                      },
                      {
                        'icon': Symbols.send,
                        'color': Colors.green,
                        'tooltip': 'Registrar turno',
                        'onPressed': _iniciarConfirmacaoTurno,
                        'isLoading': _loadingRegistro,
                      },
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoricoPanel() {
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
              Icon(Icons.history, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('Histórico', style: AppTextStyles.title(context)),
            ],
          ),
          const SizedBox(height: 12),
          InlinePeriodPicker(
            startDate: _dataInicio,
            endDate: _dataFim,
            onClear: () => setState(() {
              _dataInicio = null;
              _dataFim = null;
            }),
            onRangeSelected: (start, end) {
              setState(() {
                _dataInicio = start;
                _dataFim = end;
              });
              _carregarHistorico();
            },
            trailing: _buildTransparentIconGroup(
              context,
              [
                {
                  'icon': Icons.search,
                  'color': IconColors.search(context),
                  'tooltip': 'Buscar',
                  'onPressed': () {
                    _carregarHistorico();
                  },
                },
                {
                  'icon': Symbols.ink_eraser,
                  'color': IconColors.delete(context),
                  'tooltip': 'Limpar filtros',
                  'onPressed': () {
                    setState(() {
                      _dataInicio = null;
                      _dataFim = null;
                    });
                    _carregarHistorico();
                  },
                },
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loadingHistorico
                ? const Center(child: CircularProgressIndicator())
                : _historicoTurnos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.schedule,
                                size: 48,
                                color: getSecondaryTextColor(context)),
                            const SizedBox(height: 8),
                            Text('Sem turnos registrados',
                                style: TextStyle(
                                    color: getSecondaryTextColor(context),
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historicoTurnos.length,
                        itemBuilder: (context, index) {
                          final item = _historicoTurnos[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: getBorderColor(context), width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['dt_saida'] ??
                                        item['dt_entrada'] ??
                                        item['dt_ocorrencia'] ??
                                        'Data não informada',
                                    style: TextStyle(
                                      color: getSecondaryTextColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  // Novo posto (Entrada)
                                  Text(
                                    'Novo posto:',
                                    style: TextStyle(
                                      color: getSecondaryTextColor(context),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item['nome_entrada'] ??
                                        item['usuario_atende_nome'] ??
                                        'Usuário não informado',
                                    style: TextStyle(
                                      color: getTextColor(context),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (item['observacao']?.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      item['observacao'],
                                      style: TextStyle(
                                        color: getSecondaryTextColor(context),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
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
          hintText: (startDate == null && endDate == null) ? 'Período' : null,
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
