import 'dart:io';

void main() {
  final path = 'lib/features/modals/condominio_modal.dart';
  final file = File(path);
  final lines = file.readAsLinesSync();

  final newLines = <String>[];
  bool skip = false;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    
    if (line.contains('void _visualizarAviso(Map<String, dynamic> aviso) async {')) {
      skip = true;
    }
    
    if (skip && line.contains('Overlay.of(context).insert(overlay);')) {
      // Continue skipping this line and the next two lines to close the function
      continue;
    }
    
    if (skip && line.trim() == '}' && newLines.isNotEmpty && 
        lines[i-1].contains('Overlay.of(context).insert(overlay);')) {
      skip = false;
      continue;
    }
    
    if (!skip) {
      newLines.add(line);
    }
  }

  final finalLines = <String>[];
  bool skipPanel = false;
  
  for (final line in newLines) {
    if (line.contains('class AvisoDetalhesPanel extends SidePanel {')) {
      skipPanel = true;
    }
    
    if (skipPanel && line.contains('class CondominioPanel extends SidePanel {')) {
      skipPanel = false;
    }
    
    if (!skipPanel) {
      finalLines.add(line);
    }
  }

  file.writeAsStringSync(finalLines.join('\n'));
}
