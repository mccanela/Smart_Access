part of '../dashboard.dart';

class _TipoDocumentoSelector extends StatefulWidget {
  final List<String> tiposDocumento;
  final String? valorSelecionado;
  final ValueChanged<String?> onChanged;

  const _TipoDocumentoSelector({
    required this.tiposDocumento,
    required this.valorSelecionado,
    required this.onChanged,
  });

  @override
  State<_TipoDocumentoSelector> createState() => _TipoDocumentoSelectorState();
}

class _TipoDocumentoSelectorState extends State<_TipoDocumentoSelector> {
  bool _isExpanded = false;
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Campo principal
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDarkMode(context)
                    ? const Color(0xFF374151)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode(context)
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.valorSelecionado ?? 'Selecione...',
                      style: TextStyle(
                        color: widget.valorSelecionado != null
                            ? (isDarkMode(context)
                                ? Colors.white
                                : Colors.black)
                            : (isDarkMode(context)
                                ? Colors.grey[400]
                                : const Color(0xFF6B7280)),
                        fontSize: 16,
                      ),
                    ),
                  ),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: isDarkMode(context)
                        ? Colors.grey[400]
                        : const Color(0xFF6B7280),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Lista expansível
          if (_isExpanded)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: isDarkMode(context)
                    ? const Color(0xFF374151)
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDarkMode(context)
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFD1D5DB),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: widget.tiposDocumento.map((tipo) {
                  final isSelected = widget.valorSelecionado == tipo;
                  return GestureDetector(
                    onTap: () {
                      widget.onChanged(tipo);
                      setState(() {
                        _isExpanded = false;
                      });
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDarkMode(context)
                                ? const Color(0xFF4B5563)
                                : const Color(0xFFF3F4F6))
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tipo,
                        style: TextStyle(
                          color:
                              isDarkMode(context) ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w500 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
