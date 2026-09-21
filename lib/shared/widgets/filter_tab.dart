import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class FilterTab extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color themeColor; // Cor principal (Azul, Roxo, etc)
  final Widget content;
  final bool initiallyExpanded;

  const FilterTab({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.tune, // Ícone padrão de filtros
    required this.themeColor,
    this.initiallyExpanded = true,
  });

  @override
  State<FilterTab> createState() => _FilterTabState();
}

class _FilterTabState extends State<FilterTab> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Mistura a cor tema com branco (modo escuro) ou preto (modo claro) para o texto
    final textColor = isDark
        ? Color.lerp(widget.themeColor, Colors.white, 0.3)!
        : Color.lerp(widget.themeColor, Colors.black, 0.2)!;

    final borderColor = widget.themeColor.withOpacity(0.3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: borderColor, width: 1.0), // Borda fina e sutil
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // CABEÇALHO EXPANSÍVEL
          GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                // Removido o gradiente, usando cor sólida suave baseada no tema
                color: isDark
                    ? widget.themeColor.withOpacity(0.15)
                    : widget.themeColor.withOpacity(0.08),
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(11))
                    : BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Icon(widget.icon, size: 18, color: textColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      CupertinoIcons.chevron_down,
                      size: 18,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CORPO DO FILTRO (Animação de tamanho)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isExpanded
                ? ClipRect(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          top: 20, left: 16, right: 16, bottom: 16),
                      child: widget.content,
                    ),
                  )
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}
