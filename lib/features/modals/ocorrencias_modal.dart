import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/utils/ui_standards.dart';
import '../../core/theme/icon_colors.dart';
import '../../shared/widgets/custom_imput.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/facial_capture_modal.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../shared/widgets/inline_feedback.dart';
import '../../shared/widgets/inline_period_picker.dart';
import '../../shared/widgets/inline_single_date_picker.dart';
import '../dashboard/widgets/segmented_tab_bar.dart';
import '../../shared/widgets/filter_tab.dart';

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
                  'Período',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: getTextColor(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: getTextColor(context)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCalendarGrid(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  onPressed: () {
                    widget.onRangeSelected(
                        selectedRange.start, selectedRange.end);
                    Navigator.of(context).pop();
                  },
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday;

    final daysInMonth = lastDayOfMonth.day;
    final totalCells = 42; // 6 semanas x 7 dias

    return Column(
      children: [
        // Cabeçalho com mês/ano e navegação
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
                fontWeight: FontWeight.w600,
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
        const SizedBox(height: 16),
        // Dias da semana
        Row(
          children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: getSecondaryTextColor(context),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Grid de dias
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayOffset = index - (firstDayOfWeek - 1);
              final day = dayOffset + 1;
              final date = DateTime(_focusedDay.year, _focusedDay.month, day);

              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final isInRange = date.isAfter(
                      selectedRange.start.subtract(const Duration(days: 1))) &&
                  date.isBefore(selectedRange.end.add(const Duration(days: 1)));
              final isStart = date.day == selectedRange.start.day &&
                  date.month == selectedRange.start.month &&
                  date.year == selectedRange.start.year;
              final isEnd = date.day == selectedRange.end.day &&
                  date.month == selectedRange.end.month &&
                  date.year == selectedRange.end.year;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;
              final isDark = isDarkMode(context);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selectedRange.start == selectedRange.end) {
                      // Primeira seleção
                      if (date.isBefore(selectedRange.start)) {
                        selectedRange =
                            DateTimeRange(start: date, end: selectedRange.end);
                      } else {
                        selectedRange = DateTimeRange(
                            start: selectedRange.start, end: date);
                      }
                    } else {
                      // Nova seleção
                      selectedRange = DateTimeRange(start: date, end: date);
                    }
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isStart || isEnd
                        ? const Color(0xFF684F8E)
                        : isInRange
                            ? isDark
                                ? const Color(0xFF684F8E).withValues(alpha: 0.4)
                                : const Color(0xFF684F8E).withValues(alpha: 0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday
                        ? Border.all(color: const Color(0xFF684F8E), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isStart || isEnd
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isStart || isEnd
                            ? Colors.white
                            : isInRange && isDark
                                ? Colors.white
                                : getTextColor(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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

// Componente SingleDateCalendarDialog para seleção de data única
class SingleDateCalendarDialog extends StatefulWidget {
  final DateTime? initialDate;

  const SingleDateCalendarDialog({
    super.key,
    this.initialDate,
  });

  @override
  State<SingleDateCalendarDialog> createState() =>
      _SingleDateCalendarDialogState();
}

class _SingleDateCalendarDialogState extends State<SingleDateCalendarDialog> {
  DateTime? selectedDate;
  DateTime _focusedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    selectedDate = null; // Não pré-selecionar nenhuma data
    _focusedDay = widget.initialDate ?? DateTime.now();
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
                  'Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: getTextColor(context),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: getTextColor(context)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _buildCalendarGrid(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoButton.filled(
                  onPressed: selectedDate != null
                      ? () {
                          Navigator.of(context).pop(selectedDate);
                        }
                      : null,
                  child: const Text('Confirmar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final lastDayOfMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final firstDayOfWeek = firstDayOfMonth.weekday;

    final daysInMonth = lastDayOfMonth.day;
    final totalCells = 42; // 6 semanas x 7 dias

    return Column(
      children: [
        // Cabeçalho com mês/ano e navegação
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
                fontWeight: FontWeight.w600,
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
        const SizedBox(height: 16),
        // Dias da semana
        Row(
          children: ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb']
              .map((day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: getSecondaryTextColor(context),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        // Grid de dias
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.2,
            ),
            itemCount: totalCells,
            itemBuilder: (context, index) {
              final dayOffset = index - (firstDayOfWeek - 1);
              final day = dayOffset + 1;
              final date = DateTime(_focusedDay.year, _focusedDay.month, day);

              if (day < 1 || day > daysInMonth) {
                return const SizedBox.shrink();
              }

              final isSelected = selectedDate != null &&
                  date.year == selectedDate!.year &&
                  date.month == selectedDate!.month &&
                  date.day == selectedDate!.day;
              final isToday = date.year == DateTime.now().year &&
                  date.month == DateTime.now().month &&
                  date.day == DateTime.now().day;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDate = date;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF684F8E)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isToday && !isSelected
                        ? Border.all(color: const Color(0xFF684F8E), width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isToday
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color:
                            isSelected ? Colors.white : getTextColor(context),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
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

class OcorrenciasScreen extends StatefulWidget {
  final VoidCallback onClose;

  // --- ADICIONE ESTES DOIS PARÂMETROS ---
  final bool hasFocus;
  final VoidCallback onFocusRequested;
  // --------------------------------------

  const OcorrenciasScreen({
    super.key,
    required this.onClose,
    this.hasFocus = false, // Padrão falso para não quebrar outras telas
    required this.onFocusRequested, // Função obrigatória para avisar o Dashboard
  });

  @override
  State<OcorrenciasScreen> createState() => _OcorrenciasScreenState();
}

class _OcorrenciasScreenState extends State<OcorrenciasScreen> {
  bool _loadingHistorico = false;
  bool _loadingRegistro = false;

  // Controle de aba ativa (0 = Nova Ocorrência, 1 = Histórico)
  int _tabOcorrencias = 0;

  // Controllers
  final _localController = TextEditingController();
  final _descricaoController = TextEditingController();

  // Dados
  List<Map<String, dynamic>> _unidades = [];
  List<Map<String, dynamic>> _historicoOcorrencias = [];
  Map<String, dynamic>? _unidadeSelecionada;
  DateTime? _filtroDataInicio;
  DateTime? _filtroDataFim;
  DateTime? _dataOcorrencia;

  // Imagem selecionada
  XFile? _imagemSelecionada;
  String? _imagemBase64;

  final GlobalKey _registrarOcorrenciaKey = GlobalKey();
  String? _feedbackMessage;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();

    _carregarUnidades();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _localController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _selecionarImagem() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null) {
        // Converter para base64
        String base64Image = '';
        if (kIsWeb) {
          // No web, ler como bytes
          final bytes = await image.readAsBytes();
          base64Image = base64Encode(bytes);
        } else {
          // No mobile, ler do arquivo
          final bytes = await image.readAsBytes();
          base64Image = base64Encode(bytes);
        }

        setState(() {
          _imagemSelecionada = image;
          _imagemBase64 = base64Image;
        });
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao selecionar imagem',
        message: 'Não foi possível selecionar a imagem. Tente novamente.',
      );
    }
  }

  Future<void> _abrirCamera() async {
    try {
      final resultado = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const FacialCaptureModal(
          isFrontal: false,
          title: 'Capturar Foto',
          semEnquadramento: true,
        ),
      );

      if (resultado != null && resultado.isNotEmpty && mounted) {
        setState(() {
          _imagemBase64 = resultado.replaceFirst('data:image/png;base64,', '');
          _imagemSelecionada = null; // Limpar XFile pois veio da câmera
        });
      }
    } catch (e) {
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao capturar foto',
          message: 'Não foi possível capturar a foto. Tente novamente.',
        );
      }
    }
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
          SegmentedTabBar(
            labels: const ['Ocorrência', 'Histórico'],
            tooltips: const [
              'Registrar nova ocorrência',
              'Histórico de ocorrências',
            ],
            selected: _tabOcorrencias,
            hasFocus: widget.hasFocus,
            // 👇 ADICIONE A PROPRIEDADE BADGES AQUI 👇
            badges: {
              1: _historicoOcorrencias
                  .length, // Substitua pelo nome real da sua lista
            },
            onChanged: (i) {
              widget
                  .onFocusRequested(); // <--- AVISA O DASHBOARD QUE FOI CLICADO
              setState(() => _tabOcorrencias = i);
            },
            color: const Color.fromARGB(204, 234, 177, 7),
          ),
          const SizedBox(height: 10),
          Expanded(
            // Apenas aplica o Padding por fora, deixando o scroll para cada painel
            child: _tabOcorrencias == 0
                ? SingleChildScrollView(child: _buildNovaOcorrenciaPanel())
                : _buildHistoricoPanel(), // Se esse for um ListView, ele faz o próprio scroll
          ),
        ],
      ),
    );
  }

  Widget _buildNovaOcorrenciaPanel() {
    return FilterTab(
      title:
          'Nova Ocorrência', // Você pode mudar para 'Filtros de Ocorrência' se preferir
      themeColor: const Color(0xFFF59E0B), // Amarelo da aba Ocorrências
      icon: Icons.tune,
      initiallyExpanded: false,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<Map<String, dynamic>>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _unidades;
                }
                return _unidades.where((Map<String, dynamic> option) {
                  final String optionString = (option['unidade_mostra'] ??
                          option['unidade_ds'] ??
                          option['nome'] ??
                          option['id']?.toString() ??
                          '')
                      .toString()
                      .toLowerCase();
                  return optionString
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) =>
                  option['unidade_mostra'] ??
                  option['unidade_ds'] ??
                  option['nome'] ??
                  option['id']?.toString() ??
                  '',
              onSelected: (Map<String, dynamic> selection) {
                setState(() {
                  _unidadeSelecionada = selection;
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                // Sincronizar controller se houver seleção inicial e texto vazio
                if (_unidadeSelecionada != null &&
                    textEditingController.text.isEmpty) {
                  textEditingController.text =
                      _unidadeSelecionada!['unidade_mostra'] ??
                          _unidadeSelecionada!['unidade_ds'] ??
                          _unidadeSelecionada!['nome'] ??
                          '';
                }
                return CharacterCounterField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Relatado por',
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
                    elevation: 4.0,
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
                            onTap: () {
                              onSelected(option);
                            },
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
                                option['unidade_mostra'] ??
                                    option['unidade_ds'] ??
                                    option['nome'] ??
                                    option['id']?.toString() ??
                                    '',
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
          InlineSingleDatePicker(
            selectedDate: _dataOcorrencia,
            onDateSelected: (date) {
              setState(() => _dataOcorrencia = date);
            },
            onClear: () {
              setState(() => _dataOcorrencia = null);
            },
          ),
          const SizedBox(height: 12),
          CustomInput(
            hintText: 'Local da ocorrência',
            controller: _localController,
          ),
          const SizedBox(height: 12),
          CustomInput(
            hintText: 'Ocorrência',
            maxLines: 5,
            maxLength: 500, // 👉 Adicione esta linha
            controller: _descricaoController,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildTransparentIconGroup(
                context,
                [
                  {
                    'icon': Symbols.ink_eraser,
                    'color': IconColors.delete(context),
                    'tooltip': 'Limpar formulário',
                    'onPressed': () {
                      setState(() {
                        _unidadeSelecionada = null;
                        _dataOcorrencia = null;
                        _localController.clear();
                        _descricaoController.clear();
                        _imagemSelecionada = null;
                        _imagemBase64 = null;
                      });
                    },
                  },
                  {
                    'icon': _imagemSelecionada != null
                        ? Icons.image
                        : Icons.upload_rounded,
                    'color': IconColors.camera(context),
                    'tooltip': _imagemSelecionada != null
                        ? 'Imagem selecionada'
                        : 'Upload de imagem',
                    'onPressed': _selecionarImagem,
                  },
                  {
                    'icon': Symbols.photo_camera,
                    'color': IconColors.camera(context),
                    'tooltip': _imagemBase64 != null
                        ? 'Foto capturada'
                        : 'Capturar foto',
                    'onPressed': _abrirCamera,
                  },
                  {
                    'key': _registrarOcorrenciaKey,
                    'icon': Symbols.send,
                    'color': Colors.green,
                    'tooltip': 'Registrar ocorrência',
                    'onPressed': _registrarOcorrencia,
                    'isLoading': _loadingRegistro,
                  },
                ],
              ),
            ],
          ),
          InlineFeedbackWidget(
            message: _feedbackMessage,
            color: _feedbackColor,
          ),
          if (_imagemBase64 != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getBorderColor(context)),
                      color: getBackgroundColor(context),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        base64Decode(_imagemBase64!.contains(',')
                            ? _imagemBase64!.split(',').last
                            : _imagemBase64!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image,
                                    color: getSecondaryTextColor(context)),
                                const SizedBox(height: 8),
                                Text(
                                  'Erro ao carregar imagem',
                                  style: TextStyle(
                                      color: getSecondaryTextColor(context),
                                      fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() {
                            _imagemBase64 = null;
                            _imagemSelecionada = null;
                          });
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
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
  }

  Widget _buildHistoricoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilterTab(
          title: 'Filtros de Histórico',
          themeColor: const Color(0xFFF59E0B), // Amarelo da aba Ocorrências
          icon: Icons.tune,
          initiallyExpanded: false,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (context, constraints) {
                return Autocomplete<Map<String, dynamic>>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _unidades;
                    }
                    return _unidades.where((Map<String, dynamic> option) {
                      final String optionString = (option['unidade_mostra'] ??
                              option['unidade_ds'] ??
                              option['nome'] ??
                              option['id']?.toString() ??
                              '')
                          .toString()
                          .toLowerCase();
                      return optionString
                          .contains(textEditingValue.text.toLowerCase());
                    });
                  },
                  displayStringForOption: (Map<String, dynamic> option) =>
                      option['unidade_mostra'] ??
                      option['unidade_ds'] ??
                      option['nome'] ??
                      option['id']?.toString() ??
                      'Sem nome',
                  onSelected: (Map<String, dynamic> value) {
                    // Implementar filtro por unidade se necessário
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode,
                      onFieldSubmitted) {
                    return CharacterCounterField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      decoration: inputDecorationPadrao(
                        context,
                        labelText: 'Unidade',
                      ).copyWith(
                        suffixIcon: textEditingController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.close,
                                    size: 20,
                                    color: getSecondaryTextColor(context)),
                                onPressed: () {
                                  textEditingController.clear();
                                },
                              )
                            : const Icon(Icons.arrow_drop_down,
                                color: Colors.grey),
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
                                    (option['unidade_mostra'] ??
                                            option['unidade_ds'] ??
                                            option['nome'] ??
                                            option['id']?.toString() ??
                                            'Sem nome')
                                        .toString(),
                                    style:
                                        TextStyle(color: getTextColor(context)),
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
              InlinePeriodPicker(
                startDate: _filtroDataInicio,
                endDate: _filtroDataFim,
                onClear: () => setState(() {
                  _filtroDataInicio = null;
                  _filtroDataFim = null;
                }),
                onRangeSelected: (start, end) {
                  setState(() {
                    _filtroDataInicio = start;
                    _filtroDataFim = end;
                  });
                  _carregarHistorico();
                },
                // ❌ A propriedade 'trailing' foi removida daqui
              ),

              // 👇 ADICIONAMOS UM ESPAÇAMENTO E OS BOTÕES EM UMA NOVA LINHA
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
                          _carregarHistorico();
                        },
                      },
                      {
                        'icon': Symbols.ink_eraser,
                        'color': IconColors.delete(context),
                        'tooltip': 'Limpar filtros',
                        'onPressed': () {
                          setState(() {
                            _filtroDataInicio = null;
                            _filtroDataFim = null;
                          });
                          _carregarHistorico();
                        },
                      },
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // 2. ESPAÇAMENTO ENTRE FILTROS E RESULTADOS
        const SizedBox(height: 12),

        // 3. LISTA DE OCORRÊNCIAS
        Expanded(
          child: _loadingHistorico
              ? AppLoading.loadingIndicator(message: 'Carregando histórico...')
              : _historicoOcorrencias.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history,
                              size: 48, color: getSecondaryTextColor(context)),
                          const SizedBox(height: 8),
                          Text(
                            'Sem ocorrências registradas',
                            style: TextStyle(
                              color: getSecondaryTextColor(context),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _historicoOcorrencias.length,
                      itemBuilder: (context, index) {
                        final ocorrencia = _historicoOcorrencias[index];
                        return _buildOcorrenciaItem(
                          '${ocorrencia['nomeusu_intr'] ?? ''} - ${ocorrencia['unidadeusu_intr'] ?? ''} /${ocorrencia['prediousu_intr'] ?? ''} registrou em ${(ocorrencia['dt_ocorrencia'] ?? ocorrencia['data'] ?? '').split(' ').first}',
                          ocorrencia['mensagem_txt'] ?? '',
                          'Local: ${ocorrencia['local_txt'] ?? 'Não especificado'}',
                          // 👇 ADICIONE ESTAS DUAS LINHAS:
                          temFoto: ocorrencia['tem_foto'] == true,
                          linkFoto: ocorrencia['link_foto'] as String?,
                        );
                      },
                    ),
        ),
      ],
    );
  }

  //-----------------------------//
  // Detalhe em Texto Simples
  //-----------------------------//
  Widget _buildTextDetail(String label, String? value) {
    return SizedBox(
      width: 140, // Largura fixa para criar colunas alinhadas no Wrap
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: getSecondaryTextColor(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value ?? 'N/A',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: getTextColor(context),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOcorrenciaItem(String date, String title, String author,
      {bool temFoto = false, String? linkFoto}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context), width: 1),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start, // Garante que fiquem alinhados no topo
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date,
                    style: TextStyle(
                        fontSize: 12,
                        color: getSecondaryTextColor(context),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text(title,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: getTextColor(context))),
                if (author.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(author,
                      style: TextStyle(
                          fontSize: 12, color: getSecondaryTextColor(context))),
                ],
              ],
            ),
          ),
          // 👇 BOTÃO PARA A FOTO
          if (temFoto && linkFoto != null && linkFoto.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: IconButton(
                icon: const Icon(Icons.image),
                color: IconColors.camera(
                    context), // Mantendo o seu padrão de cores
                tooltip: 'Ver foto anexada',
                onPressed: () => _mostrarFotoModal(linkFoto),
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
          labelText: 'Período',
        ),
        child: Text(
          (startDate != null || endDate != null)
              ? _formatPeriodDisplay(startDate, endDate)
              : '',
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

  String _formatarDataParaDisplay(DateTime date) {
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }

  void _mostrarFotoModal(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // IMAGEM
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: getBackgroundColor(context),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 200,
                      width: 200,
                      alignment: Alignment.center,
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 150,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image,
                            size: 48, color: getSecondaryTextColor(context)),
                        const SizedBox(height: 8),
                        Text('Erro ao carregar imagem',
                            style: TextStyle(
                                color: getSecondaryTextColor(context))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // BOTÃO FECHAR
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.6),
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

  // Carregar unidades
  Future<void> _carregarUnidades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('tokensessao_txt');
      final tokenSessao = (encrypted != null && encrypted.isNotEmpty)
          ? decryptText(encrypted)
          : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('ocorrencias', 'unidades'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Tentar diferentes estruturas de resposta da API
        List<Map<String, dynamic>> unidadesCarregadas = [];

        if (data['data']?['unidades'] is List) {
          // Estrutura: {"data": {"unidades": [...]}} - API unidadelist
          unidadesCarregadas =
              List<Map<String, dynamic>>.from(data['data']['unidades']);
        } else if (data['data'] is List) {
          // Estrutura: {"data": [...]}
          unidadesCarregadas = List<Map<String, dynamic>>.from(data['data']);
        } else if (data['data']?['lista'] is List) {
          // Estrutura: {"data": {"lista": [...]}}
          unidadesCarregadas =
              List<Map<String, dynamic>>.from(data['data']['lista']);
        } else if (data['lista'] is List) {
          // Estrutura: {"lista": [...]}
          unidadesCarregadas = List<Map<String, dynamic>>.from(data['lista']);
        } else if (data is List) {
          // Estrutura: [...]
          unidadesCarregadas = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          _unidades = unidadesCarregadas;
        });
      }
    } catch (e) {
      // Exception loading units
    }
  }

  // Carregar histórico
  Future<void> _carregarHistorico() async {
    setState(() {
      _loadingHistorico = true;
    });

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

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('ocorrencias', 'historico'));

      // Formatar datas para o padrão DD/MM/YYYY
      String dataInicio = "";
      String dataFim = "";
      if (_filtroDataInicio != null) {
        dataInicio =
            "${_filtroDataInicio!.day.toString().padLeft(2, '0')}/${_filtroDataInicio!.month.toString().padLeft(2, '0')}/${_filtroDataInicio!.year}";
      }
      if (_filtroDataFim != null) {
        dataFim =
            "${_filtroDataFim!.day.toString().padLeft(2, '0')}/${_filtroDataFim!.month.toString().padLeft(2, '0')}/${_filtroDataFim!.year}";
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "data_inicio": dataInicio,
          "data_fim": dataFim,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Tentar diferentes estruturas de resposta da API
        List<Map<String, dynamic>> listaCompleta = [];

        if (data['data']?['ocorrencias'] is List) {
          // Estrutura: {"data": {"ocorrencias": [...]}} - API ocorrencialist
          listaCompleta =
              List<Map<String, dynamic>>.from(data['data']['ocorrencias']);
        } else if (data['data'] is List) {
          // Estrutura: {"data": [...]}
          listaCompleta = List<Map<String, dynamic>>.from(data['data']);
        } else if (data['data']?['lista'] is List) {
          // Estrutura: {"data": {"lista": [...]}}
          listaCompleta =
              List<Map<String, dynamic>>.from(data['data']['lista']);
        } else if (data['lista'] is List) {
          // Estrutura: {"lista": [...]}
          listaCompleta = List<Map<String, dynamic>>.from(data['lista']);
        }

        setState(() {
          _historicoOcorrencias = listaCompleta.take(10).toList();
        });
      } else {
        print(
            'Erro ao carregar ocorrências: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Exception loading history
    } finally {
      setState(() {
        _loadingHistorico = false;
      });
    }
  }

  // Registrar ocorrência
  Future<void> _registrarOcorrencia() async {
    if (_unidadeSelecionada == null) {
      setState(() {
        _feedbackMessage = 'Selecione uma unidade para a ocorrência.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    if (_localController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Digite o local da ocorrência.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    if (_descricaoController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Digite a descrição da ocorrência.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    // Starting registration process
    setState(() {
      _loadingRegistro = true;
      _feedbackMessage = null; // Clear previous feedback
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
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (tokenSessao.isEmpty) {
        setState(() {
          _feedbackMessage = 'Sua sessão expirou. Faça login novamente.';
          _feedbackColor = Colors.red;
        });
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('ocorrencias', 'registrar'));

      // Formatar data para o padrão ISO 8601 se selecionada
      String dataOcorrencia = "";
      if (_dataOcorrencia != null) {
        dataOcorrencia =
            "${_dataOcorrencia!.year.toString().padLeft(4, '0')}-${_dataOcorrencia!.month.toString().padLeft(2, '0')}-${_dataOcorrencia!.day.toString().padLeft(2, '0')}T00:00:00.000";
      }

      final payload = {
        "canal_id": 496,
        "categoriasac_id": 5,
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "dt_ocorrencia": dataOcorrencia,
        "flg_mostra": "N",
        "fotobase64": _imagemBase64 ?? "",
        "id_terceiro": "",
        "ip": "[IP_ADDRESS]",
        "local_txt": _localController.text.trim(),
        "mensagem_txt": _descricaoController.text.trim(),
        "nota_num": 0,
        "prioridade_num": 0,
        "sac_id": 0,
        "statussac_id": 114,
        "subject": "",
        "titulo_txt": "Ocorrência via portaria",
        "usuario_atende": _unidadeSelecionada!['usuario_id']?.toString() ?? "",
        "usuario_interacao": int.tryParse(usuarioId)?.toString() ?? "",
        "usuario_reclamado": 0,
        "usuario_solicita": int.tryParse(usuarioId)?.toString() ?? "",
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
        setState(() {
          _feedbackMessage = 'Ocorrência registrada com sucesso!';
          _feedbackColor = Colors.green;
          _unidadeSelecionada = null;
          _dataOcorrencia = null;
          _imagemSelecionada = null;
          _imagemBase64 = null;
        });

        // Limpar formulário
        _localController.clear();
        _descricaoController.clear();

        // Recarregar histórico
        await _carregarHistorico();
      } else {
        setState(() {
          _feedbackMessage = 'Erro ao registrar ocorrência.';
          _feedbackColor = Colors.red;
        });
      }
    } catch (e) {
      setState(() {
        _feedbackMessage = 'Erro de conexão com o servidor.';
        _feedbackColor = Colors.red;
      });
    } finally {
      setState(() {
        _loadingRegistro = false;
      });
    }
  }
}
