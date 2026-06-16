import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
// Import removed
import 'package:material_symbols_icons/symbols.dart';
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/utils/ui_standards.dart';
import '../../core/theme/icon_colors.dart';
import '../../shared/widgets/custom_imput.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../shared/widgets/inline_feedback.dart';
import '../../shared/widgets/inline_period_picker.dart';

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
                    fontWeight: FontWeight.bold,
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
        final isDark = isDarkMode(context);

        return GestureDetector(
          onTap: () => _onDateSelected(currentDate),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isStart || isEnd
                  ? const Color(0xFF1E40AF)
                  : isInRange
                      ? isDark
                          ? const Color(0xFF1E40AF).withValues(alpha: 0.35)
                          : const Color(0xFF1E40AF).withValues(alpha: 0.1)
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
                          ? isDark
                              ? Colors.white
                              : const Color(0xFF1E40AF)
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
    {bool isLoading = false, bool isOpaque = false, double? iconSize}) {
  final tooltipMessage = isOpaque ? '$tooltip (desabilitado)' : tooltip;

  return Tooltip(
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

class AlertasScreen extends StatefulWidget {
  final VoidCallback onClose;
  const AlertasScreen({super.key, required this.onClose});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  bool _loadingHistorico = false;
  bool _loadingRegistroAlerta = false;
  bool _loadingRegistroPanico = false;

  // Controllers
  final _tituloController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _searchHistoricoController = TextEditingController();

  // Dados
  List<Map<String, dynamic>> _historicoAlertasOriginal = [];
  List<Map<String, dynamic>> _historicoAlertasFiltrados = [];
  List<Map<String, dynamic>> _listaAlertas = [];
  Map<String, dynamic>? _categoriaSelecionada;
  Uint8List? _fotoAlerta;
  String? _extensaoFoto;
  DateTime? _filtroDataInicioHistorico;
  DateTime? _filtroDataFimHistorico;
  String? _feedbackMessage;
  Color? _feedbackColor;

  @override
  void initState() {
    super.initState();

    // Adicionar dados iniciais para evitar tela vazia
    _listaAlertas = [
      {
        'id': 1,
        'titulo': 'Carregando categorias...',
        'categoria_ds': 'Carregando...'
      },
    ];

    _carregarListaAlertas();
    _carregarHistorico();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _descricaoController.dispose();
    _searchHistoricoController.dispose();
    super.dispose();
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
            icon: Icons.notifications,
            title: 'Alertas',
            onClose: widget.onClose,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildNovoAlertaPanel()),
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

  Widget _buildNovoAlertaPanel() {
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
              Icon(Icons.notifications, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text('Novo Alerta', style: AppTextStyles.title(context)),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, constraints) {
            return Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(
                text: _categoriaSelecionada != null
                    ? (_categoriaSelecionada!['descricao'] ?? '')
                    : '',
              ),
              optionsBuilder: (TextEditingValue textEditingValue) {
                if (textEditingValue.text.isEmpty) {
                  return _listaAlertas;
                }
                return _listaAlertas.where((Map<String, dynamic> option) {
                  return (option['descricao'] ?? '')
                      .toString()
                      .toLowerCase()
                      .contains(textEditingValue.text.toLowerCase());
                });
              },
              displayStringForOption: (Map<String, dynamic> option) =>
                  (option['descricao'] ?? '').toString(),
              onSelected: (Map<String, dynamic> value) {
                setState(() {
                  _categoriaSelecionada = value;
                  _descricaoController.text = value['descricao'] ?? '';
                });
              },
              fieldViewBuilder: (context, textEditingController, focusNode,
                  onFieldSubmitted) {
                return CharacterCounterField(
                  controller: textEditingController,
                  focusNode: focusNode,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Tipo de alerta',
                  ).copyWith(
                    suffixIcon: textEditingController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () {
                              textEditingController.clear();
                              setState(() {
                                _categoriaSelecionada = null;
                                _descricaoController.clear();
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
                                (option['descricao'] ?? 'Sem descrição')
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
            hintText: 'Alerta',
            controller: _tituloController,
          ),
          const SizedBox(height: 12),
          CustomInput(
            hintText: 'Descrição do alerta',
            maxLines: 5,
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
                        _tituloController.clear();
                        _descricaoController.clear();
                        _categoriaSelecionada = null;
                        _fotoAlerta = null;
                      });
                    },
                  },
                  {
                    'icon': Symbols.photo_camera,
                    'color': IconColors.camera(context),
                    'tooltip': 'Capturar foto',
                    'onPressed': _capturarFoto,
                    'isLoading': false,
                  },
                  {
                    'icon': Symbols.send,
                    'color': Colors.green,
                    'tooltip': 'Registrar alerta',
                    'onPressed': _registrarAlerta,
                    'isLoading': _loadingRegistroAlerta,
                  },
                  {
                    'icon': Icons.warning_amber_rounded,
                    'color': Colors.red,
                    'tooltip': 'Registrar pânico',
                    'onPressed': _registrarPanico,
                    'isLoading': _loadingRegistroPanico,
                  },
                ],
              ),
            ],
          ),
          InlineFeedbackWidget(
            message: _feedbackMessage,
            color: _feedbackColor,
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
          const SizedBox(height: 20),
          InlinePeriodPicker(
            startDate: _filtroDataInicioHistorico,
            endDate: _filtroDataFimHistorico,
            onClear: () => setState(() {
              _filtroDataInicioHistorico = null;
              _filtroDataFimHistorico = null;
            }),
            onRangeSelected: (start, end) {
              setState(() {
                _filtroDataInicioHistorico = start;
                _filtroDataFimHistorico = end;
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
                      _filtroDataInicioHistorico = null;
                      _filtroDataFimHistorico = null;
                      _searchHistoricoController.clear();
                    });
                    _carregarHistorico();
                  },
                },
              ],
            ),
          ),
          const SizedBox(height: 20),
          CharacterCounterField(
            controller: _searchHistoricoController,
            decoration: inputDecorationPadrao(
              context,
              labelText: 'Pesquisar alertas',
            ),
            onChanged: (value) => _onSearchChanged(value),
          ),
          const SizedBox(height: 20),
          const SizedBox(height: 20),
          Expanded(
            child: _loadingHistorico
                ? AppLoading.loadingIndicator(
                    message: 'Carregando histórico...')
                : _historicoAlertasFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.notifications_off_outlined,
                                size: 48,
                                color: getSecondaryTextColor(context)),
                            const SizedBox(height: 8),
                            Text('Sem alertas registrados',
                                style: TextStyle(
                                    color: getSecondaryTextColor(context),
                                    fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _historicoAlertasFiltrados.length,
                        itemBuilder: (context, index) {
                          final alerta = _historicoAlertasFiltrados[index];
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
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          alerta['data'] ??
                                              alerta['dt_ocorrencia'] ??
                                              alerta['dt_registro'] ??
                                              '',
                                          style: TextStyle(
                                            color:
                                                getSecondaryTextColor(context),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alerta['titulo'] ??
                                              alerta['titulo_txt'] ??
                                              'Sem título',
                                          style: TextStyle(
                                            color: getTextColor(context),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if ((alerta['mensagem'] ??
                                                alerta['texto'] ??
                                                alerta['descricao'] ??
                                                '')
                                            .toString()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            alerta['mensagem'] ??
                                                alerta['texto'] ??
                                                alerta['descricao'] ??
                                                '',
                                            style: TextStyle(
                                              color: getSecondaryTextColor(
                                                  context),
                                              fontSize: 12,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        if ((alerta['nomeusu_solicita'] ??
                                                alerta['usuario_nome'] ??
                                                alerta['usuario'] ??
                                                '')
                                            .toString()
                                            .isNotEmpty)
                                          Text(
                                            'Por: ${alerta['nomeusu_solicita'] ?? alerta['usuario_nome'] ?? alerta['usuario'] ?? ''}',
                                            style: TextStyle(
                                              color: getSecondaryTextColor(
                                                  context),
                                              fontSize: 12,
                                            ),
                                          ),
                                        if ((alerta['unidade_mostra'] ??
                                                alerta['unidade'] ??
                                                '')
                                            .toString()
                                            .isNotEmpty)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 4),
                                            child: Text(
                                              alerta['unidade_mostra'] ??
                                                  alerta['unidade'] ??
                                                  '',
                                              style: TextStyle(
                                                color: getSecondaryTextColor(
                                                    context),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
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

  // Carregar lista de alertas
  Future<void> _carregarListaAlertas() async {
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

      final url = Uri.parse(
          '${ApiConfig.getEndpoint('alertas', 'categorias')}?pai=1753');

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
        setState(() {
          _listaAlertas =
              List<Map<String, dynamic>>.from(data['data']?['lista'] ?? []);
        });
      }
    } catch (e) {
      // Exception loading alerts list
    }
  }

  // Carregar histórico de alertas
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

      final url = Uri.parse(ApiConfig.getEndpoint('alertas', 'historico'));

      // Formatar período para o padrão DD/MM/YYYY
      String dataInicioFormatada = "";
      String dataFimFormatada = "";
      if (_filtroDataInicioHistorico != null) {
        dataInicioFormatada =
            "${_filtroDataInicioHistorico!.day.toString().padLeft(2, '0')}/${_filtroDataInicioHistorico!.month.toString().padLeft(2, '0')}/${_filtroDataInicioHistorico!.year}";
      }
      if (_filtroDataFimHistorico != null) {
        dataFimFormatada =
            "${_filtroDataFimHistorico!.day.toString().padLeft(2, '0')}/${_filtroDataFimHistorico!.month.toString().padLeft(2, '0')}/${_filtroDataFimHistorico!.year}";
      }

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
          "data_inicio": dataInicioFormatada,
          "data_fim": dataFimFormatada,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // A API retorna em data.alertas, não data.lista
        final lista =
            List<Map<String, dynamic>>.from(data['data']?['alertas'] ?? []);
        print('📋 [ALERTAS] Total de alertas recebidos: ${lista.length}');
        if (lista.isNotEmpty) {
          print('📋 [ALERTAS] Primeiro alerta: ${lista.first}');
        }
        setState(() {
          _historicoAlertasOriginal = lista;
          _historicoAlertasFiltrados = _historicoAlertasOriginal;
        });
        print(
            '📋 [ALERTAS] Cards montados: ${_historicoAlertasFiltrados.length}');
      } else {
        print(
            '❌ [ALERTAS] Erro na API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Exception loading history
    } finally {
      setState(() {
        _loadingHistorico = false;
      });
    }
  }

  // Função para filtrar alertas
  void _filtrarAlertas(String query) {
    if (query.isEmpty) {
      setState(() {
        _historicoAlertasFiltrados = _historicoAlertasOriginal;
      });
    } else {
      setState(() {
        _historicoAlertasFiltrados = _historicoAlertasOriginal.where((alerta) {
          final titulo = (alerta['titulo'] ?? '').toString().toLowerCase();
          final descricao =
              (alerta['descricao'] ?? '').toString().toLowerCase();
          final queryLower = query.toLowerCase();
          return titulo.contains(queryLower) || descricao.contains(queryLower);
        }).toList();
      });
    }
  }

  // Função para conectar o controller de busca ao filtro
  void _onSearchChanged(String query) {
    _filtrarAlertas(query);
  }

  // Capturar foto
  Future<void> _capturarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera);

    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _fotoAlerta = bytes;
        _extensaoFoto = 'jpg';
      });
    }
  }

  // Registrar alerta
  Future<void> _registrarAlerta() async {
    if (_categoriaSelecionada == null) {
      setState(() {
        _feedbackMessage = 'Selecione um tipo de alerta.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    if (_tituloController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Digite um título para o alerta.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    setState(() {
      _loadingRegistroAlerta = true;
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

      final url = Uri.parse(ApiConfig.getEndpoint('alertas', 'registrar'));

      // Preparar payload para alerta normal
      Map<String, dynamic> payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "avisocategoria_id": 1, // FIXO para alerta normal
        "usuariode_id": int.tryParse(usuarioId) ?? 0,
        "titulo": _tituloController.text.trim(),
        "texto": _descricaoController.text.trim(),
        "url": "",
        "ip": "11111111",
        "textodisplay": "", // FIXO
        "funcoes_id": 5, // FIXO
        "flg_agora": "S", // FIXO
        "flg_sms": "N", // FIXO
        "extensao": _extensaoFoto ?? "",
        "fotobase64": _fotoAlerta != null ? base64Encode(_fotoAlerta!) : "",
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
        // Sucesso: mostrar feedback elegante
        setState(() {
          _feedbackMessage = 'Alerta registrado com sucesso!';
          _feedbackColor = Colors.green;
          _categoriaSelecionada = null;
          _fotoAlerta = null;
          _extensaoFoto = null;
        });
        _tituloController.clear();
        _descricaoController.clear();

        // Recarregar histórico
        await _carregarHistorico();
      } else {
        setState(() {
          _feedbackMessage = 'Erro ao registrar alerta.';
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
        _loadingRegistroAlerta = false;
      });
    }
  }

  Future<void> _registrarPanico() async {
    if (_tituloController.text.trim().isEmpty) {
      setState(() {
        _feedbackMessage = 'Digite um título para o pânico.';
        _feedbackColor = Colors.red;
      });
      return;
    }

    setState(() {
      _loadingRegistroPanico = true;
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

      final url = Uri.parse(ApiConfig.getEndpoint('alertas', 'registrar'));

      // Preparar payload para pânico
      Map<String, dynamic> payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "avisocategoria_id": 33, // FIXA para pânico
        "usuariode_id": int.tryParse(usuarioId) ?? 0,
        "titulo": _tituloController.text.trim(),
        "texto": _descricaoController.text.trim(),
        "url": "",
        "ip": "11111111",
        "textodisplay": "", // FIXO
        "funcoes_id": 140, // FIXO para pânico
        "flg_agora": "S", // FIXO
        "flg_sms": "N", // FIXO
        "extensao": _extensaoFoto ?? "",
        "fotobase64": _fotoAlerta != null ? base64Encode(_fotoAlerta!) : "",
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
          _feedbackMessage = 'Pânico registrado com sucesso!';
          _feedbackColor = Colors.green;
          _categoriaSelecionada = null;
          _fotoAlerta = null;
          _extensaoFoto = null;
        });
        _tituloController.clear();
        _descricaoController.clear();

        // Recarregar histórico
        await _carregarHistorico();
      } else {
        setState(() {
          _feedbackMessage = 'Erro ao registrar pânico.';
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
        _loadingRegistroPanico = false;
      });
    }
  }

  Widget _buildPeriodFilter({
    required BuildContext context,
    required DateTime? startDate,
    required DateTime? endDate,
    required Function(DateTime?) onStartDateChanged,
    required Function(DateTime?) onEndDateChanged,
    required Function() onPeriodSelected,
  }) {
    String formatPeriodDisplay(DateTime? startDate, DateTime? endDate) {
      if (startDate == null && endDate == null) {
        return '';
      }

      String formatDate(DateTime date) {
        return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
      }

      final startStr = startDate != null ? formatDate(startDate) : '';
      final endStr = endDate != null ? formatDate(endDate) : '';

      if (startDate != null && endDate != null) {
        return '$startStr até $endStr';
      } else if (startDate != null) {
        return 'A partir de $startStr';
      } else {
        return 'Até $endStr';
      }
    }

    return InkWell(
      onTap: () => _showPeriodPicker(context, startDate, endDate,
          onStartDateChanged, onEndDateChanged, onPeriodSelected),
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
          formatPeriodDisplay(startDate, endDate),
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

  Future<void> _showPeriodPicker(
    BuildContext context,
    DateTime? currentStartDate,
    DateTime? currentEndDate,
    Function(DateTime?) onStartDateChanged,
    Function(DateTime?) onEndDateChanged,
    Function() onPeriodSelected,
  ) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return RangeCalendarDialog(
          onRangeSelected: (startDate, endDate) {
            onStartDateChanged(startDate);
            onEndDateChanged(endDate);
            onPeriodSelected();
          },
        );
      },
    );
  }
}
