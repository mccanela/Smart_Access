part of '../dashboard.dart';

class _EntradaConvidadoPanel extends StatefulWidget {
  final Map<String, dynamic> convidado;
  final String reservaId;

  const _EntradaConvidadoPanel({
    required this.convidado,
    required this.reservaId,
  });

  @override
  State<_EntradaConvidadoPanel> createState() => _EntradaConvidadoPanelState();
}

class _EntradaConvidadoPanelState extends State<_EntradaConvidadoPanel> {
  String? _fotoBase64;
  final bool _carregandoFoto = false;
  bool _loadingAtualizarFacial = false;
  bool _salvando = false;

  // Controllers para os campos
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _autorizanteController = TextEditingController();
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _empresaController = TextEditingController();
  final TextEditingController _creciController = TextEditingController();
  final TextEditingController _quantPessoasController = TextEditingController();
  final TextEditingController _placaController = TextEditingController();
  final TextEditingController _veiculoController = TextEditingController();
  final TextEditingController _vagaFlgController = TextEditingController();
  String? _tipoDocumentoSelecionado;

  final List<String> _tiposDocumento = ['RG', 'CPF', 'ID', 'PASSAPORT'];

  @override
  void initState() {
    super.initState();
    print(
        'ðŸ” [DEBUG] _EntradaConvidadoPanel.initState - widget.reservaId: "${widget.reservaId}"');
    _inicializarCampos();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _autorizanteController.dispose();
    _documentoController.dispose();
    _empresaController.dispose();
    _creciController.dispose();
    _quantPessoasController.dispose();
    _placaController.dispose();
    _veiculoController.dispose();
    _vagaFlgController.dispose();
    super.dispose();
  }

  void _inicializarCampos() {
    // Debug: mostrar todos os campos do objeto convidado
    print('ðŸ” [DEBUG] Todos os campos de widget.convidado:');
    print('ðŸ” [DEBUG] JSON completo: ${jsonEncode(widget.convidado)}');
    widget.convidado.forEach((key, value) {
      print('  $key: $value');
    });

    // Preencher campos com dados existentes se houver
    _nomeController.text =
        widget.convidado['nome'] ?? widget.convidado['convidado_txt'] ?? '';
    _emailController.text =
        widget.convidado['email'] ?? widget.convidado['email_txt'] ?? '';
    _autorizanteController.text = widget.convidado['autorizante'] ??
        widget.convidado['autorizante_txt'] ??
        '';
    _documentoController.text = widget.convidado['documento'] ??
        widget.convidado['documento_txt'] ??
        '';
    _empresaController.text =
        widget.convidado['empresa'] ?? widget.convidado['empresa_txt'] ?? '';
    _creciController.text =
        widget.convidado['creci'] ?? widget.convidado['creci_txt'] ?? '';
    _quantPessoasController.text = (widget.convidado['quant_pessoas'] ??
            widget.convidado['quantPessoas'] ??
            '')
        .toString();
    _placaController.text = widget.convidado['placa'] ?? '';
    _veiculoController.text =
        widget.convidado['veiculo'] ?? widget.convidado['veiculo_txt'] ?? '';
    _vagaFlgController.text =
        widget.convidado['vaga_flg'] ?? widget.convidado['vagaFlg'] ?? '';

    // Garantir que o tipo de documento seja válido (deve estar na lista ou ser null)
    final tipoDocOriginal =
        widget.convidado['tipodoc'] ?? widget.convidado['tipodoc_txt'];
    _tipoDocumentoSelecionado =
        _tiposDocumento.contains(tipoDocOriginal) ? tipoDocOriginal : null;

    // Carregar foto do convidado se existir
    _carregarFotoConvidado();
  }

