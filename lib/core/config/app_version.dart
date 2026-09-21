import 'package:http/http.dart' as http;

const String appVersion = '3.0.0';

Future<String> getDeviceIp() async {
  try {
    final response = await http.get(Uri.parse('https://api.ipify.org'));
    if (response.statusCode == 200) {
      return response.body; // Retorna o IP (ex: 177.32.45.1)
    }
  } catch (e) {
    print('⚠️ Erro ao capturar IP: $e');
  }
  return ''; // Retorna vazio se falhar, para não quebrar o log
}
