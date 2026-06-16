import 'dart:io';

void main() {
  final dir = Directory('.');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  int count = 0;
  for (var file in files) {
    if (file.path.contains('remove_ellipsis.dart')) continue;

    String content = file.readAsStringSync();

    // Match hintText, labelText, or label followed by a string ending with ...
    final regex = RegExp(
        "(hintText|labelText|label)\\s*:\\s*(['\\\"])(.*?)\\.\\.\\.(['\\\"])");

    String newContent = content.replaceAllMapped(regex, (match) {
      return '${match.group(1)}: ${match.group(2)}${match.group(3)}${match.group(4)}';
    });

    // Also we might have text directly in a string inside Text('...') or something similar,
    // but the user's specific request "todos os campos" implies input fields. We'll stick to hintText and labelText.
    // However, I should also match `inputDecorationPadrao(context, hintText: 'Nome...')`
    // Wait, the regex "(hintText|labelText|label)\\s*:\\s*(['\\\"])(.*?)\\.\\.\\.(['\\\"])" will match any "hintText: '...'"

    if (newContent != content) {
      file.writeAsStringSync(newContent);
      count++;
      print('Updated: ${file.path}');
    }
  }
  print('Modificados $count arquivos.');
}
