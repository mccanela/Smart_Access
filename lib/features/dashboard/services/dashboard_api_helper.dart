import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/crypto_utils.dart';

/// Helper centralizado para chamadas HTTP do dashboard.
/// Elimina repetição de obter token/condominioId em cada método.
class DashboardApiHelper {
  /// Obtém token e condominioId do SharedPreferences.
  /// Retorna null se não houver sessão válida.
  static Future<AuthData?> getAuthData() async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
    final tokenSessao =
        encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

    final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
    final condominioId =
        encryptedCondominioId.isNotEmpty ? decryptText(encryptedCondominioId) : '';

    final encryptedUsuarioId = prefs.getString('usuario_id') ?? '';
    final usuarioId =
        encryptedUsuarioId.isNotEmpty ? decryptText(encryptedUsuarioId) : '';

    if (tokenSessao.isEmpty) return null;

    return AuthData(
      token: tokenSessao,
      condominioId: condominioId,
      condominioIdInt: int.tryParse(condominioId) ?? 0,
      usuarioId: usuarioId,
      usuarioIdInt: int.tryParse(usuarioId) ?? 0,
    );
  }

  /// Faz POST autenticado e retorna o body parseado, ou null em caso de erro.
  static Future<Map<String, dynamic>?> post(
    String url,
    Map<String, dynamic> payload, {
    String? token,
  }) async {
    final auth = token ?? (await getAuthData())?.token;
    if (auth == null || auth.isEmpty) return null;

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $auth',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Faz GET autenticado e retorna o body parseado, ou null em caso de erro.
  static Future<Map<String, dynamic>?> get(String url, {String? token}) async {
    final auth = token ?? (await getAuthData())?.token;
    if (auth == null || auth.isEmpty) return null;

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $auth',
        },
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Extrai lista de uma resposta JSON com múltiplos formatos possíveis.
  /// Tenta: data.lista, lista, data (se List), root (se List).
  static List<Map<String, dynamic>> extractList(
    Map<String, dynamic>? responseData, {
    String? listKey,
  }) {
    if (responseData == null) return [];

    dynamic target;
    if (listKey != null) {
      target = responseData[listKey] ?? responseData['data']?[listKey];
    }

    target ??= responseData['data']?['lista'] ??
        responseData['lista'] ??
        responseData['data'];

    if (target is List) {
      return List<Map<String, dynamic>>.from(target);
    }
    return [];
  }
}

/// Dados de autenticação do usuário logado.
class AuthData {
  final String token;
  final String condominioId;
  final int condominioIdInt;
  final String usuarioId;
  final int usuarioIdInt;

  const AuthData({
    required this.token,
    required this.condominioId,
    required this.condominioIdInt,
    required this.usuarioId,
    required this.usuarioIdInt,
  });
}
