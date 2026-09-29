import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/crypto_utils.dart'; // Ajuste o caminho se necessário
import '../../core/config/api_config.dart'; // Ajuste o caminho se necessário

class ConvidadosApi {
  static Future<List<dynamic>> ConvidadosList(String reservaId,
      [String? reservaConvidadoId]) async {
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

    final url = Uri.parse(
      ApiConfig.getUrl(
        'dashboard',
        'convidados',
        params: {
          'reserva_id': reservaId,
          // Só adiciona a chave no Map se a condição for verdadeira
          if (reservaConvidadoId != null &&
              reservaConvidadoId.trim().isNotEmpty)
            'reservaconvidado_id': reservaConvidadoId,
          'culture': 'pt-br',
        },
      ),
    );

    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        // Enviando também no body para garantir compatibilidade com a API
        body: jsonEncode({
          "condominio_id": condominioId,
          "reserva_id": int.tryParse(reservaId) ?? 0
        }));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']?['convidados'] ?? [];
    } else {
      throw Exception('Erro na API (${response.statusCode}): ${response.body}');
    }
  }

  static Future<List<dynamic>> ConvidadosEntradaSaida(String reservaId,
      [String? reservaConvidadoId]) async {
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

    final url = Uri.parse(
      ApiConfig.getUrl(
        'convidados',
        'entradasaida',
        params: {
          'reserva_id': reservaId,
          // Só adiciona a chave no Map se a condição for verdadeira
          if (reservaConvidadoId != null &&
              reservaConvidadoId.trim().isNotEmpty)
            'reservaconvidado_id': reservaConvidadoId,
          'culture': 'pt-br',
        },
      ),
    );

    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        // Enviando também no body para garantir compatibilidade com a API
        body: jsonEncode({
          "condominio_id": condominioId,
          "reserva_id": int.tryParse(reservaId) ?? 0
        }));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']?['lista'] ?? [];
    } else {
      throw Exception('Erro na API (${response.statusCode}): ${response.body}');
    }
  }

  static Future<void> AtualizarConvidadoAgendamento(
      Map<String, dynamic> convidado) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        (encryptedToken.isNotEmpty) ? decryptText(encryptedToken) : '';

    if (tokenSessao.isEmpty) throw Exception('Token de sessão inválido');

    final reservaId = convidado['reserva_id'] is int
        ? convidado['reserva_id']
        : int.tryParse(convidado['reserva_id']?.toString() ?? '0') ?? 0;
    final reservaconvidadoId = convidado['reservaconvidado_id'] is int
        ? convidado['reservaconvidado_id']
        : int.tryParse(convidado['reservaconvidado_id']?.toString() ?? '0') ??
            0;

    // Tratamento de foto (similar ao que você já faz na entrada)
    String? fotoBase64 = convidado['foto']?.toString();
    final String? linkFoto = convidado['link_foto']?.toString();
    bool hasUrlAsPhoto = fotoBase64 != null && fotoBase64.startsWith('http');
    bool hasLinkFoto =
        linkFoto != null && linkFoto.isNotEmpty && linkFoto.startsWith('http');

    if ((fotoBase64 == null ||
            fotoBase64.isEmpty ||
            fotoBase64 == 'null' ||
            hasUrlAsPhoto) &&
        hasLinkFoto) {
      try {
        final response = await http.get(Uri.parse(linkFoto));
        if (response.statusCode == 200) {
          fotoBase64 = base64Encode(response.bodyBytes);
        } else {}
      } catch (e) {
        print('Erro ao converter imagem: $e');
      }
    }
    if (fotoBase64 != null && fotoBase64.contains(',')) {
      fotoBase64 = fotoBase64.split(',').last;
    }
    final urlUpd = Uri.parse(ApiConfig.getEndpoint('convidados', 'atualizar'));
    final payloadUpd = {
      'condominio_id':
          int.tryParse(convidado['condominio_id']?.toString() ?? '0') ?? 0,
      'reserva_id': reservaId,
      'reservaconvidado_id': reservaconvidadoId,
      'convidado_txt': convidado['nome'] ?? convidado['convidado_txt'] ?? '',
      'email_txt': convidado['email'] ?? convidado['email_txt'] ?? '',
      'autorizante_txt':
          convidado['autorizante'] ?? convidado['autorizante_txt'] ?? '',
      'documento_txt':
          convidado['documento'] ?? convidado['documento_txt'] ?? '',
      'empresa_txt': convidado['empresa'] ?? convidado['empresa_txt'] ?? '',
      'creci_txt': convidado['creci'] ?? convidado['creci_txt'] ?? '',
      'placa': convidado['placa'] ?? '',
      'veiculo_txt': convidado['veiculo'] ?? convidado['veiculo_txt'] ?? '',
      'tipodoc_txt': convidado['tipodoc'] ?? convidado['tipodoc_txt'] ?? '',
      'quant_pessoas':
          int.tryParse(convidado['quant_pessoas']?.toString() ?? '1') ?? 1,
      'vaga_flg': (convidado['vaga_flg'] == 'S' ||
              convidado['flg_vaga'] == 'S' ||
              convidado['vaga'] != null)
          ? 'S'
          : 'N',
      'excluir': 'N',
      'id_acesso': '',
      'fotoBase64': fotoBase64,
    };

    final responseUpd = await http.post(
      urlUpd,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $tokenSessao',
      },
      body: jsonEncode(payloadUpd),
    );

    if (responseUpd.statusCode == 200) {
      final dataUpd = jsonDecode(responseUpd.body);

      // Validação 1: Status global da API
      if (dataUpd['status'] != 200) {
        throw Exception('Erro ao atualizar dados: ${dataUpd['message']}');
      }

      // Validação 2: Status 200, mas com erro lógico dentro do array "data"
      if (dataUpd['data'] != null &&
          dataUpd['data'] is List &&
          dataUpd['data'].isNotEmpty) {
        final itemData = dataUpd['data'][0];

        if (itemData['erro'] == 1 || itemData['erro'] == '1') {
          throw Exception(
              itemData['mensagem'] ?? 'Ocorreu um erro interno na operação.');
        }
      }
    } else {
      throw Exception('Erro HTTP na atualização: ${responseUpd.statusCode}');
    }
  }
}
