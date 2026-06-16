import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Utilitários para processamento de imagens
class ImageUtils {
  /// Limite de tamanho de arquivo: 300KB
  static const int MAX_FILE_SIZE = 300 * 1024; // 307200 bytes

  /// Comprime uma imagem base64 para garantir que tenha no máximo 300KB
  /// Se a imagem for maior, reduz a qualidade através de redimensionamento
  static Future<String> compressImageToMaxSize(String base64Image) async {
    try {
      // Remover prefixo se existir
      String cleanBase64 =
          base64Image.replaceFirst('data:image/png;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpeg;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpg;base64,', '');

      // Decodificar a imagem
      Uint8List imageBytes = base64Decode(cleanBase64);

      // Verificar se já está dentro do limite
      if (imageBytes.length <= MAX_FILE_SIZE) {
        return base64Image; // Retornar original se já estiver ok
      }

      // Se for maior que 300KB, comprimir através de redimensionamento
      final compressedBase64 = await _compressImageByResizing(imageBytes);

      // Verificar novamente o tamanho após compressão
      final compressedBytes = base64Decode(compressedBase64);
      if (compressedBytes.length <= MAX_FILE_SIZE) {
        return 'data:image/jpeg;base64,$compressedBase64';
      }

      // Se ainda for grande demais, tentar compressão mais agressiva
      final aggressivelyCompressed =
          await _compressImageAggressively(imageBytes);
      return 'data:image/jpeg;base64,$aggressivelyCompressed';
    } catch (e) {
      print('Erro ao comprimir imagem: $e');
      // Em caso de erro, retornar a imagem original
      return base64Image;
    }
  }

