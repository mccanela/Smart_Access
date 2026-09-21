import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/services/feedback_utils.dart';
import '../../core/utils/ui_standards.dart';
import '../../core/config/api_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart';
import '../../shared/widgets/screen_header.dart';
import '../../shared/widgets/character_counter_field.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../../core/theme/icon_colors.dart';
import '../dashboard/widgets/transparent_icon_group.dart';

/// Painel visual do assistente ConectCon IA.
class ConectConIAPanel extends StatefulWidget {
  final VoidCallback? onClose;
  const ConectConIAPanel({super.key, this.onClose});

  @override
  State<ConectConIAPanel> createState() => _ConectConIAPanelState();
}

class _ConectConIAPanelState extends State<ConectConIAPanel> {
  final TextEditingController _leftSearchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool _isLoading = false;
  bool _isSmartAccess = false;

  // Variáveis de estado para a resposta da IA (Esquerda)
  String? _respostaDaIA;
  String? _perguntaFeita;

  // Variáveis de estado para o histórico (Direita)
  List<Map<String, String>> _historicoPerguntas = [];
  String? _perguntaSelecionada;
  String? _respostaSelecionada;
  int _consultasRealizadas = 0;
  int _consultasTotais = 5;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _carregarHistoricoLocal();
    _carregarControleConsultas();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _isSmartAccess = prefs.getBool('is_smart_access') ?? false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar is_smart_access: $e');
    }
  }

