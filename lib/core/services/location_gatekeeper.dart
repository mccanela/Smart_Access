import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../core/config/api_config.dart';
import '../../core/services/crypto_utils.dart';

/// Função global e independente para obter a posição obrigatória do usuário.
/// Pode ser importada e chamada em qualquer lugar, como no main.dart ou no login.dart.
Future<Position> obterPosicaoObrigatoria(int condominioId) async {
  bool servicoAtivado;
  LocationPermission permissao;

// 1. Pula a verificação de serviço nativo se estiver rodando na Web.
  // Evita o erro MissingPluginException no Cloudflare/Navegador.
  if (!kIsWeb) {
    servicoAtivado = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivado) {
      return Future.error(
        'Os serviços de localização do seu dispositivo estão desativados.\n'
        'Ative o GPS para usar o sistema.',
      );
    }
  }

  // 2. Verifica as permissões de localização do navegador
  permissao = await Geolocator.checkPermission();
  if (permissao == LocationPermission.denied) {
    permissao = await Geolocator.requestPermission();
    if (permissao == LocationPermission.denied) {
      return Future.error(
        'Permissão de localização negada.\n'
        'O acesso ao sistema requer a sua localização.',
      );
    }
  }

  if (permissao == LocationPermission.deniedForever) {
    return Future.error(
      'Acesso ao sistema negado.\n'
      'Clique no ícone de cadeado na barra de endereços do seu navegador, '
      'permita a localização e recarregue a página.',
    );
  }

  Position posicao = await Geolocator.getCurrentPosition();

  if (condominioId == 0) {
    final idString = await ApiConfig.getCondominioId();
    condominioId = int.parse(idString);
  }

// 4. Valida as coordenadas no back-end
  bool perimetroLiberado = await _verificarPerimetroNaApi(
      condominioId, posicao.latitude, posicao.longitude);

  if (!perimetroLiberado) {
    return Future.error(
        'Seu computador está fora do perímetro para utilização do sistema.');
  }
  // 3. Se passou pelas validações, retorna as coordenadas
  return posicao;
}

/// Widget "Porteiro" que bloqueia as rotas do app até que a localização seja concedida.
class LocationGatekeeper extends StatefulWidget {
  final Widget child;

  const LocationGatekeeper({super.key, required this.child});

  @override
  State<LocationGatekeeper> createState() => _LocationGatekeeperState();
}

Future<bool> _verificarPerimetroNaApi(
    int condominioId, double latitude, double longitude) async {
  try {
    // Caso precise pegar o condominio_id real salvo na sessão, descomente as linhas abaixo:
    // final prefs = await SharedPreferences.getInstance();
    // final int condominioId = prefs.getInt('condominio_id') ?? 0;

    final getSessaoUrl = ApiConfig.getEndpoint('auth', 'getSession');
    final sessaoResponse = await http.post(
      Uri.parse(getSessaoUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'usuario_id': 1183}),
    );
    final sessaoData = jsonDecode(sessaoResponse.body);
    String token = '';
    if (sessaoData is Map) {
      if (sessaoData.containsKey('data')) {
        // USER INSTRUCTION: "pegue o data que esta em response de getsessao ... ele é o bearer"
        token = sessaoData['data']?.toString() ?? '';
      } else if (sessaoData.containsKey('token')) {
        token = sessaoData['token'];
      } else if (sessaoData.containsKey('access_token')) {
        token = sessaoData['access_token'];
      } else {
        // Fallback
        token = sessaoData.values
            .firstWhere((v) => v is String && v.length > 20, orElse: () => '')
            .toString();
      }
    }

    final url = Uri.parse(
      ApiConfig.getEndpoint('condominio', 'CondominioGeoPosicao'),
    );

    final body = {
      "condominio_id": condominioId, // Substitua por condominioId se necessário
      "espacosocial_id": 0,
      "latitude": latitude,
      "longitude": longitude,
      "metros": 1000.0
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);

      // Acessa o nó 'data' e verifica a propriedade 'abreportao'
      if (jsonResponse['data'] != null &&
          jsonResponse['data']['abreportao'] != null) {
        return jsonResponse['data']['abreportao'] == true;
      }
    }

    // Se a API não retornou 200 ou o JSON veio diferente do esperado, assumimos bloqueio
    return false;
  } catch (e) {
    debugPrint('Erro ao verificar perímetro na API: $e');
    // Em caso de erro de rede ou timeout, por segurança, negamos o acesso
    return false;
  }
}

class _LocationGatekeeperState extends State<LocationGatekeeper> {
  late Future<Position> _posicaoFuture;

  @override
  void initState() {
    super.initState();

    //final int condominioId = ApiConfig.getCondominioId() as int;
    _posicaoFuture = obterPosicaoObrigatoria(0);
  }

  void _tentarNovamente() {
    //final int condominioId = ApiConfig.getCondominioId() as int;
    setState(() {
      _posicaoFuture = obterPosicaoObrigatoria(0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: _posicaoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.location_off_rounded,
                      size: 80,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Acesso Restrito',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tentar Novamente"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: _tentarNovamente,
                    )
                  ],
                ),
              ),
            ),
          );
        }

        // Se deu tudo certo, libera a renderização do app/rotas normais
        return widget.child;
      },
    );
  }
}
