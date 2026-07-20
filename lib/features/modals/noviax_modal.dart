import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/feedback_utils.dart';
import '../../core/utils/ui_standards.dart';
import '../../core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart';
import '../../shared/widgets/screen_header.dart';

/// Painel visual do assistente ConectCon IA.
class ConectConIAPanel extends StatefulWidget {
  final VoidCallback? onClose;
  const ConectConIAPanel({super.key, this.onClose});

  @override
  State<ConectConIAPanel> createState() => _ConectConIAPanelState();
}

class _ConectConIAPanelState extends State<ConectConIAPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _respostaDaIA;
  String? _perguntaFeita;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // Funçao auxiliar para obter condomínio ID do SignalR (preferencial) ou ApiConfig
  Future<int> getCondominioIdAtual() async {
    // Prioridade 1: Pegar do SignalR se estiver disponível
    // Prioridade 2: Fallback para ApiConfig
    final condominioIdStr = await ApiConfig.getCondominioId();
    return int.tryParse(condominioIdStr) ?? 0;
  }

  Future<void> _enviar() async {
    final pergunta = _controller.text.trim();
    if (pergunta.isEmpty) return;

    // Desfoca o teclado e inicia o loading
    _focusNode.unfocus();
    setState(() {
      _isLoading = true;
      _respostaDaIA = null;
      _perguntaFeita = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (condominioId.isEmpty || tokenSessao.isEmpty) return;

    try {
      final url =
          Uri.parse(ApiConfig.getEndpoint('dashboard', 'ConectConIAPortaria'));

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $tokenSessao'
        },
        body: jsonEncode({
          "condominio_id": condominioId,
          "pergunta": pergunta,
        }),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          final raiz = data['data'];
          final texto = raiz.replaceAll(r'\n', '<br/>');
          setState(() {
            _respostaDaIA = texto ?? response.body;
            _perguntaFeita = pergunta;
          });
        } catch (e) {
          // Fallback caso a resposta não seja um JSON válido e sim texto plano
          setState(() {
            _respostaDaIA = response.body;
            _perguntaFeita = pergunta;
          });
        }
      } else {
        FeedbackUtils.showWarning(
          context: context,
          title: 'Erro na API',
          message: 'Código de erro: ${response.statusCode}',
        );
        setState(() {
          _respostaDaIA = 'Erro ao processar a resposta. Tente novamente.';
          _perguntaFeita = pergunta;
        });
      }
    } catch (e) {
      FeedbackUtils.showWarning(
        context: context,
        title: 'Erro de conexão',
        message: 'Não foi possível conectar com a IA.',
      );
      setState(() {
        _respostaDaIA = 'Erro de conexão: $e';
        _perguntaFeita = pergunta;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCloseCallback = widget.onClose;

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
          ScreenHeader(
            icon: Icons.smart_toy_outlined,
            title: 'Novia X',
            onClose: onCloseCallback ?? () => Navigator.of(context).pop(),
          ),
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
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(
                          top: 24, left: 16, right: 16, bottom: 16),
                      child: Text(
                        'Dúvidas sobre regras e procedimentos?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w300,
                          color: getTextColor(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: getCardColor(context),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: getBorderColor(context)),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                onSubmitted: (_) => _enviar(),
                                decoration: InputDecoration(
                                  hintText: "Pergunte a NOVIA-X",
                                  hintStyle: TextStyle(
                                      color: getSecondaryTextColor(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w300),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(
                                  color: getTextColor(context),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                            Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 2),
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: _isLoading ? null : _enviar,
                                tooltip: 'Enviar',
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2))
                                    : const Icon(Icons.arrow_upward,
                                        color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: _respostaDaIA != null
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _buildPainelResposta(context),
                            )
                          : const SizedBox.shrink(),
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

  Widget _buildPainelResposta(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getFormGrisColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pergunta: $_perguntaFeita',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: getTextColor(context),
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _respostaDaIA!,
            style: TextStyle(
              color: getTextColor(context),
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
