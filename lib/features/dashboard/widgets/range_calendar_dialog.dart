part of '../dashboard.dart';

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
                  'Período de Agendamento',
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
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
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
                CupertinoButton(
                  color: const Color(0xFF1E40AF),
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
    // weekday: 1=Mon..7=Sun. Grid starts on Sunday (column 0).
    final startOffset = firstDayOfMonth.weekday % 7; // Sun=0, Mon=1...Sat=6

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
        final day = index - startOffset + 1;

        if (day < 1 || day > daysInMonth) {
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
        // Segunda seleçao - definir fim do range
        if (date.isBefore(selectedRange.start)) {
          selectedRange = DateTimeRange(start: date, end: selectedRange.start);
        } else {
          selectedRange = DateTimeRange(start: selectedRange.start, end: date);
        }
      } else {
        // Nova seleçao - reset
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
