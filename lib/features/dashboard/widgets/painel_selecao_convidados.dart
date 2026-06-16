part of '../dashboard.dart';

class _PainelSelecaoConvidados extends StatefulWidget {
  final String titulo;
  final List<Map<String, dynamic>> convidados;
  final String reservaId;
  final Function(Map<String, dynamic>) onSelecionar;
  final VoidCallback? onFechar;
  final VoidCallback? onAtualizar;

  const _PainelSelecaoConvidados({
    required this.titulo,
    required this.convidados,
    required this.reservaId,
    required this.onSelecionar,
    this.onFechar,
    this.onAtualizar,
  });

  @override
  State<_PainelSelecaoConvidados> createState() =>
      _PainelSelecaoConvidadosState();
}

class _PainelSelecaoConvidadosState extends State<_PainelSelecaoConvidados> {
  // Helper method to build grouped icon buttons
  Widget _buildGroupedIcon(
    IconData icon,
    Color color,
    VoidCallback? onPressed,
    String tooltip, {
    bool isLoading = false,
    bool isOpaque = false,
    bool isMarked = false,
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

  Widget _buildDivider(Color color) {
    return Container(
      width: 1,
      height: 28,
      color: color,
    );
  }

  Widget _buildTransparentIconGroup(List<IconActionData> actions) {
    final defaultColor = getTextColor(context);
    final dividerColor = defaultColor.withValues(alpha: 0.3);

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
            final actionIndex = index ~/ 2;
            final action = actions[actionIndex];
            return _buildGroupedIcon(
              action.icon,
              action.color ?? defaultColor,
              action.onPressed,
              action.tooltip,
              isLoading: action.isLoading,
              isOpaque: action.isOpaque,
              isMarked: action.isMarked,
            );
          } else {
            return _buildDivider(dividerColor);
          }
        }),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 1200;
    final isVerySmallScreen = screenWidth < 800;

