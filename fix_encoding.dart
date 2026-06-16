import 'dart:io';

void main() {
  final file = File(
      r'c:\Users\mcane\Desktop\smart_flutter_portaria\lib\features\dashboard\dashboard.dart');
  var content = file.readAsStringSync();

  // First, fix the damage from the previous failed PowerShell attempt
  // It seems 'Ã' (C3) was interpreted/replaced by 'á' (E1) or similar.
  // In the view_file output we saw 'á§' instead of 'Ã§' and 'Cá³digo' instead of 'CÃ³digo'.
  // We want to get back to a state where we can fix the common UTF-8-as-Latin1 errors.

  // Let's look at common patterns again:
  // InformaÃ§Ãµes -> Informaá§áµes
  // Cá³digo -> CÃ³digo

  // If we replace 'á' followed by the second byte char back to the correct accented char:
  final mappings = {
    'á§': 'ç',
    'á£': 'ã',
    'á¡': 'á',
    'á©': 'é',
    'áª': 'ê',
    'á­': 'í',
    'á³': 'ó',
    'á´': 'ô',
    'áµ': 'õ',
    'áº': 'ú',
    'á¢': 'â',
    // Also the ones that were already Ã
    'Ã§': 'ç',
    'Ã£': 'ã',
    'Ã¡': 'á',
    'Ã©': 'é',
    'Ãª': 'ê',
    'Ã­': 'í',
    'Ã³': 'ó',
    'Ã´': 'ô',
    'Ãµ': 'õ',
    'Ãº': 'ú',
    'Ã¢': 'â',
    'Ã€': 'À',
    'Ã‰': 'É',
    'Ã“': 'Ó',
    'Ãš': 'Ú',
  };

  mappings.forEach((key, value) {
    content = content.replaceAll(key, value);
  });

  file.writeAsStringSync(content);
  print('Successfully fixed encoding issues.');
}
