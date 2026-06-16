import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/utils/ui_standards.dart';
import '../../main.dart';
import '../../shared/widgets/character_counter_field.dart';

// ============================================================================
// PANELS LATERAIS PARA FUNCIONALIDADES DO DASHBOARD
// ============================================================================

// Panel para Encomendas
class EncomendasPanel extends SidePanel {
  const EncomendasPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'encomendas';

  @override
  State<EncomendasPanel> createState() => _EncomendasPanelState();
}

class _EncomendasPanelState extends State<EncomendasPanel> {
  bool _loadingEntregas = false;
  final TextEditingController _filtroUnidadeController =
      TextEditingController();
  String _filtroUnidade = '';
  List<Map<String, dynamic>> _entregasList = [];

  @override
  void initState() {
    super.initState();
    _listarEntregas();
  }

  Future<void> _listarEntregas() async {
    setState(() => _loadingEntregas = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('entregas', 'lista'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _entregasList =
              List<Map<String, dynamic>>.from(data['data']?['lista'] ?? []);
        });
      }
    } catch (e) {
      // Erro silencioso
    } finally {
      setState(() => _loadingEntregas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border:
                  Border(bottom: BorderSide(color: Colors.black26, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Encomendas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de pesquisa
                  CharacterCounterField(
                    controller: _filtroUnidadeController,
                    decoration:
                        inputDecorationPadrao(context, hintText: 'Buscar encomendas'),
                    onChanged: (value) {
                      setState(() {
                        _filtroUnidade = value.toLowerCase();
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Lista de encomendas
                  Expanded(
                    child: _loadingEntregas
                        ? Center(child: CircularProgressIndicator())
                        : _entregasList.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                itemCount: _entregasList.length,
                                itemBuilder: (context, idx) {
                                  final entrega = _entregasList[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.black26, width: 1),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            entrega['nome_morador'] ??
                                                'Morador',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            entrega['descricao'] ??
                                                'Sem descrição',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700]),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Data: ${entrega['dt_entrada'] ?? 'Sem data'}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
}

// Panel para Visitantes/Agendamentos
class VisitantesPanel extends SidePanel {
  const VisitantesPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'visitantes';

  @override
  State<VisitantesPanel> createState() => _VisitantesPanelState();
}

class _VisitantesPanelState extends State<VisitantesPanel> {
  bool _loadingAgendamentos = false;
  final TextEditingController _filtroUnidadeController =
      TextEditingController();
  String _filtroUnidade = '';
  List<Map<String, dynamic>> _agendamentosList = [];

  @override
  void initState() {
    super.initState();
    _fetchAgendamentos();
  }

  Future<void> _fetchAgendamentos() async {
    setState(() => _loadingAgendamentos = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('agendamentos', 'lista'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _agendamentosList =
              List<Map<String, dynamic>>.from(data['data']?['lista'] ?? []);
        });
      }
    } catch (e) {
      // Erro silencioso
    } finally {
      setState(() => _loadingAgendamentos = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border:
                  Border(bottom: BorderSide(color: Colors.black26, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Visitantes/Agendamentos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Campo de pesquisa
                  CharacterCounterField(
                    controller: _filtroUnidadeController,
                    decoration: inputDecorationPadrao(context, 
                        hintText: 'Buscar agendamentos'),
                    onChanged: (value) {
                      setState(() {
                        _filtroUnidade = value.toLowerCase();
                      });
                    },
                  ),

                  const SizedBox(height: 20),

                  // Lista de agendamentos
                  Expanded(
                    child: _loadingAgendamentos
                        ? Center(child: CircularProgressIndicator())
                        : _agendamentosList.isEmpty
                            ? const SizedBox.shrink()
                            : ListView.builder(
                                itemCount: _agendamentosList.length,
                                itemBuilder: (context, idx) {
                                  final agendamento = _agendamentosList[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                          color: Colors.black26, width: 1),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            agendamento['nome_visitante'] ??
                                                'Visitante',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            agendamento['unidade_mostra'] ??
                                                'Unidade',
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700]),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Data: ${agendamento['dt_agendamento'] ?? 'Sem data'}',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600]),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
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
}

// Panel para Unidades
class UnidadesPanel extends SidePanel {
  const UnidadesPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'unidades';

  @override
  State<UnidadesPanel> createState() => _UnidadesPanelState();
}

class _UnidadesPanelState extends State<UnidadesPanel> {
  bool _loading = false;
  List<Map<String, dynamic>> _unidadesList = [];

  @override
  void initState() {
    super.initState();
    _carregarUnidades();
  }

  Future<void> _carregarUnidades() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('unidades', 'lista'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _unidadesList =
              List<Map<String, dynamic>>.from(data['data']?['lista'] ?? []);
        });
      }
    } catch (e) {
      // Erro silencioso
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border:
                  Border(bottom: BorderSide(color: Colors.black26, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Unidades',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loading
                  ? Center(child: CircularProgressIndicator())
                  : _unidadesList.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          itemCount: _unidadesList.length,
                          itemBuilder: (context, idx) {
                            final unidade = _unidadesList[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.black26, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      unidade['unidade_mostra'] ?? 'Unidade',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      unidade['tipo_unidade'] ??
                                          'Tipo não informado',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700]),
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
    );
  }
}

// Panel para Vagas
class VagasPanel extends SidePanel {
  const VagasPanel({super.key, required super.onClose});

  @override
  String get panelKey => 'vagas';

  @override
  State<VagasPanel> createState() => _VagasPanelState();
}

class _VagasPanelState extends State<VagasPanel> {
  bool _loadingVagas = false;
  List<Map<String, dynamic>> _vagasList = [];

  @override
  void initState() {
    super.initState();
    _fetchVagas();
  }

  Future<void> _fetchVagas() async {
    setState(() => _loadingVagas = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt');
      final tokenSessao = (encryptedToken != null && encryptedToken.isNotEmpty)
          ? decryptText(encryptedToken)
          : '';
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = (encryptedCondominioId.isNotEmpty)
          ? decryptText(encryptedCondominioId)
          : '';

      if (tokenSessao.isEmpty) {
        FeedbackUtils.showError(
          context: context,
          title: 'Sessão Expirada',
          message: 'Sua sessão expirou. Faça login novamente.',
        );
        return;
      }

      final url = Uri.parse(ApiConfig.getEndpoint('vagas', 'lista'));
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode({
          "condominio_id": int.tryParse(condominioId) ?? 0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _vagasList =
              List<Map<String, dynamic>>.from(data['data']?['lista'] ?? []);
        });
      }
    } catch (e) {
      // Erro silencioso
    } finally {
      setState(() => _loadingVagas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black26, width: 1),
      ),
      child: Column(
        children: [
          // Header
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border:
                  Border(bottom: BorderSide(color: Colors.black26, width: 1)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Text(
                  'Vagas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: _loadingVagas
                  ? Center(child: CircularProgressIndicator())
                  : _vagasList.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.builder(
                          itemCount: _vagasList.length,
                          itemBuilder: (context, idx) {
                            final vaga = _vagasList[idx];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border:
                                    Border.all(color: Colors.black26, width: 1),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vaga['vaga_txt'] ??
                                          vaga['vaga'] ??
                                          'Vaga',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      vaga['tipo_vaga'] ?? 'Tipo não informado',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[700]),
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
    );
  }
}
