import 'package:signalr_core/signalr_core.dart';
import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';

class SignalRService {
  //-----------------------------//
  // SINGLETON PATTERN
  //-----------------------------//
  static final SignalRService _instance = SignalRService._internal();
  factory SignalRService() => _instance;
  SignalRService._internal();

  //-----------------------------//
  // ESTADO DA CONEXAO
  //-----------------------------//
  HubConnection? _hubConnection;
  bool _isDisposed = false; // Flag para controlar ciclo de vida da sessao
  bool _isInitializing = false; // Bloqueio de concorrencia

  //-----------------------------//
  // DADOS E CALLBACKS
  //-----------------------------//
  int? _condominioIdAtual;
  Function(List<dynamic>)? onPassagensUpdate;

  //-----------------------------//
  // STREAM DE ESTADO
  //-----------------------------//
  // Broadcast stream para UI ouvir mudancas de conexao (Sidebar, etc)
  final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected =>
      _hubConnection?.state == HubConnectionState.connected && !_isDisposed;

  int? get condominioId => _condominioIdAtual;

  //-----------------------------//
  // URL do SignalR
  //-----------------------------//
  final String _baseUrl = "wss://signalr.conectcon.net.br:10901/client";

  //-----------------------------//
  // INICIALIZACAO (SESSAO)
  //-----------------------------//
  Future<void> initialize() async {
    if (_isInitializing) {
      print('[SignalR] ⚠️ Bloqueio: Inicializacao ja em andamento.');
      return;
    }
    _isInitializing = true;

    try {
      // 1. Obter credenciais iniciais
      final token = await ApiConfig.getBearerToken();
      final condominioIdStr = await ApiConfig.getCondominioId();
      final novoCondominioId = int.tryParse(condominioIdStr) ?? 0;

      if (token.isEmpty || novoCondominioId == 0) {
        print('[SignalR] Abortando: Token invalido ou ID=0.');
        return;
      }

      // Check se ja estamos conectados no MESMO condominio
      if (isConnected && _condominioIdAtual == novoCondominioId) {
        print(
            '[SignalR] ✅ Ja conectado ao condominio $_condominioIdAtual. Solicitando apenas refresh de dados.');
        await _solicitarListaInicial(novoCondominioId);
        // Sinaliza que a conexão está ativa para a UI
        _notifyConnectionState(true);
        return;
      }

      // Se mudou de condominio ou nao esta conectado, recomecar do zero
      print('[SignalR] Reiniciando sessao (Condominio: $novoCondominioId)...');
      await dispose();
      _isDisposed = false; // Reativar flag apos dispose

      _condominioIdAtual = novoCondominioId;

      // ⚠️ IMPORTANTE: Para WebSockets com skipNegotiation, passamos apenas os parâmetros fixos.
      // O token DEVE vir da accessTokenFactory para que seja atualizado em cada tentativa de reconexão.
      final urlComParametros = "$_baseUrl?condominio_id=$novoCondominioId";

      print(
          '[SignalR] Iniciando NOVA sessao para condominio: $novoCondominioId');

      // 3. Criar nova instancia de conexao
      _hubConnection = HubConnectionBuilder()
          .withUrl(
        urlComParametros,
        HttpConnectionOptions(
          // Factory DINÂMICA: busca o token atualizado a cada reconexão
          accessTokenFactory: () async => await ApiConfig.getBearerToken(),
          withCredentials: false,
          transport: HttpTransportType.webSockets,
          skipNegotiation: true,
        ),
      )
          .withAutomaticReconnect([
        0, // Imediato
        2000, // 2s
        5000, // 5s
        10000, // 10s
        20000, // 20s
        30000, // 30s
        // Tentar reconectar a cada 30s por muito tempo (aprox 24h)
        for (var i = 0; i < 2880; i++) 30000,
      ]).build();

      // 4. Configurar handlers
      print('[SignalR] 📋 Configurando event handlers...');
      _setupEventHandlers();

      // 5. Conectar
      print('[SignalR] 🔌 Iniciando conexão...');
      await _hubConnection!.start();
      print('[SignalR] ✅ Conectado e ativo. Estado: ${_hubConnection!.state}');
      _notifyConnectionState(true);

      // 5.5 Entrar no Grupo do Condominio (CRUCIAL PARA REALTIME)
      try {
        print(
            '[SignalR] 🏢 Entrando no grupo do condominio: $novoCondominioId');
        await _hubConnection!
            .invoke("EntrarNoCondominio", args: [novoCondominioId]);
        print('[SignalR] ✅ Entrou no grupo com sucesso!');
      } catch (e) {
        print(
            '[SignalR] ⚠️ Falha ao invocar EntrarNoCondominio (Talvez o metodo nao exista ou ja esteja no grupo): $e');
      }

      // 6. Invocar lista inicial
      print('[SignalR] 📞 Solicitando lista inicial de passagens...');
      await _solicitarListaInicial(novoCondominioId);
      print('[SignalR] ✅ Lista inicial solicitada com sucesso');
    } catch (e) {
      print('[SignalR] 🔴 Erro fatal na inicializacao: $e');
      _notifyConnectionState(false);
      // Se falhar na partida, garante limpeza
      await dispose();
    } finally {
      _isInitializing = false;
    }
  }

