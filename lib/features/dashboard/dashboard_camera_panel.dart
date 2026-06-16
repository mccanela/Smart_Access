import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';
import '../../core/services/image_utils.dart';
import 'dashboard.dart' as dashboard;

// Tipos de enquadramento para câmera
enum CameraFrameType {
  face, // Enquadramento oval para rosto
  document, // Enquadramento retangular para documento
  package, // Enquadramento quadrado para encomenda
  none, // Sem enquadramento
}

// Funções auxiliares para cores adaptáveis ao tema (Copiadas para evitar dependência circular complexa)
bool _isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color _getBackgroundColor(BuildContext context) {
  return _isDarkMode(context) ? Colors.black : Colors.white;
}

Color _getTextColor(BuildContext context) {
  return _isDarkMode(context) ? Colors.white : Colors.black;
}

Color _getSecondaryTextColor(BuildContext context) {
  return _isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF6B7280);
}

Color _getBorderColor(BuildContext context) {
  return _isDarkMode(context) ? Colors.grey[600]! : Colors.grey.shade300;
}

// CustomPainter para desenhar enquadramentos na câmera com design elegante
class FramePainter extends CustomPainter {
  final CameraFrameType frameType;

  FramePainter({required this.frameType});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    switch (frameType) {
      case CameraFrameType.face:
        _drawFaceFrame(canvas, size, center);
        break;
      case CameraFrameType.document:
        _drawDocumentFrame(canvas, size, center);
        break;
      case CameraFrameType.package:
        _drawPackageFrame(canvas, size, center);
        break;
      case CameraFrameType.none:
      default:
        // Sem enquadramento
        break;
    }
  }

  void _drawFaceFrame(Canvas canvas, Size size, Offset center) {
    // Fundo escuro para destacar a área do rosto
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Círculo central de 70% da largura mínima para enquadramento do rosto
    final double minScreenSide =
        size.width < size.height ? size.width : size.height;
    final double radius = minScreenSide * 0.35; // 70% / 2 = 35% do raio

    // Limpar a área do círculo (BlendMode.clear remove os pixels)
    final clearPaint = Paint()..blendMode = BlendMode.clear;
    canvas.drawCircle(center, radius, clearPaint);

    // Borda do círculo em roxo (como no exemplo)
    final borderPaint = Paint()
      ..color = const Color(0xFF6D5DFB) // Roxo como no exemplo
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    canvas.drawCircle(center, radius, borderPaint);
  }

  void _drawDocumentFrame(Canvas canvas, Size size, Offset center) {
    // Fundo semi-transparente com gradiente
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.7),
          Colors.black.withValues(alpha: 0.5),
          Colors.black.withValues(alpha: 0.7),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Área de destaque para o documento com proporção realística (3:2 ou 4:3)
    final docWidth = size.width * 0.8;
    final docHeight = docWidth * 0.625; // Proporção 5:8 para documento

    final docRect = Rect.fromCenter(
      center: center,
      width: docWidth,
      height: docHeight,
    );

    // Sombra interna para profundidade
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final shadowRect = Rect.fromCenter(
      center: center + const Offset(4, 4),
      width: docWidth + 8,
      height: docHeight + 8,
    );
    canvas.drawRRect(
        RRect.fromRectAndRadius(shadowRect, const Radius.circular(16)),
        shadowPaint);

    // Área principal do documento com gradiente sutil
    final docPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.08),
          Colors.white.withValues(alpha: 0.12),
        ],
      ).createShader(docRect);

    canvas.drawRRect(
        RRect.fromRectAndRadius(docRect, const Radius.circular(16)), docPaint);

    // Borda principal com brilho
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 1.5);

    canvas.drawRRect(
        RRect.fromRectAndRadius(docRect, const Radius.circular(16)),
        borderPaint);

    // Borda interna mais fina
    final innerBorderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(
        RRect.fromRectAndRadius(docRect, const Radius.circular(16)),
        innerBorderPaint);

    // Marcadores de canto aprimorados (tipo scanner)
    _drawDocumentCornerMarkers(canvas, docRect, 24.0, Colors.cyanAccent, 3.0);

    // Linha central de orientação
    final guidePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(center.dx, docRect.top + 20),
      Offset(center.dx, docRect.bottom - 20),
      guidePaint,
    );

    // Pontos de referência nos cantos
    _drawReferencePoints(canvas, docRect, Colors.white.withValues(alpha: 0.8));
  }

  void _drawPackageFrame(Canvas canvas, Size size, Offset center) {
    // Fundo com gradiente dinâmico para encomendas
    final backgroundPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.black.withValues(alpha: 0.8),
          Colors.black.withValues(alpha: 0.6),
          Colors.black.withValues(alpha: 0.4),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Área quadrada otimizada para encomendas
    final squareSize = size.width * 0.75;
    final packageRect = Rect.fromCenter(
      center: center,
      width: squareSize,
      height: squareSize,
    );

    // Efeito 3D com sombra projetada
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;

    // Sombra múltipla para efeito 3D
    for (int i = 0; i < 3; i++) {
      final shadowOffset = Offset(2.0 + i * 2, 2.0 + i * 2);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              packageRect.shift(shadowOffset), const Radius.circular(20)),
          shadowPaint);
    }

    // Área principal da caixa
    final boxPaint = Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
        RRect.fromRectAndRadius(packageRect, const Radius.circular(20)),
        boxPaint);

    // Marcadores de canto estilo "caixa" (L shapes)
    _drawPackageCornerMarkers(
        canvas, packageRect, 40.0, const Color(0xFFFFB74D), 4.0);

    // Grade interna para orientação
    _drawPackageGrid(canvas, packageRect, Colors.white.withValues(alpha: 0.2));

    // Ícone central estilizado
    _drawPackageIcon(canvas, center, squareSize * 0.2);

    // Texto indicativo (opcional)
    _drawPackageInstructions(canvas, packageRect, Colors.white);
  }

  void _drawDocumentCornerMarkers(
      Canvas canvas, Rect rect, double size, Color color, double strokeWidth) {
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final halfSize = size / 2;

    // Topo esquerdo
    canvas.drawLine(
      Offset(rect.left - 4, rect.top),
      Offset(rect.left + halfSize, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top - 4),
      Offset(rect.left, rect.top + halfSize),
      cornerPaint,
    );

    // Topo direito
    canvas.drawLine(
      Offset(rect.right + 4, rect.top),
      Offset(rect.right - halfSize, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top - 4),
      Offset(rect.right, rect.top + halfSize),
      cornerPaint,
    );

    // Baixo esquerdo
    canvas.drawLine(
      Offset(rect.left - 4, rect.bottom),
      Offset(rect.left + halfSize, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom + 4),
      Offset(rect.left, rect.bottom - halfSize),
      cornerPaint,
    );

    // Baixo direito
    canvas.drawLine(
      Offset(rect.right + 4, rect.bottom),
      Offset(rect.right - halfSize, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom + 4),
      Offset(rect.right, rect.bottom - halfSize),
      cornerPaint,
    );
  }

  // Pontos de referência nos cantos do documento
  void _drawReferencePoints(Canvas canvas, Rect rect, Color color) {
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final pointRadius = 3.0;

    // Pontos nos cantos
    canvas.drawCircle(Offset(rect.left, rect.top), pointRadius, pointPaint);
    canvas.drawCircle(Offset(rect.right, rect.top), pointRadius, pointPaint);
    canvas.drawCircle(Offset(rect.left, rect.bottom), pointRadius, pointPaint);
    canvas.drawCircle(Offset(rect.right, rect.bottom), pointRadius, pointPaint);
  }

  // Marcadores de canto estilo "caixa" para encomendas
  void _drawPackageCornerMarkers(
      Canvas canvas, Rect rect, double size, Color color, double strokeWidth) {
    final cornerPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final halfSize = size / 2;

    // Topo esquerdo - quadrado
    canvas.drawLine(Offset(rect.left - halfSize, rect.top),
        Offset(rect.left + halfSize, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top - halfSize),
        Offset(rect.left, rect.top + halfSize), cornerPaint);

    // Topo direito - quadrado
    canvas.drawLine(Offset(rect.right - halfSize, rect.top),
        Offset(rect.right + halfSize, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top - halfSize),
        Offset(rect.right, rect.top + halfSize), cornerPaint);

    // Fundo esquerdo - quadrado
    canvas.drawLine(Offset(rect.left - halfSize, rect.bottom),
        Offset(rect.left + halfSize, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom - halfSize),
        Offset(rect.left, rect.bottom + halfSize), cornerPaint);

    // Fundo direito - quadrado
    canvas.drawLine(Offset(rect.right - halfSize, rect.bottom),
        Offset(rect.right + halfSize, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom - halfSize),
        Offset(rect.right, rect.bottom + halfSize), cornerPaint);
  }

  // Grade interna para orientação de posicionamento da encomenda
  void _drawPackageGrid(Canvas canvas, Rect rect, Color color) {
    final gridPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Linhas horizontais
    final horizontalSpacing = rect.height / 4;
    for (int i = 1; i < 4; i++) {
      final y = rect.top + (horizontalSpacing * i);
      canvas.drawLine(
          Offset(rect.left + 20, y), Offset(rect.right - 20, y), gridPaint);
    }

    // Linhas verticais
    final verticalSpacing = rect.width / 4;
    for (int i = 1; i < 4; i++) {
      final x = rect.left + (verticalSpacing * i);
      canvas.drawLine(
          Offset(x, rect.top + 20), Offset(x, rect.bottom - 20), gridPaint);
    }
  }

  // Ícone central de encomenda
  void _drawPackageIcon(Canvas canvas, Offset center, double size) {
    final iconPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Desenha uma caixa simplificada
    final boxSize = size * 0.8;
    final boxRect =
        Rect.fromCenter(center: center, width: boxSize, height: boxSize * 0.7);

    // Contorno da caixa
    canvas.drawRect(boxRect, iconPaint);

    // Linha diagonal para indicar profundidade
    canvas.drawLine(
      Offset(boxRect.left, boxRect.top),
      Offset(boxRect.right, boxRect.bottom),
      iconPaint,
    );
  }

  // Texto de orientação para encomendas
  void _drawPackageInstructions(Canvas canvas, Rect rect, Color color) {
    // Implementação vazia conforme original
  }

  // Mantido para compatibilidade se necessário
  void _drawCornerMarkers(
      Canvas canvas, Rect rect, double size, Color color, double strokeWidth) {
    _drawDocumentCornerMarkers(canvas, rect, size, color, strokeWidth);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// Widget de câmera usado nos painéis laterais
class CameraSidePanelWidget extends StatefulWidget {
  final bool isFrontal;
  final String? deviceId;
  final CameraFrameType frameType;
  final Function(String)? onPhotoTaken;
  final VoidCallback? onCancel;

  const CameraSidePanelWidget({
    super.key,
    this.isFrontal = false,
    this.deviceId,
    this.frameType = CameraFrameType.none,
    this.onPhotoTaken,
    this.onCancel,
  });

  @override
  State<CameraSidePanelWidget> createState() => _CameraSidePanelWidgetState();
}

class _CameraSidePanelWidgetState extends State<CameraSidePanelWidget> {
  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  html.MediaStream? _stream;
  bool _canCapture = false;
  bool _mounted = true;
  html.DivElement? _root;
  String? _currentViewType;
  List<html.MediaDeviceInfo> _availableCameras = [];
  String? _selectedDeviceId;
  bool _showCameraSelector = false;
  bool _hasCameraError = false;

  // Controles de zoom
  double _zoomLevel = 0.8; // Nível de zoom atual (0.8 = 80%)
  final double _minZoom = 0.5; // 50% mínimo
  final double _maxZoom = 3.0; // 300% máximo
  final double _zoomStep = 0.1; // Incremento de 10%

  @override
  void initState() {
    super.initState();
    print(
        '📸 CameraSidePanelWidget initState - frameType: ${widget.frameType}, isFrontal: ${widget.isFrontal}');

    // Reset state for fresh start
    _canCapture = false;
    _video = null;
    _canvas = null;
    _stream = null;
    _root = null;
    _currentViewType = null;
    _hasCameraError = false;
    _selectedDeviceId = null;
    _showCameraSelector = false;
    _availableCameras = [];

    // Inicializar câmera após o widget estar completamente montado e renderizado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Aguardar um pouco mais para garantir que o overlay foi inserido e o widget renderizado
      Future.delayed(const Duration(milliseconds: 300), () async {
        if (!mounted) {
          print('⚠️ Widget não está montado, cancelando inicialização');
          return;
        }

        print('📸 Widget montado, iniciando carregamento de câmera...');
        await _solicitarPermissoesECarregarCamera();
      });
    });
  }

  Future<void> _solicitarPermissoesECarregarCamera() async {
    try {
      print('📸 Iniciando carregamento de câmera...');

      print('📸 Solicitando permissões de câmera primeiro...');
      bool permissoesConcedidas = false;

      try {
        final basicConstraints = <String, dynamic>{
          'audio': false,
          'video': <String, dynamic>{
            if (widget.isFrontal)
              'facingMode': 'user'
            else
              'facingMode': 'environment',
          },
        };

        final tempStream = await html.window.navigator.mediaDevices!
            .getUserMedia(basicConstraints);

        tempStream.getTracks().forEach((track) => track.stop());
        permissoesConcedidas = true;
        print('✅ Permissões de câmera concedidas');

        await Future.delayed(const Duration(milliseconds: 200));
      } catch (permError) {
        print('⚠️ Erro ao solicitar permissões: $permError');
        permissoesConcedidas = false;
      }

      print('📸 Enumerando câmeras disponíveis...');
      await _enumerarCameras();

      if (_availableCameras.isNotEmpty) {
        if (_selectedDeviceId == null && _availableCameras.isNotEmpty) {
          _selectedDeviceId = _availableCameras.first.deviceId;
        }
        print('📸 Inicializando câmera com deviceId: $_selectedDeviceId');
      } else {
        print('📸 Nenhuma câmera enumerada, usando facingMode');
      }

      await _inicializarCamera();

      if (mounted && _availableCameras.length > 1 && _canCapture) {
        setState(() {
          _showCameraSelector = true;
        });
      }

      if (!_canCapture && _selectedDeviceId != null) {
        print('📸 Tentando novamente sem deviceId específico...');
        _selectedDeviceId = null;
        await _inicializarCamera();
      }
    } catch (e) {
      print('❌ Erro ao carregar câmera: $e');
      if (mounted) {
        setState(() {
          _hasCameraError = true;
          _canCapture = false;
        });
      }
    }
  }

  Future<void> _enumerarCameras() async {
    try {
      print('📸 Enumerando câmeras disponíveis...');
      final devices =
          await html.window.navigator.mediaDevices!.enumerateDevices();
      _availableCameras = devices
          .where((device) => device.kind == 'videoinput')
          .cast<html.MediaDeviceInfo>()
          .toList();

      print('📸 ${_availableCameras.length} câmera(s) encontrada(s)');
      for (var camera in _availableCameras) {
        print('  - ${camera.label} (${camera.deviceId})');
      }

      _availableCameras = _availableCameras
          .where((camera) =>
              camera.deviceId != null && camera.deviceId!.isNotEmpty)
          .toList();

      if (_availableCameras.isEmpty) {
        print('⚠️ Nenhuma câmera com deviceId válido encontrada');
      }
    } catch (e) {
      print('❌ Erro ao enumerar câmeras: $e');
    }
  }

  void _selecionarCamera(String deviceId) {
    setState(() {
      _selectedDeviceId = deviceId;
      _showCameraSelector = false;
    });
    _inicializarCamera();
  }

  void _registerSimpleViewFactory() {
    _currentViewType ??=
        'camera-side-view-${DateTime.now().millisecondsSinceEpoch}';

    _video ??= html.VideoElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..autoplay = true
      ..muted = true
      ..controls = false
      ..setAttribute('playsinline', 'true')
      ..setAttribute('autoplay', 'true')
      ..setAttribute('muted', 'true');

    _canvas ??= html.CanvasElement()..style.display = 'none';

    if (_root == null) {
      _root = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center';

      _root!.append(_video!);
      _root!.append(_canvas!);
    }

    ui_web.platformViewRegistry.registerViewFactory(_currentViewType!,
        (int viewId) {
      print('📹 Factory chamada para criar view - viewId: $viewId');
      return _root!;
    });

    print('✅ Factory registrada - viewType: $_currentViewType');
  }

  Future<void> _inicializarCamera() async {
    print(
        '📸 _inicializarCamera chamada - isFrontal: ${widget.isFrontal}, frameType: ${widget.frameType}');

    try {
      _pararCamera();
      await Future.delayed(const Duration(milliseconds: 200));

      _registerSimpleViewFactory();
      await Future.delayed(const Duration(milliseconds: 300));

      int attempts = 0;
      while (_video == null && attempts < 15) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }

      if (_video == null) {
        print(
            '❌ Vídeo não está disponível após aguardar - forçando criação...');
        if (_video == null) {
          _video = html.VideoElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.objectFit = 'cover'
            ..autoplay = true
            ..muted = true
            ..controls = false
            ..setAttribute('playsinline', 'true')
            ..setAttribute('autoplay', 'true')
            ..setAttribute('muted', 'true');

          _root ??= html.DivElement()
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.backgroundColor = '#000000'
            ..style.display = 'flex'
            ..style.alignItems = 'center'
            ..style.justifyContent = 'center';

          _canvas ??= html.CanvasElement()..style.display = 'none';

          _root!.append(_video!);
          _root!.append(_canvas!);
          print('✅ Vídeo criado manualmente');
        }
      }

      if (_video == null) {
        print('❌ Não foi possível criar vídeo');
        if (mounted) {
          setState(() {
            _hasCameraError = true;
            _canCapture = false;
          });
        }
        return;
      }

      final videoConstraints = <String, dynamic>{
        'width': {'ideal': 1280, 'max': 1920},
        'height': {'ideal': 720, 'max': 1080},
        'aspectRatio': {'ideal': 16 / 9},
      };

      final deviceIdToUse = _selectedDeviceId ?? widget.deviceId;
      if (deviceIdToUse != null &&
          deviceIdToUse.isNotEmpty &&
          deviceIdToUse != 'default') {
        videoConstraints['deviceId'] = {'exact': deviceIdToUse};
        print('📸 Usando deviceId específico: $deviceIdToUse');
      } else {
        if (widget.isFrontal) {
          videoConstraints['facingMode'] = 'user';
          print('📸 Configurando câmera frontal (user)');
        } else {
          videoConstraints['facingMode'] = 'environment';
          print('📸 Configurando câmera traseira (environment)');
        }
      }

      final Map<String, dynamic> constraints = {
        'audio': false,
        'video': videoConstraints,
      };

      try {
        print('📸 Tentativa 1 - getUserMedia com constraints completas');
        _stream =
            await html.window.navigator.mediaDevices!.getUserMedia(constraints);
        print('📸 Tentativa 1 - sucesso!');
      } catch (e) {
        print('❌ Tentativa 1 falhou: $e');
        final fallbackConstraints = <String, dynamic>{
          'audio': false,
          'video': <String, dynamic>{
            if (widget.isFrontal)
              'facingMode': 'user'
            else
              'facingMode': 'environment',
            'width': {'ideal': 640},
            'height': {'ideal': 480},
          },
        };

        try {
          print('📸 Tentativa 2 - fallback constraints');
          _stream = await html.window.navigator.mediaDevices!
              .getUserMedia(fallbackConstraints);
          print('📸 Tentativa 2 - sucesso!');
        } catch (fallbackError) {
          print('❌ Tentativa 2 falhou: $fallbackError');
          final minimalConstraints = <String, dynamic>{
            'audio': false,
            'video': true,
          };

          try {
            print('📸 Tentativa 3 - constraints mínimas');
            _stream = await html.window.navigator.mediaDevices!
                .getUserMedia(minimalConstraints);
            print('📸 Tentativa 3 - sucesso!');
          } catch (minimalError) {
            print('❌ Todas as tentativas falharam: $minimalError');
            if (mounted) {
              setState(() {
                _hasCameraError = true;
                _canCapture = false;
              });
            }
            return;
          }
        }
      }

      if (_video == null) {
        print('❌ Vídeo não está disponível para atribuir stream');
        if (mounted) {
          setState(() {
            _hasCameraError = true;
            _canCapture = false;
          });
        }
        _stream?.getTracks().forEach((track) => track.stop());
        _stream = null;
        return;
      }

      _video!.srcObject = _stream;
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        await _video!.play();
        print('✅ Vídeo iniciado com sucesso');
      } catch (playError) {
        print('⚠️ Erro ao iniciar vídeo: $playError, tentando novamente...');
        await Future.delayed(const Duration(milliseconds: 200));
        try {
          await _video!.play();
          print('✅ Vídeo iniciado na segunda tentativa');
        } catch (retryError) {
          print('❌ Erro ao iniciar vídeo na segunda tentativa: $retryError');
          if (mounted) {
            setState(() {
              _hasCameraError = true;
              _canCapture = false;
            });
          }
          return;
        }
      }

      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        setState(() {
          _canCapture = true;
          _hasCameraError = false;
        });
        _aplicarZoom();
      }

      _video!.onCanPlay.listen((_) {
        if (mounted) {
          setState(() {
            _canCapture = true;
            _hasCameraError = false;
          });
          _aplicarZoom();
        }
      });
      _video!.onLoadedMetadata.listen((_) {
        if (mounted && (_video!.videoWidth > 0 && _video!.videoHeight > 0)) {
          setState(() {
            _canCapture = true;
            _hasCameraError = false;
          });
        }
      });

      Future.delayed(const Duration(seconds: 2), () async {
        if (!mounted) return;
        if (_video != null &&
            (_video!.videoWidth == 0 || _video!.videoHeight == 0)) {
          try {
            await _video!.play();
            setState(() {});
          } catch (_) {}
        }
      });
    } catch (e) {
      print('Erro ao inicializar câmera: $e');
      if (mounted) {
        setState(() {
          _canCapture = false;
          _hasCameraError = true;
        });
      }
    }
  }

  Future<void> _capture() async {
    if (!_canCapture || _video == null || _canvas == null) return;

    try {
      final int videoWidth = _video!.videoWidth;
      final int videoHeight = _video!.videoHeight;

      print('📹 Resolução real do vídeo: ${videoWidth}x$videoHeight');

      _canvas!.width = videoWidth;
      _canvas!.height = videoHeight;

      final ctx = _canvas!.getContext('2d') as html.CanvasRenderingContext2D;
      ctx.drawImage(_video!, 0, 0);

      final dataUrl = _canvas!.toDataUrl('image/png');

      String processedDataUrl = dataUrl;
      if (widget.frameType == CameraFrameType.face) {
        print('🎭 Aplicando máscara facial para remover fundo...');
        processedDataUrl = await ImageUtils.applyFaceMask(dataUrl);

        final processedSizeKB = ImageUtils.getImageSizeInKB(processedDataUrl);
        if (processedSizeKB > 400) {
          processedDataUrl =
              await ImageUtils.compressImageToMaxSize(processedDataUrl);
        }
      } else {
        processedDataUrl =
            await ImageUtils.compressImageToMaxSize(processedDataUrl);
      }

      widget.onPhotoTaken?.call(processedDataUrl);

      if (dashboard.restaurarPainelAnteriorGlobal != null) {
        dashboard.restaurarPainelAnteriorGlobal!();
      } else {
        dashboard.fecharPainelLateralGlobal();
      }
    } catch (e) {
      print('Erro ao capturar foto: $e');
    }
  }

  void _cancel() {
    if (!mounted) return;
    _pararCamera();
    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      dashboard.fecharPainelLateralGlobal();
    }
  }

  void _zoomIn() {
    setState(() {
      _zoomLevel = (_zoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
      _aplicarZoom();
    });
  }

  void _zoomOut() {
    setState(() {
      _zoomLevel = (_zoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
      _aplicarZoom();
    });
  }

  void _aplicarZoom() {
    if (_video != null) {
      _video!.style.transform = 'scale($_zoomLevel)';
      _video!.style.transformOrigin = 'center center';
      print('🔍 Zoom aplicado: ${_zoomLevel}x');
    }
  }

  @override
  void dispose() {
    _mounted = false;
    _pararCamera();
    super.dispose();
  }

  void _pararCamera() {
    print('🛑 Parando câmera e liberando recursos...');

    try {
      if (_stream != null) {
        _stream!.getTracks().forEach((track) {
          try {
            track.stop();
          } catch (e) {
            print('⚠️ Erro ao parar track: $e');
          }
        });
        _stream = null;
      }

      if (_video != null) {
        try {
          _video!.srcObject = null;
          _video!.pause();
          _video = null;
        } catch (e) {
          print('⚠️ Erro ao limpar vídeo: $e');
        }
      }

      _canvas = null;
      _root = null;
      _canCapture = false;
    } catch (e) {
      print('❌ Erro ao parar câmera: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _isDarkMode(context);

    String getTitle() {
      switch (widget.frameType) {
        case CameraFrameType.face:
          return 'Tirar Foto do Rosto';
        case CameraFrameType.document:
          return 'Tirar Foto do Documento';
        case CameraFrameType.package:
          return 'Tirar Foto da Encomenda';
        case CameraFrameType.none:
        default:
          return 'Tirar Foto';
      }
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF684F8E),
                const Color(0xFF8B5CF6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          constraints: const BoxConstraints(
            minHeight: 70,
          ),
          child: Row(
            children: [
              Icon(
                _getIconForFrameType(),
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  getTitle(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: _cancel,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Fechar',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                  hoverColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            child: _showCameraSelector
                ? _buildCameraSelector()
                : Stack(
                    children: [
                      if (_currentViewType != null)
                        SizedBox(
                          width: double.infinity,
                          height: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            child: SizedBox(
                              width: 640.0,
                              height: 480.0,
                              child:
                                  HtmlElementView(viewType: _currentViewType!),
                            ),
                          ),
                        ),
                      if (_currentViewType == null ||
                          (!_canCapture && !_hasCameraError))
                        Positioned.fill(
                          child: Container(
                            color: Colors.black,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: _hasCameraError
                                          ? Colors.red.withValues(alpha: 0.1)
                                          : Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      _hasCameraError
                                          ? Icons.error
                                          : Icons.camera_alt,
                                      color: _hasCameraError
                                          ? Colors.red
                                          : Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _hasCameraError
                                        ? 'Erro ao acessar câmera'
                                        : 'Iniciando câmera...',
                                    style: TextStyle(
                                      color: _hasCameraError
                                          ? Colors.red
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_hasCameraError) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Verifique se a câmera está permitida',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 12),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _hasCameraError = false;
                                          _canCapture = false;
                                        });
                                        _inicializarCamera();
                                      },
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Tentar novamente'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: _getTextColor(context),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 8),
                                        textStyle:
                                            const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  if (!_hasCameraError && !_canCapture) ...[
                                    const SizedBox(height: 8),
                                    const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (widget.frameType != CameraFrameType.none &&
                          _canCapture)
                        Positioned.fill(
                          child: _buildFrameOverlay(),
                        ),
                      if (_canCapture)
                        Positioned(
                          bottom: 20,
                          left: 20,
                          right: 20,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _getInstructionsForFrameType(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      if (_availableCameras.length > 1 && _canCapture)
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: IconButton(
                              onPressed: () {
                                setState(() {
                                  _showCameraSelector = true;
                                });
                              },
                              icon: const Icon(
                                Icons.cameraswitch,
                                color: Colors.white,
                              ),
                              tooltip: 'Trocar câmera',
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2937) : Colors.white,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _zoomLevel > _minZoom
                          ? const Color(0xFF1FA463)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _zoomOut,
                      icon: const Icon(Icons.remove,
                          size: 24, color: Colors.white),
                      tooltip: 'Diminuir zoom',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${(_zoomLevel * 100).toInt()}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getTextColor(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _zoomLevel < _maxZoom
                          ? const Color(0xFF1FA463)
                          : Colors.grey[300],
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _zoomIn,
                      icon:
                          const Icon(Icons.add, size: 24, color: Colors.white),
                      tooltip: 'Aumentar zoom',
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _cancel,
                      icon: const Icon(Icons.close, size: 20),
                      label: const Text('Cancelar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _canCapture ? _capture : null,
                      icon: const Icon(Icons.camera_alt, size: 20),
                      label: const Text('Capturar',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1FA463),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 14, horizontal: 20),
                        elevation: 2,
                        shadowColor:
                            const Color(0xFF1FA463).withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getIconForFrameType() {
    switch (widget.frameType) {
      case CameraFrameType.face:
        return Icons.person;
      case CameraFrameType.document:
        return Icons.description;
      case CameraFrameType.package:
        return Icons.inventory_2;
      case CameraFrameType.none:
      default:
        return Icons.camera_alt;
    }
  }

  String _getInstructionsForFrameType() {
    switch (widget.frameType) {
      case CameraFrameType.face:
        return 'Posicione seu ROSTO dentro da área oval. Mantenha os olhos na linha guia e o rosto centralizado';
      case CameraFrameType.document:
        return 'Posicione o documento dentro da área retangular e mantenha-o plano';
      case CameraFrameType.package:
        return 'Enquadre a encomenda completamente dentro da área quadrada';
      case CameraFrameType.none:
      default:
        return 'Posicione o objeto desejado e capture a foto';
    }
  }

  Widget _buildFrameOverlay() {
    return CustomPaint(
      painter: FramePainter(frameType: widget.frameType),
    );
  }

  Widget _buildCameraSelector() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.camera_alt,
            size: 64,
            color: Colors.white,
          ),
          const SizedBox(height: 20),
          const Text(
            'Selecione uma câmera',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            '${_availableCameras.length} câmera(s) encontrada(s)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Expanded(
            child: ListView.builder(
              itemCount: _availableCameras.length,
              itemBuilder: (context, index) {
                final camera = _availableCameras[index];
                final cameraLabel = camera.label ?? '';
                final isFrontal = cameraLabel.toLowerCase().contains('front') ||
                    cameraLabel.toLowerCase().contains('frontal') ||
                    cameraLabel.toLowerCase().contains('user');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    leading: Icon(
                      isFrontal ? Icons.camera_front : Icons.camera_rear,
                      color: Colors.white,
                    ),
                    title: Text(
                      cameraLabel.isNotEmpty
                          ? cameraLabel
                          : 'Câmera ${index + 1} ${isFrontal ? '(Frontal)' : '(Traseira)'}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                    onTap: () => _selecionarCamera(camera.deviceId ?? ''),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
