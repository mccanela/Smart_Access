import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
//-----------------------------//
// Web only: open links in a new browser tab
//-----------------------------//
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/config/api_config.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../main.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../shared/widgets/expandable_tabs.dart';
import '../../core/utils/ui_standards.dart';

// Grupo de ícones transparentes genérico
Widget _buildTransparentIconGroup(
    BuildContext context, List<Map<String, dynamic>> actions) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final iconColor = isDark ? Colors.white : Colors.black;
  final dividerColor = iconColor.withValues(alpha: 0.3);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(40),
      border: Border.all(color: dividerColor.withValues(alpha: 0.15), width: 1),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(actions.length * 2 - 1, (index) {
        if (index % 2 == 0) {
          // Ícone
          final actionIndex = index ~/ 2;
          final action = actions[actionIndex];
          return _buildGroupedIcon(
            action['icon'] as IconData,
            iconColor,
            action['onPressed'] as VoidCallback,
            action['tooltip'] as String,
          );
        } else {
          // Divisor
          return _buildDivider(dividerColor);
        }
      }),
    ),
  );
}

Widget _buildGroupedIcon(
    IconData icon, Color color, VoidCallback? onPressed, String tooltip,
    {bool isLoading = false, bool isOpaque = false, double? iconSize}) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12),
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

class CondominioModal extends StatefulWidget {
  final VoidCallback onClose;
  const CondominioModal({super.key, required this.onClose});

  @override
  State<CondominioModal> createState() => _CondominioModalState();
}

