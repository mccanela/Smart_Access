import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/ui_standards.dart';
import '../../core/config/app_version.dart';
import '../../shared/widgets/screen_header.dart';
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';

class NovidadesModal extends StatefulWidget {
  final VoidCallback? onClose;
  const NovidadesModal({super.key, this.onClose});

  @override
  State<NovidadesModal> createState() => _NovidadesModalState();
}

class _NovidadesModalState extends State<NovidadesModal> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _versoes = [];

  @override
  void initState() {
    super.initState();
    _fetchNovidades();
  }

  Future<void> _fetchNovidades() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final url = Uri.parse('${ApiConfig.socialhUrl}/avisolist');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({'condominio_id': 0, 'aviso_id': 10994005}),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        // Caminho ajustado para buscar dentro de data -> avisoCondominio
        final List<dynamic> listaApi =
            decoded['data']?['avisoCondominio'] ?? [];

        setState(() {
          _versoes = List<Map<String, dynamic>>.from(listaApi);
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              'Erro ao carregar novidades (Status: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Não foi possível conectar ao servidor.';
        _isLoading = false;
      });
    }
  }

  // Função auxiliar para converter o texto em HTML para texto simples formatado
  String _limparHtml(String htmlString) {
    if (htmlString.isEmpty) return '';

    // Substitui quebras de linha HTML por quebras reais
    String parsed =
        htmlString.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');

    // Substitui parágrafos e títulos por quebras de linha
    parsed = parsed.replaceAll(
        RegExp(r'</p>|<p>|</h1>|</h2>|</h3>|<ul>|</ul>|<ol>|</ol>',
            caseSensitive: false),
        '\n');

    // Transforma itens de lista em "bullets" nativos
    parsed = parsed.replaceAll(RegExp(r'<li>', caseSensitive: false), '• ');
    parsed = parsed.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');

    // Remove todas as tags restantes (ex: <b>, <i>, <blockquote>)
    parsed = parsed.replaceAll(RegExp(r'<[^>]*>'), '');

    // Decodifica entidades HTML comuns
    parsed = parsed
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");

    // Remove quebras de linha triplas ou maiores geradas pelo replace
    parsed = parsed.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return parsed.trim();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: getBackgroundColor(context),
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
          ScreenHeader(
            icon: Icons.whatshot,
            title: 'Versões',
            onClose: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                    ? Center(
                        child: Text(
                          _errorMessage,
                          style:
                              TextStyle(color: getSecondaryTextColor(context)),
                        ),
                      )
                    : _versoes.isEmpty
                        ? Center(
                            child: Text(
                              'Nenhuma novidade encontrada.',
                              style: TextStyle(
                                  color: getSecondaryTextColor(context)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(32),
                            itemCount: _versoes.length,
                            itemBuilder: (context, index) {
                              final versaoDados = _versoes[index];

                              // Extração com base no novo JSON
                              final titulo =
                                  versaoDados['titulo_txt'] ?? 'Atualização';
                              final dateStr = versaoDados['dt_reg_br'] ?? '';
                              final rawHtml = versaoDados['texto_txt'] ?? '';

                              final textoLimpo = _limparHtml(rawHtml);

                              // Tentar extrair a versão do próprio HTML (ex: "Novidades 3.0.0")
                              String versionStr = '3.0.0';
                              final versionMatch = RegExp(
                                      r'Novidades\s+([0-9]+\.[0-9]+\.[0-9]+)',
                                      caseSensitive: false)
                                  .firstMatch(rawHtml);
                              if (versionMatch != null &&
                                  versionMatch.groupCount >= 1) {
                                versionStr = versionMatch.group(1)!;
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 24),
                                child: _buildVersionSection(
                                  context,
                                  version: versionStr,
                                  date: dateStr,
                                  items: [
                                    _ChangeItem(
                                      icon: Icons
                                          .auto_awesome, // Ícone padrão para a caixa de novidades
                                      title: titulo,
                                      description: textoLimpo,
                                    )
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionSection(
    BuildContext context, {
    required String version,
    required String date,
    required List<_ChangeItem> items,
  }) {
    final isCurrent = version == appVersion;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? const Color(0xFF684F8E) : getBorderColor(context),
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? const Color(0xFF684F8E)
                      : getBorderColor(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'v$version',
                  style: TextStyle(
                    color: isCurrent
                        ? Colors.white
                        : getSecondaryTextColor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                date,
                style: TextStyle(
                  color: getSecondaryTextColor(context),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map((item) => _buildChangeRow(context, item)),
        ],
      ),
    );
  }

  Widget _buildChangeRow(BuildContext context, _ChangeItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF684F8E).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.turned_in,
              size: 18,
              color: const Color(0xFF684F8E),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: getSecondaryTextColor(context),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangeItem {
  final IconData icon;
  final String title;
  final String description;
  const _ChangeItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