  //-----------------------------//
  // DESCONEXAO E LIMPEZA (DESTRUICAO TOTAL)
  //-----------------------------//
  Future<void> dispose() async {
    print('[SignalR] Finalizando sessao (dispose commands)...');
    _isDisposed = true; // Impede novos eventos de serem processados

    // 1. NÃO resetar callbacks - eles devem persistir entre reconexões
    // onPassagensUpdate = null; // COMENTADO: callback deve persistir

    // 2. Parar conexao se existir
    if (_hubConnection != null) {
      if (_hubConnection!.state != HubConnectionState.disconnected) {
        try {
          await _hubConnection!.stop();
        } catch (e) {
          print('[SignalR] Erro ao parar conexao (ignorado): $e');
        }
      }

      // Remover referencas internas do hub
      _hubConnection = null;
    }

    // 3. Limpar estado local
    _condominioIdAtual = null;

    // 4. Notificar UI que desconectou
    _notifyConnectionState(false);

    print('[SignalR] Sessao totalmente destruida.');
  }

  //-----------------------------//
  // FLUXO DE COMANDOS
  //-----------------------------//
  Future<void> _solicitarListaInicial(int condominioId) async {
    if (_isDisposed || _hubConnection == null) return;

    try {
      print('[SignalR] 📤 Invoke: PassagemListar($condominioId)');
      await _hubConnection!.invoke("PassagemListar", args: [condominioId]);
      print(
          '[SignalR] ✅ Invoke PassagemListar completado (aguardando evento do servidor...)');
    } catch (e) {
      print('[SignalR] ❌ Erro ao solicitar lista inicial: $e');
    }
  }

  // Contrato para atualizar o status de leitura da passagem no servidor via WebSocket
  Future<void> PassagemUpdateTela(dynamic id) async {
    print('[SignalR] entrou PassagemUpdateTela com id: $id');
    if (_isDisposed || _hubConnection == null || !isConnected) return;
    try {
      // 1. Criamos o mapa (objeto JSON)
      final payload = {"id": int.parse(id.toString())};
      final int idInt = int.parse(id.toString());
      // 2. Enviamos o payload dentro da lista de argumentos
      await _hubConnection!.invoke("PassagemUpdateTela", args: [idInt]);

      print('[SignalR] 📤 Invoke: PassagemUpdateTela($payload)');
    } catch (e) {
      print('[SignalR] ❌ Erro ao invocar PassagemUpdateTela: $e');
    }
  }