class _CondominioModalState extends State<CondominioModal>
    with SingleTickerProviderStateMixin {
  bool _loadingEndereco = false;
  bool _loadingCorpoDiretivo = false;
  bool _loadingRegimento = false;
  bool _loadingTerceirizados = false;
  bool _loadingAvisosInternos = false;

  Map<String, dynamic>? _enderecoData;
  List<Map<String, dynamic>> _corpoDiretivoList = [];
  List<Map<String, dynamic>> _riDocs = [];
  List<Map<String, dynamic>> _terceirizadosList = [];
  List<Map<String, dynamic>> _terceirizadosFiltered = [];
  final Set<int> _expandedTerceirizados = {};
  List<Map<String, dynamic>> _avisosInternosList = [];
  List<Map<String, dynamic>> _avisosFiltered = [];

  final TextEditingController _searchTerceirizadosController =
      TextEditingController();
  final TextEditingController _searchAvisosController = TextEditingController();

  // Helper for Standard Search Decoration
  InputDecoration _standardSearchDecoration(BuildContext context,
      {String? hintText}) {
    final isDark = isDarkMode(context);
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 16),
      labelStyle: const TextStyle(fontSize: 16),
      prefixIcon: Icon(
        Icons.search,
        color: isDark ? Colors.white70 : Colors.black,
      ),
      filled: true,
      fillColor: isDark ? const Color.fromARGB(255, 40, 40, 40) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
          color: Color(0xFF684F8E),
          width: 1.5,
        ),
      ),
      isDense: true,
    );
  }

  String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isNotEmpty
            ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
            : '')
        .join(' ');
  }

  // Estilos de texto padronizados para toda a modal
  static TextStyle _tsTitle(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400, // Menos pesado para elegância
        color: isDarkMode(context) ? Colors.white : Colors.black,
      );
  static TextStyle _tsBody(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w300, // Mais fina e elegante
        color: isDarkMode(context) ? Colors.white70 : Colors.black,
      );
  static TextStyle _tsCaption(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: isDarkMode(context) ? Colors.white54 : Colors.black87,
      );
  static TextStyle _tsSectionTitle(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDarkMode(context) ? Colors.white : const Color(0xFF101828),
      );
  static TextStyle _tsLink(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: isDarkMode(context) ? Colors.blue.shade300 : Colors.black,
        decoration: TextDecoration.underline,
      );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchEndereco();
    _fetchCorpoDiretivo();
    _fetchRegimento();
    _fetchTerceirizados();
    _fetchAvisosInternos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchTerceirizadosController.dispose();
    _searchAvisosController.dispose();
    super.dispose();
  }

  Future<void> _fetchEndereco() async {
    setState(() {
      _loadingEndereco = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();
      final headers = await ApiConfig.getDefaultHeaders();

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('condominio', 'endereco')),
        headers: headers,
        body: jsonEncode({'condominio_id': condominioId}),
      );

      // REMOVIDO: Print de debug da resposta

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // A estrutura correta é data['data']['result'][0]
        final resultData = data['data']?['result']?[0] ?? data['data'] ?? data;
        setState(() {
          _enderecoData = resultData;
          _loadingEndereco = false;
        });
      } else {
        // REMOVIDO: Print de erro de status code
        setState(() {
          _loadingEndereco = false;
        });
      }
    } catch (e) {
      // REMOVIDO: Print de erro de exception
      setState(() {
        _loadingEndereco = false;
      });
    }
  }

  Future<void> _fetchCorpoDiretivo() async {
    setState(() {
      _loadingCorpoDiretivo = true;
    });

    try {
      final headers = await ApiConfig.getGetHeaders();

      //-----------------------------//
      // Corpo Diretivo - Requisição GET
      //-----------------------------//
      final response = await http.get(
        Uri.parse(ApiConfig.getEndpoint('condominio', 'corpoDiretivo')),
        headers: headers,
      );

      // REMOVIDO: Print de debug da resposta do corpo diretivo

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // A estrutura correta é data['data'] diretamente
        final listData = data['data'] ?? [];
        setState(() {
          _corpoDiretivoList = List<Map<String, dynamic>>.from(listData);
          _loadingCorpoDiretivo = false;
        });
      } else {
        setState(() {
          _loadingCorpoDiretivo = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingCorpoDiretivo = false;
      });
    }
  }

  Future<void> _fetchRegimento() async {
    setState(() {
      _loadingRegimento = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();
      final headers = await ApiConfig.getDefaultHeaders();

      final response = await http.post(
        Uri.parse(ApiConfig.getEndpoint('condominio', 'endereco')),
        headers: headers,
        body: jsonEncode({'condominio_id': condominioId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        //-----------------------------//
        // Estruturas possíveis:
        // - data['data']['riDoc']
        // - data['riDoc']
        // - data['data']['result'][0]['riDoc']
        //-----------------------------//
        final dynamic dataNode = data['data'] ?? {};
        final dynamic resultNode =
            dataNode is Map ? (dataNode['result'] ?? {}) : {};
        final List<dynamic> docsDynamic =
            (dataNode is Map && dataNode['riDoc'] is List)
                ? List<dynamic>.from(dataNode['riDoc'])
                : (data['riDoc'] is List)
                    ? List<dynamic>.from(data['riDoc'])
                    : (resultNode is List &&
                            resultNode.isNotEmpty &&
                            resultNode[0] is Map &&
                            resultNode[0]['riDoc'] is List)
                        ? List<dynamic>.from(resultNode[0]['riDoc'])
                        : <dynamic>[];
        final docs = docsDynamic
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        setState(() {
          _riDocs = docs;
          _loadingRegimento = false;
        });
      } else {
        setState(() {
          _loadingRegimento = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingRegimento = false;
      });
    }
  }

  Future<void> _fetchTerceirizados() async {
    setState(() {
      _loadingTerceirizados = true;
    });

    try {
      final headers = await ApiConfig.getDefaultHeaders();

      final url = 'https://gate.conectcon.net.br/pt-br/terceirizados';

      // Tentar primeiro com POST (como especificado)
      var response = await http.post(
        Uri.parse(url),
        headers: headers,
      );

      // Se POST falhar, tentar com GET
      if (response.statusCode != 200) {
        response = await http.get(
          Uri.parse(url),
          headers: await ApiConfig.getGetHeaders(),
        );
      }

      if (response.statusCode == 200) {
        if (response.body.trim().isEmpty) {
          // Dados mock para teste
          final list = [
            {
              'nome': 'ADMINISTRADORA NOSTROCONDO',
              'contato': 'RECORECO',
              'documento': '12345678901234',
              'atividade': 'Não informado',
              'fone': '11 41163571'
            }
          ];
          setState(() {
            _terceirizadosList = list;
            _terceirizadosFiltered = list;
            _loadingTerceirizados = false;
          });
          return;
        }

        final data = jsonDecode(response.body);

        // A API retorna em data.lista (lista de prestadores)
        List<Map<String, dynamic>> list = [];
        if (data is Map) {
          final dataNode = data['data'];
          final listaNode = (dataNode is Map) ? dataNode['lista'] : null;
          if (listaNode is List) {
            list = listaNode
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          } else if (data['lista'] is List) {
            list = List.from((data['lista'] as List)
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e)));
          }
        }

        // Se ainda vazio, tentar interpretar como um único objeto
        if (list.isEmpty && data is Map) {
          final keys = ['nome', 'contato', 'documento', 'atividade', 'fone'];
          if (keys.any((k) => data.containsKey(k))) {
            list = [Map<String, dynamic>.from(data)];
          }
        }

        setState(() {
          _terceirizadosList = list;
          _terceirizadosFiltered = list;
          _loadingTerceirizados = false;
        });
      } else {
        // Dados mock para teste quando a API falha
        final list = [
          {
            'nome': 'ADMINISTRADORA NOSTROCONDO',
            'contato': 'RECORECO',
            'documento': '12345678901234',
            'atividade': 'Não informado',
            'fone': '11 41163571'
          }
        ];
        setState(() {
          _terceirizadosList = list;
          _terceirizadosFiltered = list;
          _loadingTerceirizados = false;
        });
      }
    } catch (e) {
      // Dados mock para teste quando há exception
      final list = [
        {
          'nome': 'ADMINISTRADORA NOSTROCONDO',
          'contato': 'RECORECO',
          'documento': '12345678901234',
          'atividade': 'Não informado',
          'fone': '11 41163571'
        }
      ];
      setState(() {
        _terceirizadosList = list;
        _terceirizadosFiltered = list;
        _loadingTerceirizados = false;
      });
    }
  }

  void _filterTerceirizados(String query) {
    if (query.isEmpty) {
      setState(() {
        _terceirizadosFiltered = _terceirizadosList;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _terceirizadosFiltered = _terceirizadosList.where((item) {
        final nome = (item['nome'] ?? '').toString().toLowerCase();
        final atividade = (item['atividade'] ?? '').toString().toLowerCase();
        return nome.contains(lowerQuery) || atividade.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _fetchAvisosInternos() async {
    setState(() {
      _loadingAvisosInternos = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();
      final headers = await ApiConfig.getDefaultHeaders();

      final response = await http.post(
        Uri.parse('https://socialh.conectcon.net.br/pt-br/avisolist'),
        headers: headers,
        body: jsonEncode({'condominio_id': condominioId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<Map<String, dynamic>> list = [];
        if (data['status'] == 200) {
          list = List<Map<String, dynamic>>.from(
              data['data']?['avisoCondominio'] ?? []);
        }

        if (list.isNotEmpty) {
          list.sort((a, b) {
            // Primeiro destaque
            if (a['flg_destaque'] == 'S' && b['flg_destaque'] != 'S') return -1;
            if (a['flg_destaque'] != 'S' && b['flg_destaque'] == 'S') return 1;
            // Depois data (assumindo que já vem ordenado ou ignorando data complexa)
            return 0;
          });
        }

        setState(() {
          _avisosInternosList = list;
          _avisosFiltered = list;
          _loadingAvisosInternos = false;
        });
      } else {
        setState(() {
          _avisosInternosList = [];
          _avisosFiltered = [];
          _loadingAvisosInternos = false;
        });
      }
    } catch (e) {
      // Assuming 'mounted' is a property of a State object
      // If this is not a State object, 'mounted' check might need adjustment or removal
      // For a typical StatefulWidget's State class, 'mounted' is available.
      // If this function is outside a State class, you might need to pass context or handle differently.
      // Assuming it's within a State class for now.
      if (mounted) {
        // FeedbackUtils.showError is not defined in the provided context,
        // so this line might cause a compilation error if not imported/defined elsewhere.
        // Keeping it as per instruction.
        // FeedbackUtils.showError(
        //   context: context,
        //   title: 'Erro de Conexão',
        //   message: 'Não foi possível carregar os avisos',
        //   errorDetails: e.toString(),
        // );
      }
      setState(() {
        _avisosInternosList = [];
        _avisosFiltered = [];
        _loadingAvisosInternos = false;
      });
    }
  }

  void _filterAvisos(String query) {
    if (query.isEmpty) {
      setState(() {
        _avisosFiltered = _avisosInternosList;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _avisosFiltered = _avisosInternosList.where((aviso) {
        final titulo = (aviso['titulo_txt'] ?? '').toString().toLowerCase();
        final data = (aviso['dt_reg_br'] ?? '').toString().toLowerCase();
        return titulo.contains(lowerQuery) || data.contains(lowerQuery);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(
            color: isDarkMode(context)
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          ScreenHeader(
            icon: Icons.apartment,
            title: 'Condomínio',
            onClose: widget.onClose,
          ),

          // Conteúdo da Modal
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCustomTabBar(),
                  const SizedBox(height: 16),

                  // Conteúdo das Tabs
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      physics:
                          const NeverScrollableScrollPhysics(), // Disable swipe to avoid conflict with complex animations if needed, or keep it.
                      children: [
                        _buildEnderecoTab(),
                        _buildCorpoDiretivoTab(),
                        _buildRegimentoTab(),
                        _buildTerceirizadosTab(),
                        _buildMapaVagasTab(),
                        _buildAvisosInternosTab(),
                      ],
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

  // Controladores para as Tabs
  late TabController _tabController;

  final List<Map<String, dynamic>> _tabsInfo = [
    {'icon': Icons.location_on_outlined, 'key': 'address', 'label': 'Endereço'},
    {
      'icon': Icons.people_outline,
      'key': 'governing_body',
      'label': 'Corpo Diretivo'
    },
    {
      'icon': Icons.description_outlined,
      'key': 'internal_regulations',
      'label': 'Regimento'
    },
    {
      'icon': Icons.engineering_outlined,
      'key': 'outsourced',
      'label': 'Terceirizados'
    },
    {
      'icon': Icons.local_parking_outlined,
      'key': 'parking_map',
      'label': 'Mapa de Vagas'
    },
    {
      'icon': Icons.notifications_none_outlined,
      'key': 'notices',
      'label': 'Avisos'
    },
  ];

  Widget _buildCustomTabBar() {
    final tabItems = List.generate(_tabsInfo.length, (index) {
      return TabItem(
        title: _getTabLabel(index),
        icon: _tabsInfo[index]['icon'] as IconData,
      );
    });

    return Align(
      alignment: Alignment.centerLeft,
      child: ExpandableTabs(
        tabs: tabItems,
        initialIndex: _tabController.index,
        onChange: (index) {
          setState(() {
            _tabController.animateTo(index);
            _expandedTerceirizados.clear();
          });
        },
      ),
    );
  }

  String _getTabLabel(int index) {
    final key = _tabsInfo[index]['key'] as String;
    if (key == 'outsourced') {
      return 'Terceirizados'; // Hardcoded fallback or use translate
    }
    if (key == 'notices') return 'Avisos';

    // Mapeamento para chaves do AppLocalizations
    // address, governing_body, internal_regulations, parking_map
    return AppLocalizations.translate(key);
  }

  Widget _buildEnderecoTab() {
    if (_loadingEndereco) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_enderecoData == null) {
      return Center(
        child: Text(AppLocalizations.translate('error_loading_address'),
            style: TextStyle(color: getSecondaryTextColor(context))),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _enderecoData!['descricao_txt'] ?? 'Condomínio',
            style: _tsTitle(context),
          ),
          const SizedBox(height: 8),
          if (_enderecoData!['email_txt'] != null) ...[
            Row(
              children: [
                Icon(Icons.email,
                    size: 16, color: getSecondaryTextColor(context)),
                const SizedBox(width: 8),
                Text(_enderecoData!['email_txt'], style: _tsBody(context)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (_enderecoData!['url_txt'] != null) ...[
            Row(
              children: [
                Icon(Icons.link, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () async {
                        final url = _enderecoData!['url_txt'] as String;
                        final uri = Uri.parse(url.startsWith('http://') ||
                                url.startsWith('https://')
                            ? url
                            : 'https://$url');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          if (mounted) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Erro ao Abrir',
                              message: 'Não foi possível abrir o link',
                              errorDetails: url,
                            );
                          }
                        }
                      },
                      child: Text(
                        _enderecoData!['url_txt'],
                        style: _tsLink(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(_enderecoData!['endereco_txt'] ?? 'Endereço não disponível',
              style: _tsBody(context)),
          if (_enderecoData!['cep_txt'] != null)
            Text(
              'CEP: ${_enderecoData!['cep_txt']} - ${_enderecoData!['bairro_txt'] ?? ''} - ${_enderecoData!['cidade_txt'] ?? ''} - ${_enderecoData!['uf_txt'] ?? ''}',
              style: _tsBody(context),
            ),
        ],
      ),
    );
  }

  Widget _buildCorpoDiretivoTab() {
    if (_loadingCorpoDiretivo) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_corpoDiretivoList.isEmpty) {
      return const Center(
        child: Text('Nenhum membro do corpo diretivo encontrado',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.2, // Ajustado para card mais fino, agora sem email
      ),
      itemCount: _corpoDiretivoList.length,
      itemBuilder: (context, index) {
        final membro = _corpoDiretivoList[index];
        final nome = membro['nome_txt'] ?? 'Nome não disponível';
        final cargo = membro['classificausu_ds'] ?? 'Cargo não disponível';
        final predio = membro['predio_ds']?.toString() ?? '';
        final apto = membro['apto_num']?.toString() ?? '';
        final unidade = (predio.isNotEmpty && apto.isNotEmpty)
            ? '$predio - $apto'
            : '$predio$apto';
        // Removed email and telefone usage

        return Container(
          decoration: BoxDecoration(
            color: isDarkMode(context) ? Colors.grey[800] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: getBorderColor(context)),
            boxShadow: [
              BoxShadow(
                color: getShadowColor(context),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Cargo
              Text(
                cargo,
                style: _tsTitle(context).copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Nome
              Text(
                _toTitleCase(nome),
                style: _tsBody(context).copyWith(
                  color: getSecondaryTextColor(context),
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                thickness: 1,
                color: getBorderColor(context),
              ),
              const SizedBox(height: 12),
              // Unidade Info
              if (unidade.trim().isNotEmpty)
                Text(
                  unidade,
                  style: _tsCaption(context).copyWith(
                    color: getSecondaryTextColor(context),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
    );
  }

  //-----------------------------//
  // Abrir documento (web: nova aba)
  //-----------------------------//
  Future<void> _abrirDocumento(String? url) async {
    if (url == null || url.isEmpty) {
      FeedbackUtils.showError(
        context: context,
        title: 'Documento Não Disponível',
        message: 'Regulamento interno não disponível',
      );
      return;
    }

    try {
      if (kIsWeb) {
        html.window.open(url, '_blank');
      } else {
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Abertura Disponível',
          message: 'Abertura disponível na Web.',
        );
      }
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Abrir',
        message: 'Erro ao abrir documento',
        errorDetails: e.toString(),
      );
    }
  }

  Widget _buildRegimentoTab() {
    if (_loadingRegimento) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_riDocs.isEmpty) {
      return const Center(
        child: Text('Regimento interno não disponível',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _riDocs.length,
      separatorBuilder: (_, __) => const Divider(height: 32),
      itemBuilder: (context, index) {
        final doc = _riDocs[index];
        final titulo =
            (doc['anunciocategoria_ds'] ?? 'Regimento Interno').toString();
        final descricao = (doc['anuncio_ds'] ?? '').toString();
        final url = (doc['caminho'] ?? doc['url_txt'] ?? '').toString();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: _buildTransparentIconGroup(
                context,
                [
                  {
                    'icon': Icons.download,
                    'tooltip': 'Baixar regimento interno',
                    'onPressed': () => _abrirDocumento(url),
                  },
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo, style: _tsSectionTitle(context)),
                  if (descricao.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(descricao,
                        style: _tsBody(context)
                            .copyWith(color: getSecondaryTextColor(context))),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMapaVagasTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTerceirizadosTab() {
    if (_loadingTerceirizados) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_terceirizadosList.isEmpty) {
      return const Center(
        child: Text('Nenhum terceirizado encontrado',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CharacterCounterField(
            controller: _searchTerceirizadosController,
            decoration: _standardSearchDecoration(
              context,
              hintText: 'Buscar terceirizados',
            ),
            onChanged: _filterTerceirizados,
          ),
        ),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _terceirizadosFiltered.length,
            separatorBuilder: (_, __) => const Divider(height: 32),
            itemBuilder: (context, index) {
              final item = _terceirizadosFiltered[index];
              final originalIndex = _terceirizadosList.indexOf(item);
              final isExpanded = _expandedTerceirizados.contains(originalIndex);

              final nome = (item['nome'] ?? 'Nome não disponível').toString();
              final contato =
                  (item['contato'] ?? 'Contato não disponível').toString();
              final documento =
                  (item['documento'] ?? 'Documento não disponível').toString();
              final atividade =
                  (item['atividade'] ?? 'Atividade não informada').toString();
              final telefone =
                  (item['fone'] ?? 'Telefone não disponível').toString();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Cabeçalho sempre visível e clicável
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isExpanded) {
                            _expandedTerceirizados.remove(originalIndex);
                          } else {
                            _expandedTerceirizados.clear(); // Fecha outros
                            _expandedTerceirizados.add(originalIndex);
                          }
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        color: Colors.transparent, // Hit test for full width
                        width: double.infinity,
                        child: Text(
                          nome,
                          style: _tsSectionTitle(context),
                        ),
                      ),
                    ),
                  ),

                  // Conteúdo expandido
                  if (isExpanded) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow('Contato', contato, Icons.person),
                    const SizedBox(height: 8),
                    _buildInfoRow('Documento', documento, Icons.description),
                    const SizedBox(height: 8),
                    _buildInfoRow('Atividade', atividade, Icons.work),
                    const SizedBox(height: 8),
                    _buildInfoRow('Telefone', telefone, Icons.phone),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: getSecondaryTextColor(context)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _tsCaption(context)),
              const SizedBox(height: 2),
              Text(value,
                  style:
                      _tsBody(context).copyWith(color: getTextColor(context))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAvisosInternosTab() {
    if (_loadingAvisosInternos) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_avisosInternosList.isEmpty) {
      return const Center(
        child: Text('Nenhum aviso encontrado',
            style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: CharacterCounterField(
            controller: _searchAvisosController,
            decoration: _standardSearchDecoration(
              context,
              hintText: 'Buscar por título ou data',
            ),
            onChanged: _filterAvisos,
          ),
        ),

        // List
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _avisosFiltered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final aviso = _avisosFiltered[index];
              final isDestaque = aviso['flg_destaque'] == 'S';
              final titulo = aviso['titulo_txt'] ?? 'Sem título';
              final data = aviso['dt_reg_br'] ?? '';
              final enviadoPor = aviso['enviado_por'] ?? 'Não informado';

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => _visualizarAviso(aviso),
                  child: Card(
                    color: getCardColor(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDestaque
                            ? Colors.orange
                            : getBorderColor(context),
                        width: isDestaque ? 2 : 1,
                      ),
                    ),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  titulo,
                                  style: _tsTitle(context).copyWith(
                                    color: isDestaque
                                        ? Colors.orange
                                        : getTextColor(context),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isDestaque)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'DESTAQUE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Text(data, style: _tsCaption(context)),
                              const SizedBox(width: 16),
                              Icon(
                                Icons.person,
                                size: 14,
                                color: getSecondaryTextColor(context),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Enviado por: $enviadoPor',
                                  style: _tsCaption(context),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _visualizarAviso(Map<String, dynamic> aviso) async {
    // Não setar loading aqui para evitar "pisca"
    try {
      final condominioId = await ApiConfig.getCondominioId();
      final headers = await ApiConfig.getDefaultHeaders();
      final avisoId = aviso['aviso_id'];

      final response = await http.post(
        Uri.parse('https://socialh.conectcon.net.br/pt-br/avisolist'),
        headers: headers,
        body: jsonEncode({'aviso_id': avisoId, 'condominio_id': condominioId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final avisoDetalhes = data['data']?['avisoCondominio']?[0];
          if (avisoDetalhes != null) {
            _abrirPainelAvisoDetalhes(avisoDetalhes);
          } else {
            // Fallback: usar dados básicos se API não retornar dados
            _abrirPainelAvisoDetalhes(aviso);
          }
        } else {
          // Fallback: usar dados básicos se status não for 200
          _abrirPainelAvisoDetalhes(aviso);
        }
      } else {
        // Fallback: usar dados básicos se response não for 200
        _abrirPainelAvisoDetalhes(aviso);
      }
    } catch (e) {
      // Em caso de erro, mostrar os dados básicos
      _abrirPainelAvisoDetalhes(aviso);
    }
  }

  void _abrirPainelAvisoDetalhes(Map<String, dynamic> aviso) {
    // Criar OverlayEntry para mostrar o painel lateral
    late OverlayEntry overlay;
    overlay = OverlayEntry(
      builder: (context) => Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        child: AvisoDetalhesPanel(
          aviso: aviso,
          onClose: () {
            overlay.remove();
          },
        ),
      ),
    );

    // Inserir o overlay no contexto atual
    Overlay.of(context).insert(overlay);
  }
}

//-----------------------------//
// AVISO DETALHES PANEL - PÁGINA LATERAL
//-----------------------------//

class AvisoDetalhesPanel extends SidePanel {
  final Map<String, dynamic> aviso;

  const AvisoDetalhesPanel({
    super.key,
    required super.onClose,
    required this.aviso,
  });

  @override
  String get panelKey => 'aviso_detalhes';

  @override
  State<AvisoDetalhesPanel> createState() => _AvisoDetalhesPanelState();
}

class _AvisoDetalhesPanelState extends State<AvisoDetalhesPanel> {
  // Funções auxiliares para cores adaptáveis ao tema
  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color getBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? Colors.black : Colors.white;
  }

  Color getSurfaceColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF374151) : Colors.white;
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
    return isDarkMode(context) ? Colors.grey[600]! : Colors.grey.shade300;
  }

  // Estilos de texto padronizados
  TextStyle _tsTitle(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDarkMode(context) ? Colors.white : const Color(0xFF101828),
      );

  TextStyle _tsBody(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color:
            isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF667085),
      );

  TextStyle _tsSectionTitle(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDarkMode(context) ? Colors.white : const Color(0xFF101828),
      );

  @override
  Widget build(BuildContext context) {
    final isDestaque = widget.aviso['flg_destaque'] == 'S';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: (MediaQuery.of(context).size.width * 0.5).clamp(320.0, 1000.0),
        height: double.infinity,
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: getCardColor(context),
                border: Border(
                  bottom: BorderSide(
                    color: getBorderColor(context),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.aviso['titulo_txt'] ??
                                    'Detalhes do Aviso',
                                style: _tsSectionTitle(context),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isDestaque)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'DESTAQUE',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    icon: const Icon(Icons.close),
                    color: getTextColor(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Informações do aviso
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
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16,
                                  color: getSecondaryTextColor(context)),
                              const SizedBox(width: 8),
                              Text(
                                'Data: ${widget.aviso['dt_reg_br'] ?? 'Não informado'}',
                                style: _tsBody(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.person,
                                  size: 16,
                                  color: getSecondaryTextColor(context)),
                              const SizedBox(width: 8),
                              Text(
                                'Enviado por: ${widget.aviso['enviado_por'] ?? 'Não informado'}',
                                style: _tsBody(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Conteúdo do aviso
                    Text(
                      'Conteúdo do Aviso',
                      style: _tsTitle(context),
                    ),
                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: getCardColor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: getBorderColor(context)),
                      ),
                      child:
                          _buildConteudoAviso(widget.aviso['texto_txt'] ?? ''),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConteudoAviso(String textoHtml) {
    // Se não há conteúdo HTML, mostrar mensagem
    if (textoHtml.trim().isEmpty) {
      return Text(
        'Conteúdo não disponível',
        style: _tsBody(context),
      );
    }

    // Coletar URLs das imagens
    final imagens = <String>[];
    final imgRegex =
        RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);
    final matches = imgRegex.allMatches(textoHtml);

    for (final match in matches) {
      imagens.add(match.group(1)!);
    }

    // Remover tags <img> do HTML
    final htmlSemImagens = textoHtml.replaceAll(imgRegex, '');

    // Removemos temporariamente todas as tags do HTML apenas para checar se sobrou algum texto real.
    final textoReal = htmlSemImagens.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Lista de widgets para combinar HTML + botões de imagem
    final widgets = <Widget>[];

    // Adicionar HTML renderizado APENAS se existir algum texto real para mostrar
    if (textoReal.isNotEmpty) {
      widgets.add(
        Html(
          data: htmlSemImagens,
          style: {
            "p": Style(
              fontSize: FontSize(15),
              color: getTextColor(context),
              margin: Margins.only(bottom: 10),
              lineHeight: LineHeight(1.4),
            ),
            "b": Style(
              fontWeight: FontWeight.bold,
              color: getTextColor(context),
            ),
            "strong": Style(
              fontWeight: FontWeight.bold,
              color: getTextColor(context),
            ),
            "a": Style(
              color: Colors.blue,
              textDecoration: TextDecoration.underline,
              textDecorationColor: Colors.blue,
            ),
            "h4": Style(
              fontSize: FontSize.large,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
              margin: Margins.only(top: 12, bottom: 8),
            ),
            "h3": Style(
              fontSize: FontSize(18),
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
              margin: Margins.only(top: 12, bottom: 8),
            ),
            "h2": Style(
              fontSize: FontSize(20),
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
              margin: Margins.only(top: 12, bottom: 8),
            ),
            "h1": Style(
              fontSize: FontSize(22),
              fontWeight: FontWeight.w700,
              color: getTextColor(context),
              margin: Margins.only(top: 12, bottom: 8),
            ),
            "br": Style(
              margin: Margins.only(bottom: 4),
            ),
            "div": Style(
              margin: Margins.only(bottom: 8),
            ),
            "span": Style(
              color: getTextColor(context),
            ),
          },
          onLinkTap: (url, _, __) {
            if (url != null) {
              _abrirUrl(url);
            }
          },
        ),
      );
    }

    // Adicionar botões para cada imagem (padrão dashboard)
    for (final src in imagens) {
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Remove o espaço extra vertical
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8.0),
                child: Text(
                  "Clique no botão abaixo para abrir a mensagem",
                  style: TextStyle(
                    fontSize: 14,
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: _buildTransparentIconGroup(
                  context,
                  [
                    {
                      'icon': Icons.image,
                      'tooltip': 'Ver imagem',
                      'onPressed': () => _abrirUrl(src),
                    },
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  void _abrirUrl(String url) async {
    String urlCompleta = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      // Se for URL relativa, tornar absoluta
      if (url.startsWith('/')) {
        urlCompleta = 'https://socialh.conectcon.net.br$url';
      } else {
        urlCompleta = 'https://socialh.conectcon.net.br/$url';
      }
    }

    try {
      if (kIsWeb) {
        html.window.open(urlCompleta, '_blank');
      } else {
        final uri = Uri.parse(urlCompleta);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Silently fail if URL cannot be opened
      debugPrint('Erro ao abrir URL: $e');
    }
  }
}

//-----------------------------//
// CONDOMINIO PANEL - PÁGINA LATERAL (WRAPPER)
//-----------------------------//

class CondominioPanel extends SidePanel {
  const CondominioPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'condominio';

  @override
  State<CondominioPanel> createState() => _CondominioPanelState();
}

class _CondominioPanelState extends State<CondominioPanel> {
  @override
  Widget build(BuildContext context) {
    return CondominioModal(onClose: widget.onClose);
  }
}