// --- Controle de Consultas Diárias ---
  Future<void> _carregarControleConsultas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().split('T')[0];
      final savedDate = prefs.getString('noviax_last_query_date');

      if (savedDate != today) {
        // Se mudou o dia (ou é o primeiro acesso com essa chave nova)
        await prefs.setString('noviax_last_query_date', today);
        await prefs.setInt('noviax_consultas_realizadas', 0); // <--- CHAVE NOVA
        if (mounted) {
          setState(() {
            _consultasRealizadas = 0;
          });
        }
      } else {
        // Se é o mesmo dia
        final count =
            prefs.getInt('noviax_consultas_realizadas') ?? 0; // <--- CHAVE NOVA
        if (mounted) {
          setState(() {
            _consultasRealizadas = count;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao carregar controle de consultas: $e');
    }
  }

  Future<void> _incrementarConsultas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Garante que só incrementa se não tiver estourado o limite
      if (_consultasRealizadas < _consultasTotais) {
        final newCount = _consultasRealizadas + 1;
        await prefs.setInt(
            'noviax_consultas_realizadas', newCount); // <--- CHAVE NOVA
        if (mounted) {
          setState(() {
            _consultasRealizadas = newCount;
          });
        }
      }
    } catch (e) {
      debugPrint('Erro ao incrementar consulta: $e');
    }
  }

  // --- Funções de Persistência Local ---
  Future<void> _carregarHistoricoLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('noviax_historico_perguntas');
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        setState(() {
          _historicoPerguntas = decoded
              .map((item) => Map<String, String>.from(item as Map))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar histórico local: $e');
    }
  }

  Future<void> _salvarPerguntaNoHistorico(
      String pergunta, String resposta) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove caso a pergunta já exista (evita duplicidade) e insere no topo
      _historicoPerguntas.removeWhere((item) => item['pergunta'] == pergunta);
      _historicoPerguntas.insert(0, {
        'pergunta': pergunta,
        'resposta': resposta,
      });

      final String jsonString = jsonEncode(_historicoPerguntas);
      await prefs.setString('noviax_historico_perguntas', jsonString);

      setState(() {});
    } catch (e) {
      debugPrint('Erro ao salvar no histórico local: $e');
    }
  }

  @override
  void dispose() {
    _leftSearchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final pergunta = _leftSearchController.text.trim();
    if (pergunta.isEmpty) return;

    if (_consultasRealizadas >= _consultasTotais) {
      FeedbackUtils.showWarning(
        context: context,
        title: 'Limite Atingido',
        message:
            'Você já atingiu o limite de $_consultasTotais consultas por dia.',
      );
      return;
    }
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

    if (condominioId.isEmpty || tokenSessao.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

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
        String textoResposta = '';
        try {
          final data = jsonDecode(response.body);
          final raiz = data['data'];
          textoResposta = (raiz as String).replaceAll(r'\n', '\n');
        } catch (e) {
          textoResposta = response.body;
        }

        setState(() {
          _respostaDaIA = textoResposta;
          _perguntaFeita = pergunta;
        });

        // Salva localmente a pergunta e a resposta formatada
        await _salvarPerguntaNoHistorico(pergunta, textoResposta);

        // 👇 2. DECREMENTA APENAS QUANDO A IA RESPONDER COM SUCESSO
        await _incrementarConsultas();
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
      _leftSearchController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    // ADICIONADO: Detectar se é uma tela de celular
    final isMobile = MediaQuery.of(context).size.width < 800;

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
            icon: Icons.auto_awesome,
            title: 'NOVIA X',
            onClose: widget.onClose ?? () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Padding(
              // ADICIONADO: Reduzir o padding no mobile para ganhar espaço
              padding: EdgeInsets.all(isMobile ? 16.0 : 32.0),
              child: isMobile
                  ? Column(
                      // 📱 NO MOBILE: Empilha verticalmente
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildLeftColumn()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildRightColumn()),
                      ],
                    )
                  : Row(
                      // 💻 NO DESKTOP: Mantém lado a lado
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildLeftColumn()),
                        const SizedBox(width: 18),
                        Expanded(child: _buildRightColumn()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn() {
    return Container(
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border.all(color: getBorderColor(context), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(14.5)),
            child: Stack(
              children: [
                Tooltip(
                  message:
                      'NOVIA-X é a inteligência artificial que te auxilia buscando informações na convenção, regimento interno e plano operacional da portaria.', // <--- Isso funciona como o "title" do HTML
                  child: Image.network(
                    'https://pub-9313ea4eec6c404c845254ee76d0a174.r2.dev/geral/noviax.png',
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    semanticLabel:
                        'NOVIA-X é a inteligência artificial que te auxilia buscando informações na convenção, regimento interno e plano operacional da portaria.', // <--- Isso funciona como o "alt" do HTML
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 180,
                      color: Colors.blueGrey,
                      alignment: Alignment.center,
                      child: const Text(
                        'Imagem não encontrada',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  bottom: 12,
                  left: 16,
                  child: Text(
                    'Procedimentos',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'NOVIA-X é a inteligência artificial que te auxilia buscando informações na convenção, regimento interno e plano operacional da portaria.'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },
                    child: const Icon(Icons.info_outline, color: Colors.white),
                  ),
                )
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSearchField(
                    controller: _leftSearchController,
                    labelText: 'Preciso saber como...',
                    onEnterPressed:
                        (_isLoading || _consultasRealizadas >= _consultasTotais)
                            ? null
                            : _enviar,
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$_consultasRealizadas/$_consultasTotais consultas realizadas hoje', // <-- Frase ajustada
                      style: TextStyle(
                          fontSize: 10,
                          color: _consultasRealizadas >= _consultasTotais
                              ? Colors.red
                              : getSecondaryTextColor(context)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (_respostaDaIA != null)
                    _buildResultadoIA()
                  else
                    _buildPlaceholderProcedimento(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String labelText,
    VoidCallback? onEnterPressed,
  }) {
    return CharacterCounterField(
      controller: controller,
      focusNode: controller == _leftSearchController ? _focusNode : null,
      maxLength: 100,
      onSubmitted: (_) {
        if (onEnterPressed != null) onEnterPressed();
      },
      decoration: inputDecorationPadrao(
        context,
        labelText: labelText,
      ).copyWith(
        suffixIcon: InkWell(
          onTap: onEnterPressed,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
            child: Text(
              'Enter',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightColumn() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: getCardColor(context),
        border: Border.all(color: getBorderColor(context), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bookmark, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Histórico',
                style: AppTextStyles.title(context),
              ),
              const SizedBox(width: 8),
              Icon(Icons.unfold_more, color: getSecondaryTextColor(context)),

              // ADICIONADO: Empurra o botão de limpar para a direita
              const Spacer(),
              if (_perguntaSelecionada != null)
                TransparentIconGroup([
                  IconActionData(
                    icon: Symbols.ink_eraser,
                    tooltip: 'Limpar seleção atual',
                    color: IconColors.delete(context),
                    onPressed: () {
                      setState(() {
                        _perguntaSelecionada = null;
                        _respostaSelecionada = null;
                      });
                    },
                  ),
                ]),
            ],
          ),
          const SizedBox(height: 20),

          // DropdownButton com o Histórico Local
          DropdownButtonFormField<String>(
            isExpanded: true,
            value: _perguntaSelecionada,
            decoration: inputDecorationPadrao(
              context,
              labelText: 'Selecione um procedimento salvo',
            ),
            dropdownColor: getCardColor(context),
            hint: Text(
              _historicoPerguntas.isEmpty
                  ? 'Nenhum histórico encontrado'
                  : 'Escolha uma pergunta...',
              style: TextStyle(
                fontSize: 14,
                color: getSecondaryTextColor(context),
              ),
            ),
            items: _historicoPerguntas.map((item) {
              return DropdownMenuItem<String>(
                value: item['pergunta'],
                child: Text(
                  item['pergunta'] ?? '',
                  overflow: TextOverflow
                      .ellipsis, // Evita quebrar a linha no dropdown fechado
                  style: TextStyle(
                    fontSize: 14,
                    color: getTextColor(context),
                  ),
                ),
              );
            }).toList(),
            onChanged: (novoValor) {
              if (novoValor != null) {
                final itemEncontrado = _historicoPerguntas.firstWhere(
                  (element) => element['pergunta'] == novoValor,
                  orElse: () => {'resposta': ''},
                );

                setState(() {
                  _perguntaSelecionada = novoValor;
                  _respostaSelecionada = itemEncontrado['resposta'];
                });
              }
            },
          ),
          const SizedBox(height: 20),

          // Renderização Dinâmica da Resposta Selecionada (ou texto vazio)
          Expanded(
            child: SingleChildScrollView(
              child: _respostaSelecionada != null &&
                      _respostaSelecionada!.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _perguntaSelecionada ?? '',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: getTextColor(context)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _respostaSelecionada!,
                          style: TextStyle(
                              fontSize: 14,
                              color: getTextColor(context),
                              height: 1.4),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        _historicoPerguntas.isEmpty
                            ? 'Faça uma pergunta ao lado para salvar o histórico.'
                            : 'Selecione uma pergunta acima para ver a resposta.',
                        style: TextStyle(
                          fontSize: 13,
                          color: getSecondaryTextColor(context),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderProcedimento() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: getTextColor(context)),
        ),
        const SizedBox(height: 12),
        Text(
          '',
          style: TextStyle(
              fontSize: 14, color: getTextColor(context), height: 1.4),
        ),
      ],
    );
  }

  Widget _buildResultadoIA() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"$_perguntaFeita"',
          style: TextStyle(
              fontSize: 16,
              fontStyle:
                  FontStyle.italic, // 👇 ISSO AQUI DEIXA O TEXTO EM ITÁLICO
              fontWeight: FontWeight.bold,
              color: getTextColor(context)),
        ),
        const SizedBox(height: 12),
        Text(
          _respostaDaIA ??
              '', // <-- Aspas no texto e proteção contra null no lugar certo
          style: TextStyle(
            fontSize: 14,
            color: getTextColor(context),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
