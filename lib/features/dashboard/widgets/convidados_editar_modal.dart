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
  late TextEditingController _documentoController;
  late TextEditingController _nomeController;
  late TextEditingController _modeloController;
  late TextEditingController _placaController;
  late TextEditingController _obsController;

  final FocusNode _documentoFocusNode = FocusNode();
  final FocusNode _nomeFocusNode = FocusNode();
  final FocusNode _modeloFocusNode = FocusNode();
  final FocusNode _placaFocusNode = FocusNode();
  final FocusNode _obsFocusNode = FocusNode();

  Map<String, dynamic>? _selectedMarca;
  Map<String, dynamic>? _selectedCor;
  Map<String, dynamic>? _selectedVaga;

  String? _fotoRostoEntrada;
  bool _isLoading = false;

  bool _isErrorsalvar = false;
  String? _mensagemSalvar;

  @override
  void initState() {
    super.initState();
    final c = widget.convidado;

// 👇 Garante que se vier nulo, ele transforma em texto vazio real
    String documentoValue =
        (c['documento'] ?? c['documento_txt'] ?? '').toString();

    if (documentoValue == "Não Informado" || documentoValue == "null") {
      documentoValue = "";
    }

    _documentoController = TextEditingController(text: (documentoValue));
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

    // 👇 Removido o sinal de exclamação usando interpolação segura
    print(' _fotoRostoEntrada WIDGET.CONVIDADO $_fotoRostoEntrada');

    if (_fotoRostoEntrada == 'null') _fotoRostoEntrada = null;
  }

  @override
  void dispose() {
    _documentoController.dispose();
    _nomeController.dispose();
    _modeloController.dispose();
    _placaController.dispose();
    _obsController.dispose();

    _documentoFocusNode.dispose();
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

  bool _validarFormulario() {
    final doc = _documentoController.text.trim();

    // Valida o Documento
    if (doc.isEmpty || doc.toLowerCase() == "não informado") {
      FeedbackUtils.showWarning(
        context: context,
        title: 'Atenção',
        message: 'O preenchimento do Documento é obrigatório.',
      );
      return false; // Interrompe a execução
    }

    if (!Utilities.isDocumentoValido(doc)) {
      FeedbackUtils.showWarning(
          context: context,
          title: 'Documento Inválido',
          message: 'O documento preenchido não é um CPF, CNPJ ou RG válido.');
      return false;
    }

    // Aproveitamos para mover a validação do Nome para cá, centralizando tudo!
    if (_nomeController.text.trim().isEmpty) {
      FeedbackUtils.showWarning(
        context: context,
        title: 'Atenção',
        message: 'Preencha o Nome do convidado.',
      );
      return false; // Interrompe a execução
    }

    return true; // Tudo certo, pode seguir!
  }

  Map<String, dynamic> _getDadosAtualizados() {
    final dados = Map<String, dynamic>.from(widget.convidado);

    final doc = _documentoController.text.trim();
    if (doc.toLowerCase() == "não informado") {
      dados['documento'] = "";
    } else {
      dados['documento'] = Utilities.removerPontuacao(doc);
    }

    dados['nome'] = _nomeController.text.trim();
    dados['modelo'] = _modeloController.text.trim();
    dados['placa'] = _placaController.text.trim();
    dados['observacao'] = _obsController.text.trim();
    dados['foto'] = _fotoRostoEntrada;

    if (_selectedMarca != null) dados['marca_id'] = _selectedMarca!['id'];
    if (_selectedCor != null) dados['cor_id'] = _selectedCor!['id'];
    if (_selectedVaga != null) {
      dados['vaga_id'] = _selectedVaga!['id'] ?? _selectedVaga!['vaga_id'];
    }

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

    String documentoValue = (widget.convidado['documento'] ??
            widget.convidado['documento_txt'] ??
            '')
        .toString();

    if (documentoValue == "Não Informado") {
      documentoValue = "";
    }

    // Identifica no build() se é um novo convidado
    final isNovo = documentoValue == "" ||
        (widget.convidado['reservaconvidado_id'] == 0) ||
        (widget.convidado['id'] == 0);

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
                  // CAMPO DOCUMENTO CONDICIONAL
                  isNovo
                      ? CharacterCounterField(
                          controller: _documentoController,
                          maxLength: 14,
                          labelText: 'Documento',
                          focusNode: _documentoFocusNode,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16),
                          inputFormatters: [
                            DocumentoFormatter(),
                          ],
                          decoration: inputDecorationPadrao(context,
                              hintText: 'Documento'),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: getBorderColor(context)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Informe o Documento',
                                style: TextStyle(
                                  color: getSecondaryTextColor(context),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                documentoValue,
                                style: TextStyle(
                                  // 👇 Cor mais clara (estilo placeholder) se estiver vazio
                                  color: documentoValue.isNotEmpty
                                      ? getTextColor(context)
                                      : getSecondaryTextColor(context)
                                          .withValues(alpha: 0.6),
                                  fontSize: 16,
                                  // 👇 Tira o negrito se for o placeholder
                                  fontWeight: documentoValue.isNotEmpty
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ),
                  const SizedBox(height: 12),

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
                                // 1. Valida o formulário antes de prosseguir
                                if (!_validarFormulario()) return;

                                setState(() {
                                  _isLoading = true;
                                  _isErrorsalvar = false;
                                  _mensagemSalvar = null;
                                });
                                try {
                                  final dadosAtualizados =
                                      _getDadosAtualizados();

                                  // 2. Chama a API de atualização diretamente de dentro do modal
                                  await ConvidadosApi
                                      .AtualizarConvidadoAgendamento(
                                          dadosAtualizados);

                                  setState(() {
                                    _isErrorsalvar = false;
                                    _mensagemSalvar =
                                        'Dados do convidado salvos com sucesso!';
                                  });

                                  // 3. Chama o callback do Dashboard apenas para atualizar a tela
                                  await widget.onSalvar(dadosAtualizados);

                                  //fecharPainelLateralGlobal();
                                } catch (e) {
                                  // 👇 Exibe o erro na própria tela em vez do popup
                                  setState(() {
                                    _isErrorsalvar = true;
                                    _mensagemSalvar = e
                                        .toString()
                                        .replaceAll('Exception: ', '');
                                  });
                                } finally {
                                  setState(() => _isLoading = false);
                                }
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
                                  if (!_validarFormulario()) return;
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
                                  if (!_validarFormulario()) return;
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
                  if (_mensagemSalvar != null && _mensagemSalvar!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _isErrorsalvar
                              ? const Icon(Icons.error_outline,
                                  color: Colors.red, size: 16)
                              : const Icon(Icons.save_outlined,
                                  color: Colors.green, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _mensagemSalvar!,
                              style: TextStyle(
                                color:
                                    _isErrorsalvar ? Colors.red : Colors.green,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
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
