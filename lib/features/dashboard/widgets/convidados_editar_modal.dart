part of '../dashboard.dart';

class EditarConvidadoModal extends StatefulWidget {
  final Map<String, dynamic> convidado;
  final List<Map<String, dynamic>> marcasList;
  final List<Map<String, dynamic>> coresList;
  final List<Map<String, dynamic>> vagasList;

  final Future<void> Function(Map<String, dynamic> dadosAtualizados) onEntrada;
  final Future<void> Function(Map<String, dynamic> dadosAtualizados) onSaida;
  final Future<void> Function(Map<String, dynamic> dadosAtualizados) onSalvar;

  const EditarConvidadoModal({
    super.key,
    required this.convidado,
    required this.marcasList,
    required this.coresList,
    required this.vagasList,
    required this.onEntrada,
    required this.onSaida,
    required this.onSalvar,
  });

  @override
  State<EditarConvidadoModal> createState() => _EditarConvidadoModalState();
}

class _EditarConvidadoModalState extends State<EditarConvidadoModal> {
  late TextEditingController _nomeController;
  late TextEditingController _modeloController;
  late TextEditingController _placaController;
  late TextEditingController _obsController;

  final FocusNode _nomeFocusNode = FocusNode();
  final FocusNode _modeloFocusNode = FocusNode();
  final FocusNode _placaFocusNode = FocusNode();
  final FocusNode _obsFocusNode = FocusNode();

  Map<String, dynamic>? _selectedMarca;
  Map<String, dynamic>? _selectedCor;
  Map<String, dynamic>? _selectedVaga;

  String? _fotoRostoEntrada;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.convidado;

    _nomeController =
        TextEditingController(text: c['nome'] ?? c['convidado_txt'] ?? '');
    _modeloController = TextEditingController(
        text: c['modelo'] ?? c['veiculo'] ?? c['veiculo_txt'] ?? '');
    _placaController = TextEditingController(text: c['placa'] ?? '');
    _obsController =
        TextEditingController(text: c['observacao'] ?? c['obs'] ?? '');

    try {
      if (c['marca_id'] != null && c['marca_id'].toString() != '0') {
        _selectedMarca = widget.marcasList.firstWhere(
            (m) => m['id'].toString() == c['marca_id'].toString(),
            orElse: () => <String, dynamic>{});
        if (_selectedMarca!.isEmpty) _selectedMarca = null;
      }
    } catch (_) {}

    try {
      if (c['cor_id'] != null && c['cor_id'].toString() != '0') {
        _selectedCor = widget.coresList.firstWhere(
            (cor) => cor['id'].toString() == c['cor_id'].toString(),
            orElse: () => <String, dynamic>{});
        if (_selectedCor!.isEmpty) _selectedCor = null;
      }
    } catch (_) {}

    try {
      if (c['vaga_id'] != null && c['vaga_id'].toString() != '0') {
        _selectedVaga = widget.vagasList.firstWhere(
            (v) =>
                (v['id'] ?? v['vaga_id']).toString() == c['vaga_id'].toString(),
            orElse: () => <String, dynamic>{});
        if (_selectedVaga!.isEmpty) _selectedVaga = null;
      }
    } catch (_) {}

