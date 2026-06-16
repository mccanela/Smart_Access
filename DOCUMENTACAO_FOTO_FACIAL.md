# Sistema de Captura de Foto Facial - Documentação

## 📋 Visão Geral

Este sistema implementa uma solução completa para captura de fotos faciais com:
- ✅ Câmera com enquadramento facial
- ✅ Remoção automática de fundo (usando ML Kit)
- ✅ Suporte para galeria de fotos
- ✅ Interface animada e intuitiva
- ✅ Suporte para Web e Mobile

## 📁 Arquivos Criados

### 1. `custom_image_picker.dart`
Widget principal que gerencia a interface de captura de foto.

**Recursos:**
- Animação circular que expande quando a câmera é ativada
- Botões para câmera e galeria
- Controles de captura, confirmação e refazer
- Preview da imagem capturada

### 2. `face_camera_view.dart`
Widget que gerencia a câmera e processamento de imagem.

**Recursos:**
- Inicialização automática da câmera frontal
- Overlay de enquadramento facial (face_overlay.png)
- Processamento de fundo com ML Kit Selfie Segmentation
- Suporte para Web (sem processamento de fundo)
- Tratamento de erros e estados de loading

### 3. `face_overlay.png`
Imagem PNG transparente com guia de posicionamento facial.
- Localização: `assets/images/face_overlay.png`
- Usado como overlay durante a captura

## 🔧 Dependências Adicionadas

```yaml
dependencies:
  camera: ^0.11.0+2
  google_mlkit_selfie_segmentation: ^0.6.0
  google_mlkit_text_recognition: ^0.11.0  # Downgrade para compatibilidade
```

## 🚀 Como Usar

### Uso Básico em Modal

```dart
import 'package:smart_flutter/shared/widgets/custom_image_picker.dart';

void _mostrarModalFoto() {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CustomImagePicker(
          onImageSelected: (path) {
            // Fazer algo com o path da foto
            print('Foto capturada: $path');
            Navigator.of(context).pop();
          },
        ),
      ),
    ),
  );
}
```

### Uso Direto em Página

```dart
CustomImagePicker(
  onImageSelected: (String path) {
    // O path pode ser usado para:
    // 1. Converter para base64
    // 2. Fazer upload para API
    // 3. Salvar localmente
    setState(() {
      _fotoPath = path;
    });
  },
)
```

## 🎨 Fluxo de Uso

1. **Estado Inicial**: Mostra um círculo com ícone de pessoa
2. **Opções**: Usuário pode escolher entre Câmera ou Galeria
3. **Câmera Ativa**: 
   - Círculo expande para 320x320
   - Mostra preview da câmera com overlay facial
   - Botão de captura aparece
4. **Foto Capturada**:
   - Processamento de fundo (mobile)
   - Botões de Refazer ou Confirmar
5. **Confirmação**: Retorna o path da foto via callback

## 🔄 Processamento de Imagem

### Mobile (Android/iOS)
- Usa ML Kit Selfie Segmentation
- Remove fundo automaticamente
- Substitui fundo por preto
- Salva como `_processed.jpg`

### Web
- Não processa fundo
- Retorna imagem original

## ⚙️ Configurações Importantes

### Permissões Necessárias

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>NSCameraUsageDescription</key>
<string>Precisamos acessar sua câmera para capturar fotos faciais</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Precisamos acessar sua galeria para selecionar fotos</string>
```

### Web
- Requer HTTPS em produção
- Permissões de câmera solicitadas pelo navegador

## 🎯 Personalização

### Cores e Estilo

No `custom_image_picker.dart`, você pode personalizar:

```dart
// Cor da borda do círculo
border: Border.all(color: Colors.blueAccent, width: 3),

// Cor do botão de captura
color: Colors.blue,

// Cor do botão de confirmação (marcado)
color: const Color(0xFF684F8E), // Roxo
```

### Tamanho do Círculo

```dart
final double containerSize = _isCameraActive ? 320 : 200;
```

### Qualidade da Imagem

```dart
// Em face_camera_view.dart
ResolutionPreset.high  // Pode ser: low, medium, high, veryHigh, ultraHigh

// Em custom_image_picker.dart (galeria)
imageQuality: 80,  // 0-100
```

## 🐛 Troubleshooting

### Câmera não inicializa
- Verificar permissões
- Em Web, verificar se está usando HTTPS
- Verificar se o dispositivo tem câmera

### Erro de dependência
- Executar `flutter pub get`
- Verificar compatibilidade de versões
- Limpar cache: `flutter clean`

### Imagem não processa fundo
- Verificar se está em mobile (Web não processa)
- Verificar se ML Kit está configurado
- Checar logs para erros de segmentação

## 📱 Integração com API

### Converter para Base64

```dart
import 'dart:io';
import 'dart:convert';

Future<String> imageToBase64(String path) async {
  final bytes = await File(path).readAsBytes();
  return base64Encode(bytes);
}

// Uso
CustomImagePicker(
  onImageSelected: (path) async {
    final base64 = await imageToBase64(path);
    // Enviar para API
    await api.enviarFoto(base64);
  },
)
```

## 📊 Performance

- Inicialização da câmera: ~1-2s
- Captura de foto: Instantânea
- Processamento de fundo: ~2-4s (depende do dispositivo)
- Tamanho médio da imagem: 200-500KB

## 🔐 Segurança

- Fotos são salvas temporariamente no cache do app
- Lembre-se de deletar fotos após upload
- Não armazene fotos sensíveis sem criptografia

## 📝 Notas Adicionais

- O overlay facial é apenas visual, não valida posicionamento
- Para validação facial real, integre com serviços como AWS Rekognition ou Azure Face API
- O processamento de fundo pode falhar em condições de baixa luz
- Considere adicionar feedback visual durante processamento
