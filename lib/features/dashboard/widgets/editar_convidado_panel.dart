part of '../dashboard.dart';

class _EditarConvidadoPanel extends StatefulWidget {
  final Map<String, dynamic> convidado;
  final String reservaId;

  const _EditarConvidadoPanel({
    required this.convidado,
    required this.reservaId,
  });

  @override
  State<_EditarConvidadoPanel> createState() => _EditarConvidadoPanelState();
}

class _EditarConvidadoPanelState extends State<_EditarConvidadoPanel> {
  String? _fotoBase64;
  String? _fotoConvidadoApi; // Foto carregada da API unidadefoto
  final bool _carregandoFoto = false;
  bool _salvando = false;

  // Controladores para os campos editáveis
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  String? _tipoDocumentoSelecionado;
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _autorizanteController = TextEditingController();
  final TextEditingController _creciController = TextEditingController();
  final TextEditingController _quantPessoasController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _veiculoController = TextEditingController();
  final TextEditingController _vagaFlgController = TextEditingController();

  // Opá§ões para tipo de documento
  final List<String> _tiposDocumento = ['RG', 'CPF', 'ID', 'Passaport'];

  @override
  void initState() {
    super.initState();
    _inicializarCampos();
  }

  @override
  void dispose() {
    // Dispose de todos os controladores
    _nomeController.dispose();
    _emailController.dispose();
    _documentoController.dispose();
    _empresaController.dispose();
    _autorizanteController.dispose();
    _creciController.dispose();
    _quantPessoasController.dispose();
    _placaController.dispose();
    _veiculoController.dispose();
    _vagaFlgController.dispose();
    super.dispose();
  }

