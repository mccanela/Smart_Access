import 'package:flutter/material.dart';
import '../../../core/utils/ui_standards.dart';

class MiniSegmented extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final void Function(int) onChanged;
  final Color color;

  const MiniSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final icons = <IconData>[];
    for (final label in labels) {
      final l = label.toLowerCase();
      if (l.contains('p. servi') || l.contains('p.servi') || l.contains('prestador')) {
        icons.add(Icons.build);
      } else if (l.contains('visitante')) {
        icons.add(Icons.person);
      } else {
        icons.add(Icons.help_outline);
      }
    }

    final isDark = isDarkMode(context);
    final selectedIconColor = isDark ? Colors.blue[400] : const Color(0xFF1E3A8A);
    final unselectedIconColor = isDark ? Colors.grey[400] : const Color(0xFF9CA3AF);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: getBorderColor(context), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < labels.length; i++)
            Tooltip(
              message: labels[i],
              waitDuration: const Duration(milliseconds: 200),
              preferBelow: false,
              enableFeedback: true,
              decoration: BoxDecoration(
                color: selected == i ? selectedIconColor : Colors.grey.shade700,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              textStyle: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  height: 40,
                  alignment: Alignment.center,
                  child: Icon(
                    icons[i],
                    size: 22,
                    color: selected == i ? selectedIconColor : unselectedIconColor,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
