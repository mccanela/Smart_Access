import 'package:encrypt/encrypt.dart' as encrypt;

// Chave fixa para exemplo. Em produção, use uma chave forte.
final _key = encrypt.Key.fromUtf8(
  '12345678901234567890123456789012',
); // 32 bytes para AES-256

String encryptText(String plainText) {
  try {
    if (plainText.isEmpty) return '';

    // Gerar IV aleatório para cada criptografia
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);

    // Combinar IV + texto criptografado em base64
    final combined = '${iv.base64}:${encrypted.base64}';
    return combined;
  } catch (e) {
    // REMOVIDO: Print de erro ao criptografar
    return '';
  }
}

String decryptText(String encryptedText) {
  try {
    if (encryptedText.isEmpty) return '';

    // Separar IV e texto criptografado
    final parts = encryptedText.split(':');
    if (parts.length != 2) {
      // REMOVIDO: Print de formato inválido
      return '';
    }

    final ivBase64 = parts[0];
    final encryptedBase64 = parts[1];

    final iv = encrypt.IV.fromBase64(ivBase64);
    final encrypter = encrypt.Encrypter(encrypt.AES(_key));
    final decrypted = encrypter.decrypt64(encryptedBase64, iv: iv);

    return decrypted;
  } catch (e) {
    // REMOVIDO: Print de erro ao descriptografar
    return '';
  }
}
