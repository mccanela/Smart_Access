import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/feedback_utils.dart';
import '../../../core/utils/ui_standards.dart';
import '../../../core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/crypto_utils.dart';

/// Painel visual do assistente ConectCon IA.
class ConectConIAPanel extends StatefulWidget {
  const ConectConIAPanel({super.key});

  @override
  State<ConectConIAPanel> createState() => _ConectConIAPanelState();
}

class _ConectConIAPanelState extends State<ConectConIAPanel> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  String? _respostaDaIA;

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
        // Tenta fazer o parse da resposta JSON.
        // Supondo que a API retorne algo como {"resposta": "texto da IA..."}
        // Se retornar apenas texto puro, basta usar response.body.
        try {
          final data = jsonDecode(response.body);
          final raiz = data['data'];
          final texto = raiz.replaceAll(r'\n', '<br/>');
          setState(() {
            _respostaDaIA = texto ?? response.body;
          });
        } catch (e) {
          // Fallback caso a resposta não seja um JSON válido e sim texto plano
          setState(() {
            _respostaDaIA = response.body;
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
    final isDark = isDarkMode(context);
    // Trocado "Center" por "Align" no topo + SingleChildScrollView para rolagem
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Dúvidas sobre regras e procedimentos?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: getFormGrisColor(context),
                  borderRadius: BorderRadius.circular(10),
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
                          hintStyle:
                              TextStyle(color: getSecondaryTextColor(context)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black,
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
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.arrow_upward,
                                color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Painel da Resposta da IA
              if (_respostaDaIA != null) _buildPainelResposta(context),
            ],
          ),
        ),
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
              const Icon(Icons.smart_toy, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'ConectCon IA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: getTextColor(context),
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

  Widget _modoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: getTextColor(context)),
      label: Text(label,
          style: TextStyle(color: getTextColor(context), fontSize: 13)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: getBorderColor(context)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
    );
  }
}
