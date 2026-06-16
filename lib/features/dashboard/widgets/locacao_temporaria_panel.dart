part of '../dashboard.dart';

class _LocacaoTemporariaPanel extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> convidados;
  final String reservaId;

  const _LocacaoTemporariaPanel({
    required this.titulo,
    required this.convidados,
    required this.reservaId,
  });

  @override
  State<_LocacaoTemporariaPanel> createState() =>
      _LocacaoTemporariaPanelState();
}

class _LocacaoTemporariaPanelState extends State<_LocacaoTemporariaPanel> {
  bool _loadingAtualizarFacial = false;

  Widget _buildDivider(Color color) {
    return Container(
      width: 1,
      height: 28,
      color: color,
    );
  }

  Widget _buildGroupedIcon(
    IconData icon,
    Color color,
    VoidCallback? onPressed,
    String tooltip, {
    bool isLoading = false,
    bool isOpaque = false,
    double? iconSize,
  }) {
    final tooltipMessage = isOpaque ? '$tooltip (desabilitado)' : tooltip;

    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      enableFeedback: true,
      waitDuration: isOpaque
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isOpaque ? Colors.grey.shade800 : const Color(0xFF10133E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        cursor: isLoading
            ? SystemMouseCursors.basic
            : (onPressed == null || isOpaque
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click),
        child: GestureDetector(
          onTap: (isLoading || isOpaque) ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            decoration: isOpaque
                ? BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    color: isLoading
                        ? color.withValues(alpha: 0.5)
                        : (isOpaque ? color.withValues(alpha: 0.35) : color),
                    size: iconSize ?? (isOpaque ? 24 : 28),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentIconGroup(List<Map<String, dynamic>> actions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor = iconColor.withValues(alpha: 0.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        border:
            Border.all(color: dividerColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(actions.length * 2 - 1, (index) {
          if (index % 2 == 0) {
            // ácone
            final actionIndex = index ~/ 2;
            final action = actions[actionIndex];
            return _buildGroupedIcon(
              action['icon'] as IconData,
              iconColor,
              action['onPressed'] as VoidCallback?,
              action['tooltip'] as String,
              isLoading: action['isLoading'] as bool? ?? false,
            );
          } else {
            // Divisor
            return _buildDivider(dividerColor);
          }
        }),
      ),
    );
  }

  Future<void> _atualizarFacialLocal(
      Map<String, dynamic> convidado, BuildContext context) async {
    setState(() {
      _loadingAtualizarFacial = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final condominioId = await ApiConfig.getCondominioId();

      final payload = {
        'condominio_id':
            convidado['condominio_id'] ?? int.tryParse(condominioId) ?? 0,
        'id': convidado['reservaconvidado_id'] ?? convidado['sequencia'] ?? 0,
        'tiporegra': 459,
        'tipoequipamento_id': 1126,
      };

      final url = Uri.parse('${ApiConfig.gateUrl}/dispositivoatualizacao');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $tokenSessao',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Sucesso',
          message: 'Atualizaçao facial realizada com sucesso!',
        );
      } else {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Erro na atualizaçao facial',
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
        _loadingAtualizarFacial = false;
      });
    }
  }

  DateTime? _parseDateTime(String dataHora) {
    if (dataHora.isEmpty) return null;
    try {
      // Tentar diferentes formatos
      if (dataHora.contains('-')) {
        final partes = dataHora.split(' ');
        if (partes.length >= 2) {
          final dataPartes = partes[0].split('-');
          final horaPartes = partes[1].split(':');
          if (dataPartes.length == 3 && horaPartes.length >= 2) {
            return DateTime(
              int.parse(dataPartes[2]),
              int.parse(dataPartes[1]),
              int.parse(dataPartes[0]),
              int.parse(horaPartes[0]),
              int.parse(horaPartes[1]),
            );
          }
        }
      }
      return DateTime.parse(dataHora);
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: getCardColor(context),
            border: Border(bottom: BorderSide(color: getBorderColor(context))),
            boxShadow: [
              BoxShadow(
                color: getShadowColor(context),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(-2, 0), // Sombra para o lado esquerdo
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.home_work, color: getTextColor(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.titulo,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: getTextColor(context))),
                    const SizedBox(height: 2),
                    Text('Agendamento de Locaçao Temporária',
                        style: TextStyle(
                            color: getSecondaryTextColor(context),
                            fontSize: 13)),
                  ],
                ),
              ),
              // Botá£o para fechar o painel
              IconButton(
                onPressed: () => fecharPainelLateralGlobal(),
                icon: Icon(Icons.close, color: getTextColor(context)),
                tooltip: 'Fechar painel',
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _filledButton('Incluir na Lista',
                    color: const Color(0xFF1FA463), onTap: () {}),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _searchInput()),
                    const SizedBox(width: 8),
                    _filledButton('Gerar PDF',
                        color: const Color(0xFF4169E1), onTap: () {}),
                  ],
                ),
                const SizedBox(height: 8),
                _infoChip('Convidados encontrados: ${widget.convidados.length}',
                    Icons.group),
                const SizedBox(height: 8),
                _guestsTable(context),
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _searchInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getBorderColor(context)),
        color: getSurfaceColor(context),
      ),
      child: const TextField(
        decoration: InputDecoration(
          hintText: 'Pesquisar convidados',
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _infoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: getBorderColor(context)),
        color: getSurfaceColor(context),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: getTextColor(context)),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(fontSize: 13, color: getTextColor(context))),
        ],
      ),
    );
  }

  Widget _guestsTable(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: getShadowColor(context),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _tableHeader(context),
          const Divider(height: 1),
          ...widget.convidados.map((c) => _tableRow(c)),
        ],
      ),
    );
  }

  Widget _tableHeader(BuildContext context) {
    // Responsividade baseada na largura da tela
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 800;
    final isVerySmallScreen = screenWidth < 600;

    final th = TextStyle(
        fontWeight: FontWeight.w600,
        color: const Color(0xFF6A5AA0),
        fontSize: isVerySmallScreen ? 12 : (isSmallScreen ? 13 : 14));

    // Ajustar espaá§amentos baseado no tamanho da tela
    final horizontalPadding =
        isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0);
    final verticalPadding = isVerySmallScreen ? 10.0 : 14.0;
    final iconSpacing =
        isVerySmallScreen ? 40.0 : (isSmallScreen ? 48.0 : 56.0);
    final actionsWidth =
        isVerySmallScreen ? 140.0 : (isSmallScreen ? 160.0 : 180.0);

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, vertical: verticalPadding),
      child: Row(
        children: [
          // Indicador I
          Container(
            width: 24,
            alignment: Alignment.center,
            child: Text('I', style: th),
          ),
          // Nome
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text('Nome', style: th),
            ),
          ),
          // Documento
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text('Documento', style: th),
            ),
          ),
          // Veículo/Placa
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.centerLeft,
              child: Text('Veículo/Placa', style: th),
            ),
          ),
          // Aá§ões
          Container(
            width: actionsWidth,
            alignment: Alignment.centerLeft,
            child: Text('Aá§ões', style: th),
          ),
        ],
      ),
    );
  }

  // Funçao para determinar se deve mostrar botá£o de entrada ou saída
  bool _deveMostrarEntrada(Map<String, dynamic> convidado) {
    // Campos específicos: "entrada" e "saida" conforme especificado pelo usuário
    final entradaStr = convidado['entrada']?.toString();
    final saidaStr = convidado['saida']?.toString();

    // Se não há informaá§ões de entrada/saída, assumir que deve mostrar entrada
    if ((entradaStr == null || entradaStr.isEmpty) &&
        (saidaStr == null || saidaStr.isEmpty)) {
      return true;
    }

    // Se há entrada mas não há saída, deve mostrar saída
    if ((entradaStr != null && entradaStr.isNotEmpty) &&
        (saidaStr == null || saidaStr.isEmpty)) {
      return false; // Mostrar saída
    }

    // Se há saída mas não há entrada, deve mostrar entrada
    if ((saidaStr != null && saidaStr.isNotEmpty) &&
        (entradaStr == null || entradaStr.isEmpty)) {
      return true; // Mostrar entrada
    }

    // Se há ambos os campos preenchidos, deve mostrar entrada (para nova entrada que limpará saída)
    if ((entradaStr != null && entradaStr.isNotEmpty) &&
        (saidaStr != null && saidaStr.isNotEmpty)) {
      return true; // Mostrar entrada (para permitir nova entrada que limpará saída)
    }

    // Default: mostrar entrada
    return true;
  }

  Widget _tableRow(Map<String, dynamic> c) {
    // Determinar estado de entrada/saída baseado nos dados da API
    // Se isEntrada == true, significa que o próximo passo é ENTREGAR, ou seja, está FORA.
    // Se isEntrada == false, significa que o próximo passo é SAáDA, ou seja, está DENTRO.
    // A ção _deveMostrarEntrada retorna true se deve mostrar botá£o de ENTRADA (está fora).
    final deveMostrarEntrada = _deveMostrarEntrada(c);

    // Variável local para controle de estado (se necessário, mas idealmente usa-se dados da API)
    // Aqui usamos o cálculo inicial.

    return StatefulBuilder(
      builder: (context, setState) {
        // Responsividade baseada na largura da tela
        final screenWidth = MediaQuery.of(context).size.width;
        final isSmallScreen = screenWidth < 800;
        final isVerySmallScreen = screenWidth < 600;

        // Ajustar espaá§amentos baseado no tamanho da tela
        final horizontalPadding =
            isVerySmallScreen ? 8.0 : (isSmallScreen ? 10.0 : 12.0);
        final verticalPadding = isVerySmallScreen ? 8.0 : 10.0;
        final iconSpacing =
            isVerySmallScreen ? 40.0 : (isSmallScreen ? 48.0 : 56.0);
        final actionsWidth =
            isVerySmallScreen ? 140.0 : (isSmallScreen ? 160.0 : 180.0);

        final actions = <Map<String, dynamic>>[];

        // REGRA 1: "em todas as opá§oes tem o selecionar"
        // Botá£o de Editar/Selecionar SEMPRE presente.
        actions.add({
          'icon': Icons.edit,
          'tooltip': 'Editar',
          'onPressed': () {
            // "carrega no forms o usuario para que possa editar"
            abrirPainelLateralGlobal(
              _EditarConvidadoPanel(
                convidado: c,
                reservaId: widget.reservaId,
              ),
            );
          },
        });

        // Lógica refinada baseada em data de entrada
        final entradaStr = c['entrada']?.toString() ?? '';
        final saidaStr = c['saida']?.toString() ?? '';
        final jaDeuEntrada = entradaStr.isNotEmpty;
        final jaDeuSaida = saidaStr.isNotEmpty;

        if (jaDeuEntrada && !jaDeuSaida) {
          // Está DENTRO - verificar data da entrada
          DateTime? dataEntrada;
          try {
            if (entradaStr.isNotEmpty) {
              // Formato esperado: "DD/MM/YYYY HH:MM:SS"
              final parts = entradaStr.split(' ');
              if (parts.isNotEmpty) {
                final dateParts = parts[0].split('/');
                if (dateParts.length == 3) {
                  dataEntrada = DateTime(
                    int.parse(dateParts[2]),
                    int.parse(dateParts[1]),
                    int.parse(dateParts[0]),
                  );
                }
              }
            }
          } catch (e) {
            print('Erro ao parsear data de entrada: $e');
          }

          final hoje = DateTime.now();
          final hojeSemHora = DateTime(hoje.year, hoje.month, hoje.day);
          final entradaSemHora = dataEntrada != null
              ? DateTime(dataEntrada.year, dataEntrada.month, dataEntrada.day)
              : null;

          if (entradaSemHora != null && entradaSemHora.isBefore(hojeSemHora)) {
            // Entrada anterior a hoje â†’ Nova Entrada
            actions.add({
              'icon': Icons.login,
              'tooltip': 'Nova Entrada',
              'onPressed': () async {
                final reservaId = widget.reservaId;
                final reservaconvidadoId =
                    c['reservaconvidado_id']?.toString() ??
                        c['sequencia']?.toString() ??
                        '';

                final sucesso = await registrarEntradaSaidaGlobal(
                    reservaId, reservaconvidadoId, true); // true = Entrada

                if (sucesso && mounted) {
                  setState(() {
                    // Limpar saída visualmente para refletir que entrou
                    c['saida'] = "";
                    // Atualizar entrada visualmente
                    c['entrada'] = DateTime.now().toString();
                  });
                  FeedbackUtils.showSuccess(
                      context: context,
                      title: 'Nova Entrada',
                      message: 'Entrada registrada com sucesso!');
                }
              },
            });
          } else {
            // Entrada hoje ou data inválida â†’ Saída
            actions.add({
              'icon': Icons.exit_to_app,
              'tooltip': 'Saída',
              'onPressed': () async {
                final reservaId = widget.reservaId;
                final reservaconvidadoId =
                    c['reservaconvidado_id']?.toString() ??
                        c['sequencia']?.toString() ??
                        '';

                // Executar Saída (isEntrada = false)
                final sucesso = await registrarEntradaSaidaGlobal(
                    reservaId, reservaconvidadoId, false);

                if (sucesso && mounted) {
                  // Atualizar UI
                  setState(() {
                    c['saida'] = DateTime.now().toString();
                  });
                }
              },
            });
          }
        } else {
          // Está FORA (nunca entrou ou ciclo fechado)
          actions.add({
            'icon': Icons.login,
            'tooltip': 'Entrada', // Nova Entrada ou Primeira Entrada
            'onPressed': () async {
              final cicloFechado = jaDeuEntrada && jaDeuSaida;

              if (cicloFechado) {
                // NOVA ENTRADA: "nao quero que carregue no forms quero que acione a api dando entrada ali mesmo"
                final reservaId = widget.reservaId;
                final reservaconvidadoId =
                    c['reservaconvidado_id']?.toString() ??
                        c['sequencia']?.toString() ??
                        '';

                final sucesso = await registrarEntradaSaidaGlobal(
                    reservaId, reservaconvidadoId, true); // true = Entrada

                if (sucesso && mounted) {
                  setState(() {
                    // Limpar saída visualmente para refletir que entrou
                    c['saida'] = "";
                    // Atualizar entrada visualmente
                    c['entrada'] = DateTime.now().toString();
                  });
                  FeedbackUtils.showSuccess(
                      context: context,
                      title: 'Nova Entrada',
                      message: 'Entrada registrada com sucesso!');
                }
              } else {
                // PRIMEIRA ENTRADA: "só crrega o forma na primeira entrada"
                abrirPainelLateralGlobal(
                  _EditarConvidadoPanel(
                    convidado: c,
                    reservaId: widget.reservaId,
                  ),
                );
              }
            },
          });
        }

        // Adicionar outras aá§ões padrão se necessário (foto, facial)
        actions.add({
          'icon': Icons.face_retouching_natural,
          'tooltip': 'Atualizar Facial',
          'onPressed': () async => await _atualizarFacialLocal(c, context),
          'isLoading': _loadingAtualizarFacial,
        });

        /* Botao de ver foto removido para limpar a interface ou mantido? 
           O request focou em Entrada/Saida/Selecionar. Vou manter atualizar facial pois é util.
        */

        return Padding(
          padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding, vertical: verticalPadding),
          child: Row(
            children: [
              // Indicador I (Icone Status)
              Container(
                width: 24,
                alignment: Alignment.center,
                child: Icon(
                    !deveMostrarEntrada
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    color: !deveMostrarEntrada
                        ? const Color(0xFF1FA463)
                        : Colors.grey,
                    size: 20),
              ),
              // Nome
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                      (c['nome'] ?? c['convidado_txt'] ?? '').toString(),
                      style: TextStyle(
                          fontSize: isVerySmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w500)),
                ),
              ),
              // Documento
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                      (c['documento'] ?? c['documento_txt'] ?? '').toString(),
                      style: TextStyle(fontSize: isVerySmallScreen ? 11 : 13)),
                ),
              ),
              // Veículo/Placa
              Expanded(
                flex: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if ((c['veiculo'] ?? '').toString().isNotEmpty)
                        Text((c['veiculo'] ?? '').toString(),
                            style: TextStyle(
                                fontSize: isVerySmallScreen ? 10 : 12,
                                fontWeight: FontWeight.w500)),
                      if ((c['placa'] ?? '').toString().isNotEmpty)
                        Text((c['placa'] ?? '').toString(),
                            style: TextStyle(
                                fontSize: isVerySmallScreen ? 9 : 11,
                                color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              // Aá§ões dynamicamente geradas
              Container(
                width: actionsWidth,
                alignment: Alignment.centerLeft,
                child: Transform.translate(
                  offset: const Offset(-10, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _buildTransparentIconGroup(actions),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filledButton(String label,
      {required VoidCallback onTap, required Color color}) {
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
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 40, // Altura ajustada para corresponder aos campos de texto
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}