  //-----------------------------//
  // CONFIGURACAO DE LISTENERS (EVENTOS DO SERVIDOR)
  //-----------------------------//
  void _setupEventHandlers() {
    if (_isDisposed || _hubConnection == null) return;

    // ⚠️ IMPORTANTE: Remover handlers antigos para evitar duplicação
    try {
      _hubConnection!.off("PassagemListar");
      _hubConnection!.off("PassagensUpdate");
      _hubConnection!.off("Comandos");
    } catch (_) {}

    // Handler Unificado de Passagens
    _hubConnection!.on("PassagemListar", (args) {
      // print('🔔 [SignalR] EVENTO "PassagemListar" RECEBIDO!'); // Verbose
      _processPassagensData(args);
    });

    _hubConnection!.on("PassagensUpdate", (args) {
      print('🔔 [SignalR] EVENTO "PassagensUpdate" RECEBIDO!');
      _processPassagensData(args);
    });

    // Opcional: Handler para Comandos se existir retorno
    _hubConnection!.on("Comandos", (args) {
      print('🔔 [SignalR] EVENTO "Comandos" RECEBIDO: $args');
    });

    print(
        '[SignalR] Event handlers configurados (PassagemListar, PassagensUpdate)');

    _hubConnection!.onclose((error) {
      print('[SignalR] onclose (Terminado): $error');
      _notifyConnectionState(false);
    });

    _hubConnection!.onreconnecting((error) {
      print('[SignalR] Tentando reconexao automatica (lib)...');
      _notifyConnectionState(false);
    });

    _hubConnection!.onreconnected((connectionId) async {
      print('[SignalR] Reconectado automaticamente (lib)!');
      _notifyConnectionState(true);
      if (_condominioIdAtual != null) {
        // 🔥 REENTRAR NO GRUPO APÓS RECONEXÃO
        try {
          print(
              '[SignalR] 🏢 Re-entrando no grupo do condominio: $_condominioIdAtual');
          await _hubConnection!
              .invoke("EntrarNoCondominio", args: [_condominioIdAtual]);
          print('[SignalR] ✅ Re-entrou no grupo com sucesso!');
        } catch (e) {
          print('[SignalR] ⚠️ Falha ao re-entrar no grupo: $e');
        }

        _solicitarListaInicial(_condominioIdAtual!);
      }
    });
  }

  void _processPassagensData(List<Object?>? arguments) {
    if (_isDisposed) return; // Bloqueio de seguranca

    try {
      final payload =
          (arguments != null && arguments.isNotEmpty) ? arguments.first : null;
      // print('[SignalR] Payload recebido. Tipo: ${payload.runtimeType}');

      List<dynamic> passagensData = [];

      // LÓGICA DE UNWRAP ROBUSTA
      if (payload is List) {
        // Se for uma lista direta [Item1, Item2] ou [[Item1, Item2]]
        if (payload.isNotEmpty && payload.first is List) {
          // Caso [[Item1, Item2]] (SignalR as vezes encapsula)
          passagensData = payload.first;
        } else {
          // Caso [Item1, Item2]
          passagensData = payload;
        }
      } else if (payload is Map) {
        // Tentativa 1: Chaves diretas (Listas encapsuladas)
        if (payload.containsKey('data') && payload['data'] is List) {
          passagensData = payload['data'];
        } else if (payload.containsKey('passagens') &&
            payload['passagens'] is List) {
          passagensData = payload['passagens'];
        }
        // Tentativa 2: Unwrap recursivo (ex: data -> data)
        else if (payload.containsKey('data') && payload['data'] is Map) {
          final innerData = payload['data'];
          if (innerData.containsKey('data') && innerData['data'] is List) {
            passagensData = innerData['data'];
          } else if (innerData.containsKey('passagens') &&
              innerData['passagens'] is List) {
            passagensData = innerData['passagens'];
          } else {
            // Se o innerData for um Map mas não tiver as chaves, talvez ele seja o item?
            passagensData = [innerData];
          }
        } else {
          // Fallback: Se o payload é um Map e não tem chaves de lista,
          // ele pode ser o próprio objeto de passagem individual (Update real-time)
          passagensData = [payload];
        }
      }

      // Converter e Filtrar
      final passagens = passagensData
          .map((item) {
            if (item is Map) return Map<String, dynamic>.from(item);
            if (item is String) return jsonDecode(item) as Map<String, dynamic>;
            return <String, dynamic>{};
          })
          .where((p) => p.isNotEmpty)
          .toList();

      if (passagens.isNotEmpty) {
        // print('📊 [SignalR] Passagens processadas: ${passagens.length}');
      }

      // Enviar para UI (apenas se nao estiver disposed)
      if (!_isDisposed && onPassagensUpdate != null) {
        // print('✅ [SignalR] Atualizando UI via callback');
        onPassagensUpdate!(passagens);
      }
    } catch (e) {
      print('[SignalR] Erro ao processar dados: $e');
    }
  }

  void _notifyConnectionState(bool connected) {
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(connected);
    }
  }
}
