import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class SegmentedTabBar extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final void Function(int) onChanged;
  final Color color;
  final List<String>? tooltips;

  const SegmentedTabBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
    required this.color,
    this.tooltips,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segmentColor = _getSegmentColor(isDark);
    final icons = _getIcons();

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF3C3C43).withValues(alpha: 0.18),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            () {
              final widget = GestureDetector(
                onTap: () => onChanged(i),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color:
                          selected == i ? segmentColor : Colors.transparent,
                      boxShadow: selected == i
                          ? [
                              BoxShadow(
                                color: segmentColor.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icons[i],
                            size: 18,
                            color: selected == i
                                ? Colors.white
                                : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade600),
                          ),
                          if (selected == i) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                labels[i],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
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

              final withTooltip = (tooltips != null && i < tooltips!.length)
                  ? Tooltip(message: tooltips![i], child: widget)
                  : widget;
              return selected == i
                  ? Expanded(child: withTooltip)
                  : withTooltip;
            }(),
          ],
        ],
      ),
    );
  }

  Color _getSegmentColor(bool isDark) {
    final firstLabel = labels.first.toLowerCase();
    if (firstLabel.contains('entrada') ||
        firstLabel.contains('saída') ||
        firstLabel.contains('saidas') ||
        firstLabel.contains('avulso')) {
      return const Color(0xFF00C853);
    } else if (firstLabel.contains('agendamentos')) {
      return const Color(0xFF7338E6);
    } else if (firstLabel.contains('unidade') ||
        firstLabel.contains('unidades')) {
      return const Color(0xFF7C38A5);
    } else if (firstLabel.contains('encomendas') ||
        firstLabel.contains('entregar')) {
      return const Color(0xFFFF6D00);
    }
    return color;
  }

  List<IconData> _getIcons() {
    return labels.map((label) {
      final l = label.toLowerCase();
      if (l.contains('entrada')) return Icons.login;
      if (l.contains('saída') || l.contains('saidas')) return Icons.logout;
      if (l.contains('passagens')) return Icons.directions_walk;
      if (l.contains('agendamentos')) return Icons.calendar_today;
      if (l.contains('avulso')) return Icons.badge;
      if (l.contains('unidade') || l.contains('unidades')) return Icons.business;
      if (l.contains('veículos') || l.contains('veiculo')) return Icons.directions_car;
      if (l.contains('vagas')) return Symbols.garage;
      if (l.contains('encomendas')) return Symbols.package_2;
      if (l.contains('entregar')) return Symbols.hand_package;
      if (l.contains('conectcon') || l.contains(' ia') || l == 'ia') {
        return Icons.smart_toy_outlined;
      }
      return Icons.help_outline;
    }).toList();
  }
}