    _fotoRostoEntrada = c['link_foto']?.toString() ?? c['foto']?.toString();
    if (_fotoRostoEntrada == 'null') _fotoRostoEntrada = null;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    _obsController.dispose();
    _nomeFocusNode.dispose();
    _modeloFocusNode.dispose();
    _placaFocusNode.dispose();
    _obsFocusNode.dispose();
    super.dispose();
  }

  Future<void> _tirarFotoRosto() async {
    final completer = Completer<String?>();
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (ctx) => Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Fundo escuro (Barrier)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  overlayEntry.remove();
                  if (!completer.isCompleted) completer.complete(null);
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                ),
              ),
            ),
            // Modal de Captura
            Center(
              child: FacialCaptureModal(
                // Interceptamos o clique de fechar (X)
                onClose: () {
                  overlayEntry.remove();
                  if (!completer.isCompleted) completer.complete(null);
                },
                // Interceptamos a captura da foto
                onCapture: (String fotoBase64) {
                  overlayEntry.remove();
                  if (!completer.isCompleted) completer.complete(fotoBase64);
                },
              ),
            ),
          ],
        ),
      ),
    );

    // Injeta a tela na camada MAIS ALTA possível do Flutter (acima do painel lateral)
    Overlay.of(context, rootOverlay: true).insert(overlayEntry);

    // Fica aguardando a interação do usuário na modal
    final result = await completer.future;

    if (result != null && result.isNotEmpty) {
      setState(() {
        _fotoRostoEntrada = result;
      });
    }
  }

  Map<String, dynamic> _getDadosAtualizados() {
    final dados = Map<String, dynamic>.from(widget.convidado);
    dados['nome'] = _nomeController.text.trim();
    dados['modelo'] = _modeloController.text.trim();
    dados['placa'] = _placaController.text.trim();
    dados['observacao'] = _obsController.text.trim();
    dados['foto'] = _fotoRostoEntrada;

    if (_selectedMarca != null) dados['marca_id'] = _selectedMarca!['id'];
    if (_selectedCor != null) dados['cor_id'] = _selectedCor!['id'];
    if (_selectedVaga != null)
      dados['vaga_id'] = _selectedVaga!['id'] ?? _selectedVaga!['vaga_id'];

    return dados;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;

    final entradaStr =
        (widget.convidado['entrada'] ?? widget.convidado['dt_entrada'] ?? '')
            .toString();
    final saidaStr =
        (widget.convidado['saida'] ?? widget.convidado['dt_saida'] ?? '')
            .toString();
    bool jaDeuEntrada = entradaStr.isNotEmpty;
    bool jaDeuSaida = saidaStr.isNotEmpty;

    return Container(
      padding: const EdgeInsets.only(top: 8),
      child: SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // COLUNA 1: FOTO CAPTURADA E BOTÃO
            // ==========================================
            Container(
              width: 300, // Largura ideal para a foto
              margin: const EdgeInsets.only(right: 20),
              child: Column(
                children: [
                  Container(
                    height: 300,
                    width: 300,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getBorderColor(context)),
                    ),
                    child: _fotoRostoEntrada != null &&
                            _fotoRostoEntrada!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _fotoRostoEntrada!.startsWith('http')
                                ? Image.network(
                                    _fotoRostoEntrada!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(Icons.person_outline,
                                                color: Colors.grey, size: 60),
                                  )
                                : () {
                                    final bytes =
                                        _safeBase64Decode(_fotoRostoEntrada);
                                    if (bytes != null) {
                                      return Image.memory(
                                        bytes,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.person_outline,
                                                    color: Colors.grey,
                                                    size: 60),
                                      );
                                    }
                                    return const Icon(Icons.person_outline,
                                        color: Colors.grey, size: 60);
                                  }(),
                          )
                        : const Icon(Icons.person_outline,
                            color: Colors.grey, size: 60),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _tirarFotoRosto,
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text('Capturar',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade300
                            : Colors.blue.shade700,
                        side: BorderSide(
                            color: isDark
                                ? Colors.blue.shade300
                                : Colors.blue.shade700),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==========================================
            // COLUNA 2: FORMULÁRIO E AÇÕES
            // ==========================================
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CharacterCounterField(
                    controller: _nomeController,
                    maxLength: 50,
                    labelText: 'Nome e Sobrenome',
                    focusNode: _nomeFocusNode,
                    style: const TextStyle(fontSize: 16),
                    decoration: inputDecorationPadrao(context,
                        hintText: 'Nome e Sobrenome'),
                  ),
                  const SizedBox(height: 12),

                  isSmallScreen
                      ? Column(
                          children: [
                            buildStandardAutocomplete<Map<String, dynamic>>(
                              context: context,
                              labelText: 'Marca',
                              items: widget.marcasList,
                              itemAsString: (item) =>
                                  item['descricao'] ?? 'Marca',
                              selectedItem: _selectedMarca,
                              onSelected: (value) {
                                setState(() {
                                  _selectedMarca = value;
                                  if (value == null) _selectedCor = null;
                                });
                              },
                              constraints: const BoxConstraints(maxHeight: 250),
                            ),
                            const SizedBox(height: 12),
                            CharacterCounterField(
                                controller: _modeloController,
                                labelText: 'Modelo Veículo',
                                maxLength: 30,
                                focusNode: _modeloFocusNode,
                                decoration: inputDecorationPadrao(context,
                                    hintText: 'Modelo Veículo')),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText: 'Marca',
                                items: widget.marcasList,
                                itemAsString: (item) =>
                                    item['descricao'] ?? 'Marca',
                                selectedItem: _selectedMarca,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedMarca = value;
                                    if (value == null) _selectedCor = null;
                                  });
                                },
                                constraints:
                                    const BoxConstraints(maxHeight: 250),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: CharacterCounterField(
                                  controller: _modeloController,
                                  labelText: 'Modelo Veículo',
                                  maxLength: 30,
                                  focusNode: _modeloFocusNode,
                                  decoration: inputDecorationPadrao(context,
                                      hintText: 'Modelo Veículo')),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),

                  isSmallScreen
                      ? Column(
                          children: [
                            CharacterCounterField(
                                controller: _placaController,
                                labelText: 'Placa',
                                maxLength: 8,
                                focusNode: _placaFocusNode,
                                decoration: inputDecorationPadrao(context,
                                    hintText: 'Placa')),
                            const SizedBox(height: 12),
                            buildStandardAutocomplete<Map<String, dynamic>>(
                              context: context,
                              labelText: 'Cor',
                              items: widget.coresList,
                              itemAsString: (item) =>
                                  item['descricao'] ?? 'Cor',
                              selectedItem: _selectedCor,
                              onSelected: (value) {
                                setState(() {
                                  _selectedCor = value;
                                  if (value == null) _selectedMarca = null;
                                });
                              },
                              constraints: const BoxConstraints(maxHeight: 250),
                            ),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: CharacterCounterField(
                                  controller: _placaController,
                                  labelText: 'Placa',
                                  maxLength: 8,
                                  focusNode: _placaFocusNode,
                                  decoration: inputDecorationPadrao(context,
                                      hintText: 'Placa')),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: buildStandardAutocomplete<
                                  Map<String, dynamic>>(
                                context: context,
                                labelText: 'Cor',
                                items: widget.coresList,
                                itemAsString: (item) =>
                                    item['descricao'] ?? 'Cor',
                                selectedItem: _selectedCor,
                                onSelected: (value) {
                                  setState(() {
                                    _selectedCor = value;
                                    if (value == null) _selectedMarca = null;
                                  });
                                },
                                constraints:
                                    const BoxConstraints(maxHeight: 250),
                              ),
                            ),
                          ],
                        ),
                  const SizedBox(height: 12),

                  buildStandardAutocomplete<Map<String, dynamic>>(
                    context: context,
                    labelText: 'Vaga',
                    items: widget.vagasList,
                    itemAsString: (v) {
                      final txt = (v['vaga_txt'] ??
                              v['vaga'] ??
                              v['vaga_nome'] ??
                              v['descricao'] ??
                              '')
                          .toString();
                      final local = (v['local'] ?? '').toString();
                      return [txt, local]
                          .where((e) => e.isNotEmpty)
                          .join(' • ');
                    },
                    selectedItem: _selectedVaga,
                    onSelected: (value) {
                      setState(() {
                        _selectedVaga = value;
                      });
                    },
                    constraints: const BoxConstraints(maxHeight: 250),
                  ),
                  const SizedBox(height: 12),

                  CharacterCounterField(
                    controller: _obsController,
                    labelText: 'Observação',
                    maxLength: 255,
                    focusNode: _obsFocusNode,
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                    decoration:
                        inputDecorationPadrao(context, hintText: 'Observação'),
                  ),
                  const SizedBox(height: 24),

                  // ==========================================
                  // BOTÕES DE AÇÃO: SALVAR / ENTRADA / SAÍDA
                  // ==========================================
                  Align(
                    alignment: Alignment.centerRight,
                    child: TransparentIconGroup([
                      IconActionData(
                        icon: Symbols.close,
                        tooltip: 'Cancelar Edição',
                        color: Colors.grey,
                        onPressed: () => fecharPainelLateralGlobal(),
                      ),
                      IconActionData(
                        icon: Icons.save_outlined,
                        color: Colors.blue,
                        tooltip: 'Salvar Dados',
                        isLoading: _isLoading,
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() => _isLoading = true);
                                await widget.onSalvar(_getDadosAtualizados());
                                setState(() => _isLoading = false);
                              },
                      ),
                      if (jaDeuEntrada && !jaDeuSaida)
                        IconActionData(
                          icon: Icons.logout,
                          tooltip: 'Registrar Saída',
                          color: Colors.red,
                          isMarked: true,
                          isLoading: _isLoading,
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  setState(() => _isLoading = true);
                                  await widget.onSaida(_getDadosAtualizados());
                                  setState(() => _isLoading = false);
                                },
                        ),
                      if (!jaDeuEntrada)
                        IconActionData(
                          icon: Icons.login,
                          tooltip: 'Registrar Entrada',
                          color: Colors.green,
                          isMarked: true,
                          isLoading: _isLoading,
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_nomeController.text.trim().isEmpty) {
                                    FeedbackUtils.showWarning(
                                        context: context,
                                        title: 'Atenção',
                                        message:
                                            'Preencha o Nome do convidado.');
                                    return;
                                  }
                                  if (_fotoRostoEntrada == null ||
                                      _fotoRostoEntrada!.isEmpty) {
                                    FeedbackUtils.showWarning(
                                        context: context,
                                        title: 'Foto Ausente',
                                        message:
                                            'Use o botão Capturar para anexar uma foto.');
                                    return;
                                  }
                                  setState(() => _isLoading = true);
                                  await widget
                                      .onEntrada(_getDadosAtualizados());
                                  setState(() => _isLoading = false);
                                },
                        ),
                    ]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