  Future<void> _carregarFotoConvidado() async {
    // Mesmo código da ção anterior para carregar foto
    final reservaconvidadoId = widget.convidado['reservaconvidado_id'];

    if (reservaconvidadoId == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final url = Uri.parse('${ApiConfig.gateUrl}/foto');
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String? fotoBase64;
        final data = responseData['data'];
        if (data is Map) {
          fotoBase64 = (data['fotobase64'] ?? data['fotoBase64'])?.toString();
        } else if (data is List && data.isNotEmpty) {
          final first = data.first;
          if (first is Map) {
            fotoBase64 =
                (first['fotobase64'] ?? first['fotoBase64'])?.toString();
          }
        } else {
          // Fallback caso venha fora de 'data'
          fotoBase64 =
              (responseData['fotobase64'] ?? responseData['fotoBase64'])
                  ?.toString();
        }

        if (fotoBase64 != null && fotoBase64.isNotEmpty) {
          final fotoProcessada = fotoBase64
              .replaceFirst('data:image/png;base64,', '')
              .replaceFirst('data:image/jpeg;base64,', '');
          setState(() {
            _fotoBase64 = fotoProcessada;
          });
        }
      }
    } catch (e) {
      print('Erro ao carregar foto do convidado: $e');
    }
  }

  Future<void> _registrarFotoApi({
    required int condominioId,
    required String tipo, // 'AV' or 'AG'
    required int id,
    required String fotoBase64,
    required int ordemNum,
  }) async {
    if (fotoBase64.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

    final url = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');

    final payload = {
      "condominio_id": condominioId,
      "tipoUSU": "USU",
      "ordem_num": ordemNum,
      "foto": fotoBase64,
    };

    if (tipo == 'AV') {
      payload["pessoacadastro_id"] = id;
    } else {
      payload["reservaConvidado_Id"] = id;
    }

    try {
      print('ðŸ“¸ Chamando FotoRegistrar para $tipo ID: $id');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );
      print('ðŸ“¸ Resposta FotoRegistrar: ${response.statusCode}');
    } catch (e) {
      print('âŒ Erro ao registrar foto: $e');
    }
  }

  Future<void> _abrirCameraModal() async {
    abrirCameraLateral(
      frameType: CameraFrameType.face,
      onPhotoTaken: (String photoDataUrl) async {
        // Comprimir imagem para máximo 300KB
        final compressedDataUrl =
            await ImageUtils.compressImageToMaxSize(photoDataUrl);
        setState(() {
          _fotoBase64 = compressedDataUrl.split(',').last;
        });
      },
    );
  }

  Future<void> _salvarEntrada() async {
    if (_salvando) return;

    setState(() {
      _salvando = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      // Verificar se é AV (avulso) ou AG (agendamento) ANTES de criar payload
      final tipo = widget.convidado['tipo']?.toString() ?? '';
      final isAvulso = tipo == 'AV';

      print(
          'ðŸ” [DEBUG] _salvarEntrada - tipo: $tipo, isAvulso: $isAvulso, reservaId: ${widget.reservaId}');

      bool podeProcessarEntrada = false;

      // Para AV, pular a atualizaçao via convidadoupd e ir direto para registro de entrada avulso
      // Para AG, atualizar convidado primeiro e depois registrar entrada
      if (!isAvulso) {
        // Converter reserva_id corretamente
        // PRIORIDADE 1: Pegar do objeto convidado (vem da API convidadolist)
        var reservaIdInt = widget.convidado['reserva_id'] ??
            widget.convidado['agendamento_id'] ??
            0;

        // PRIORIDADE 2: Se ainda estiver 0, tentar do widget.reservaId (fallback)
        if (reservaIdInt == 0) {
          reservaIdInt = int.tryParse(widget.reservaId) ?? 0;
        }

        print(
            'ðŸ” [DEBUG] widget.convidado[reserva_id]: ${widget.convidado['reserva_id']}');
        print('ðŸ” [DEBUG] widget.reservaId: "${widget.reservaId}"');
        print('ðŸ” [DEBUG] reservaIdInt final: $reservaIdInt');

        if (reservaIdInt == 0) {
          print(
              'âš ï¸ [WARNING] reserva_id está 0! Verifique se widget.convidado ou widget.reservaId tem valor válido');
        }

        final payload = {
          'reserva_id': reservaIdInt,
          'reservaconvidado_id': widget.convidado['reservaconvidado_id'] ??
              widget.convidado['sequencia'] ??
              0,
          'convidado_txt': _nomeController.text.trim(),
          'email_txt': _emailController.text.trim(),
          'tipodoc_txt': _tipoDocumentoSelecionado ?? '',
          'documento_txt': _documentoController.text.trim(),
          'empresa_txt': _empresaController.text.trim(),
          'autorizante_txt': _autorizanteController.text.trim(),
          'creci_txt': _creciController.text.trim(),
          'quant_pessoas': int.tryParse(_quantPessoasController.text) ?? 0,
          'placa': _placaController.text.trim(),
          'veiculo_txt': _veiculoController.text.trim(),
          'id_acesso': widget.convidado['id_acesso']?.toString() ?? '',
          'excluir': 'N',
          'vaga_flg': _vagaFlgController.text.trim(),
          if (_fotoBase64 != null && _fotoBase64!.isNotEmpty)
            'fotoBase64': _fotoBase64!
                .replaceFirst('data:image/png;base64,', '')
                .replaceFirst('data:image/jpeg;base64,', ''),
        };

        print('ðŸ” [DEBUG] Payload convidadoupd: ${jsonEncode(payload)}');

        final url = Uri.parse('${ApiConfig.socialhUrl}/convidadoupd');
        print('[DEBUG] URL convidadoupd: $url');

        final response = await http.post(
          url,
          headers: {
            'Authorization': 'Bearer $tokenSessao',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(payload),
        );

        print(
            'ðŸ” [DEBUG] Response status convidadoupd: ${response.statusCode}');
        print('ðŸ” [DEBUG] Response body convidadoupd: ${response.body}');

        if (response.statusCode != 200) {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro',
            message: 'Erro ao atualizar dados do convidado',
          );
          setState(() {
            _salvando = false;
          });
          return;
        }

        // Foto agora é enviada no payload principal do convidadoupd
        /*
        if (_fotoBase64 != null) {
          final convidadoId = widget.convidado['reservaconvidado_id'] ??
              widget.convidado['sequencia'];
          if (convidadoId != null) {
            await _registrarFotoApi(
              condominioId: widget.convidado['condominio_id'] ?? 0,
              tipo: 'AG',
              id: convidadoId,
              ordemNum: 1,
              fotoBase64: _fotoBase64!
                  .replaceFirst('data:image/png;base64,', '')
                  .replaceFirst('data:image/jpeg;base64,', ''),
            );
          }
        }
        */

        podeProcessarEntrada = true;
      } else {
        // Para AV, pode processar entrada diretamente
        podeProcessarEntrada = true;
      }

      // Agora processar entrada (AV ou AG)
      bool entradaSucesso = false;

      // Processar entrada baseado no tipo
      if (podeProcessarEntrada) {
        // Se for AV, usar API de avulso (avulsoregistroentrada), nunca convidadomov
        if (isAvulso) {
          print(
              'ðŸ” [DEBUG] Tipo AV detectado no painel lateral - usando API avulsoregistroentrada');

          Future<void> registrarFotoApi({
            required int condominioId,
            required String tipo, // 'AV' or 'AG'
            required int id,
            required String fotoBase64,
            required int ordemNum,
          }) async {
            if (fotoBase64.isEmpty) return;

            final prefs = await SharedPreferences.getInstance();
            final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
            final tokenSessao =
                encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

            final url = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');

            final payload = {
              "condominio_id": condominioId,
              "tipoUSU": "USU",
              "ordem_num": ordemNum,
              "foto": fotoBase64,
            };

            if (tipo == 'AV') {
              payload["pessoacadastro_id"] = id;
            } else {
              payload["reservaConvidado_Id"] = id;
            }

            try {
              print(
                  'ðŸ“¸ Chamando FotoRegistrar para $tipo ID: $id Ordem: $ordemNum');
              final response = await http.post(
                url,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $tokenSessao',
                },
                body: jsonEncode(payload),
              );
              print('ðŸ“¸ Resposta FotoRegistrar: ${response.statusCode}');
            } catch (e) {
              print('âŒ Erro ao registrar foto: $e');
            }
          }

          // Para AV, usar a API de registro de entrada avulso
          final prefs = await SharedPreferences.getInstance();
          final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
          final condominioId = (encryptedCondominioId.isNotEmpty)
              ? decryptText(encryptedCondominioId)
              : '';

          final documento = _documentoController.text.trim();
          final nome = widget.convidado['nome'] ??
              widget.convidado['convidado_txt'] ??
              '';

          // Buscar pessoadocumento_id do cadastro avulso
          final urlCadastro = Uri.parse(
              '${ApiConfig.gateUrl}/cadastroavulsolist/?documento=$documento');
          final responseCadastro = await http.post(
            urlCadastro,
            headers: {
              'Authorization': 'Bearer $tokenSessao',
              'Content-Type': 'application/json',
            },
          );

          int pessoadocumentoId = 0;
          if (responseCadastro.statusCode == 200) {
            final dataCadastro = jsonDecode(responseCadastro.body);
            if (dataCadastro['data'] is List &&
                (dataCadastro['data'] as List).isNotEmpty) {
              pessoadocumentoId =
                  dataCadastro['data'][0]['pessoadocumento_id'] ?? 0;
            }
          }

          // Se não encontrou, criar cadastro
          if (pessoadocumentoId == 0) {
            final urlEdit =
                Uri.parse(ApiConfig.getEndpoint('dashboard', 'editarCadastro'));
            final payloadEdit = {
              "pessoadocumento_id": 0,
              "nome": nome,
              "documento": documento,
              "tipodoc": _tipoDocumentoSelecionado ?? 'R',
              "empresa": '',
              "email": '',
            };
            final responseEdit = await http.post(
              urlEdit,
              headers: {
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $tokenSessao',
              },
              body: jsonEncode(payloadEdit),
            );
            if (responseEdit.statusCode == 200) {
              final dataEdit = jsonDecode(responseEdit.body);
              pessoadocumentoId = dataEdit['data']?['pessoadocumento_id'] ?? 0;
            }
          }

          // Chamar API de registro de entrada avulso
          final urlAvulso = Uri.parse(
              ApiConfig.getEndpoint('dashboard', 'registroEntradaAvulso'));
          final payloadAvulso = {
            "condominio_id": int.tryParse(condominioId) ?? 0,
            "pessoadocumento_id": pessoadocumentoId,
            "documento": documento,
            "nome": nome,
            "entradacadastro_id": 0,
            "apto_id": widget.convidado['apto_id'] ?? 0,
            "autorizante": _autorizanteController.text,
            "tipovisita": "V",
            "leitor_id": 0,
            "outraident_id": 0,
            "vaga_id": 0,
            "marca_id": 0,
            "cor_id": 0,
            "placa": "",
            "modelo": "",
            "flg_garagem": "",
            "dt_fim": "",
            "observacao": "",
          };

          // Foto agora é enviada separadamente via FotoRegistrar
          // if (_fotoBase64 != null) { ... }

          final responseAvulso = await http.post(
            urlAvulso,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $tokenSessao',
            },
            body: jsonEncode(payloadAvulso),
          );

          entradaSucesso = responseAvulso.statusCode == 200;

          if (entradaSucesso) {
            if (_fotoBase64 != null && _fotoBase64!.isNotEmpty) {
              await registrarFotoApi(
                condominioId: int.tryParse(condominioId) ?? 0,
                tipo: 'AV',
                id: pessoadocumentoId,
                ordemNum: 1,
                fotoBase64: _fotoBase64!
                    .replaceFirst('data:image/png;base64,', '')
                    .replaceFirst('data:image/jpeg;base64,', ''),
              );
            }
            /*
            // Document photo not supported in this panel yet
            if (_fotoDocumentoBase64 != null &&
                _fotoDocumentoBase64!.isNotEmpty) {
              await _registrarFotoApi(
                condominioId: int.tryParse(condominioId) ?? 0,
                tipo: 'AV',
                id: pessoadocumentoId,
                ordemNum: 2,
                fotoBase64: _fotoDocumentoBase64!
                    .replaceFirst('data:image/png;base64,', '')
                    .replaceFirst('data:image/jpeg;base64,', ''),
              );
            }
            */
          }
        } else {
          // Para AG (agendamento), usar convidadomov
          final reservaconvidadoId =
              widget.convidado['reservaconvidado_id']?.toString() ??
                  widget.convidado['sequencia']?.toString() ??
                  '';

          if (reservaconvidadoId.isNotEmpty) {
            print(
                'ðŸ” [DEBUG] Chamando convidadomov - reservaId: ${widget.reservaId}, reservaconvidadoId: $reservaconvidadoId');
            entradaSucesso = await registrarEntradaSaidaGlobal(
              widget.reservaId,
              reservaconvidadoId,
              true, // true para entrada
            );
            print('ðŸ” [DEBUG] Resultado convidadomov: $entradaSucesso');
          }
        }

        if (entradaSucesso) {
          // Após registrar entrada, atualizar dispositivo facial
          setState(() {
            _loadingAtualizarFacial = true;
          });
          try {
            await _atualizarFacialGlobal(widget.convidado, context);
          } finally {
            setState(() {
              _loadingAtualizarFacial = false;
            });
          }

          // Para AV, fechar o painel após entrada
          // Para AG, atualizar lista e manter painel aberto
          if (isAvulso) {
            fecharPainelLateralGlobal();
            FeedbackUtils.showSuccess(
              context: context,
              title: 'Sucesso',
              message: 'Entrada avulsa registrada com sucesso!',
            );
          } else {
            // No modo Agendamentos, atualizar lista e manter painel aberto
            final reservaconvidadoId =
                widget.convidado['reservaconvidado_id']?.toString() ??
                    widget.convidado['sequencia']?.toString() ??
                    '';
            if (removerConvidadoGlobal != null &&
                reservaconvidadoId.isNotEmpty) {
              // Atualizar lista buscando novamente da API (modo Agendamentos)
              await removerConvidadoGlobal!(reservaconvidadoId);
            } else {
              // Fechar o painel (fallback)
              fecharPainelLateralGlobal();
            }

            FeedbackUtils.showSuccess(
              context: context,
              title: 'Sucesso',
              message: 'Entrada registrada com sucesso!',
            );
          }
        } else {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro',
            message: isAvulso
                ? 'Erro ao registrar entrada avulsa.'
                : 'Dados atualizados, mas falha ao registrar entrada.',
          );
        }
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Erro ao registrar entrada',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Erro: $e',
      );
    } finally {
      setState(() {
        _salvando = false;
      });
    }
  }

  bool get _temEntradaAtiva {
    final entradaStr = widget.convidado['entrada']?.toString();
    final saidaStr = widget.convidado['saida']?.toString();

    // Se tem entrada E NáƒO tem saída -> Ativa
    if ((entradaStr != null && entradaStr.isNotEmpty) &&
        (saidaStr == null || saidaStr.isEmpty)) {
      return true;
    }
    return false;
  }

  Future<void> _registrarSaida() async {
    if (_salvando) return;

    setState(() {
      _salvando = true;
    });

    try {
      var reservaId = widget.reservaId;
      if (reservaId.isEmpty || reservaId == '0') {
        reservaId = widget.convidado['reserva_id']?.toString() ??
            widget.convidado['id_pai']?.toString() ??
            '';
      }

      var reservaconvidadoId =
          widget.convidado['reservaconvidado_id']?.toString() ??
              widget.convidado['sequencia']?.toString() ??
              '';

      if (reservaconvidadoId.isEmpty) {
        FeedbackUtils.showError(
            context: context,
            title: 'Erro',
            message: 'ID do convidado não encontrado');
        setState(() {
          _salvando = false;
        });
        return;
      }

      final sucesso = await registrarEntradaSaidaGlobal(
          reservaId, reservaconvidadoId, false);

      if (sucesso) {
        fecharPainelLateralGlobal();
      }
    } catch (e) {
      print('Erro ao registrar saída: $e');
      FeedbackUtils.showError(
          context: context, title: 'Erro', message: 'Erro ao registrar saída');
    } finally {
      if (mounted) {
        setState(() {
          _salvando = false;
        });
      }
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Tooltip(
      message: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: onTap == null ? Colors.grey : color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Icon(icon, color: Colors.white, size: 24)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.48,
      height: double.infinity,
      color: getCardColor(context),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF684F8E),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Spacer(),
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => fecharPainelLateralGlobal(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
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
                  // Foto
                  Text(
                    'Foto do Convidado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Builder(
                      builder: (context) {
                        if (_fotoBase64 != null) {
                          try {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                image: DecorationImage(
                                  image:
                                      MemoryImage(base64Decode(_fotoBase64!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          } catch (e) {
                            return Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: getSurfaceColor(context),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade300),
                              ),
                              child: const Icon(Icons.error,
                                  size: 48, color: Colors.red),
                            );
                          }
                        } else {
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  Border.all(color: getBorderColor(context)),
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
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: _carregandoFoto ? null : _abrirCameraModal,
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: _carregandoFoto
                                ? Colors.grey
                                : const Color(0xFF684F8E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _carregandoFoto
                                ? Icons.hourglass_empty
                                : Icons.camera_alt,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Campos do formulário
                  Text(
                    'Informaá§ões do Convidado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: getTextColor(context),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Autorizante
                  TextFormField(
                    controller: _autorizanteController,
                    decoration:
                        inputDecorationPadrao(context, hintText: 'Autorizante'),
                  ),
                  const SizedBox(height: 16),

                  // Tipo Documento e Documento lado a lado
                  Row(
                    children: [
                      Expanded(
                        child: _TipoDocumentoSelector(
                          tiposDocumento: _tiposDocumento,
                          valorSelecionado: _tipoDocumentoSelecionado,
                          onChanged: (value) {
                            setState(() {
                              _tipoDocumentoSelecionado = value;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _documentoController,
                          decoration: inputDecorationPadrao(context,
                              hintText: 'Documento'),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Botões de açao
                  // Botões de açao
                  if (_temEntradaAtiva)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildActionButton(
                          label: 'Cancelar',
                          icon: Icons.close,
                          color: Colors.grey.shade300,
                          onTap: _salvando
                              ? null
                              : () => fecharPainelLateralGlobal(),
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          label: 'Nova Entrada',
                          icon: Icons.login,
                          color: const Color(0xFF1FA463),
                          onTap: _salvando ? null : _salvarEntrada,
                          isLoading: _salvando,
                        ),
                        const SizedBox(width: 16),
                        _buildActionButton(
                          label: 'Registrar Saída',
                          icon: Icons.logout,
                          color: Colors.red.shade400,
                          onTap: _salvando ? null : _registrarSaida,
                          isLoading: _salvando,
                        ),
                      ],
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _salvando
                                ? null
                                : () => fecharPainelLateralGlobal(),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.close,
                                color: getTextColor(context),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: _salvando ? null : _salvarEntrada,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: _salvando
                                    ? Colors.grey
                                    : const Color(0xFF1FA463),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _salvando
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                            ),
                          ),
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
}
