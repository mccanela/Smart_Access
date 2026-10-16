import 'package:flutter/services.dart';

class Utilities {
  static String removerPontuacao(String texto) {
    // A expressão r'[.,/\-]' agora procura por ponto, vírgula, barra ou traço
    return texto.replaceAll(RegExp(r'[.,/\-]'), '');
  }

  static bool isDocumentoValido(String documento) {
    // Remove formatação básica, mas preserva letras (para passaporte) e números
    final docLimpo =
        documento.replaceAll(RegExp(r'[.,/\-\s]'), '').toUpperCase();
    if (docLimpo.isEmpty) return false;

    // 1. Valida Passaporte (Padrão BR: 2 letras + 7 números. Ou geral: 6 a 15 caracteres alfanuméricos contendo letras)
    if (RegExp(r'^[A-Z]{2}\d{7}$').hasMatch(docLimpo) ||
        (RegExp(r'^[A-Z0-9]{6,15}$').hasMatch(docLimpo) &&
            docLimpo.contains(RegExp(r'[A-Z]')))) {
      return true;
    }

    // 2. Extrai APENAS os números para validar CPF, CNPJ e RG
    final doc = docLimpo.replaceAll(RegExp(r'[^0-9]'), '');
    if (doc.isEmpty) return false;

    // Valida CPF (Exatamente 11 dígitos com cálculo de módulo 11)
    if (doc.length == 11) {
      if (RegExp(r'^(\d)\1*$').hasMatch(doc)) return false;
      List<int> numbers = doc.split('').map(int.parse).toList();
      int sum1 = 0;
      for (int i = 0; i < 9; i++) sum1 += numbers[i] * (10 - i);
      int digit1 = 11 - (sum1 % 11);
      if (digit1 >= 10) digit1 = 0;
      if (numbers[9] != digit1) return false;

      int sum2 = 0;
      for (int i = 0; i < 10; i++) sum2 += numbers[i] * (11 - i);
      int digit2 = 11 - (sum2 % 11);
      if (digit2 >= 10) digit2 = 0;
      return numbers[10] == digit2;
    }

    // Valida CNPJ (Exatamente 14 dígitos com cálculo de módulo 11)
    if (doc.length == 14) {
      if (RegExp(r'^(\d)\1*$').hasMatch(doc)) return false;
      List<int> numbers = doc.split('').map(int.parse).toList();
      int sum1 = 0;
      List<int> weights1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      for (int i = 0; i < 12; i++) sum1 += numbers[i] * weights1[i];
      int digit1 = sum1 % 11 < 2 ? 0 : 11 - (sum1 % 11);
      if (numbers[12] != digit1) return false;

      int sum2 = 0;
      List<int> weights2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2];
      for (int i = 0; i < 13; i++) sum2 += numbers[i] * weights2[i];
      int digit2 = sum2 % 11 < 2 ? 0 : 11 - (sum2 % 11);
      return numbers[13] == digit2;
    }

    // RG ou Busca Parcial: Aceita entre 6 e 10 dígitos (tamanho padrão para RGs no Brasil)
    if (doc.length >= 6 && doc.length <= 10) return true;

    return false; // Bloqueia tamanhos inconsistentes
  }

  static String maskName(String name) {
    if (name.isEmpty) return name;
    final parts = name.trim().split(' ');
    if (parts.length <= 1) return name;
    final firstName = parts[0];
    final secondPart = parts[1];
    if (secondPart.isEmpty) return firstName;

    return name;
    //return '$firstName ${secondPart[0]}.';
  }

  static String maskDocument(String documento) {
    if (documento.isEmpty) return '';

    String doc = documento.trim();

    // Se o documento for muito curto (ex: testando digitação), retorna sem quebrar
    if (doc.length <= 6) return doc;

    String inicio = doc.substring(0, 3);
    String fim = doc.substring(doc.length - 3);

    // Preenche o meio com asteriscos mantendo o tamanho original da string
    String mascara = '*' * (doc.length - 6);

    return '$inicio$mascara$fim';
  }
}

class DocumentoFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Verifica se o texto contém alguma letra
    final hasLetters = RegExp(r'[a-zA-Z]').hasMatch(newValue.text);

    if (hasLetters) {
      // Se tiver letra, tratamos como passaporte (sem máscara, converte para maiúscula, limite de 15 caracteres)
      String text =
          newValue.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
      if (text.length > 15) return oldValue;

      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }

    // Se for apenas número, segue a lógica de CPF/CNPJ
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Bloqueia digitação além de 14 números (CNPJ)
    if (text.length > 14) return oldValue;

    // Define a máscara dinamicamente (Até 11 é CPF/RG, passou de 11 vira CNPJ)
    String mask = text.length <= 11 ? '###.###.###-##' : '##.###.###/####-##';

    String formatted = '';
    int i = 0;
    for (var m in mask.split('')) {
      if (i >= text.length) break;
      if (m == '#') {
        formatted += text[i];
        i++;
      } else {
        formatted += m;
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
