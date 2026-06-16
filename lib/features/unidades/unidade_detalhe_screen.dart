import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/services/crypto_utils.dart';
// Funções auxiliares para cores adaptáveis ao tema
import '../../shared/widgets/registro_dispositivos_page.dart';
import '../../core/config/api_config.dart';

// Funções auxiliares para cores adaptáveis ao tema
bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color getBackgroundColor(BuildContext context) {
  return isDarkMode(context) ? Colors.black : Colors.white;
}

Color getSurfaceColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color.fromARGB(255, 40, 40, 40)
      : Colors.white;
}

Color getCardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color.fromARGB(255, 40, 40, 40)
      : const Color(0xFFF8F9FB);
}

Color getTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.white : Colors.black;
}

Color getSecondaryTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF6B7280);
}

Color getBorderColor(BuildContext context) {
  return isDarkMode(context) ? Colors.grey[800]! : Colors.grey.shade300;
}

Color getShadowColor(BuildContext context) {
  return isDarkMode(context)
      ? Colors.black.withValues(alpha: 0.3)
      : Colors.black.withValues(alpha: 0.1);
}

class UnidadeDetalheScreen extends StatefulWidget {
  final VoidCallback onClose;
  final Map<String, dynamic> unidade;
  final Function(Widget, {VoidCallback? onClose})? onOpenPanel;
  final VoidCallback? onBackToParent;
  final bool? permissaoAcessoPessoas;

  const UnidadeDetalheScreen({
    super.key,
    required this.onClose,
    required this.unidade,
    this.onBackToParent,
    this.onOpenPanel,
    this.permissaoAcessoPessoas,
  });

  @override
  State<UnidadeDetalheScreen> createState() => _UnidadeDetalheScreenState();
}

class _UnidadeDetalheScreenState extends State<UnidadeDetalheScreen> {
  List<Map<String, dynamic>> _moradores = [];
  List<Map<String, dynamic>> _veiculos = [];
  List<Map<String, dynamic>> _visitantes = [];
  List<Map<String, dynamic>> _prestadores = [];
  bool _loading = true;
  bool _mostrarBicicletas = false;
  //-----------------------------//
  // Mapa para armazenar nomes dos associados dos veículos
  //-----------------------------//
  Map<int, String> _nomesAssociados = {};
  //-----------------------------//
  final Set<String> _revealedPii = {};

  @override
  void initState() {
    super.initState();
    print(
        'UnidadeDetalheScreen initState - permissaoAcessoPessoas: ${widget.permissaoAcessoPessoas}');
    _carregarDadosUnidade();
  }

