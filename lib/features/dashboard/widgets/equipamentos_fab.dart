import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/crypto_utils.dart';
import '../../../core/services/feedback_utils.dart';
import '../../../core/utils/ui_standards.dart';

/// Standalone FAB widget that displays and controls equipamentos (botoeiras).
///
/// The parent is responsible for calculating [fabLeftPosition] and passing it in.
class EquipamentosFAB extends StatefulWidget {
  /// The pre-calculated left position for the FAB inside the parent Stack.
  final double fabLeftPosition;

  const EquipamentosFAB({
    super.key,
    required this.fabLeftPosition,
  });

  @override
  State<EquipamentosFAB> createState() => _EquipamentosFABState();
}

class _EquipamentosFABState extends State<EquipamentosFAB> {
  bool _fabExpandido = false;
  List<Map<String, dynamic>> _equipamentosList = [];
  bool _loadingEquipamentos = false;
  bool _loadingComando = false;
  bool _hoverActive = false;
  // Estado das bolinhas para cada equipamento (0 = nenhuma, 1 = primeira verde, 2 = segunda verde)
  final Map<int, int> _estadoBolinhasEquipamento = {};
  // Estado visual do botao apos acionamento (verde com check)
  final Map<int, bool> _botaoAcionado = {};

  // ------------------------------------------------------------------
  // Data fetching
  // ------------------------------------------------------------------

  Future<void> _fetchEquipamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty || condominioId.isEmpty) return;

    setState(() {
      _loadingEquipamentos = true;
    });

    try {
      final url =
          Uri.parse('https://gate.conectcon.net.br/pt-br/equipamentolist');
      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
      };

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

        // Parsing robusto para encontrar 'ativos'
        List<dynamic> equipamentos = [];

        if (data['ativos'] != null) {
          equipamentos = data['ativos'];
        } else if (data['data'] != null) {
          if (data['data'] is Map && data['data']['ativos'] != null) {
            equipamentos = data['data']['ativos'];
          } else if (data['data'] is List) {
            equipamentos = data['data'];
          }
        }

        setState(() {
          _equipamentosList = List<Map<String, dynamic>>.from(equipamentos);
          _loadingEquipamentos = false;
        });
      } else {
        setState(() {
          _loadingEquipamentos = false;
        });
      }
    } catch (e) {
      setState(() {
        _loadingEquipamentos = false;
      });
    }
  }

  Future<void> _enviarComando(Map<String, dynamic> equipamento) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
    final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
    final usuarioId = (encryptedUsuarioId.isNotEmpty)
        ? int.tryParse(decryptText(encryptedUsuarioId)) ?? 0
        : 0;

    if (tokenSessao.isEmpty) return;

    setState(() {
      _loadingComando = true;
    });

    try {
      final url = Uri.parse(
          'https://gate.conectcon.net.br/pt-br/controleatualizacaoins');
      final payload = {
        "condominio_id": int.tryParse(condominioId) ?? 0,
        "id": usuarioId,
        "tipocomando": 2072,
        "tiporegra": 118,
        "tipoequipamento_id": 0,
        "leitor_id": equipamento['leitor_id'] ?? 0,
        "acao_flg": "B"
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        // Sucesso silencioso
      } else {
        if (mounted) {
          FeedbackUtils.showError(
            context: context,
            title: 'Erro ao Enviar',
            message: 'Erro ao enviar comando',
            errorDetails: 'Status: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Enviar',
          message: 'Erro ao enviar comando',
          errorDetails: e.toString(),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingComando = false;
        });
      }
    }
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      bottom: 20,
      left: widget.fabLeftPosition < 0 ? 0 : widget.fabLeftPosition,
      child: MouseRegion(
        onEnter: (event) {
          // Só ativa hover para mouse real (não touch)
          if (event.kind == PointerDeviceKind.mouse) {
            _hoverActive = true;
            if (_equipamentosList.isEmpty && !_loadingEquipamentos) {
              _fetchEquipamentos();
            }
            setState(() {
              _fabExpandido = true;
            });
          }
        },
        onExit: (event) {
          // Só fecha via hover para mouse real (não touch)
          if (event.kind == PointerDeviceKind.mouse) {
            _hoverActive = false;
            Future.delayed(const Duration(milliseconds: 150), () {
              if (mounted && !_hoverActive) {
                setState(() {
                  _fabExpandido = false;
                });
              }
            });
          }
        },
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Botoes dos equipamentos (aparecem quando expandido)
              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: (_fabExpandido == true)
                    ? Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: IntrinsicWidth(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_loadingEquipamentos)
                                _buildLoadingIndicator()
                              else if (_equipamentosList.isEmpty)
                                _buildEmptyIndicator()
                              else
                                _buildEquipamentoButtons(),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              // Botao principal (target do hover)
              _buildMainButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Sub-widgets
  // ------------------------------------------------------------------

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Carregando...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFD1D5DB),
            width: 1,
          ),
        ),
        child: const Text(
          'Sem equipamentos disponíveis',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildEquipamentoButtons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _equipamentosList.asMap().entries.map((entry) {
        final index = entry.key;
        final equipamento = entry.value;
        final equipamentoId =
            equipamento['id'] ?? equipamento['equipamento_id'] ?? index;
        final nome = equipamento['nome']?.toString() ??
            equipamento['descricao']?.toString() ??
            'Equipamento ${index + 1}';
        final estadoBolinhas =
            _estadoBolinhasEquipamento[equipamentoId] ?? 0;
        final botaoAcionado = _botaoAcionado[equipamentoId] ?? false;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(28),
            child: InkWell(
              onTap: _loadingComando
                  ? null
                  : () {
                      setState(() {
                        _estadoBolinhasEquipamento[equipamentoId] = 2;
                        _botaoAcionado[equipamentoId] = true;
                        _enviarComando(equipamento).then((_) {
                          Future.delayed(const Duration(seconds: 2), () {
                            if (mounted) {
                              setState(() {
                                _estadoBolinhasEquipamento[equipamentoId] = 0;
                                _botaoAcionado[equipamentoId] = false;
                              });
                            }
                          });
                        });
                      });
                    },
              borderRadius: BorderRadius.circular(28),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: botaoAcionado
                      ? const Color(0xFF00C853)
                      : getCardColor(context),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: botaoAcionado
                        ? const Color(0xFF00C853)
                        : getBorderColor(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Duas bolinhas
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: estadoBolinhas >= 1
                                ? const Color(0xFF00C853)
                                : Colors.transparent,
                            border: Border.all(
                              color: getBorderColor(context),
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: estadoBolinhas >= 2
                                ? const Color(0xFF00C853)
                                : Colors.transparent,
                            border: Border.all(
                              color: getBorderColor(context),
                              width: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Check quando acionado
                    if (botaoAcionado) ...[
                      const Icon(
                        Icons.check_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        nome,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: botaoAcionado
                              ? Colors.white
                              : getTextColor(context),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMainButton() {
    return Card(
      elevation: 4,
      margin: EdgeInsets.zero,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(40),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 40,
        constraints: const BoxConstraints(
          minWidth: 250,
        ),
        decoration: BoxDecoration(
          color: getFormGrisColor(context),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black)
                .withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () {
              setState(() {
                _fabExpandido = !_fabExpandido;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Symbols.radio_button_checked,
                    color: Color(0xFFF19E39),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Botoeiras',
                    style: TextStyle(
                      color: getSecondaryTextColor(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
