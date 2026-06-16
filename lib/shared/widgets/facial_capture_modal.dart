import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';
import 'dart:ui' show ImageFilter;
import '../../core/services/image_utils.dart';
import '../../core/services/feedback_utils.dart';

// CustomPainter para guias de enquadramento facial
class FacialGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    // Linha horizontal central (altura dos olhos)
    canvas.drawLine(
      Offset(0, center.dy - 30),
      Offset(size.width, center.dy - 30),
      paint,
    );

    // Linha horizontal inferior (altura do queixo)
    canvas.drawLine(
      Offset(0, center.dy + 50),
      Offset(size.width, center.dy + 50),
      paint,
    );

    // Linhas verticais para largura do rosto
    canvas.drawLine(
      Offset(center.dx - 40, center.dy - 60),
      Offset(center.dx - 40, center.dy + 80),
      paint,
    );

    canvas.drawLine(
      Offset(center.dx + 40, center.dy - 60),
      Offset(center.dx + 40, center.dy + 80),
      paint,
    );

    // Pontos de referência
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    // Pontos para olhos
    canvas.drawCircle(Offset(center.dx - 25, center.dy - 30), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx + 25, center.dy - 30), 3, dotPaint);

    // Ponto para nariz
    canvas.drawCircle(Offset(center.dx, center.dy), 3, dotPaint);

    // Ponto para boca
    canvas.drawCircle(Offset(center.dx, center.dy + 35), 3, dotPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Widget HTML para vídeo seguindo padrão do dashboard
class HtmlVideoWidget extends StatelessWidget {
  final html.VideoElement? videoElement;
  final html.DivElement? rootElement;
  final String? currentViewType;

  const HtmlVideoWidget({
    super.key,
    required this.videoElement,
    required this.rootElement,
    required this.currentViewType,
  });

  @override
  Widget build(BuildContext context) {
    // Sempre renderizar HtmlElementView se temos um viewType
    if (currentViewType != null && currentViewType!.isNotEmpty) {
      return HtmlElementView(viewType: currentViewType!);
    }

    // Fallback: container vazio com loading
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

// Modal de câmera seguindo padrão do dashboard
class FacialCaptureModal extends StatefulWidget {
  final bool isFrontal;
  final String? deviceId;
  final String? title;
  final bool isQuadrado;
  final bool semEnquadramento;
  final Function(String)? onCapture;
  final VoidCallback? onClose;

  const FacialCaptureModal({
    super.key,
    this.isFrontal = true, // Default true for facial capture
    this.deviceId,
    this.title,
    this.isQuadrado = false,
    this.semEnquadramento = false,
    this.onCapture,
    this.onClose,
  });

  @override
  State<FacialCaptureModal> createState() => _FacialCaptureModalState();
}

class _FacialCaptureModalState extends State<FacialCaptureModal> {
  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  html.MediaStream? _stream;
  bool _mounted = true;
  html.DivElement? _root;
  String? _currentViewType;
  bool _initializing = true;

  // Funções auxiliares para cores adaptáveis ao tema
  bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  Color getBackgroundColor(BuildContext context) {
    return isDarkMode(context) ? Colors.black : Colors.white;
  }

  Color getSurfaceColor(BuildContext context) {
    return isDarkMode(context) ? const Color(0xFF374151) : Colors.white;
  }

  Color getTextColor(BuildContext context) {
    return isDarkMode(context) ? Colors.white : Colors.black;
  }

  @override
  void initState() {
    super.initState();

    // Reset state for fresh start
    _video = null;
    _canvas = null;
    _stream = null;
    _root = null;
    _currentViewType = null;
    _videoInputDevices = [];
    _selectedDeviceId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarCamera();
    });
  }

  List<dynamic> _videoInputDevices = [];
  String? _selectedDeviceId;

  Future<void> _listarDispositivos() async {
    try {
      final devices =
          await html.window.navigator.mediaDevices!.enumerateDevices();
      final videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
      if (_mounted) {
        setState(() {
          _videoInputDevices = videoInputs;
          // Tentar sincronizar seleção inicial
          if (_selectedDeviceId == null && videoInputs.isNotEmpty) {
            // Se houver um stream ativo, tenta pegar o ID dele
            if (_stream != null && _stream!.getVideoTracks().isNotEmpty) {
              final settings = _stream!.getVideoTracks().first.getSettings();
              if (settings['deviceId'] != null) {
                _selectedDeviceId = settings['deviceId'];
              }
            }
            // Se falhar, usa o do widget ou null
            _selectedDeviceId ??= widget.deviceId;
          }
        });
      }
    } catch (e) {
      print('Erro ao listar dispositivos: $e');
    }
  }

  void _registerSimpleViewFactory() {
    _currentViewType ??= 'camera-view-${DateTime.now().millisecondsSinceEpoch}';

    try {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_currentViewType!,
          (int viewId) {
        if (_root != null && _mounted) {
          try {
            if (_root!.parent != null || _root!.children.isNotEmpty) {
              return _root!;
            }
          } catch (e) {
            // Elemento pode ter sido removido
          }
        }

        // Criar um elemento temporário
        final tempRoot = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.flexDirection = 'column'
          ..style.color = '#fff'
          ..style.fontSize = '16px'
          ..style.fontFamily = 'Arial, sans-serif';

        final iconDiv = html.DivElement()
          ..text = '📹'
          ..style.marginBottom = '10px';

        final textDiv = html.DivElement()
          ..text = 'Inicializando câmera...'
          ..style.textAlign = 'center';

        final subtitleDiv = html.DivElement()
          ..text = 'Aguarde alguns segundos'
          ..style.fontSize = '12px'
          ..style.marginTop = '5px'
          ..style.opacity = '0.7';

        tempRoot.append(iconDiv);
        tempRoot.append(textDiv);
        tempRoot.append(subtitleDiv);

        return tempRoot;
      });
    } catch (e) {
      // Factory já pode estar registrada
    }
  }

  void _limparElementosAntigos() {
    try {
      final existing = html.document.querySelectorAll('[id^="camera-view-"]');
      for (final element in existing) {
        element.remove();
      }
    } catch (e) {
      // Ignorar erros de limpeza
    }
  }

  Future<void> _inicializarCamera() async {
    _limparElementosAntigos();

    try {
      _registerSimpleViewFactory();

      _root = html.DivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.overflow = 'hidden'
        ..style.borderRadius = '12px'
        ..style.backgroundColor = '#000'
        ..style.position = 'relative'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center';

      _video = html.VideoElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..autoplay = true
        ..muted = true
        ..controls = false
        ..setAttribute('playsinline', 'true')
        ..setAttribute('autoplay', 'true')
        ..setAttribute('muted', 'true')
        ..style.display = 'block'
        ..style.borderRadius = '8px';

      _canvas = html.CanvasElement(width: 640, height: 480);

      if (_root != null && _video != null) {
        _root!.append(_video!);
      }

      if (_mounted) {
        setState(() {});
      }

      await _startStream();
      await _listarDispositivos(); // Listar após garantir permissão
    } catch (e) {
      if (_mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _startStream() async {
    try {
      final nav = html.window.navigator;
      final mediaDevices = nav.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('MediaDevices não disponível');
      }

      _pararStream(); // Chamada síncrona

      // Ensure clean state before requesting new stream
      if (_video != null) {
        _video!.srcObject = null;
      }

      final Map<String, dynamic> constraints = {
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        },
        'audio': false
      };

      if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': _selectedDeviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      } else if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': widget.deviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      } else if (widget.isFrontal) {
        // Para câmera frontal, forçar facingMode apenas se não houver deviceId
        constraints['video'] = {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      }

      final stream = await mediaDevices.getUserMedia(constraints);

      // Se o widget foi fechado durante a solicitação, encerra a stream imediatamente
      if (!_mounted) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }

      // IMPORTANTE: Se já existe um _stream (concorrência), precisamos pará-lo antes de sobrescrever
      if (_stream != null) {
        _stream!.getTracks().forEach((track) => track.stop());
        _stream = null;
      }

      _stream = stream;

      if (_video != null && _stream != null) {
        _video!.srcObject = _stream;

        if (_mounted) {
          setState(() {
            _initializing = false;
          });
          // Pequeno delay apenas para UI update se necessário, mas reduzido
          Future.delayed(const Duration(milliseconds: 50), () {
            if (_mounted) setState(() {});
          });
        }
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  void _pararStream() {
    try {
      if (_stream != null) {
        _stream!.getTracks().forEach((track) => track.stop());
        _stream = null;
      }
    } catch (e) {
      // Ignorar erros
    }
  }

  Future<void> _capture() async {
    try {
      // Tentar capturar sempre, mesmo se elementos não estiverem prontos
      if (_video == null) {
        // Criar canvas temporário se vídeo não estiver disponível
        _canvas ??= html.CanvasElement(width: 640, height: 480);
        // Retornar uma imagem vazia ou tentar capturar do vídeo se disponível
        final dataUrl = _canvas!.toDataUrl('image/png');
        final compressedDataUrl =
            await ImageUtils.compressImageToMaxSize(dataUrl);
        if (widget.onCapture != null) {
          widget.onCapture!(compressedDataUrl);
        } else {
          Navigator.of(context).pop(compressedDataUrl);
        }
        return;
      }

      _canvas ??= html.CanvasElement(width: 640, height: 480);
      final ctx = _canvas!.context2D;

      final width = _video!.videoWidth > 0 ? _video!.videoWidth : 640;
      final height = _video!.videoHeight > 0 ? _video!.videoHeight : 480;

      _canvas!.width = width;
      _canvas!.height = height;

      ctx.drawImage(_video!, 0, 0);

      final dataUrl = _canvas!.toDataUrl('image/png');

      // Comprimir imagem para máximo 300KB
      final compressedDataUrl =
          await ImageUtils.compressImageToMaxSize(dataUrl);

      if (widget.onCapture != null) {
        widget.onCapture!(compressedDataUrl);
      } else {
        Navigator.of(context).pop(compressedDataUrl);
      }
    } catch (e) {
      // Mesmo em caso de erro, tentar retornar algo
      try {
        _canvas ??= html.CanvasElement(width: 640, height: 480);
        final dataUrl = _canvas!.toDataUrl('image/png');
        final compressedDataUrl =
            await ImageUtils.compressImageToMaxSize(dataUrl);
        if (widget.onCapture != null) {
          widget.onCapture!(compressedDataUrl);
        } else {
          Navigator.of(context).pop(compressedDataUrl);
        }
      } catch (fallbackError) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Capturar',
          message: 'Erro ao capturar foto',
          errorDetails: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Center(
          child: Container(
            width: 420,
            height: 520,
            decoration: BoxDecoration(
              color: getBackgroundColor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDarkMode(context)
                    ? const Color(0xFF1F2937)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A), // Azul escuro
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.title ?? 'Capturar Foto',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),

                // Área da câmera
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                      borderRadius: BorderRadius.circular(12),
                      // Fundo adaptável ao tema: Preto no escuro, Branco no claro (transparent para evitar bordas feias se possível, mas user pediu branco)
                      color: isDarkMode(context) ? Colors.black : Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Widget personalizado para exibir vídeo HTML
                          HtmlVideoWidget(
                            videoElement: _video,
                            rootElement: _root,
                            currentViewType: _currentViewType,
                          ),

                          // Seletor de Câmera (Design Glassmorphism com PopupMenuButton)
                          if (_videoInputDevices.isNotEmpty)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.2),
                                        width: 1,
                                      ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: Theme(
                                        data: ThemeData.dark().copyWith(
                                          cardColor: const Color(0xFF1F2937),
                                        ),
                                        child: PopupMenuButton<String>(
                                          offset: const Offset(0, 45),
                                          color: const Color(0xFF1F2937),
                                          shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12)),
                                          tooltip: 'Selecionar Câmera',
                                          onSelected: (String? newValue) {
                                            if (newValue != null &&
                                                newValue != _selectedDeviceId) {
                                              setState(() {
                                                _selectedDeviceId = newValue;
                                              });
                                              _startStream();
                                            }
                                          },
                                          itemBuilder: (BuildContext context) {
                                            return _videoInputDevices
                                                .map((device) {
                                              final isSelected =
                                                  device.deviceId ==
                                                      _selectedDeviceId;
                                              return PopupMenuItem<String>(
                                                value: device.deviceId,
                                                height: 40,
                                                child: Container(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    width: double.infinity,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          device.label !=
                                                                      null &&
                                                                  device.label
                                                                      .isNotEmpty
                                                              ? device.label
                                                              : 'Câmera ${_videoInputDevices.indexOf(device) + 1}',
                                                          style: TextStyle(
                                                            color: isSelected
                                                                ? Colors.white
                                                                : Colors
                                                                    .white70,
                                                            fontWeight:
                                                                isSelected
                                                                    ? FontWeight
                                                                        .w600
                                                                    : FontWeight
                                                                        .normal,
                                                            fontSize: 12,
                                                          ),
                                                        ),
                                                        if (device !=
                                                            _videoInputDevices
                                                                .last)
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .only(
                                                                    top: 6),
                                                            child: Divider(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                        alpha:
                                                                            0.1),
                                                                height: 1),
                                                          )
                                                      ],
                                                    )),
                                              );
                                            }).toList();
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.cameraswitch_rounded,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                ConstrainedBox(
                                                  constraints:
                                                      const BoxConstraints(
                                                          maxWidth: 140),
                                                  child: Text(
                                                    (() {
                                                      final dev = _videoInputDevices
                                                          .firstWhere(
                                                              (d) =>
                                                                  d.deviceId ==
                                                                  _selectedDeviceId,
                                                              orElse: () =>
                                                                  null);
                                                      return dev != null &&
                                                              dev.label
                                                                  .isNotEmpty
                                                          ? dev.label
                                                          : 'Câmera';
                                                    })(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  color: Colors.white
                                                      .withValues(alpha: 0.8),
                                                  size: 18,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Overlay de enquadramento
                          if (!widget.semEnquadramento)
                            if (widget.isQuadrado)
                              Center(
                                child: Container(
                                  width: 240,
                                  height: 240,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              )
                            else if (widget.isFrontal)
                              Center(
                                child: Container(
                                  width: 200,
                                  height: 260,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      width: 3,
                                    ),
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(100),
                                    child: Container(
                                      color: Colors.transparent,
                                      child: CustomPaint(
                                        painter: FacialGuidePainter(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                          // Botão de captura (sempre habilitado)
                          Positioned(
                            bottom: 16,
                            child: ElevatedButton.icon(
                              onPressed: _capture,
                              icon: const Icon(Icons.camera_alt, size: 20),
                              label: const Text('Tirar Foto'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mounted = false;
    _pararStream();

    try {
      if (_video != null) {
        _video!.srcObject = null;
        _video!.removeAttribute('src');
        _video!.remove();
        _video = null;
      }

      if (_root != null) {
        _root!.remove();
        _root = null;
      }

      _canvas = null;
      _currentViewType = null;
    } catch (e) {
      // Ignorar erros de limpeza
    }

    super.dispose();
  }
}
