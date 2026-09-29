import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/utils/ui_standards.dart';
import '../../shared/widgets/character_counter_field.dart';

class PassagensModal extends StatelessWidget {
  final VoidCallback onClose;
  final TextEditingController documentoController;
  final TextEditingController nomeController;
  final TextEditingController placaController;
  final VoidCallback onClear;
  final VoidCallback onSearch;
  final bool isLoading;
  final List<Map<String, dynamic>> historicoFiltrado;

  // Callbacks para os componentes complexos do Dashboard
  final Widget Function() buildUnidadeAutocomplete;
  final Widget Function() buildPeriodFilter;
  final Widget Function(Map<String, dynamic> passagem, int index)
      buildPassagemCard;

  const PassagensModal({
    super.key,
    required this.onClose,
    required this.documentoController,
    required this.nomeController,
    required this.placaController,
    required this.onClear,
    required this.onSearch,
    required this.isLoading,
    required this.historicoFiltrado,
    required this.buildUnidadeAutocomplete,
    required this.buildPeriodFilter,
    required this.buildPassagemCard,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: MediaQuery.of(context).size.width * 0.4,
      color: isDark ? const Color(0xFF111827) : Colors.white,
      child: Column(
        children: [
          // 👇 CABEÇALHO AZUL IDÊNTICO À IMAGEM
          Container(
            color: const Color(0xFF0277BD),
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.directions_walk, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Text('Histórico de Passagens',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
                IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: onClose)
              ],
            ),
          ),
          // 👇 CORPO DO PAINEL LATERAL
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 👇 CAIXA DE FILTROS ESTILO DA IMAGEM (Borda azul clara)
                  Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFF4F9FD),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.blue.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    color: isDark
                                        ? Colors.grey.shade700
                                        : Colors.blue.shade100)),
                          ),
                          child: Text('Filtros de Passagens',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade300
                                      : const Color(0xFF0277BD),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16)),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: CharacterCounterField(
                                      controller: documentoController,
                                      labelText: 'Documento',
                                      maxLength: 14,
                                      decoration: inputDecorationPadrao(context,
                                          hintText: 'Documento'),
                                      onSubmitted: (_) => onSearch(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: buildUnidadeAutocomplete(),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: CharacterCounterField(
                                      controller: nomeController,
                                      labelText: 'Nome e Sobrenome',
                                      maxLength: 50,
                                      decoration: inputDecorationPadrao(context,
                                          hintText: 'Nome e Sobrenome'),
                                      onSubmitted: (_) => onSearch(),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: CharacterCounterField(
                                      controller: placaController,
                                      labelText: 'Placa',
                                      maxLength: 7,
                                      decoration: inputDecorationPadrao(context,
                                          hintText: 'Placa'),
                                      onSubmitted: (_) => onSearch(),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              buildPeriodFilter(),
                              const SizedBox(height: 16),
                              // 👇 PÍLULA DE BOTÕES COMO NA IMAGEM
                              Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.white,
                                    border: Border.all(
                                        color: isDark
                                            ? Colors.grey.shade600
                                            : Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Tooltip(
                                        message: 'Limpar filtros',
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: onClear,
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 8.0),
                                            child: Icon(Symbols.ink_eraser,
                                                color: Color(0xFF9C27B0),
                                                size: 22),
                                          ),
                                        ),
                                      ),
                                      Container(
                                          width: 1,
                                          height: 20,
                                          color: isDark
                                              ? Colors.grey.shade600
                                              : Colors.grey.shade300),
                                      Tooltip(
                                        message: 'Pesquisar',
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: isLoading ? null : onSearch,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12.0,
                                                vertical: 8.0),
                                            child: isLoading
                                                ? const SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                            strokeWidth: 2))
                                                : const Icon(Symbols.search,
                                                    color: Color(0xFF03A9F4),
                                                    size: 22),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 👇 RESULTADOS DO HISTÓRICO NO PAINEL LATERAL
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : historicoFiltrado.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.search_off,
                                        size: 48, color: Colors.grey.shade400),
                                    const SizedBox(height: 16),
                                    Text('Nenhum resultado encontrado.',
                                        style: TextStyle(
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                itemCount: historicoFiltrado.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox.shrink(),
                                itemBuilder: (context, index) {
                                  return buildPassagemCard(
                                      historicoFiltrado[index], index);
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
