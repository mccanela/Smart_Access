import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart'; // Ajuste o caminho se necessário
import '../../core/config/api_config.dart'; // Ajuste o caminho se necessário
import '../../core/config/app_version.dart' as config;

class CondominioApi {
  static Future<List<dynamic>> Agenda(String data) async {
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

    final url = Uri.parse(ApiConfig.getEndpoint('condominio', 'agenda'));
    final payload = {
      'condominio_id': condominioId,
      'data': data,
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
      return data['data'] ?? [];
    } else {
      throw Exception('Erro na API (${response.statusCode}): ${response.body}');
    }
  }

  // --- Função responsável por registrar o log de acesso ATUALIZADA ---
  static Future<void> registrarLogVisualizacao(int targetUsuarioId,
      String nomeUsuario, String conteudoInformacao) async {
    try {
      print('📝 Disparando log de visualização: $targetUsuarioId');

      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

      final url = Uri.parse(ApiConfig.getEndpoint('unidade', 'UsuarioLog'));

      final String condominioIdStr = await ApiConfig.getCondominioId();
      final int condominioId = int.tryParse(condominioIdStr) ?? 0;

// Buscando o IP antes de montar o payload
      String ipDoUsuario = await config.getDeviceIp();

      final payload = {
        "condominio_id": condominioId,
        "usuario_id": targetUsuarioId,
        "funcoes_id": 134,
        "usuarioope_id": targetUsuarioId,
        "ip_addr": ipDoUsuario,
        "texto_detalhe":
            "Visualização de dado sensível: $conteudoInformacao (Usuário: $nomeUsuario)",
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
        print('⚠️ Falha ao registrar log. Status: ${response.statusCode}');
      }
    } catch (e) {
      print('⚠️ Erro ao registrar log de visualização: $e');
    }
  }
  // ---------------------------------------------------------
}