  Future<void> _carregarDadosUnidade() async {
    setState(() => _loading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final url = Uri.parse('https://gate.conectcon.net.br/pt-br/unidadelist');
      final condominioId = await ApiConfig.getCondominioId();

      final payload = {
        "apto_id": widget.unidade['apto_id'] ?? 0,
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "flg_principal": "N",
      };

      print('Carregando dados da unidade: $payload');

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
        final unidades =
            List<Map<String, dynamic>>.from(data['data']?['unidades'] ?? []);
        final veiculos =
            List<Map<String, dynamic>>.from(data['data']?['veiculos'] ?? []);

        //-----------------------------//
        // Criar mapa de nomes dos associados para veículos
        //-----------------------------//
        final nomesAssociadosTemp = <int, String>{};
        for (final usuario in unidades) {
          final usuarioId = usuario['usuario_id'] ?? usuario['id'];
          final nome = usuario['nome'] ??
              usuario['nome_txt'] ??
              usuario['usuario_nome'] ??
              '';
          if (usuarioId != null && nome.isNotEmpty) {
            nomesAssociadosTemp[usuarioId] = nome;
          }
        }
        //-----------------------------//

        // Categorizar os usuários por situação
        final moradoresTemp = <Map<String, dynamic>>[];
        final visitantesTemp = <Map<String, dynamic>>[];
        final prestadoresTemp = <Map<String, dynamic>>[];

        for (final usuario in unidades) {
          final situacao = usuario['situacao'];
          // Usar diretamente os dados que vêm da API unidadelist
          final usuarioData = {
            ...usuario, // Copiar todos os campos da API
            'tipo_display': situacao == 'P'
                ? 'Proprietário'
                : situacao == 'M'
                    ? 'Morador'
                    : situacao == 'F'
                        ? 'Visitante'
                        : 'Prestador',
          };

          switch (situacao) {
            case 'P': // Proprietário
            case 'M': // Morador
              moradoresTemp.add(usuarioData);
              break;
            case 'F': // Visitante
              visitantesTemp.add(usuarioData);
              break;
            case 'S': // Prestador
              prestadoresTemp.add(usuarioData);
              break;
          }
        }

        setState(() {
          _moradores = moradoresTemp;
          _veiculos = veiculos;
          _visitantes = visitantesTemp;
          _prestadores = prestadoresTemp;
          _nomesAssociados = nomesAssociadosTemp;
          _loading = false;
        });

        print(
            'Carregados: ${_moradores.length} moradores, ${_veiculos.length} veículos, ${_visitantes.length} visitantes, ${_prestadores.length} prestadores');
      } else {
        print(
            'Erro na API unidadelist: ${response.statusCode} - ${response.body}');
        setState(() => _loading = false);
      }
    } catch (e) {
      print('Erro ao carregar dados da unidade: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unidadeNome =
        widget.unidade['unidade_mostra'] ?? widget.unidade['nome'] ?? 'Unidade';

    return Container(
      color: getBackgroundColor(context),
      child: Column(
        children: [
          // Header matching Ocorrências modal style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF10133E),
              border: Border(
                  bottom: BorderSide(color: Color(0xFF10133E), width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.meeting_room, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    unidadeNome,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 20, color: Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Fechar',
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Padding(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 600 ? 16 : 24),
                    child: Column(
                      children: [
                        // Primeira linha: Moradores e Veículos
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child:
                                      _section('Moradores', _residentItems())),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: _section(
                                      _veiculos.any((v) =>
                                              v['automarca_id']?.toString() ==
                                              '99')
                                          ? 'Veículos I Bicicletas'
                                          : 'Veículos',
                                      _vehicleItems())),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Segunda linha: Colaboradores (Prestadores) e Visitantes
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: _section(
                                      'Colaboradores', _providerItems())),
                              const SizedBox(width: 16),
                              Expanded(
                                  child:
                                      _section('Visitantes', _visitorItems())),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Terceira linha: Contatos e Pets
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                  child: _section('Contatos', _contactItems())),
                              const SizedBox(width: 16),
                              Expanded(child: _section('Pets', _petItems())),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
          )
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Container(
      padding:
          EdgeInsets.all(MediaQuery.of(context).size.width < 600 ? 12 : 16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (title != 'Veículos I Bicicletas') ...[
                Icon(
                  title == 'Moradores'
                      ? Icons.person
                      : title.contains('Veículos')
                          ? (_mostrarBicicletas
                              ? Icons.pedal_bike
                              : Icons.directions_car)
                          : title.contains('Visitantes')
                              ? Icons.groups
                              : title == 'Contatos'
                                  ? Icons.phone
                                  : title == 'Pets'
                                      ? Icons.pets
                                      : Icons.work,
                  color: getTextColor(context),
                ),
                const SizedBox(width: 8),
              ],
              if (title == 'Veículos I Bicicletas')
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarBicicletas = false;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 18,
                                color: !_mostrarBicicletas
                                    ? getTextColor(context)
                                    : getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Veículos',
                                style: TextStyle(
                                  fontWeight: !_mostrarBicicletas
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: !_mostrarBicicletas
                                      ? getTextColor(context)
                                      : getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Text(
                        ' I ',
                        style: TextStyle(
                          color: getTextColor(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarBicicletas = true;
                            });
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.pedal_bike,
                                size: 18,
                                color: _mostrarBicicletas
                                    ? getTextColor(context)
                                    : getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Bicicletas',
                                style: TextStyle(
                                  fontWeight: _mostrarBicicletas
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: _mostrarBicicletas
                                      ? getTextColor(context)
                                      : getSecondaryTextColor(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Expanded(
                  child: Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: getTextColor(context))),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  'Nenhum ${title == 'Veículos I Bicicletas' ? (_mostrarBicicletas ? 'Bicicleta' : 'Veículo') : title.toLowerCase()} encontrado',
                  style: TextStyle(color: getSecondaryTextColor(context)),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Mapa para armazenar o estado das fotos: user_id -> base64
  final Map<int, String?> _loadedPhotos = {};
  // Mapa para controlar se a foto está sendo carregada: user_id -> bool
  final Map<int, bool> _loadingPhotos = {};
  // Mapa para controlar visibilidade da foto: user_id -> bool
  final Map<int, bool?> _photoVisibility = {};

  Future<void> _togglePhoto(int id, String tipo, int condominioId) async {
    // Se já está visível, ocultar
    if (_photoVisibility[id] == true) {
      setState(() {
        _photoVisibility[id] = false;
      });
      return;
    }

    // Se já tem foto carregada, apenas mostrar
    if (_loadedPhotos.containsKey(id) && _loadedPhotos[id] != null) {
      setState(() {
        _photoVisibility[id] = true;
      });
      return;
    }

    // Buscar foto
    setState(() {
      _loadingPhotos[id] = true;
      _photoVisibility[id] = true;
    });

    final photo = await _fetchPhoto(id, tipo, condominioId);

    if (mounted) {
      setState(() {
        _loadingPhotos[id] = false;
        _loadedPhotos[id] = photo;
      });
    }
  }

  Future<String?> _fetchPhoto(int id, String tipo, int condominioId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final url = Uri.parse(ApiConfig.getEndpoint('unidade', 'fotolistar'));

      final payload = {
        'condominio_id': condominioId,
        'tipoUSU': tipo,
        'usuario_id': id,
      };

      print('📸 Buscando foto via fotolistar: $url - Body: $payload');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (!mounted) return null;

      print('📸 Resposta fotolistar: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('📸 Dados recebidos: $data');

        String? fotoResult;

        if (data is Map) {
          // Verifica se 'data' é uma lista (estrutura comum)
          if (data['data'] is List && data['data'].isNotEmpty) {
            final item = data['data'][0];
            fotoResult = item['fotourl'];
          }
          // Verifica se 'data' é um Map direto
          else if (data['data'] is Map) {
            fotoResult = data['data']['fotourl'];
          }
          // Caso a API retorne 'fotourl' na raiz (fallback)
          else if (data['fotourl'] != null) {
            fotoResult = data['fotourl'];
          }

          // Se ainda não encontrou, tenta 'foto' ou 'arquivo' se for URL
          if (fotoResult == null) {
            // Tenta pegar de data[0] novamente se falhou acima
            dynamic item;
            if (data['data'] is List && data['data'].isNotEmpty) {
              item = data['data'][0];
            } else if (data['data'] is Map)
              item = data['data'];
            else
              item = data;

            if (item != null && item is Map) {
              if (item['foto'] != null &&
                  item['foto'].toString().startsWith('http')) {
                fotoResult = item['foto'];
              } else if (item['arquivo'] != null &&
                  item['arquivo'].toString().startsWith('http')) {
                fotoResult = item['arquivo'];
              }
            }
          }
        }

        if (fotoResult != null &&
            fotoResult.isNotEmpty &&
            fotoResult.startsWith('http')) {
          return fotoResult;
        }
      }
    } catch (e) {
      print('Erro ao buscar foto: $e');
    }
    return null;
  }

  String _maskName(String nomeCompleto) {
    final partes = nomeCompleto.trim().split(RegExp(r'\s+'));
    if (partes.length == 1) return partes.first;

    final List<String> resultado = [partes.first];
    for (int i = 1; i < partes.length; i++) {
      final parte = partes[i];
      if (parte.length > 3) {
        resultado.add('${parte.substring(0, 3)}***');
      } else {
        resultado.add('$parte***');
      }
    }
    return resultado.join(' ');
  }

  String _formatarNome(String? nomeCompleto, {int? id}) {
    if (nomeCompleto == null || nomeCompleto.trim().isEmpty) return '';
    if (id != null && _revealedPii.contains('nome_$id')) {
      return nomeCompleto;
    }
    return _maskName(nomeCompleto);
  }

  List<Widget> _residentItems() => _moradores.map((morador) {
        final int id = morador['id'] ?? morador['usuario_id'] ?? 0;
        final int condId = widget.unidade['condominio_id'] is int
            ? widget.unidade['condominio_id']
            : int.tryParse(widget.unidade['condominio_id'].toString()) ?? 0;

        return _listTile(
          morador['nome'] ?? 'Residente',
          id: id,
          tipo: 'USU',
          condominioId: condId,
          badge: morador['tipo_display'] ?? '',
          showAccessBadge: widget.permissaoAcessoPessoas == true,
          onTap: () {
            if (widget.onOpenPanel != null &&
                widget.permissaoAcessoPessoas == true) {
              widget.onOpenPanel!(
                RegistroDispositivosPage(
                  onClose: widget.onBackToParent ?? widget.onClose,
                  morador: morador,
                ),
              );
            }
          },
        );
      }).toList();

  List<Widget> _vehicleItems() {
    final filtrados = _veiculos.where((v) {
      final isBici = v['automarca_id']?.toString() == '99';
      return _mostrarBicicletas ? isBici : !isBici;
    }).toList();

    return filtrados.map((veiculo) {
      final placa = veiculo['placa'] ?? '';
      final usuarioocupanteId = veiculo['usuarioocupante_id'];
      String subtitle = 'Placa: $placa';

      if (usuarioocupanteId != null && usuarioocupanteId != 0) {
        final nomeAssociado = _nomesAssociados[usuarioocupanteId];
        if (nomeAssociado != null && nomeAssociado.isNotEmpty) {
          subtitle += '  •  Vinculado: ${_formatarNome(nomeAssociado)}';
        } else {
          subtitle += '  •  Vinculado: Não informado';
        }
      }

      // Usar ID do veículo ou do proprietário? Requisito pediu 'usuario_id', então deve ser do morador vinculado ou do próprio veículo se tiver
      final int id = veiculo['id'] ??
          veiculo['usuario_id'] ??
          0; // Ajustar conforme necessidade real
      final int condId = widget.unidade['condominio_id'] is int
          ? widget.unidade['condominio_id']
          : int.tryParse(widget.unidade['condominio_id'].toString()) ?? 0;

      return _listTile(
        veiculo['marca_auto'] ?? 'Veículo',
        id: id,
        tipo:
            'USU', // Veículo pode não ter foto de usuário, mas mantendo lógica pedida
        condominioId: condId,
        subtitle: subtitle,
        showAccessBadge: widget.permissaoAcessoPessoas == true,
        icon: _mostrarBicicletas ? Icons.pedal_bike : Icons.directions_car,
        onTap: () {
          if (widget.onOpenPanel != null &&
              widget.permissaoAcessoPessoas == true) {
            widget.onOpenPanel!(
              RegistroDispositivosPage(
                onClose: widget.onBackToParent ?? widget.onClose,
                morador: {
                  ...veiculo,
                  'tipo': 'Veículo',
                  'situacao': 'V',
                },
                modoVeiculo: true,
              ),
            );
          }
        },
      );
    }).toList();
  }

  List<Widget> _visitorItems() => _visitantes.map((visitante) {
        final flgAnunciar = visitante['flg_anunciar'] == true ||
            visitante['flg_anunciar'] == 'S' ||
            visitante['flg_anunciar'] == 's';

        final int id = visitante['id'] ?? visitante['usuario_id'] ?? 0;
        final int condId = widget.unidade['condominio_id'] is int
            ? widget.unidade['condominio_id']
            : int.tryParse(widget.unidade['condominio_id'].toString()) ?? 0;

        return _listTile(
          visitante['nome'] ?? 'Visitante',
          id: id,
          tipo: 'USU',
          condominioId: condId,
          subtitle: 'Status: Ativo',
          showAccessBadge: widget.permissaoAcessoPessoas == true,
          chip: flgAnunciar ? 'Anunciar visitante' : null,
          onTap: () {
            if (widget.onOpenPanel != null &&
                widget.permissaoAcessoPessoas == true) {
              widget.onOpenPanel!(
                RegistroDispositivosPage(
                  onClose: widget.onBackToParent ?? widget.onClose,
                  morador: visitante,
                  modoPrestadorVisitante: true,
                ),
              );
            }
          },
        );
      }).toList();

  List<Widget> _providerItems() => _prestadores.map((prestador) {
        final flgAnunciar = prestador['flg_anunciar'] == true ||
            prestador['flg_anunciar'] == 'S' ||
            prestador['flg_anunciar'] == 's';

        final int id = prestador['id'] ?? prestador['usuario_id'] ?? 0;
        final int condId = widget.unidade['condominio_id'] is int
            ? widget.unidade['condominio_id']
            : int.tryParse(widget.unidade['condominio_id'].toString()) ?? 0;

        return _listTile(
          prestador['nome'] ?? 'Prestador',
          id: id,
          tipo: 'USU',
          condominioId: condId,
          chip: flgAnunciar ? 'Anunciar colaborador' : null,
          showAccessBadge: widget.permissaoAcessoPessoas == true,
          icon: Icons.badge,
          onTap: () {
            if (widget.onOpenPanel != null &&
                widget.permissaoAcessoPessoas == true) {
              widget.onOpenPanel!(
                RegistroDispositivosPage(
                  onClose: widget.onBackToParent ?? widget.onClose,
                  morador: prestador,
                  modoPrestadorVisitante: true,
                ),
              );
            }
          },
        );
      }).toList();

  List<Widget> _contactItems() {
    // TODO: Implementar carregamento de contatos da API
    // Por enquanto, retorna uma mensagem de placeholder
    return [
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sem contatos cadastrados',
            style: TextStyle(
              color: getSecondaryTextColor(context),
              fontSize: 14,
            ),
          ),
        ),
      ),
    ];
  }

  List<Widget> _petItems() {
    // TODO: Implementar carregamento de pets da API
    // Por enquanto, retorna uma mensagem de placeholder
    return [
      Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Sem pets cadastrados',
            style: TextStyle(
              color: getSecondaryTextColor(context),
              fontSize: 14,
            ),
          ),
        ),
      ),
    ];
  }

  Widget _listTile(
    String title, {
    required int id,
    required String tipo,
    required int condominioId,
    String? subtitle,
    String? badge,
    String? chip,
    bool showAccessBadge = false,
    IconData icon = Icons.person,
    VoidCallback? onTap,
  }) {
    // Estado da foto
    final bool isVisible = _photoVisibility[id] ?? false;
    final bool isLoading = _loadingPhotos[id] ?? false;
    final String? photoData = _loadedPhotos[id];
    final bool hasPhoto = photoData != null && photoData.isNotEmpty;

    final String displayedTitle = _formatarNome(title, id: id);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: getSurfaceColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Row(
          children: [
            // Área da foto / Visualização
            GestureDetector(
              onTap: () => _togglePhoto(id, tipo, condominioId),
              child: Container(
                width: 70, // Tamanho fixo para o quadrado da foto
                height: 70,
                decoration: BoxDecoration(
                  color: isDarkMode(context)
                      ? Colors.black26
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: isLoading
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (isVisible && hasPhoto)
                          ? Image.network(
                              photoData,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Center(
                                  child: Icon(Icons.broken_image,
                                      size: 20, color: Colors.grey.shade600),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : Center(
                              child: Icon(
                                (isVisible && !hasPhoto)
                                    ? Icons.no_photography
                                    : Icons.camera_alt,
                                size:
                                    24, // Ícone um pouco maior já que não tem texto
                                color: Colors.grey.shade600,
                              ),
                            ),
                ),
              ),
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        final key = 'nome_$id';
                        if (_revealedPii.contains(key)) {
                          _revealedPii.remove(key);
                        } else {
                          _revealedPii.add(key);
                        }
                      });
                    },
                    child: Text(
                      displayedTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: getTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Linha de tags: Smart Access | Proprietário | ...
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      if (showAccessBadge) ...[
                        Text(
                          'Smart Access',
                          style: TextStyle(
                            color: getTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (badge != null)
                          Text('|',
                              style: TextStyle(
                                  color: getSecondaryTextColor(context),
                                  fontSize: 12)),
                      ],
                      if (badge != null)
                        Text(
                          badge,
                          style: TextStyle(
                            color: getTextColor(context),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            color: getSecondaryTextColor(context),
                            fontSize: 12)),
                  ],
                  if (chip != null) ...[
                    const SizedBox(height: 8),
                    _chip(chip),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.campaign, size: 16, color: getSecondaryTextColor(context)),
        const SizedBox(width: 6),
        Text(text,
            style:
                TextStyle(color: getSecondaryTextColor(context), fontSize: 12)),
      ],
    );
  }
}
