part of '../dashboard.dart';

class _ConvidadosModal extends StatefulWidget {
  final String reservaId;
  final List<Map<String, dynamic>> convidados;

  const _ConvidadosModal({
    required this.reservaId,
    required this.convidados,
  });

  @override
  State<_ConvidadosModal> createState() => _ConvidadosModalState();
}

class _ConvidadosModalState extends State<_ConvidadosModal> {
  late List<Map<String, dynamic>> _convidadosFiltrados;
  final TextEditingController _searchController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _convidadosFiltrados = widget.convidados;
    _searchController.addListener(_filterConvidados);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterConvidados() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _convidadosFiltrados = widget.convidados;
      } else {
        _convidadosFiltrados = widget.convidados.where((convidado) {
          final nome = (convidado['convidado_txt'] ?? convidado['nome'] ?? '')
              .toString()
              .toLowerCase();
          final documento =
              (convidado['documento_txt'] ?? convidado['documento'] ?? '')
                  .toString()
                  .toLowerCase();
          return nome.contains(query) || documento.contains(query);
        }).toList();
      }
    });
  }

  Future<void> _recarregarConvidados() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      if (tokenSessao.isEmpty) return;

      final url = Uri.parse(
        ApiConfig.getUrl(
          'dashboard',
          'convidados',
          params: {'reserva_id': widget.reservaId, 'culture': 'pt-br'},
        ),
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final convidadosData = data['data'];
        final lista =
            (convidadosData is Map && convidadosData['convidados'] is List)
                ? convidadosData['convidados']
                : [];

        final novosConvidados = List<Map<String, dynamic>>.from(lista);

        // Atualizar a lista filtrada
        setState(() {
          // Atualizar a lista do widget pai também
          (context as Element).visitAncestorElements((element) {
            if (element.widget is _ConvidadosModal) {
              // Ná£o podemos modificar o widget pai diretamente, mas podemos atualizar o estado local
              _convidadosFiltrados = novosConvidados;
              return false;
            }
            return true;
          });
          _convidadosFiltrados = novosConvidados;
          _loading = false;
        });
      }
    } catch (e) {
      print('Erro ao recarregar convidados: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header do painel lateral
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF7C4DFF),
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.group, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Convidados do Agendamento',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => fecharPainelLateralGlobal(),
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Fechar painel',
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.all(20),
          child: CharacterCounterField(
            controller: _searchController,
            decoration:
                inputDecorationPadrao(context, hintText: 'Buscar convidados')
                    .copyWith(
              prefixIcon: Icon(Icons.search, color: IconColors.search(context)),
            ),
          ),
        ),

        // Counter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                'Total: ${_convidadosFiltrados.length} convidados',
                style: TextStyle(
                  color: getSecondaryTextColor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _convidadosFiltrados.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 64,
                            color: getSecondaryTextColor(context),
                          ),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Sem convidados registrados',
                              style: TextStyle(
                                  color: getSecondaryTextColor(context)),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _convidadosFiltrados.length,
                      itemBuilder: (context, index) {
                        final convidado = _convidadosFiltrados[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: getCardColor(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: getBorderColor(context)),
                          ),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF7C4DFF),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              convidado['convidado_txt'] ??
                                  convidado['nome'] ??
                                  'Nome não informado',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: getTextColor(context),
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Documento: ${convidado['documento_txt'] ?? convidado['documento'] ?? 'Ná£o informado'}',
                                  style: TextStyle(
                                      color: getSecondaryTextColor(context)),
                                ),
                                if (convidado['veiculo'] != null &&
                                    convidado['veiculo'].toString().isNotEmpty)
                                  Text(
                                    'Veículo: ${convidado['veiculo']} - ${convidado['placa'] ?? ''}',
                                    style: TextStyle(
                                        color: getSecondaryTextColor(context)),
                                  ),
                                Row(
                                  children: [
                                    Text(
                                      'Agregados: ${convidado['agregados'] ?? '1'}',
                                      style: TextStyle(
                                          color:
                                              getSecondaryTextColor(context)),
                                    ),
                                    const SizedBox(width: 16),
                                    Text(
                                      'Acessos: ${convidado['acessos'] ?? '1'}',
                                      style: TextStyle(
                                          color:
                                              getSecondaryTextColor(context)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: StatefulBuilder(
                              builder: (context, setState) {
                                bool isEntrada = convidado['isEntrada'] ?? true;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isEntrada
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: GestureDetector(
                                    onTap: () async {
                                      // Registrar entrada/saída na API
                                      final reservaId = widget.reservaId;
                                      final reservaconvidadoId =
                                          convidado['reservaconvidado_id']
                                                  ?.toString() ??
                                              convidado['sequencia']
                                                  ?.toString() ??
                                              '';

                                      final sucesso =
                                          await registrarEntradaSaidaGlobal(
                                              reservaId,
                                              reservaconvidadoId,
                                              isEntrada);

                                      // Só atualizar estado visual se a API foi bem-sucedida
                                      if (sucesso && mounted) {
                                        setState(() {
                                          isEntrada = !isEntrada;
                                          convidado['isEntrada'] = isEntrada;
                                        });
                                      }
                                    },
                                    child: Text(
                                      isEntrada ? 'Entrada' : 'Saída',
                                      style: TextStyle(
                                        color: isEntrada
                                            ? Colors.green.shade800
                                            : Colors.red.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
