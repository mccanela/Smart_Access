import 'package:flutter/material.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import '../../core/utils/ui_standards.dart';

class InlineSingleDatePicker extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime date) onDateSelected;
  final VoidCallback? onClear;
  final String label;

  const InlineSingleDatePicker({
    super.key,
    this.selectedDate,
    required this.onDateSelected,
    this.onClear,
    this.label = 'Data',
  });

  @override
  State<InlineSingleDatePicker> createState() => _InlineSingleDatePickerState();
}

class _InlineSingleDatePickerState extends State<InlineSingleDatePicker> {
  bool _expanded = false;
  Key _calendarKey = UniqueKey();

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.selectedDate != null;
    final isDark = isDarkMode(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
              if (_expanded) {
                _calendarKey = UniqueKey();
                widget.onClear?.call();
              }
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: InputDecorator(
            isEmpty: !hasValue && !_expanded,
            decoration: inputDecorationPadrao(
              context,
              labelText: widget.label,
              suffixIcon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: getSecondaryTextColor(context),
              ),
              prefixIcon: Icon(
                Icons.calendar_today_outlined,
                size: 18,
                color: getSecondaryTextColor(context),
              ),
            ),
            child: hasValue
                ? Text(
                    _formatDate(widget.selectedDate!),
                    style: TextStyle(
                      fontSize: 14,
                      color: getTextColor(context),
                    ),
                  )
                : null,
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _expanded
              ? Container(
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black : getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getBorderColor(context)),
                  ),
                  child: CalendarDatePicker2(
                    key: _calendarKey,
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
                    value: const [],
                    onValueChanged: (dates) {
                      if (dates.isNotEmpty) {
                        widget.onDateSelected(dates[0]);
                        setState(() => _expanded = false);
                      }
                    },
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