  /// Comprime imagem através de redimensionamento
  static Future<String> _compressImageByResizing(Uint8List imageBytes) async {
    try {
      // Decodificar imagem
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // Calcular novas dimensões mantendo proporção
      // Reduzir para 75% do tamanho original inicialmente
      final int newWidth = (originalImage.width * 0.75).round();
      final int newHeight = (originalImage.height * 0.75).round();

      // Criar recorder para desenhar a imagem redimensionada
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Desenhar imagem redimensionada
      canvas.drawImageRect(
        originalImage,
        ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
            originalImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        ui.Paint(),
      );

      // Finalizar e obter imagem
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(newWidth, newHeight);

      // Converter para PNG (Flutter só suporta PNG nativamente)
      final ByteData? byteData =
          await resizedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        return base64Encode(byteData.buffer.asUint8List());
      }

      throw Exception('Falha ao converter imagem redimensionada');
    } catch (e) {
      print('Erro ao redimensionar imagem: $e');
      rethrow;
    }
  }

  /// Compressão mais agressiva para casos extremos
  static Future<String> _compressImageAggressively(Uint8List imageBytes) async {
    try {
      // Decodificar imagem
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      // Reduzir drasticamente para 50% do tamanho
      final int newWidth = (originalImage.width * 0.5).round();
      final int newHeight = (originalImage.height * 0.5).round();

      // Criar recorder
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Desenhar imagem muito menor
      canvas.drawImageRect(
        originalImage,
        ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
            originalImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        ui.Paint(),
      );

      // Finalizar
      final ui.Picture picture = recorder.endRecording();
      final ui.Image resizedImage = await picture.toImage(newWidth, newHeight);

      // Converter para PNG (único formato suportado pelo Flutter)
      final ByteData? byteData =
          await resizedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final compressed = base64Encode(byteData.buffer.asUint8List());

        // Verificar se ainda está grande demais
        final compressedBytes = base64Decode(compressed);
        if (compressedBytes.length > MAX_FILE_SIZE) {
          // Se ainda for grande, reduzir ainda mais o tamanho
          final int smallerWidth = (newWidth * 0.7).round();
          final int smallerHeight = (newHeight * 0.7).round();

          final ui.PictureRecorder smallRecorder = ui.PictureRecorder();
          final ui.Canvas smallCanvas = ui.Canvas(smallRecorder);

          smallCanvas.drawImageRect(
            originalImage,
            ui.Rect.fromLTWH(0, 0, originalImage.width.toDouble(),
                originalImage.height.toDouble()),
            ui.Rect.fromLTWH(
                0, 0, smallerWidth.toDouble(), smallerHeight.toDouble()),
            ui.Paint(),
          );

          final ui.Picture smallPicture = smallRecorder.endRecording();
          final ui.Image smallerImage =
              await smallPicture.toImage(smallerWidth, smallerHeight);

          final ByteData? finalData =
              await smallerImage.toByteData(format: ui.ImageByteFormat.png);
          if (finalData != null) {
            return base64Encode(finalData.buffer.asUint8List());
          }
        }

        return compressed;
      }

      throw Exception('Falha na compressão agressiva');
    } catch (e) {
      print('Erro na compressão agressiva: $e');
      rethrow;
    }
  }

  /// Rotaciona uma imagem base64 em incrementos de 90 graus
  /// quarterTurns: número de quartos de volta (1 = 90 graus, -1 = -90 graus, etc)
  static Future<String> rotateImage(
      String base64Image, int quarterTurns) async {
    try {
      if (quarterTurns % 4 == 0) return base64Image;

      // Remover prefixo se existir
      String cleanBase64 =
          base64Image.replaceFirst('data:image/png;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpeg;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpg;base64,', '');

      // Decodificar a imagem
      Uint8List imageBytes = base64Decode(cleanBase64);

      // Decodificar imagem para objeto ui.Image
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      final double width = originalImage.width.toDouble();
      final double height = originalImage.height.toDouble();

      // Calcular novas dimensões (swap se rotação for 90 ou 270)
      final bool swapDimensions = quarterTurns % 2 != 0;
      final double newWidth = swapDimensions ? height : width;
      final double newHeight = swapDimensions ? width : height;

      // Criar recorder
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);

      // Mudar ponto de origem para o centro da nova imagem
      canvas.translate(newWidth / 2, newHeight / 2);

      // Rotacionar
      canvas.rotate(quarterTurns * pi / 2);

      // Voltar origem para desenhar a imagem centralizada
      canvas.translate(-width / 2, -height / 2);

      // Desenhar
      canvas.drawImage(originalImage, ui.Offset.zero, ui.Paint());

      // Finalizar
      final ui.Picture picture = recorder.endRecording();
      final ui.Image rotatedImage =
          await picture.toImage(newWidth.toInt(), newHeight.toInt());

      // Converter e recodificar
      final ByteData? byteData =
          await rotatedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final resultBytes = byteData.buffer.asUint8List();
        // Manter o formato data URL correto se possível, mas aqui estamos retornando só o base64
        // ou com prefixo dependendo de como a entrada veio?
        // A entrada original poderia ter prefixo. Vamos assumir PNG para o output.
        return 'data:image/png;base64,${base64Encode(resultBytes)}';
      }

      return base64Image;
    } catch (e) {
      print('Erro ao rotacionar imagem: $e');
      return base64Image;
    }
  }

  /// Aplica recorte circular perfeito com fundo preto
  /// Implementa o algoritmo exato: canvas quadrado, fundo preto, clip circular, cópia centralizada
  static Future<String> applyFaceMask(String base64Image) async {
    try {
      print('🎭 Iniciando recorte circular com fundo preto...');

      // Remover prefixo se existir
      String cleanBase64 =
          base64Image.replaceFirst('data:image/png;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpeg;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpg;base64,', '');

      // Decodificar a imagem
      Uint8List imageBytes = base64Decode(cleanBase64);

      // Decodificar imagem para obter dimensões
      final ui.Codec codec = await ui.instantiateImageCodec(imageBytes);
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image originalImage = frameInfo.image;

      final int width = originalImage.width;
      final int height = originalImage.height;

      print('🖼️ Imagem carregada: ${width}x$height');

      // Aplicar recorte circular perfeito
      final ui.Image processedImage = await _applyCircularCrop(originalImage);

      // Converter para data URL
      final ByteData? byteData =
          await processedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final resultBytes = byteData.buffer.asUint8List();
        final result = 'data:image/png;base64,${base64Encode(resultBytes)}';

        return result;
      }

      throw Exception('Falha ao processar imagem com IA');
    } catch (e) {
      print('❌ Erro na IA de máscara facial: $e');
      // Fallback: retornar imagem original se der erro
      return base64Image;
    }
  }

  /// Recorte circular perfeito - APENAS conteúdo dentro do círculo de enquadramento
  /// Remove tudo fora do círculo e substitui por fundo preto
  static Future<ui.Image> _applyCircularCrop(ui.Image originalImage) async {
    final int width = originalImage.width;
    final int height = originalImage.height;

    // Centro e raio do círculo EXATO do enquadramento visual (70%)
    // Garantir que apenas o conteúdo DENTRO do círculo seja mantido
    final double minDimension = (width < height ? width : height).toDouble();
    final double radius = minDimension *
        0.65; // 65% da dimensão menor - GARANTIR apenas conteúdo do círculo
    final double centerX = width / 2;
    final double centerY = height / 2;

    print(
        '🎯 Recorte circular EXATO - Centro: ($centerX, $centerY), Raio: $radius');

    // Tamanho fixo quadrado para consistência (512x512)
    final int outputSize = 512;

    // Criar canvas para o resultado final
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    // Fundo preto puro em toda a imagem
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      ui.Paint()..color = ui.Color(0xFF000000),
    );

    // Aplicar máscara circular EXATA no centro do canvas (65% da área útil)
    canvas.save();
    final double canvasRadius =
        outputSize * 0.325; // 65% de 50% (metade do canvas) = 32.5%
    final ui.Path circlePath = ui.Path()
      ..addOval(ui.Rect.fromCircle(
          center: ui.Offset(outputSize / 2, outputSize / 2),
          radius: canvasRadius));
    canvas.clipPath(circlePath);

    print(
        '🎨 Canvas final: ${outputSize}x$outputSize, Raio do círculo: $canvasRadius');

    // Copiar apenas a área do rosto da imagem original para o centro do canvas
    // A área fonte é o círculo central da imagem original
    final double sourceX = centerX - radius;
    final double sourceY = centerY - radius;
    final double sourceWidth = radius * 2;
    final double sourceHeight = radius * 2;

    // Destino é o canvas inteiro (que será clipado pelo círculo)
    canvas.drawImageRect(
      originalImage,
      ui.Rect.fromLTWH(sourceX, sourceY, sourceWidth, sourceHeight),
      ui.Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      ui.Paint(),
    );

    canvas.restore();

    // Finalizar
    final ui.Picture picture = recorder.endRecording();
    final ui.Image resultImage = await picture.toImage(outputSize, outputSize);

    print(
        '✅ Recorte circular concluído - Tamanho final: ${outputSize}x$outputSize');
    return resultImage;
  }

  /// Calcula o tamanho aproximado da imagem em KB
  static double getImageSizeInKB(String base64Image) {
    try {
      String cleanBase64 =
          base64Image.replaceFirst('data:image/png;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpeg;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpg;base64,', '');
      final bytes = base64Decode(cleanBase64);
      return bytes.length / 1024;
    } catch (e) {
      return 0.0;
    }
  }

  /// Verifica se a imagem está dentro do limite de tamanho
  static bool isImageWithinSizeLimit(String base64Image) {
    try {
      String cleanBase64 =
          base64Image.replaceFirst('data:image/png;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpeg;base64,', '');
      cleanBase64 = cleanBase64.replaceFirst('data:image/jpg;base64,', '');
      final bytes = base64Decode(cleanBase64);
      return bytes.length <= MAX_FILE_SIZE;
    } catch (e) {
      return false;
    }
  }
}