    return Container(
      width: isSmallScreen ? screenWidth * 0.5 : 600,
      color: getCardColor(context),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: getSurfaceColor(context),
              border: Border(
                bottom: BorderSide(
                  color: getBorderColor(context),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.titulo,
                    style: TextStyle(
                      fontSize: isVerySmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(context),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, color: getTextColor(context)),
                  tooltip: 'Atualizar',
                  onPressed: widget.onAtualizar,
                ),
                IconButton(
                  icon: Icon(Icons.close, color: getTextColor(context)),
                  onPressed: () {
                    if (widget.onFechar != null) {
                      widget.onFechar!();
                    } else {
                      fecharPainelLateralGlobal();
                    }
                  },
                ),
              ],
            ),
          ),

          // Lista de convidados
          Expanded(
            child: widget.convidados.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.group_off,
                          size: 64,
                          color: getSecondaryTextColor(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum convidado encontrado',
                          style: TextStyle(
                            color: getSecondaryTextColor(context),
                            fontSize: isVerySmallScreen ? 14 : 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.convidados.length,
                    itemBuilder: (context, index) {
                      final convidado = widget.convidados[index];
                      return _buildConvidadoCard(
                          context, convidado, isVerySmallScreen);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _cleanString(dynamic value) {
    if (value == null) return '';
    final s = value.toString().trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return '';
    return s;
  }

  Future<bool> _registrarSaida(Map<String, dynamic> convidado,
      {bool silent = false}) async {
    final reservaconvidadoId = convidado['reservaconvidado_id']?.toString() ??
        convidado['id']?.toString();
    final reservaId = widget.reservaId;

    if (reservaconvidadoId == null) return false;

    final sucesso = await registrarEntradaSaidaGlobal(
        reservaId, reservaconvidadoId, false); // false = Saída

    if (!mounted) return false;

    if (sucesso) {
      if (!silent) {
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Saída Registrada',
          message: 'Saída registrada com sucesso!',
        );
      }
      if (widget.onAtualizar != null) {
        widget.onAtualizar!();
      }
      return true;
    } else {
      // Sempre mostrar erro, independente de silent, para não esconder falhas
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Falha ao registrar saída.',
      );
      return false;
    }
  }

  Future<void> _registrarSaidaEEntrada(Map<String, dynamic> convidado) async {
    // 1. Dar saída (com feedback visual para o usuário ter certeza)
    final saiu = await _registrarSaida(convidado, silent: false);

    if (!saiu) return; // Se falhou a saída, não prossegue para entrada

    if (!mounted) return;

    // 2. Abrir formulário (para nova entrada) somente após sucesso da saída
    widget.onSelecionar(convidado);
  }

  Widget _buildConvidadoCard(BuildContext context,
      Map<String, dynamic> convidado, bool isVerySmallScreen) {
    final nome =
        (convidado['nome'] ?? convidado['convidado_txt'] ?? 'Convidado')
            .toString();
    final documento =
        (convidado['documento'] ?? convidado['documento_txt'] ?? '').toString();
    final unidade =
        (convidado['unidade'] ?? convidado['unidade_mostra'] ?? '').toString();
    final periodo = (convidado['periodo'] ?? '').toString();

    // Verificar se já deu entrada
    final entradaStr =
        _cleanString(convidado['entrada'] ?? convidado['dt_entrada']);
    final saidaStr = _cleanString(convidado['saida'] ?? convidado['dt_saida']);
    final temEntrada = entradaStr.isNotEmpty;
    final temSaida = saidaStr.isNotEmpty;

    // Formatar data/hora da entrada
    String? entradaFormatada;
    if (temEntrada) {
      try {
        final entradaDateTime = DateTime.parse(entradaStr.replaceAll(' ', 'T'));
        entradaFormatada =
            '${entradaDateTime.day.toString().padLeft(2, '0')}/${entradaDateTime.month.toString().padLeft(2, '0')}/${entradaDateTime.year} ${entradaDateTime.hour.toString().padLeft(2, '0')}:${entradaDateTime.minute.toString().padLeft(2, '0')}';
      } catch (e) {
        entradaFormatada = entradaStr;
      }
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => widget.onSelecionar(convidado),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.orange.shade400,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),

            // Informaá§ões do convidado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: getTextColor(context),
                    ),
                  ),
                  if ((unidade).isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Visitante Â· $unidade',
                      style: TextStyle(color: getTextColor(context)),
                    ),
                  ],
                  const SizedBox(height: 6),
                  // Bloco extra no mesmo padrão do _listItem.extra
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (documento.isNotEmpty) ...[
                        Text(
                          'Doc: $documento',
                          style:
                              TextStyle(color: getSecondaryTextColor(context)),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (periodo.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 14,
                              color: getSecondaryTextColor(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                periodo,
                                style: TextStyle(
                                    color: getSecondaryTextColor(context)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      // Mostrar data/hora da entrada se houver
                      if (temEntrada) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 14,
                              color: Colors.green.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                temSaida
                                    ? 'Entrada: $entradaFormatada (Saiu)'
                                    : 'Entrada: $entradaFormatada',
                                style: TextStyle(
                                  color: temSaida
                                      ? getSecondaryTextColor(context)
                                      : Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Aá§ões baseadas no estado (Dentro ou Fora)
            Builder(
              builder: (context) {
                final actions = <IconActionData>[];

                if (temEntrada && !temSaida) {
                  // ESTá DENTRO: Mostrar Selecionar (Editar) e Saída
                  actions.add(IconActionData(
                    icon: Icons.edit,
                    tooltip: 'Editar / Detalhes',
                    onPressed: () => widget.onSelecionar(convidado),
                  ));
                  actions.add(IconActionData(
                    icon: Icons.exit_to_app,
                    tooltip: 'Registrar Saída',
                    color: Colors.red,
                    onPressed: () => _registrarSaida(convidado),
                  ));
                } else {
                  // ESTá FORA (Nunca entrou ou já Saiu): Mostrar Entrada
                  // "Caso a data preenchida seja < que a data corrente vai ter Nova entrada"
                  // Implica que se já tem saída (data antiga), habilita nova entrada.
                  actions.add(IconActionData(
                    icon: Icons.login,
                    tooltip:
                        'Entrada', // "Botá£o selecionar tem que se chamar Entrada"
                    color: Colors.green,
                    onPressed: () => widget.onSelecionar(convidado),
                  ));
                }

                return _buildTransparentIconGroup(actions);
              },
            ),
          ],
        ),
      ),
    );
  }
}
