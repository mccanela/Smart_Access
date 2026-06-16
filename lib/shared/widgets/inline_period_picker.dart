import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../core/utils/ui_standards.dart';

class InlinePeriodPicker extends StatefulWidget {
  final DateTime? startDate;
  final DateTime? endDate;
  final Function(DateTime startDate, DateTime endDate) onRangeSelected;
  final VoidCallback? onClear;
  final Widget? trailing;

  const InlinePeriodPicker({
    super.key,
    this.startDate,
    this.endDate,
    required this.onRangeSelected,
    this.onClear,
    this.trailing,
  });

  @override
  State<InlinePeriodPicker> createState() => _InlinePeriodPickerState();
}

class _InlinePeriodPickerState extends State<InlinePeriodPicker> {
  bool _expanded = false;
  int _calKey = 0;

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatDisplay() {
    if (widget.startDate == null && widget.endDate == null) return '';
    if (widget.startDate != null && widget.endDate != null) {
      return '${_formatDate(widget.startDate!)} até ${_formatDate(widget.endDate!)}';
    }
    if (widget.startDate != null) {
      return 'A partir de ${_formatDate(widget.startDate!)}';
    }
    return 'Até ${_formatDate(widget.endDate!)}';
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.startDate != null || widget.endDate != null;
    final isDark = isDarkMode(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    if (_expanded) {
                      _expanded = false;
                    } else {
                      _calKey++;
                      _expanded = true;
                    }
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  isEmpty: !hasValue && !_expanded,
                  decoration: inputDecorationPadrao(
                    context,
                    labelText: 'Período',
                    suffixIcon: Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: getSecondaryTextColor(context),
                    ),
                  ),
                  child: hasValue && !_expanded
                      ? Text(
                          _formatDisplay(),
                          style: TextStyle(
                            fontSize: 14,
                            color: getTextColor(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                ),
              ),
            ),
            if (widget.trailing != null) ...[
              const SizedBox(width: 12),
              widget.trailing!,
            ],
          ],
        ),
        if (_expanded)
          Container(
            key: ValueKey('period_cal_$_calKey'),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.black : getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: getBorderColor(context)),
            ),
            child: StableRangeCalendar(
              onDone: (start, end) {
                setState(() => _expanded = false);
                widget.onClear?.call();
                Future.microtask(() {
                  widget.onRangeSelected(start, end);
                });
              },
            ),
          ),
      ],
    );
  }
}

/// Widget completamente isolado que gerencia o CalendarDatePicker2.
/// Nunca é reconstruído pelo parent — só pelo key change.
class StableRangeCalendar extends StatefulWidget {
  final void Function(DateTime start, DateTime end) onDone;
  const StableRangeCalendar({super.key, required this.onDone});

  @override
  State<StableRangeCalendar> createState() => StableRangeCalendarState();
}

class StableRangeCalendarState extends State<StableRangeCalendar> {
  DateTime? _first =
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime? _second;
  @override
  Widget build(BuildContext context) {
    // Montar lista de datas selecionadas para exibição
    final List<DateTime?> displayDates = [];
    if (_first != null) displayDates.add(_first);
    if (_second != null) displayDates.add(_second);

    return CalendarDatePicker2(
      config: CalendarDatePicker2Config(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime(2015),
        lastDate: DateTime(2030),
        currentDate: DateTime.now(),
        selectedDayHighlightColor: const Color(0xFF684F8E),
        dayTextStyle: TextStyle(
          fontSize: 14,
          color: getTextColor(context),
        ),
        weekdayLabelTextStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: getSecondaryTextColor(context),
        ),
        controlsTextStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: getTextColor(context),
        ),
        dayBorderRadius: BorderRadius.circular(4),
        selectedDayTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      value: displayDates,
      onValueChanged: (dates) {
        if (dates.isEmpty) return;
        final tapped = dates[0];

        setState(() {
          if (_first == null || _second != null) {
            // Primeiro clique ou reset
            _first = tapped;
            _second = null;
          } else {
            // Segundo clique — ordenar automaticamente
            if (tapped.isBefore(_first!)) {
              _second = _first;
              _first = tapped;
            } else {
              _second = tapped;
            }
          }
        });

        if (_first != null && _second != null) {
          Future.microtask(() => widget.onDone(_first!, _second!));
        }
      },
    );
  }
}
