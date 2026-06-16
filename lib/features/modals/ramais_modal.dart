import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/crypto_utils.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/config/api_config.dart';
import '../../main.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/character_counter_field.dart';
import '../../core/utils/ui_standards.dart';

// Helper for Title Case
String _toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text
      .split(' ')
      .map((word) => word.isNotEmpty
          ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
          : '')
      .join(' ');
}

// Helper for Standard Search Decoration
InputDecoration _standardSearchDecoration(BuildContext context) {
  return inputDecorationPadrao(
    context,
    labelText: 'Buscar ramal',
    prefixIcon: Icon(
      Icons.search,
      color: getSecondaryTextColor(context),
    ),
  );
}

class RamaisModal extends StatefulWidget {
  final VoidCallback onClose;
  const RamaisModal({super.key, required this.onClose});

  @override
  State<RamaisModal> createState() => _RamaisModalState();
}

class _RamaisModalState extends State<RamaisModal> {
  List<Map<String, dynamic>> _ramais = [];
  List<Map<String, dynamic>> _ramaisFiltrados = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRamais();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRamais(String query) {
    if (query.isEmpty) {
      setState(() {
        _ramaisFiltrados = _ramais;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _ramaisFiltrados = _ramais.where((r) {
        final titulo = (r['titulo_txt'] ?? '').toString().toLowerCase();
        final url = (r['url_txt'] ?? '').toString().toLowerCase();
        return titulo.contains(lowerQuery) || url.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _fetchRamais() async {
    setState(() {
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
    final url = Uri.parse(ApiConfig.getEndpoint('ramais', 'lista'));
    final payload = {"condominio_id": condominioId};
    try {
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
        setState(() {
          _ramais = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _ramaisFiltrados = _ramais;
        });
      }
    } catch (e) {
      // erro silencioso
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ScrollController();
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.98,
          height: MediaQuery.of(context).size.height * 0.98,
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: getBackgroundColor(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: getBorderColor(context), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              ScreenHeader(
                icon: Icons.phone,
                title: AppLocalizations.translate('extensions'),
                subtitle: AppLocalizations.translate('manage_extensions'),
                onClose: widget.onClose,
              ),
              const SizedBox(height: 8),
              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: CharacterCounterField(
                  controller: _searchController,
                  onChanged: _filterRamais,
                  decoration: _standardSearchDecoration(context),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          controller: controller,
                          itemCount: _ramaisFiltrados.length,
                          itemBuilder: (context, index) {
                            final r = _ramaisFiltrados[index];
                            final titulo = _toTitleCase(r['titulo_txt'] ?? '');
                            final ramal = r['url_txt'] ?? '';

                            return ListTile(
                              leading: Icon(Icons.phone,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.primary),
                              title: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: getTextColor(context),
                                  ),
                                  children: [
                                    TextSpan(text: '$titulo - '),
                                    TextSpan(
                                      text: ramal,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

//-----------------------------//
// RAMAIS PANEL - PÁGINA LATERAL
//-----------------------------//

class RamaisPanel extends SidePanel {
  const RamaisPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'ramais';

  @override
  State<RamaisPanel> createState() => _RamaisPanelState();
}

class _RamaisPanelState extends State<RamaisPanel> {
  List<Map<String, dynamic>> _ramais = [];
  List<Map<String, dynamic>> _ramaisFiltrados = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchRamais();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterRamais(String query) {
    if (query.isEmpty) {
      setState(() {
        _ramaisFiltrados = _ramais;
      });
      return;
    }
    final lowerQuery = query.toLowerCase();
    setState(() {
      _ramaisFiltrados = _ramais.where((r) {
        final titulo = (r['titulo_txt'] ?? '').toString().toLowerCase();
        final url = (r['url_txt'] ?? '').toString().toLowerCase();
        return titulo.contains(lowerQuery) || url.contains(lowerQuery);
      }).toList();
    });
  }

  Future<void> _fetchRamais() async {
    setState(() {
      _loading = true;
    });
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
    final url = Uri.parse(ApiConfig.getEndpoint('ramais', 'lista'));
    final payload = {"condominio_id": condominioId};
    try {
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
        setState(() {
          _ramais = List<Map<String, dynamic>>.from(data['data'] ?? []);
          _ramaisFiltrados = _ramais;
        });
      }
    } catch (e) {
      // erro silencioso
    } finally {
      setState(() {
        _loading = false;
      });
    }
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
        children: [
          // Header - Estilo das fotos
          ScreenHeader(
            icon: Icons.phone,
            title: 'Ramais',
            onClose: widget.onClose,
          ),

          // Content - Lista simples (como nas fotos)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: getCardColor(context),
                  border: Border.all(color: getBorderColor(context), width: 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  // Alterado para Column para incluir o campo de busca dentro do container card
                  children: [
                    // Search Field inside the card
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: CharacterCounterField(
                        controller: _searchController,
                        onChanged: _filterRamais,
                        decoration: _standardSearchDecoration(context),
                      ),
                    ),
                    Expanded(
                      child: _loading
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Carregando ramais...',
                                    style: AppTextStyles.getStyle(context,
                                        size: 16, isSecondary: true),
                                  ),
                                ],
                              ),
                            )
                          : _ramaisFiltrados.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.phone_disabled,
                                        size: 64,
                                        color: getSecondaryTextColor(context),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _ramais.isEmpty
                                            ? 'Sem ramais cadastrados'
                                            : 'Ramal não encontrado',
                                        style: TextStyle(
                                          color: getSecondaryTextColor(context),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _ramaisFiltrados.length,
                                  itemBuilder: (context, index) {
                                    final r = _ramaisFiltrados[index];
                                    final titulo =
                                        _toTitleCase(r['titulo_txt'] ?? '');
                                    final ramal = r['url_txt'] ?? '';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 1),
                                      child: ListTile(
                                        visualDensity: VisualDensity.compact,
                                        leading: Icon(
                                          Icons.phone,
                                          size: 20,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        title: RichText(
                                          text: TextSpan(
                                            style: AppTextStyles.getStyle(
                                                context,
                                                weight: FontWeight.w400),
                                            children: [
                                              TextSpan(text: '$titulo - '),
                                              TextSpan(
                                                text: ramal, // Mostra o ramal
                                                style: const TextStyle(
                                                  fontWeight: FontWeight
                                                      .w400, // Menos negrito para elegância
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        subtitle: r['descricao_txt'] != null &&
                                                r['descricao_txt']
                                                    .toString()
                                                    .isNotEmpty
                                            ? Text(
                                                r['descricao_txt'].toString(),
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w300,
                                                  color: getSecondaryTextColor(
                                                      context),
                                                ),
                                              )
                                            : null,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 0),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
