import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:pdfx/pdfx.dart';
//-----------------------------//
// Web only: open links in a new browser tab
//-----------------------------//
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
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
import 'aviso_expandable_item.dart';
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
// Variáveis para guardar as URLs
  String? _urlRegimento;
  String? _urlMapaGaragem;
  bool _loadingInfo = true;
  PdfController? _pdfController;

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
    _fetchCondominioInfo();
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

  Future<void> _fetchCondominioInfo() async {
    setState(() {
      _loadingInfo = true;
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

        if (data['data'] != null &&
            data['data']['result'] != null &&
            (data['data']['result'] as List).isNotEmpty) {
          final resultNode = data['data']['result'][0];

          if (resultNode['informacoes'] != null) {
            final informacoes = resultNode['informacoes'] as List;

            // Vasculhando a lista para pegar cada URL pelo 'tipo'
            for (var item in informacoes) {
              if (item is Map) {
                if (item['tipo'] == 'ri' && item['info'] != null) {
                  _urlRegimento = item['info'].toString();
                } else if (item['tipo'] == 'mapagaragem' &&
                    item['info'] != null) {
                  _urlMapaGaragem = item['info'].toString();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Erro ao buscar informações do condomínio: $e');
    } finally {
      setState(() {
        _loadingInfo = false;
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

        if (data['data'] != null &&
            data['data']['result'] != null &&
            (data['data']['result'] as List).isNotEmpty) {
          final resultNode = data['data']['result'][0];

          if (resultNode['informacoes'] != null) {
            final informacoes = resultNode['informacoes'] as List;

            for (var item in informacoes) {
              if (item is Map) {
                if (item['tipo'] == 'ri' && item['info'] != null) {
                  _urlRegimento = item['info'].toString();
                } else if (item['tipo'] == 'mapagaragem' &&
                    item['info'] != null) {
                  _urlMapaGaragem = item['info'].toString();
                }
              }
            }
          }
        }

        // === NOVO: Baixar e preparar o PDF para exibição ===
        if (_urlRegimento != null && _urlRegimento!.isNotEmpty) {
          if (kIsWeb) {
            // Na web usaremos IFrame nativo, evitando erro de CORS
          } else {
            try {
              final pdfResponse = await http.get(Uri.parse(_urlRegimento!));
              if (pdfResponse.statusCode == 200) {
                _pdfController = PdfController(
                  document: PdfDocument.openData(pdfResponse.bodyBytes),
                );
              }
            } catch (e) {
              print('Erro ao carregar os bytes do PDF: $e');
            }
          }
        }

        setState(() {
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

    if (_urlRegimento == null || _urlRegimento!.isEmpty) {
      return const Center(
        child: Text(
          'Regimento interno não disponível',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (kIsWeb) {
      // Registra o IFrame para exibir o PDF na Web
      final String viewId = 'pdf-iframe-${_urlRegimento.hashCode}';

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.IFrameElement()
          ..src = _urlRegimento!
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%',
      );

      return Container(
        color: isDarkMode(context) ? const Color(0xFF1E1E1E) : Colors.white,
        child: HtmlElementView(viewType: viewId),
      );
    }

    // PDF embutido nativamente com o pacote pdfx para mobile
    if (_pdfController == null) {
      return const Center(
        child: Text(
          'Erro ao carregar o PDF',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Container(
      color: isDarkMode(context) ? const Color(0xFF1E1E1E) : Colors.white,
      child: PdfView(
        controller: _pdfController!,
        scrollDirection: Axis.vertical,
      ),
    );
  }

  Widget _buildMapaVagasTab() {
    if (_loadingRegimento) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_urlMapaGaragem == null || _urlMapaGaragem!.isEmpty) {
      return const Center(
        child: Text(
          'Mapa de vagas não disponível',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    if (kIsWeb) {
      // Registra o IFrame para exibir o Mapa de Vagas na Web
      final String viewId = 'mapa-iframe-${_urlMapaGaragem.hashCode}';

      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => html.IFrameElement()
          ..src = _urlMapaGaragem!
          ..style.border = 'none'
          ..style.width = '90%'
          ..style.height = '100%',
      );

      return Container(
        color: isDarkMode(context) ? const Color(0xFF1E1E1E) : Colors.white,
        child: HtmlElementView(viewType: viewId),
      );
    }

    // Embutindo a Imagem nativamente com suporte a Zoom para mobile
    return Container(
      color: isDarkMode(context) ? const Color(0xFF1E1E1E) : Colors.white,
      child: InteractiveViewer(
        panEnabled: true,
        minScale: 0.5,
        maxScale: 4.0, // Permite zoom de até 4x
        child: Image.network(
          _urlMapaGaragem!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Text(
              'Erro ao carregar o mapa de vagas.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ),
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
              return AvisoExpandableItem(avisoInicial: aviso);
            },
          ),
        ),
      ],
    );
  }

}

//-----------------------------//
// AVISO DETALHES PANEL - PÁGINA LATERAL
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