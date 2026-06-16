part of '../dashboard.dart';

class _ModalSelecaoEspacosSociais extends StatefulWidget {
  final List<Map<String, dynamic>> espacos;
  final Map<int, bool> selecoesIniciais;

  const _ModalSelecaoEspacosSociais({
    required this.espacos,
    required this.selecoesIniciais,
  });

  @override
  State<_ModalSelecaoEspacosSociais> createState() =>
      _ModalSelecaoEspacosSociaisState();
}

class _ModalSelecaoEspacosSociaisState
    extends State<_ModalSelecaoEspacosSociais> {
  late Map<int, bool> _selecoes;

  @override
  void initState() {
    super.initState();
    _selecoes = Map<int, bool>.from(widget.selecoesIniciais);
  }

  IconData _getIconData(String? icone) {
    switch (icone) {
      case 'Add Home Work':
        return Symbols.home_work;
      case 'Truck':
        return Symbols.local_shipping;
      case 'Id Card Alt':
        return Symbols.badge;
      case 'Tools':
        return Symbols.construction;
      case 'Emoji People Rounded':
        return Symbols.emoji_people;
      case 'Event':
        return Symbols.event_note;
      case 'Users':
        return Symbols.groups;
      case 'Home':
        return Symbols.home;
      case 'Celebration':
        return Symbols.celebration;
      case 'Electric':
        return Symbols.electric_car;
      default:
        return Symbols.event;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = screenWidth > 600 ? 600.0 : screenWidth * 0.9;
    final dialogMaxHeight = screenHeight * 0.8;
    final itemWidth = (dialogWidth - 48 - 16) / 2; // Largura para 2 por linha

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Tipo de agendamento',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(context),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: getTextColor(context)),
                  onPressed: () => Navigator.of(context).pop(null),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Lista de checkboxes (2 por linha, responsivo)
            Flexible(
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Em telas muito pequenas, mostrar 1 por linha
                    final isSmallScreen = constraints.maxWidth < 400;
                    final itemWidthCalculated =
                        isSmallScreen ? constraints.maxWidth : itemWidth;

                    return Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: widget.espacos.map((espaco) {
                        final id = espaco['espacopublico_id'] as int? ?? 0;
                        final descricao =
                            espaco['espacopublico_ds'] as String? ?? '';
                        final icone = espaco['icone'] as String?;
                        final isSelected = _selecoes[id] ?? false;

                        return SizedBox(
                          width: itemWidthCalculated,
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selecoes[id] = !isSelected;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: getCardColor(context),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? Theme.of(context).primaryColor
                                      : getBorderColor(context),
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        _selecoes[id] = value ?? false;
                                      });
                                    },
                                    fillColor: isSelected
                                        ? WidgetStateProperty.all(
                                            Theme.of(context).primaryColor,
                                          )
                                        : null,
                                    checkColor:
                                        isSelected ? Colors.white : null,
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _getIconData(icone),
                                    color: isSelected
                                        ? (isDarkMode(context)
                                            ? Colors.white
                                            : Theme.of(context).primaryColor)
                                        : getTextColor(context)
                                            .withValues(alpha: 0.7),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      descricao,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: getTextColor(context),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Botões no estilo Cupertino (responsivo)
            LayoutBuilder(
              builder: (context, constraints) {
                final isSmallScreen = constraints.maxWidth < 400;
                return isSmallScreen
                    ? Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton.filled(
                              onPressed: () {
                                final selecionados = _selecoes.entries
                                    .where((e) => e.value)
                                    .map((e) => e.key)
                                    .toList();
                                Navigator.of(context).pop(selecionados);
                              },
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                              borderRadius: BorderRadius.circular(8),
                              child: const Text(
                                'Confirmar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: CupertinoButton(
                              onPressed: () => Navigator.of(context).pop(null),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(
                                  color: CupertinoColors.label
                                      .resolveFrom(context),
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          CupertinoButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(
                                color:
                                    CupertinoColors.label.resolveFrom(context),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          CupertinoButton.filled(
                            onPressed: () {
                              final selecionados = _selecoes.entries
                                  .where((e) => e.value)
                                  .map((e) => e.key)
                                  .toList();
                              Navigator.of(context).pop(selecionados);
                            },
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 8),
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
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}
