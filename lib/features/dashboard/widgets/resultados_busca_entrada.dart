part of '../dashboard.dart';

class _ResultadosBuscaEntradaPanel extends StatefulWidget {
  final List<Map<String, dynamic>> resultados;
  final List<Map<String, dynamic>> convidadosReserva;
  final Map<String, dynamic>? reservaSelecionada;
  final String? documentoFiltroAplicado;
  final Function(Map<String, dynamic>) onSelecionar;
  final Function(Map<String, dynamic>) onSelecionarConvidado;
  final VoidCallback onFechar;

  const _ResultadosBuscaEntradaPanel({
    required this.resultados,
    required this.convidadosReserva,
    required this.reservaSelecionada,
    required this.documentoFiltroAplicado,
    required this.onSelecionar,
    required this.onSelecionarConvidado,
    required this.onFechar,
  });

  @override
  State<_ResultadosBuscaEntradaPanel> createState() =>
      _ResultadosBuscaEntradaPanelState();
}

class _ResultadosBuscaEntradaPanelState
    extends State<_ResultadosBuscaEntradaPanel> {
  bool _convidadoDeveSerDestacado(Map<String, dynamic> convidado) {
    if (widget.documentoFiltroAplicado == null) return false;
    final documentoConvidado = convidado['documento']?.toString() ?? '';
    return documentoConvidado == widget.documentoFiltroAplicado;
  }

  Widget _buildGroupedIcon(
      IconData icon, Color color, VoidCallback? onPressed, String? tooltip,
      {bool? isLoading, bool isOpaque = false, double? size}) {
    final tooltipText = tooltip ?? '';
    final tooltipMessage =
        isOpaque ? '$tooltipText (desabilitado)' : tooltipText;

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
        cursor: (isLoading == true)
            ? SystemMouseCursors.basic
            : (onPressed == null || isOpaque
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click),
        child: GestureDetector(
          onTap: ((isLoading == true) || isOpaque) ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            decoration: isOpaque
                ? BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: (isLoading == true)
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
                    color: (isLoading == true)
                        ? color.withValues(alpha: 0.5)
                        : (isOpaque ? color.withValues(alpha: 0.35) : color),
                    size: size ?? (isOpaque ? 24 : 28),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransparentIconGroup(List<IconActionData> actions) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = defaultIconColor.withValues(alpha: 0.1);
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: IntrinsicWidth(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(actions.length * 2 - 1, (index) {
            if (index % 2 == 0) {
              final actionIndex = index ~/ 2;
              final action = actions[actionIndex];
              final iconColor = action.color ?? defaultIconColor;
              return _buildGroupedIcon(
                action.icon,
                iconColor,
                action.onPressed,
                action.tooltip,
                isLoading: action.isLoading,
                size: action.iconSize ?? 18,
              );
            } else {
              return Container(
                width: 1,
                height: 14,
                color: dividerColor,
                margin: const EdgeInsets.symmetric(horizontal: 0),
              );
            }
          }),
        ),
      ),
    );
  }

  Widget _buildThumbnail(dynamic fotoData) {
    if (fotoData == null ||
        fotoData.toString().isEmpty ||
        fotoData.toString() == 'null') {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.person, color: Colors.grey, size: 28),
      );
    }

    final fotoStr = fotoData.toString();
    if (fotoStr.startsWith('http')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: NetworkImage(fotoStr),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Se for base64 (tentativa simples)
    try {
      final cleanBase64 = fotoStr
          .replaceFirst('data:image/png;base64,', '')
          .replaceFirst('data:image/jpeg;base64,', '')
          .replaceFirst('data:image/jpg;base64,', '');
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: MemoryImage(base64Decode(cleanBase64)),
            fit: BoxFit.cover,
          ),
        ),
      );
    } catch (e) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.person, color: Colors.grey, size: 28),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.grey[300]! : Colors.grey[600]!;
    final cardColor = getCardColor(context);
    final borderColor = getBorderColor(context);

    return Column(
      children: [
        // Header do painel
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: IconColors.search(context), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Resultados da Busca',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onFechar,
                icon: Icon(Icons.close, color: textColor),
                tooltip: 'Fechar',
              ),
            ],
          ),
        ),

        // Lista de resultados ou convidados
        Expanded(
          child: () {
            // Se há reserva selecionada, mostrar os convidados
            if (widget.reservaSelecionada != null) {
              if (widget.convidadosReserva.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: secondaryTextColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nenhum convidado encontrado\npara esta reserva',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: widget.convidadosReserva.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final convidado = widget.convidadosReserva[index];
                  final nome = convidado['nome'] ?? '';
                  final documento = convidado['documento'] ?? '';
                  final reservaConvidadoId = convidado['reservaconvidado_id'];

                  // Verificar se deve destacar este convidado
                  final deveDestacar = _convidadoDeveSerDestacado(convidado);

                  // Verificar se já deu entrada
                  final entradaStr =
                      (convidado['entrada'] ?? convidado['dt_entrada'] ?? '')
                          .toString();
                  final saidaStr =
                      (convidado['saida'] ?? convidado['dt_saida'] ?? '')
                          .toString();
                  final jaDeuEntrada = entradaStr.isNotEmpty;
                  final jaDeuSaida = saidaStr.isNotEmpty;
                  final podeDarEntrada = !jaDeuEntrada || jaDeuSaida;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: deveDestacar
                          ? Colors.blue.withValues(alpha: 0.1)
                          : cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: jaDeuEntrada && !jaDeuSaida
                            ? Colors.orange
                            : (deveDestacar ? Colors.blue : borderColor),
                        width: deveDestacar ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnail(
                            convidado['link_foto'] ?? convidado['foto']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header com tipo, status e botá£o selecionar

                              Row(
                                children: [
                                  // Tipo
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF7C4DFF)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF7C4DFF)
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.person,
                                            size: 16,
                                            color: const Color(0xFF7C4DFF)),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Convidado',
                                          style: TextStyle(
                                            color: const Color(0xFF7C4DFF),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Status de entrada (se aplicável)
                                  if (jaDeuEntrada && !jaDeuSaida) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange
                                            .withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: Colors.orange
                                                .withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.access_time,
                                              size: 12, color: Colors.orange),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Já entrou',
                                            style: TextStyle(
                                              color: Colors.orange,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],

                                  const Spacer(),

                                  // Botá£o de seleçao
                                  _buildTransparentIconGroup([
                                    IconActionData(
                                      icon: Icons.check,
                                      tooltip: jaDeuEntrada && !jaDeuSaida
                                          ? 'Nova Entrada/Saída'
                                          : 'Selecionar',
                                      onPressed: () => widget
                                          .onSelecionarConvidado(convidado),
                                    ),
                                  ])
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Nome
                              Text(
                                nome,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),

                              // Documento
                              if (documento.isNotEmpty) ...[
                                Row(
                                  children: [
                                    Icon(
                                      Icons.badge,
                                      size: 16,
                                      color: secondaryTextColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      documento,
                                      style: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            }

            // Caso contrário, mostrar os resultados normais da busca
            if (widget.resultados.isEmpty) {
              // Quando não há resultados, oferecer açao para adicionar avulso
              final doc = (widget.documentoFiltroAplicado ?? '').trim();
              return Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_add_alt_1,
                          color: const Color(0xFF00C853)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Adicionar novo visitante',
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              doc.isNotEmpty
                                  ? 'Documento: $doc'
                                  : 'Nenhum documento informado',
                              style: TextStyle(color: secondaryTextColor),
                            ),
                          ],
                        ),
                      ),
                      _buildTransparentIconGroup([
                        IconActionData(
                          icon: Icons.check,
                          tooltip: 'Adicionar',
                          onPressed: () {
                            // Abrir formulário em modo AV, preenchendo documento se existir
                            final entradaAvulso = <String, dynamic>{
                              'tipo': 'AV',
                              'nome': '',
                              'documento': doc,
                            };
                            widget.onSelecionar(entradaAvulso);
                          },
                        )
                      ]),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.resultados.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entrada = widget.resultados[index];
                final tipo = entrada['tipo'] ?? '';
                final nome = entrada['nome'] ?? '';
                final documento = entrada['documento'] ?? '';
                final destino = entrada['destino'] ?? '';

                // Determinar ícone baseado no tipo
                IconData tipoIcon;
                Color tipoColor;
                if (tipo == 'AG') {
                  tipoIcon = Icons.calendar_today;
                  tipoColor = const Color(0xFF7C4DFF); // Roxo para agendamentos
                } else {
                  tipoIcon = Icons.person;
                  tipoColor = const Color(0xFF00C853); // Verde para avulsos
                }

                // Verificar se já deu entrada
                final entradaStr =
                    (entrada['entrada'] ?? entrada['dt_entrada'] ?? '')
                        .toString();
                final saidaStr =
                    (entrada['saida'] ?? entrada['dt_saida'] ?? '').toString();
                final jaDeuEntrada = entradaStr.isNotEmpty;
                final jaDeuSaida = saidaStr.isNotEmpty;
                final podeDarEntrada = !jaDeuEntrada || jaDeuSaida;

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: jaDeuEntrada && !jaDeuSaida
                            ? Colors.orange
                            : borderColor),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildThumbnail(entrada['link_foto'] ?? entrada['foto']),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header com tipo, status e botá£o selecionar

                            Row(
                              children: [
                                // Tipo
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: tipoColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color:
                                            tipoColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(tipoIcon,
                                          size: 16, color: tipoColor),
                                      const SizedBox(width: 6),
                                      Text(
                                        tipo == 'AG' ? 'Agendamento' : 'Avulso',
                                        style: TextStyle(
                                          color: tipoColor,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Status de entrada (se aplicável)
                                if (jaDeuEntrada && !jaDeuSaida) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.orange.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.orange
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.access_time,
                                            size: 12, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Já entrou',
                                          style: TextStyle(
                                            color: Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                const Spacer(),

                                // Botá£o de seleçao (só se puder dar entrada)
                                if (podeDarEntrada)
                                  _buildTransparentIconGroup([
                                    IconActionData(
                                      icon: Icons.check,
                                      tooltip: 'Selecionar',
                                      onPressed: () =>
                                          widget.onSelecionar(entrada),
                                    ),
                                  ])
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.block,
                                            size: 16, color: Colors.grey),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Indisponível',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Nome
                            Text(
                              nome,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Documento
                            Row(
                              children: [
                                Icon(
                                  Icons.badge,
                                  size: 16,
                                  color: secondaryTextColor,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  documento,
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            // Destino (se disponível)
                            if (destino.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.place,
                                    size: 16,
                                    color: secondaryTextColor,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    destino,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }(),
        ),
      ],
    );
  }
}
