import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../../core/config/api_config.dart';

class AvisoExpandableItem extends StatefulWidget {
  final Map<String, dynamic> avisoInicial;

  const AvisoExpandableItem({super.key, required this.avisoInicial});

  @override
  State<AvisoExpandableItem> createState() => _AvisoExpandableItemState();
}

class _AvisoExpandableItemState extends State<AvisoExpandableItem> {
  bool _isExpanded = false;
  bool _isLoading = false;
  Map<String, dynamic>? _avisoDetalhes;

  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
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
        color: isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF667085),
      );

  TextStyle _tsCaption(BuildContext context) => TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: getSecondaryTextColor(context),
      );

  Future<void> _fetchDetalhes() async {
    if (_avisoDetalhes != null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final condominioId = await ApiConfig.getCondominioId();
      final headers = await ApiConfig.getDefaultHeaders();
      final avisoId = widget.avisoInicial['aviso_id'];

      final response = await http.post(
        Uri.parse('https://socialh.conectcon.net.br/pt-br/avisolist'),
        headers: headers,
        body: jsonEncode({'aviso_id': avisoId, 'condominio_id': condominioId}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          final detalhes = data['data']?['avisoCondominio']?[0];
          if (detalhes != null) {
            if (mounted) {
              setState(() {
                _avisoDetalhes = detalhes;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Erro ao buscar detalhes do aviso: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
        _avisoDetalhes ??= widget.avisoInicial; // fallback
      });
    }
  }

  void _abrirUrl(String url) async {
    String urlCompleta = url;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
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
      debugPrint('Erro ao abrir URL: $e');
    }
  }

  Widget _buildConteudoAviso(String textoHtml) {
    if (textoHtml.trim().isEmpty) {
      return Text(
        'Conteúdo não disponível',
        style: _tsBody(context),
      );
    }

    final imgRegex = RegExp(r'<img[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);
    final iframeRegex = RegExp(r'<iframe[^>]+src="([^"]+)"[^>]*>', caseSensitive: false);

    final imgMatches = imgRegex.allMatches(textoHtml);
    final iframeMatches = iframeRegex.allMatches(textoHtml);

    final List<Widget> mediaWidgets = [];

    for (final match in imgMatches) {
      final src = match.group(1);
      if (src != null) {
        String finalSrc = src;
        if (src.startsWith('//')) {
          finalSrc = 'https:$src';
        } else if (src.startsWith('/')) {
          finalSrc = 'https://socialh.conectcon.net.br$src';
        }
        
        mediaWidgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                finalSrc,
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
          )
        );
      }
    }

    for (final match in iframeMatches) {
      final src = match.group(1);
      if (src != null) {
        String finalSrc = src;
        if (src.startsWith('//')) {
          finalSrc = 'https:$src';
        }

        if (finalSrc.contains('youtube.com') || finalSrc.contains('youtu.be')) {
          final RegExp videoIdRegex = RegExp(r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})', caseSensitive: false);
          final idMatch = videoIdRegex.firstMatch(finalSrc);
          if (idMatch != null) {
            final videoId = idMatch.group(1);
            final thumbnailUrl = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
            
            mediaWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () => _abrirUrl(finalSrc),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            thumbnailUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              height: 200,
                              color: Colors.black12,
                              child: const Center(child: Icon(Icons.video_library, size: 50)),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 50,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            );
          } else {
             mediaWidgets.add(_buildGenericLink(finalSrc, "Abrir vídeo"));
          }
        } else {
          mediaWidgets.add(_buildGenericLink(finalSrc, "Abrir conteúdo externo"));
        }
      }
    }

    String htmlLimpo = textoHtml;
    htmlLimpo = htmlLimpo.replaceAll(imgRegex, '');
    htmlLimpo = htmlLimpo.replaceAll(iframeRegex, '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (htmlLimpo.trim().isNotEmpty)
          Html(
            data: htmlLimpo,
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
            },
            onLinkTap: (url, _, __) {
              if (url != null) {
                _abrirUrl(url);
              }
            },
          ),
        if (mediaWidgets.isNotEmpty) ...mediaWidgets,
      ],
    );
  }

  Widget _buildGenericLink(String url, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: () => _abrirUrl(url),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.open_in_new, color: Colors.blue),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final aviso = widget.avisoInicial;
    final isDestaque = aviso['flg_destaque'] == 'S';
    final titulo = aviso['titulo_txt'] ?? 'Sem título';
    final data = aviso['dt_reg_br'] ?? '';
    final enviadoPor = aviso['enviado_por'] ?? 'Não informado';

    return Card(
      color: getCardColor(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDestaque ? Colors.orange : getBorderColor(context),
          width: isDestaque ? 2 : 1,
        ),
      ),
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(12),
          onExpansionChanged: (expanded) {
            setState(() {
              _isExpanded = expanded;
            });
            if (expanded) {
              _fetchDetalhes();
            }
          },
          title: Column(
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
                        color: isDestaque ? Colors.orange : getTextColor(context),
                      ),
                      maxLines: _isExpanded ? null : 2,
                      overflow: _isExpanded ? null : TextOverflow.ellipsis,
                    ),
                  ),
                  if (isDestaque)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_avisoDetalhes != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 8),
                    _buildConteudoAviso(_avisoDetalhes!['texto_txt'] ?? ''),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
