import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'dart:async';
import 'dart:ui' show ImageFilter;
import '../../core/services/image_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/services/equipamentos_api.dart'; // Adicione o import correto do novo arquivo!

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
    if (currentViewType != null && currentViewType!.isNotEmpty) {
      return HtmlElementView(viewType: currentViewType!);
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}

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
    this.isFrontal = true,
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

class FacialGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final center = Offset(size.width / 2, size.height / 2);

    canvas.drawLine(
        Offset(0, center.dy - 30), Offset(size.width, center.dy - 30), paint);
    canvas.drawLine(
        Offset(0, center.dy + 50), Offset(size.width, center.dy + 50), paint);
    canvas.drawLine(Offset(center.dx - 40, center.dy - 60),
        Offset(center.dx - 40, center.dy + 80), paint);
    canvas.drawLine(Offset(center.dx + 40, center.dy - 60),
        Offset(center.dx + 40, center.dy + 80), paint);

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx - 25, center.dy - 30), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx + 25, center.dy - 30), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx, center.dy), 3, dotPaint);
    canvas.drawCircle(Offset(center.dx, center.dy + 35), 3, dotPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class _FacialCaptureModalState extends State<FacialCaptureModal> {
  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  html.MediaStream? _stream;
  bool _mounted = true;
  html.DivElement? _root;
  String? _currentViewType;
  bool _initializing = true;
  bool _isCameraReady = false;

  List<dynamic> _videoInputDevices = [];
  String? _selectedDeviceId;

  List<dynamic> _equipamentos = [];
  bool _isLoadingEquipamentos = true;
  String? _selectedFonte;

  bool isDarkMode(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
  Color getBackgroundColor(BuildContext context) =>
      isDarkMode(context) ? Colors.black : Colors.white;
  Color getSurfaceColor(BuildContext context) =>
      isDarkMode(context) ? const Color(0xFF374151) : Colors.white;
  Color getTextColor(BuildContext context) =>
      isDarkMode(context) ? Colors.white : Colors.black;

  @override
  void initState() {
    super.initState();
    _carregarEquipamentos();
  }

  Widget _buildFonteCapturaSelector() {
    final bool aberto = _selectedFonte == '__menu_aberto__';

    String textoSelecionado;

    if (_selectedFonte == null || aberto) {
      textoSelecionado = 'Selecione uma opção (Webcam ou Equipamento)';
    } else if (_selectedFonte == 'webcam') {
      textoSelecionado = 'Webcam (Câmera Local)';
    } else {
      final equipamento = _equipamentos.firstWhere(
        (eq) => eq['leitor_id'].toString() == _selectedFonte,
        orElse: () => null,
      );

      textoSelecionado = equipamento?['leitor_ds']?.toString() ?? 'Equipamento';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            setState(() {
              if (_selectedFonte == '__menu_aberto__') {
                _selectedFonte = null;
              } else {
                _selectedFonte = '__menu_aberto__';
              }
            });
          },
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(
                aberto ? 8 : 8,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    textoSelecionado,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _selectedFonte == null || aberto
                          ? Colors.grey.shade600
                          : getTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: aberto ? 0.5 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (aberto)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: getSurfaceColor(context),
              border: Border.all(
                color: Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFonteOption(
                  value: 'webcam',
                  icon: Icons.camera_alt_outlined,
                  label: 'Webcam (Câmera Local)',
                ),
                ..._equipamentos.map(
                  (eq) => _buildFonteOption(
                    value: eq['leitor_id'].toString(),
                    icon: Icons.sensors_outlined,
                    label: eq['leitor_ds'].toString(),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFonteOption({
    required String value,
    required IconData icon,
    required String label,
  }) {
    return InkWell(
      onTap: () {
        _onFonteChanged(value);
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: getTextColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // NOVA CHAMADA LIMPA: _carregarEquipamentos
  Future<void> _carregarEquipamentos() async {
    setState(() => _isLoadingEquipamentos = true);
    try {
      final equipamentos = await EquipamentosApi.carregarEquipamentos();
      if (_mounted) {
        setState(() {
          _equipamentos = equipamentos;
          _isLoadingEquipamentos = false;
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() => _isLoadingEquipamentos = false);
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Falha ao carregar lista de equipamentos.',
          errorDetails: e.toString(),
        );
      }
    }
  }

  // NOVA CHAMADA LIMPA: _dispararAtualizacaoIns
  Future<void> _dispararAtualizacaoIns() async {
    if (_selectedFonte == null || _selectedFonte == 'webcam') return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => const Center(child: CircularProgressIndicator()),
      );

      // Chama a API passando o ID do leitor selecionado
      await EquipamentosApi.dispararAtualizacaoIns(_selectedFonte!);

      if (_mounted) Navigator.of(context).pop(); // Fecha o loading

      FeedbackUtils.showSuccess(
        context: context,
        title: 'Sucesso',
        message: 'Comando enviado para o equipamento com sucesso!',
      );

      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (_mounted)
        Navigator.of(context).pop(); // Fecha o loading em caso de erro
      FeedbackUtils.showError(
        context: context,
        title: 'Erro',
        message: 'Falha ao comunicar com o equipamento.',
        errorDetails: e.toString(),
      );
    }
  }

  Future<void> _listarDispositivos() async {
    try {
      final devices =
          await html.window.navigator.mediaDevices!.enumerateDevices();
      final videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
      if (_mounted) {
        setState(() {
          _videoInputDevices = videoInputs;
          if (_selectedDeviceId == null && videoInputs.isNotEmpty) {
            if (_stream != null && _stream!.getVideoTracks().isNotEmpty) {
              final settings = _stream!.getVideoTracks().first.getSettings();
              if (settings['deviceId'] != null) {
                _selectedDeviceId = settings['deviceId'];
              }
            }
            _selectedDeviceId ??= widget.deviceId;
          }
        });
      }
    } catch (e) {
      print('Erro ao listar dispositivos: $e');
    }
  }

  void _registerSimpleViewFactory() {
    if (_currentViewType == null) return;

    try {
      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(_currentViewType!,
          (int viewId) {
        if (_root != null && _mounted) {
          try {
            if (_root!.parent != null || _root!.children.isNotEmpty) {
              return _root!;
            }
          } catch (e) {}
        }

        final tempRoot = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.backgroundColor = '#000'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.flexDirection = 'column'
          ..style.color = '#fff';

        tempRoot.append(html.DivElement()
          ..text = '📹'
          ..style.marginBottom = '10px');
        tempRoot.append(html.DivElement()..text = 'Aguardando câmera...');

        return tempRoot;
      });
    } catch (e) {}
  }

  void _limparElementosAntigos() {
    try {
      final existing = html.document.querySelectorAll('[id^="camera-view-"]');
      for (final element in existing) {
        element.remove();
      }
    } catch (e) {}
  }

  Future<void> _inicializarCamera() async {
    if (!_mounted) return;

    setState(() {
      _initializing = true;
      _isCameraReady = false;
    });

    _limparElementosAntigos();

    try {
      _currentViewType = 'camera-view-${DateTime.now().millisecondsSinceEpoch}';
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

      if (_mounted) setState(() {});

      await Future.delayed(const Duration(milliseconds: 200));

      await _startStream();
    } catch (e) {
      if (_mounted) setState(() => _initializing = false);
    }
  }

  Future<void> _startStream() async {
    if (_mounted) {
      setState(() {
        _isCameraReady = false;
        _initializing = true;
      });
    }

    try {
      final nav = html.window.navigator;
      final mediaDevices = nav.mediaDevices;

      if (mediaDevices == null) {
        throw Exception('MediaDevices não disponível');
      }

      _pararStream();

      if (_video != null) {
        _video!.srcObject = null;
      }

      final Map<String, dynamic> constraints = {
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
        'audio': false,
      };

      if (_selectedDeviceId != null && _selectedDeviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': _selectedDeviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        };
      } else if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': widget.deviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        };
      } else if (widget.isFrontal) {
        constraints['video'] = {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        };
      }

      final stream = await mediaDevices.getUserMedia(constraints);

      if (!_mounted) {
        stream.getTracks().forEach((track) => track.stop());
        return;
      }

      _stream = stream;

      if (_video == null) {
        throw Exception('Elemento de vídeo não inicializado');
      }

      _video!.srcObject = _stream;

      try {
        await _video!.play();
      } catch (e) {
        print('Aviso ao iniciar vídeo: $e');
      }

      if (!_mounted) return;

      /*
     * Neste ponto:
     *
     * 1. getUserMedia() funcionou
     * 2. recebemos o MediaStream
     * 3. o stream foi associado ao <video>
     * 4. play() foi chamado
     *
     * Portanto a câmera está operacional.
     *
     * Não precisamos esperar videoWidth/videoHeight.
     */
      setState(() {
        _initializing = false;
        _isCameraReady = true;
      });

      // Só depois de liberar a câmera,
      // identificamos as câmeras disponíveis.
      await _listarDispositivos();
    } catch (e) {
      print('Erro ao iniciar câmera: $e');

      if (_mounted) {
        setState(() {
          _initializing = false;
          _isCameraReady = false;
        });

        FeedbackUtils.showError(
          context: context,
          title: 'Acesso Negado',
          message:
              'Não foi possível acessar a câmera. Verifique as permissões do seu navegador.',
          errorDetails: e.toString(),
        );
      }
    }
  }

  void _pararStream() {
    try {
      if (_stream != null) {
        _stream!.getTracks().forEach((track) => track.stop());
        _stream = null;
      }
    } catch (e) {}
  }

  Future<void> _capture() async {
    try {
      if (_video == null) {
        _canvas ??= html.CanvasElement(width: 640, height: 480);
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
      final compressedDataUrl =
          await ImageUtils.compressImageToMaxSize(dataUrl);

      if (widget.onCapture != null) {
        widget.onCapture!(compressedDataUrl);
      } else {
        Navigator.of(context).pop(compressedDataUrl);
      }
    } catch (e) {
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

  void _onFonteChanged(String? newValue) {
    if (newValue == null || newValue == _selectedFonte) {
      return;
    }

    setState(() {
      _selectedFonte = newValue;
      _isCameraReady = false;
    });

    if (newValue == 'webcam') {
      _inicializarCamera();
    } else {
      _pararStream();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Trocamos o Material e SizedBox.expand por um Dialog, que força a modal a ficar na camada superior.
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation:
          0, // Tiramos a sombra padrão do Dialog para usar a do nosso Container
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: 420,
        height: 580,
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode(context)
                ? const Color(0xFF1F2937)
                : Colors.grey.shade300,
            width: 1,
          ),
          // Uma sombra leve ajuda a destacar que esta modal está por cima
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.title ?? 'Captura / Acesso',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  IconButton(
                    onPressed: () {
                      if (widget.onClose != null) {
                        widget.onClose!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: _isLoadingEquipamentos
                  ? const LinearProgressIndicator()
                  : _buildFonteCapturaSelector(),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: _selectedFonte == null
                  ? const Center(
                      child: Text('Selecione uma opção acima para continuar.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey)),
                    )
                  : _selectedFonte == 'webcam'
                      ? _buildCameraView(context)
                      : _buildApiView(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiView(BuildContext context) {
    final equip = _equipamentos.firstWhere(
        (e) => e['leitor_id'].toString() == _selectedFonte,
        orElse: () => null);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_tethering, size: 64, color: Colors.blue.shade400),
          const SizedBox(height: 16),
          Text(
            'Equipamento Selecionado:\n${equip?['leitor_ds'] ?? 'Desconhecido'}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _dispararAtualizacaoIns,
            icon: const Icon(Icons.send),
            label: const Text('Disparar Atualização'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildCameraView(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 2),
        borderRadius: BorderRadius.circular(12),
        color: isDarkMode(context) ? Colors.black : Colors.white,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            HtmlVideoWidget(
              videoElement: _video,
              rootElement: _root,
              currentViewType: _currentViewType,
            ),
            if (_videoInputDevices.isNotEmpty)
              Positioned(
                top: 12,
                right: 12,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: Theme(
                          data: ThemeData.dark()
                              .copyWith(cardColor: const Color(0xFF1F2937)),
                          child: PopupMenuButton<String>(
                            offset: const Offset(0, 45),
                            color: const Color(0xFF1F2937),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            tooltip: 'Selecionar Câmera',
                            onSelected: (String? newValue) {
                              if (newValue != null &&
                                  newValue != _selectedDeviceId) {
                                setState(() => _selectedDeviceId = newValue);
                                _startStream();
                              }
                            },
                            itemBuilder: (BuildContext context) {
                              return _videoInputDevices.map((device) {
                                final isSelected =
                                    device.deviceId == _selectedDeviceId;
                                return PopupMenuItem<String>(
                                  value: device.deviceId,
                                  height: 40,
                                  child: Container(
                                      alignment: Alignment.centerLeft,
                                      width: double.infinity,
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            device.label != null &&
                                                    device.label.isNotEmpty
                                                ? device.label
                                                : 'Câmera ${_videoInputDevices.indexOf(device) + 1}',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.white70,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (device != _videoInputDevices.last)
                                            Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 6),
                                              child: Divider(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.1),
                                                  height: 1),
                                            )
                                        ],
                                      )),
                                );
                              }).toList();
                            },
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cameraswitch_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      size: 16),
                                  const SizedBox(width: 6),
                                  ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 140),
                                    child: Text(
                                      (() {
                                        final dev =
                                            _videoInputDevices.firstWhere(
                                                (d) =>
                                                    d.deviceId ==
                                                    _selectedDeviceId,
                                                orElse: () => null);
                                        return dev != null &&
                                                dev.label.isNotEmpty
                                            ? dev.label
                                            : 'Câmera';
                                      })(),
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.keyboard_arrow_down_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.8),
                                      size: 18),
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
            if (!widget.semEnquadramento)
              if (widget.isQuadrado)
                Center(
                  child: Container(
                    width: 240,
                    height: 240,
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.8), width: 3),
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
                          color: Colors.white.withValues(alpha: 0.8), width: 3),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: Container(
                        color: Colors.transparent,
                        child: CustomPaint(painter: FacialGuidePainter()),
                      ),
                    ),
                  ),
                ),
            Positioned(
              bottom: 16,
              child: ElevatedButton.icon(
                onPressed: _isCameraReady ? _capture : null,
                icon: _isCameraReady
                    ? const Icon(Icons.camera_alt, size: 20)
                    : const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.grey),
                      ),
                label: Text(
                  _isCameraReady ? 'Tirar Foto' : 'Inicializando câmera...',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade600,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ),
          ],
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
    } catch (e) {}

    super.dispose();
  }
}
