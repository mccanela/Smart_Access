import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart'; // Ajuste o caminho se necessário
import '../../core/config/api_config.dart'; // Ajuste o caminho se necessário

class EquipamentosApi {
  /// Busca a lista de equipamentos (regras) baseada no condomínio
  static Future<List<dynamic>> carregarEquipamentos() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
    if (tokenSessao.isEmpty) {
      throw Exception('Sessão inválida. Token não encontrado.');
    }

    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';

    final url =
        Uri.parse(ApiConfig.getEndpoint('equipamento', 'equipamentoregralist'));
    final payload = {'condominio_id': condominioId};

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
      return data['data']['regras'] ?? [];
    } else {
      throw Exception('Erro na API (${response.statusCode}): ${response.body}');
    }
  }

  /// Dispara a atualização para o leitor específico
  static Future<void> dispararAtualizacaoIns(String leitorId) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';
    if (tokenSessao.isEmpty) {
      throw Exception('Sessão inválida. Token não encontrado.');
    }

    final condominioId = (encryptedCondominioId.isNotEmpty)
        ? decryptText(encryptedCondominioId)
        : '';

    // ATENÇÃO: Verifique se o primeiro parâmetro do getEndpoint (módulo) e o nome do endpoint estão corretos para a sua estrutura!
    final url = Uri.parse(
        ApiConfig.getEndpoint('equipamento', 'controleatualizacaoIns'));

    final payload = {
      'condominio_id': condominioId,
      'leitor_id': leitorId,
    };

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenSessao',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Erro na API (${response.statusCode}): ${response.body}');
    }
  }
}
