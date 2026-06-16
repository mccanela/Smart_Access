import 'package:flutter/material.dart';

class GateSystem extends StatefulWidget {
  const GateSystem({super.key});

  @override
  State<GateSystem> createState() => _GateSystemState();
}

class _GateSystemState extends State<GateSystem> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers para os campos do formulário
  final TextEditingController _documentoController = TextEditingController();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _unidadeController = TextEditingController();
  final TextEditingController _autorizanteController = TextEditingController();
  final TextEditingController _observacaoController = TextEditingController();
  final TextEditingController _marcaVeiculoController = TextEditingController();
  final TextEditingController _corVeiculoController = TextEditingController();
  final TextEditingController _modeloVeiculoController = TextEditingController();
  final TextEditingController _placaVeiculoController = TextEditingController();

  // Estado de erro para cada campo
  bool _erroDocumento = false;
  bool _erroNome = false;
  bool _erroAutorizante = false;
  bool _erroMarca = false;
  bool _erroCor = false;
  bool _erroModelo = false;
  bool _erroPlaca = false;

  // Se algum campo de veículo foi tocado
  bool _veiculoAtivo = false;

  final List<Map<String, String>> recentVisitors = [
    { 'name': 'João Silva', 'document': '123.456.789-00', 'time': '14:30', 'status': 'Aprovado', 'unit': '105', 'visiting': 'Maria Santos' },
    { 'name': 'Ana Costa', 'document': '987.654.321-00', 'time': '13:45', 'status': 'Pendente', 'unit': '201' },
    { 'name': 'Pedro Oliveira', 'document': '456.789.123-00', 'time': '12:15', 'status': 'Aprovado', 'unit': '308' },
  ];

  final List<Map<String, String>> recentPackages = [
    { 'recipient': 'Maria Santos', 'unit': '105', 'courier': 'Correios', 'time': '15:20', 'status': 'Entregue', 'tracking': 'BR123456789' },
    { 'recipient': 'João Costa', 'unit': '203', 'courier': 'Mercado Livre', 'time': '14:10', 'status': 'Pendente' },
    { 'recipient': 'Ana Silva', 'unit': '401', 'courier': 'Amazon', 'time': '13:30', 'status': 'Coletado' },
  ];

  final List<Map<String, String>> upcomingAppointments = [
    { 'visitor': 'Dr. Fernando', 'unit': '105', 'date': '2024-01-08', 'time': '16:00', 'status': 'Confirmado', 'notes': 'Manutenção do ar condicionado' },
    { 'visitor': 'Técnico Internet', 'unit': '201', 'date': '2024-01-08', 'time': '17:30', 'status': 'Pendente' },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _documentoController.dispose();
    _nomeController.dispose();
    _unidadeController.dispose();
    _autorizanteController.dispose();
    _observacaoController.dispose();
    _marcaVeiculoController.dispose();
    _corVeiculoController.dispose();
    _modeloVeiculoController.dispose();
    _placaVeiculoController.dispose();
    super.dispose();
  }

  void _limparCampos() {
    setState(() {
      _documentoController.clear();
      _nomeController.clear();
      _unidadeController.clear();
      _autorizanteController.clear();
      _observacaoController.clear();
      _marcaVeiculoController.clear();
      _corVeiculoController.clear();
      _modeloVeiculoController.clear();
      _placaVeiculoController.clear();
      _erroDocumento = false;
      _erroNome = false;
      _erroAutorizante = false;
      _erroMarca = false;
      _erroCor = false;
      _erroModelo = false;
      _erroPlaca = false;
      _veiculoAtivo = false;
    });
  }

  void _registrarEntrada() {
    setState(() {
      // Validação dos campos obrigatórios
      _erroDocumento = _documentoController.text.trim().isEmpty;
      _erroNome = _nomeController.text.trim().isEmpty;
      _erroAutorizante = _autorizanteController.text.trim().isEmpty;
      // Se algum campo de veículo foi preenchido, todos se tornam obrigatórios
      _veiculoAtivo = _marcaVeiculoController.text.trim().isNotEmpty ||
          _corVeiculoController.text.trim().isNotEmpty ||
          _modeloVeiculoController.text.trim().isNotEmpty ||
          _placaVeiculoController.text.trim().isNotEmpty;
      if (_veiculoAtivo) {
        _erroMarca = _marcaVeiculoController.text.trim().isEmpty;
        _erroCor = _corVeiculoController.text.trim().isEmpty;
        _erroModelo = _modeloVeiculoController.text.trim().isEmpty;
        _erroPlaca = _placaVeiculoController.text.trim().isEmpty;
      } else {
        _erroMarca = false;
        _erroCor = false;
        _erroModelo = false;
        _erroPlaca = false;
      }
      // Se houver algum erro, não prossegue
      if (_erroDocumento || _erroNome || _erroAutorizante || _erroMarca || _erroCor || _erroModelo || _erroPlaca) {
        return;
      }
      // Aqui você pode adicionar a lógica de cadastro
      // Após cadastrar, limpa os campos
      _limparCampos();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Sistema de Portaria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text('Controle moderno e intuitivo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              Row(
                children: const [
                  Icon(Icons.shield, size: 18, color: Colors.grey),
                  SizedBox(width: 4),
                  Text('Porteiro: João Silva', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        // Tabs
        TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Entrada'),
            Tab(text: 'Pacotes'),
            Tab(text: 'Agendamentos'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Entrada
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Formulário de Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _documentoController,
                              decoration: InputDecoration(
                                labelText: 'Documento',
                                errorText: _erroDocumento ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroDocumento ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) => setState(() => _erroDocumento = false),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _nomeController,
                              decoration: InputDecoration(
                                labelText: 'Nome e Sobrenome',
                                errorText: _erroNome ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroNome ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) => setState(() => _erroNome = false),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _unidadeController,
                              decoration: const InputDecoration(labelText: 'Unidade'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _autorizanteController,
                              decoration: InputDecoration(
                                labelText: 'Nome ou Unidade Autorizante',
                                errorText: _erroAutorizante ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroAutorizante ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) => setState(() => _erroAutorizante = false),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _observacaoController,
                              decoration: const InputDecoration(labelText: 'Observação'),
                            ),
                            const SizedBox(height: 8),
                            // Campos de veículo
                            TextField(
                              controller: _marcaVeiculoController,
                              decoration: InputDecoration(
                                labelText: 'Marca do Veículo',
                                errorText: _erroMarca ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroMarca ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _veiculoAtivo = true;
                                  _erroMarca = false;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _corVeiculoController,
                              decoration: InputDecoration(
                                labelText: 'Cor do Veículo',
                                errorText: _erroCor ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroCor ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _veiculoAtivo = true;
                                  _erroCor = false;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _modeloVeiculoController,
                              decoration: InputDecoration(
                                labelText: 'Modelo do Veículo',
                                errorText: _erroModelo ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroModelo ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _veiculoAtivo = true;
                                  _erroModelo = false;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _placaVeiculoController,
                              decoration: InputDecoration(
                                labelText: 'Placa',
                                errorText: _erroPlaca ? 'Campo obrigatório' : null,
                                border: OutlineInputBorder(
                                  borderSide: BorderSide(color: _erroPlaca ? Colors.red : Colors.grey),
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {
                                  _veiculoAtivo = true;
                                  _erroPlaca = false;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: _registrarEntrada,
                                  child: const Text('Registrar Entrada'),
                                ),
                                const SizedBox(width: 12),
                                OutlinedButton(
                                  onPressed: _limparCampos,
                                  child: const Text('Limpar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('Visitantes Recentes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...recentVisitors.map((v) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.meeting_room),
                        title: Text(v['name'] ?? ''),
                        subtitle: Text('Unidade: ${v['unit'] ?? ''} - Status: ${v['status'] ?? ''}'),
                        trailing: Text(v['time'] ?? ''),
                      ),
                    )),
                  ],
                ),
              ),
              // Pacotes
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const Text('Pacotes Recentes', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...recentPackages.map((p) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.inventory_2),
                        title: Text(p['recipient'] ?? ''),
                        subtitle: Text('Unidade: ${p['unit'] ?? ''} - Status: ${p['status'] ?? ''}'),
                        trailing: Text(p['time'] ?? ''),
                      ),
                    )),
                  ],
                ),
              ),
              // Agendamentos
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListView(
                  children: [
                    const Text('Próximos Agendamentos', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...upcomingAppointments.map((a) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.event),
                        title: Text(a['visitor'] ?? ''),
                        subtitle: Text('Unidade: ${a['unit'] ?? ''} - Status: ${a['status'] ?? ''}'),
                        trailing: Text('${a['date'] ?? ''} ${a['time'] ?? ''}'),
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}  