  void _inicializarCampos() {
    print('_inicializarCampos() foi chamado para convidado!');
    // Inicializar campos com dados do convidado (dados básicos primeiro)
    _nomeController.text =
        widget.convidado['nome'] ?? widget.convidado['convidado_txt'] ?? '';
    _emailController.text = widget.convidado['email_txt'] ?? '';
    _tipoDocumentoSelecionado = widget.convidado['tipodoc_txt'];
    _documentoController.text = widget.convidado['documento'] ??
        widget.convidado['documento_txt'] ??
        '';
    _empresaController.text = widget.convidado['empresa_txt'] ?? '';
    _autorizanteController.text = widget.convidado['autorizante_txt'] ?? '';
    _creciController.text = widget.convidado['creci_txt'] ?? '';
    _quantPessoasController.text = (widget.convidado['quant_pessoas'] ??
            widget.convidado['agregados'] ??
            1)
        .toString();
    _placaController.text = widget.convidado['placa'] ?? '';
    _veiculoController.text =
        widget.convidado['veiculo'] ?? widget.convidado['veiculo_txt'] ?? '';
    _vagaFlgController.text = widget.convidado['vaga_flg'] ?? '';

    // Carregar foto do convidado via API foto (com pequeno delay para garantir inicializaçao)
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted) {
        _carregarFotoConvidado();
      }
    });
  }

  // Método para obter valor válido do tipo documento
  String? _getValidTipoDocumentoValue() {
    return _tiposDocumento.contains(_tipoDocumentoSelecionado)
        ? _tipoDocumentoSelecionado
        : null;
  }

  // Método para obter items do dropdown de tipos documento
  List<DropdownMenuItem<String>> _getTiposDocumentoItems() {
    return _tiposDocumento.map<DropdownMenuItem<String>>((tipo) {
      return DropdownMenuItem<String>(
        value: tipo,
        child: Text(tipo),
      );
    }).toList();
  }

  // Método para carregar foto do convidado via API foto
  Future<void> _carregarFotoConvidado() async {
    print('ðŸš€ _carregarFotoConvidado() foi chamado!');
    print('ðŸ“± Widget mounted: $mounted');

    // Usar especificamente o reservaconvidado_id para a API de foto
    final reservaconvidadoId = widget.convidado['reservaconvidado_id'];

    print(
        'Carregando foto do convidado - reservaconvidado_id: $reservaconvidadoId');
    print('Convidado completo (dados iniciais): ${widget.convidado}');

    if (reservaconvidadoId == null) {
      print('reservaconvidado_id é null, não carregando foto');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final url = Uri.parse('${ApiConfig.gateUrl}/foto');
      print('URL da API foto para convidado: $url');

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'reservaconvidado_id': reservaconvidadoId,
        }),
      );

      print(
          'Resposta da API foto para convidado - Status: ${response.statusCode}');
      print('Resposta da API: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        // A estrutura da resposta pode ser diferente, vamos verificar
        print('Estrutura da resposta completa: $responseData');
        print('Estrutura da resposta - chaves: ${responseData.keys}');

        // Tentar diferentes caminhos para encontrar a foto
        String? fotoBase64;
        String caminhoEncontrado = 'nenhum';

        if (responseData['fotobase64'] != null) {
          fotoBase64 = responseData['fotobase64'];
          caminhoEncontrado = 'responseData[fotobase64]';
        } else if (responseData['foto'] != null) {
          fotoBase64 = responseData['foto'];
          caminhoEncontrado = 'responseData[foto]';
        } else if (responseData['data'] != null &&
            responseData['data']['fotobase64'] != null) {
          fotoBase64 = responseData['data']['fotobase64'];
          caminhoEncontrado = 'responseData[data][fotobase64]';
        } else if (responseData['data'] != null &&
            responseData['data']['foto'] != null) {
          fotoBase64 = responseData['data']['foto'];
          caminhoEncontrado = 'responseData[data][foto]';
        }

        print('Caminho da foto encontrado: $caminhoEncontrado');
        print(
            'Foto base64 encontrada: ${fotoBase64 != null ? 'Sim (${fotoBase64.length} caracteres)' : 'Ná£o'}');

        if (fotoBase64 != null && fotoBase64.isNotEmpty) {
          print(
              'Foto base64 original (primeiros 100 chars): ${fotoBase64.substring(0, fotoBase64.length > 100 ? 100 : fotoBase64.length)}');

          // Processar foto removendo prefixo se existir
          String fotoProcessada = fotoBase64
              .replaceFirst('data:image/png;base64,', '')
              .replaceFirst('data:image/jpeg;base64,', '');
          print(
              'Foto processada (primeiros 100 chars): ${fotoProcessada.substring(0, fotoProcessada.length > 100 ? 100 : fotoProcessada.length)}');

          // Testar se a foto processada pode ser decodificada
          try {
            base64Decode(fotoProcessada);
            print('âœ… Foto processada pode ser decodificada com sucesso');
          } catch (decodeError) {
            print('âŒ Erro ao decodificar foto processada: $decodeError');
            // Tentar sem processamento adicional
            try {
              base64Decode(fotoBase64);
              print(
                  'âœ… Foto original (sem processamento) pode ser decodificada');
              fotoProcessada = fotoBase64;
            } catch (originalDecodeError) {
              print(
                  'âŒ Erro ao decodificar foto original também: $originalDecodeError');
            }
          }

          print(
              'Definindo _fotoConvidadoApi com ${fotoProcessada.length} caracteres');
          setState(() {
            _fotoConvidadoApi = fotoProcessada;
          });
          print(
              'Foto do convidado definida com sucesso. _fotoConvidadoApi tem ${_fotoConvidadoApi?.length ?? 0} caracteres');
          print('_fotoBase64 é null? ${_fotoBase64 == null}');

          // A renderizaçao será automática quando setState for chamado
        } else {
          print('Foto base64 do convidado está vazia ou null');
        }
      } else {
        print(
            'Erro na resposta da API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // Silenciosamente ignora erro ao carregar foto do convidado
      print('Erro ao carregar foto do convidado: $e');
    }
  }

  // Funçao para salvar o convidado
  Future<void> _salvarConvidado() async {
    if (_salvando) return;

    setState(() {
      _salvando = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro de Autenticaçao',
          message: 'Token de sessá£o não encontrado',
        );
        return;
      }

      final url =
          Uri.parse('https://socialh.conectcon.net.br/pt-br/convidadoupd');

      final payload = {
        "reserva_id": int.tryParse(widget.reservaId) ?? 0,
        "reservaconvidado_id": widget.convidado['reservaconvidado_id'] ??
            widget.convidado['sequencia'] ??
            0,
        "convidado_txt": _nomeController.text.trim(),
        "email_txt": _emailController.text.trim(),
        "tipodoc_txt": _tipoDocumentoSelecionado ?? '',
        "documento_txt": _documentoController.text.trim(),
        "empresa_txt": _empresaController.text.trim(),
        "autorizante_txt": _autorizanteController.text.trim(),
        "creci_txt": _creciController.text.trim(),
        "quant_pessoas": int.tryParse(_quantPessoasController.text) ?? 1,
        "placa": _placaController.text.trim(),
        "veiculo_txt": _veiculoController.text.trim(),
        "vaga_flg": _vagaFlgController.text.trim(),
        if (_fotoBase64 != null)
          "fotoBase64": _fotoBase64!.replaceFirst('data:image/png;base64,', ''),
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true || data['status'] == 'success') {
          FeedbackUtils.showSuccess(
            context: context,
            title: 'Sucesso',
            message: 'Convidado atualizado com sucesso!',
          );
          fecharPainelLateralGlobal();
        } else {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro ao Salvar',
            message: data['message'] ?? 'Erro ao salvar convidado',
          );
        }
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro na API',
          message: 'Erro na comunicaçao com o servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Erro ao salvar convidado',
        errorDetails: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  // Funçao para abrir a página lateral da câmera
  void _abrirCameraModal() {
    abrirCameraLateral(
      frameType: CameraFrameType.face,
      onPhotoTaken: (String photoDataUrl) {
        print(
            'ðŸ“¸ Foto recebida do painel lateral! Comprimento: ${photoDataUrl.length}');
        print(
            'ðŸ“¸ Início da foto: ${photoDataUrl.substring(0, photoDataUrl.length > 50 ? 50 : photoDataUrl.length)}');
        setState(() {
          _fotoBase64 = photoDataUrl;
        });
        print(
            'âœ… Foto atualizada no estado: _fotoBase64 != null: ${_fotoBase64 != null}');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.48,
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(-2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: getCardColor(context),
              border:
                  Border(bottom: BorderSide(color: getBorderColor(context))),
            ),
            child: Row(
              children: [
                Icon(Icons.person, color: getTextColor(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Editar Convidado',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: getTextColor(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.convidado['nome'] ??
                            widget.convidado['convidado_txt'] ??
                            'Convidado',
                        style: TextStyle(
                          color: getSecondaryTextColor(context),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => fecharPainelLateralGlobal(),
                  icon: Icon(Icons.close, color: getTextColor(context)),
                  tooltip: 'Fechar painel',
                ),
              ],
            ),
          ),

          // Conteúdo
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Foto do convidado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getBorderColor(context)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Foto do Convidado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            print(
                                'ðŸ”„ Renderizando foto - _fotoBase64: ${_fotoBase64 != null ? 'Sim (${_fotoBase64!.length} chars)' : 'Ná£o'}, _fotoConvidadoApi: ${_fotoConvidadoApi != null ? 'Sim (${_fotoConvidadoApi!.length} chars)' : 'Ná£o'}');
                            print(
                                'ðŸ“Š Estado atual: _fotoBase64 starts with: ${_fotoBase64?.substring(0, 20) ?? 'null'}');
                            print(
                                'ðŸ“Š Estado atual: _fotoConvidadoApi starts with: ${_fotoConvidadoApi?.substring(0, 20) ?? 'null'}');

                            if (_fotoBase64 != null) {
                              print('ðŸŽ¯ Exibindo _fotoBase64');
                              try {
                                // Verificar se tem vírgula (data URL completo) ou não
                                final hasComma = _fotoBase64!.contains(',');
                                print(
                                    'ðŸ“Š Foto tem vírgula (data URL): $hasComma');

                                final base64Data = hasComma
                                    ? _fotoBase64!.split(',').last
                                    : _fotoBase64!;
                                print(
                                    'ðŸ“Š Base64 data length: ${base64Data.length}');
                                print(
                                    'ðŸ“Š Base64 data starts with: ${base64Data.substring(0, min(20, base64Data.length))}');

                                final decodedBytes = base64Decode(base64Data);
                                print(
                                    'âœ… Foto decodificada com sucesso! ${decodedBytes.length} bytes');

                                // Verificar se os bytes parecem válidos (PNG header: 89 50 4E 47)
                                if (decodedBytes.length > 8) {
                                  final header = decodedBytes.sublist(
                                      0, min(8, decodedBytes.length));
                                  print(
                                      'ðŸ” PNG Header: ${header.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
                                  print(
                                      'ðŸ“Š á‰ PNG válido: ${header[0] == 0x89 && header[1] == 0x50}');
                                }

                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape
                                        .circle, // â† Forma circular como o enquadramento
                                    image: DecorationImage(
                                      image: MemoryImage(decodedBytes),
                                      fit: BoxFit
                                          .cover, // â† Mantém proporçao e cobre toda a área
                                    ),
                                  ),
                                );
                              } catch (e) {
                                print(
                                    'âŒ Erro ao decodificar foto _fotoBase64: $e');
                                // Fallback para placeholder
                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    shape: BoxShape
                                        .circle, // â† Forma circular consistente
                                  ),
                                  child: const Icon(
                                    Icons.photo,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                );
                              }
                            } else if (_fotoConvidadoApi != null) {
                              print('ðŸŽ¯ Exibindo _fotoConvidadoApi');
                              print(
                                  'ðŸ“¸ Tentando decodificar _fotoConvidadoApi (comprimento: ${_fotoConvidadoApi!.length})');
                              print(
                                  'ðŸ“¸ Primeiros 50 caracteres: ${_fotoConvidadoApi!.substring(0, _fotoConvidadoApi!.length > 50 ? 50 : _fotoConvidadoApi!.length)}');

                              try {
                                print('ðŸ”§ Decodificando base64...');
                                final decodedBytes =
                                    base64Decode(_fotoConvidadoApi!);
                                print(
                                    'âœ… Decodificaçao bem-sucedida! Bytes: ${decodedBytes.length}');

                                print('ðŸŽ¨ Criando MemoryImage...');
                                final memoryImage = MemoryImage(decodedBytes);
                                print('âœ… MemoryImage criado com sucesso');

                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape
                                        .circle, // â† Forma circular consistente
                                    image: DecorationImage(
                                      image: memoryImage,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              } catch (e) {
                                print(
                                    'âŒ Erro ao processar foto do convidado: $e');
                                print('âŒ Tipo do erro: ${e.runtimeType}');
                                if (e is FormatException) {
                                  print(
                                      'âŒ Detalhes do FormatException: ${e.message}');
                                  print('âŒ Offset do erro: ${e.offset}');
                                }
                                return Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: getSurfaceColor(context),
                                    shape: BoxShape
                                        .circle, // â† Forma circular consistente
                                    border:
                                        Border.all(color: Colors.red.shade300),
                                  ),
                                  child: const Icon(Icons.error,
                                      size: 48, color: Colors.red),
                                );
                              }
                            } else {
                              print(
                                  'ðŸŽ¯ Exibindo ícone padrão (nenhuma foto)');
                              return Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: getSurfaceColor(context),
                                  shape: BoxShape
                                      .circle, // â† Forma circular consistente
                                  border: Border.all(
                                      color: getBorderColor(context)),
                                ),
                                child: Icon(
                                  Icons.person,
                                  size: 48,
                                  color: getSecondaryTextColor(context),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _carregandoFoto ? null : _abrirCameraModal,
                          icon: Icon(
                            _carregandoFoto
                                ? Icons.hourglass_empty
                                : Icons.camera_alt,
                            size: 18,
                          ),
                          label: Builder(builder: (context) {
                            final hasFoto = _fotoConvidadoApi != null ||
                                _fotoBase64 != null;
                            final buttonText = _carregandoFoto
                                ? 'Carregando...'
                                : hasFoto
                                    ? 'Cadastrar Nova Foto'
                                    : 'Tirar Foto';
                            print(
                                'ðŸ“ Texto do botá£o: $buttonText (foto API: ${_fotoConvidadoApi != null}, foto tirada: ${_fotoBase64 != null})');
                            return Text(buttonText);
                          }),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF684F8E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Informaá§ões do convidado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: getCardColor(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: getBorderColor(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informaá§ões do Convidado',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: getTextColor(context),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Layout em grid - 2 colunas por fileira
                        _buildFieldRow(
                          _buildEditableField('Nome', _nomeController),
                          _buildEditableField('Email', _emailController),
                        ),
                        _buildFieldRow(
                          Builder(
                            builder: (BuildContext context) => Container(
                              child: DropdownButtonFormField<String>(
                                key: const ValueKey('tipo_documento_dropdown'),
                                initialValue: _getValidTipoDocumentoValue(),
                                decoration: inputDecorationPadrao(context,
                                    hintText: 'Selecione o tipo'),
                                items: _getTiposDocumentoItems(),
                                onChanged: (value) {
                                  if (mounted) {
                                    FocusScope.of(context).unfocus();
                                    setState(() =>
                                        _tipoDocumentoSelecionado = value);
                                  }
                                },
                                isExpanded: true,
                                dropdownColor: getSurfaceColor(context),
                              ),
                            ),
                          ),
                          _buildEditableField(
                              'Documento', _documentoController),
                        ),
                        _buildFieldRow(
                          _buildEditableField('Empresa', _empresaController),
                          _buildEditableField(
                              'Autorizante', _autorizanteController),
                        ),
                        _buildFieldRow(
                          _buildEditableField('CRECI', _creciController),
                          _buildEditableField(
                              'Quantidade de Pessoas', _quantPessoasController,
                              keyboardType: TextInputType.number),
                        ),
                        _buildFieldRow(
                          _buildEditableField('Veículo', _veiculoController),
                          _buildEditableField('Placa', _placaController),
                        ),
                        _buildFieldRow(
                          _buildEditableField('Vaga Flag', _vagaFlgController),
                          const SizedBox(), // Espaá§o vazio para manter alinhamento
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Botões de açao
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _filledButton(
                        'Cancelar',
                        color: Colors.grey.shade500,
                        onTap: () => fecharPainelLateralGlobal(),
                      ),
                      const SizedBox(width: 16),
                      _filledButton(
                        'Salvar',
                        color:
                            _salvando ? Colors.grey : const Color(0xFF1FA463),
                        onTap: _salvando ? null : _salvarConvidado,
                        showLoading: _salvando,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldRow(Widget leftField, Widget rightField) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(child: leftField),
          const SizedBox(width: 12),
          Expanded(child: rightField),
        ],
      ),
    );
  }

  Widget _filledButton(String label,
      {required VoidCallback? onTap,
      required Color color,
      bool showLoading = false}) {
    // Determinar o ícone baseado no label
    IconData? icon;
    if (label == 'Saída') {
      icon = Icons.exit_to_app; // Mesmo ícone do botá£o "Registrar saída"
    } else if (label == 'Entrada') {
      icon = Icons.arrow_back; // Seta invertida para entrada
    } else if (label == 'Incluir na Lista') {
      icon = Icons.add; // ácone para incluir na lista
    } else if (label == 'Gerar PDF') {
      icon = Icons.picture_as_pdf; // ácone para PDF
    } else if (label == 'Cancelar') {
      icon = Icons.close; // ácone para cancelar
    } else if (label == 'Salvar') {
      icon = Icons.save; // ácone para salvar
    }

    return MouseRegion(
      cursor: onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height:
              40, // Altura ajustada para corresponder exatamente aos campos de texto (isDense: true + vertical: 12)
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: showLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller,
      {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        color: getTextColor(context),
        fontSize: 14,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: getSecondaryTextColor(context),
          fontSize: 13,
        ),
        filled: true,
        fillColor: getSurfaceColor(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF684F8E)),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }
}
