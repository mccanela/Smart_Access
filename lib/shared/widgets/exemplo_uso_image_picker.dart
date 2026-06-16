// EXEMPLO DE USO DO CUSTOM IMAGE PICKER
// Este arquivo mostra como integrar o CustomImagePicker na sua aplicação

import 'package:flutter/material.dart';
import 'package:smart_flutter/shared/widgets/custom_image_picker.dart';

/// Exemplo de como usar o CustomImagePicker em um modal ou página
class ExemploUsoImagePicker extends StatefulWidget {
  const ExemploUsoImagePicker({super.key});

  @override
  State<ExemploUsoImagePicker> createState() => _ExemploUsoImagePickerState();
}

class _ExemploUsoImagePickerState extends State<ExemploUsoImagePicker> {
  String? _fotoPath;

  void _mostrarModalFoto() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cadastro Facial',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tire uma foto para o reconhecimento',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              // O componente CustomImagePicker
              CustomImagePicker(
                onImageSelected: (path) {
                  setState(() {
                    _fotoPath = path;
                  });
                  Navigator.of(context).pop();

                  // Aqui você pode fazer o que quiser com o path da foto
                  // Por exemplo, converter para base64 e enviar para API
                  print('Foto capturada: $path');

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Foto capturada com sucesso!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
              ),

              const SizedBox(height: 24),

              // Botão para fechar
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemplo Image Picker'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_fotoPath != null) ...[
              const Text(
                'Foto capturada!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Path: $_fotoPath',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton.icon(
              onPressed: _mostrarModalFoto,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tirar Foto'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Exemplo de integração direta em uma página (sem modal)
class ExemploIntegracaoDireta extends StatefulWidget {
  const ExemploIntegracaoDireta({super.key});

  @override
  State<ExemploIntegracaoDireta> createState() =>
      _ExemploIntegracaoDiretaState();
}

class _ExemploIntegracaoDiretaState extends State<ExemploIntegracaoDireta> {
  String? _fotoPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro Facial'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Text(
              'Cadastro Facial',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Tire uma foto para o reconhecimento',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),

            // Componente customizado integrado diretamente
            CustomImagePicker(
              onImageSelected: (path) {
                setState(() {
                  _fotoPath = path;
                });

                // Processar a foto aqui
                print('Foto selecionada: $path');
              },
            ),

            const SizedBox(height: 40),

            if (_fotoPath != null)
              ElevatedButton(
                onPressed: () {
                  // Enviar para API ou processar
                  print('Enviando foto: $_fotoPath');
                },
                child: const Text('Confirmar e Enviar'),
              ),
          ],
        ),
      ),
    );
  }
}
