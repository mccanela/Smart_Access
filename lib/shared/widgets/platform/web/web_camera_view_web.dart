import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:js' as js;
// import 'package:js/js.dart' as pkg_js; // Unused
// ignore: avoid_web_libraries_in_flutter
// import 'dart:js_util' as js_util; // Removed to fix URI error
import 'dart:async';

class WebCameraView extends StatefulWidget {
  final Function(String) onImageCaptured; // Base64
  final VoidCallback onClose;
  final ValueChanged<bool>? onCaptureStatusChanged;

  const WebCameraView({
    super.key,
    required this.onImageCaptured,
    required this.onClose,
    this.onCaptureStatusChanged,
  });

  @override
  State<WebCameraView> createState() => WebCameraViewState();
}

class WebCameraViewState extends State<WebCameraView> {
  html.VideoElement? _videoElement;
  html.MediaStream? _stream;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  String? _capturedImageBase64;
  bool _isProcessing = false;

  // AI State
  bool _isAiLoaded = false;
  bool _scriptsReady = false;
  String _validationMessage = "Aguardando scripts...";
  bool _isFaceDetected = false;
  Timer? _validationTimer;
  Color _guideColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadAiScripts();
  }

  // 1. Inicialização da Câmera
  Future<void> _initializeCamera() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw "Navegador não suportado.";
      }

      _stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      _videoElement = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..srcObject = _stream
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform =
            'scaleX(-1.35) scaleY(1.35)'; // Digital Zoom 1.35x + Mirror

      // ID único para evitar conflito de factories na mesma sessão
      final viewId = 'video-web-${DateTime.now().millisecondsSinceEpoch}';

      // ignore: undefined_prefixed_name
      ui_web.platformViewRegistry.registerViewFactory(
        viewId,
        (int viewId) => _videoElement!,
      );

      // Aguarda metadados para garantir que vídeo está pronto
      await _videoElement!.onLoadedMetadata.first;
      _videoElement!.play();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          // Iniciar validação assim que a câmera estiver pronta, mesmo sem AI
          _startValidationLoop();
          // Tenta iniciar IA (se scripts já estiverem carregados)
          _checkForAiInit();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro na câmera: $e';
        });
      }
    }
  }

  // 2. Carregamento de Scripts IA
  void _loadAiScripts() {
    const scripts = [
      'https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh/face_mesh.js'
    ];

    int loaded = 0;
    void checkLoaded() {
      loaded++;
      if (loaded >= scripts.length) {
        if (mounted) {
          _scriptsReady = true;
          _checkForAiInit();
        }
      }
    }

    for (var src in scripts) {
      final selector = 'script[src="$src"]';
      final alreadyPresent = html.document.querySelector(selector) != null;

      if (alreadyPresent) {
        checkLoaded();
        continue;
      }

      final script = html.ScriptElement()
        ..src = src
        ..async = true;

      script.onLoad.listen((_) => checkLoaded());
      script.onError.listen((_) {
        debugPrint("Erro script IA: $src");
        if (mounted) {
          setState(() {
            _isAiLoaded = false;
            _validationMessage = "Erro ao carregar IA";
            _isFaceDetected = false; // Bloqueia captura
          });
        }
      });

      html.document.head?.append(script);
    }
  }

  // Sincroniza Scripts + Video
  void _checkForAiInit() {
    if (_scriptsReady && _videoElement != null && !_isAiLoaded) {
      _initializeGlobalAi();
    }
  }

  // 3. Inicialização Global JS (Clean Architecture)
  void _initializeGlobalAi() {
    if (!mounted) return;

    // Injeta a API global 'SmartCamera'
    js.context.callMethod('eval', [
      '''
      (function() {
        // Removed early return to ensure logic updates on hot restart
        // if (window.SmartCamera) return;

        window.SmartCamera = {
          faceMesh: null,
          videoElement: null,
          isReady: false,
          lastResults: null,
          
          init: async function(videoEl) {
            this.isReady = false; // Reset state
            this.videoElement = videoEl;

            if (typeof FaceMesh === 'undefined') {
               throw new Error("FaceMesh JS not loaded");
            }

            try {
              const BASE_URL_MESH = "https://cdn.jsdelivr.net/npm/@mediapipe/face_mesh";
              
              this.faceMesh = new FaceMesh({ locateFile: (f) => `\${BASE_URL_MESH}/\${f}` });
              this.faceMesh.setOptions({
                maxNumFaces: 1,
                refineLandmarks: true, 
                minDetectionConfidence: 0.85, 
                minTrackingConfidence: 0.85
              });
              
              this.faceMesh.onResults((res) => {
                 this.lastResults = res;
              });
              
              await this.faceMesh.initialize();
              this.isReady = true;
            } catch(e) {
              console.error("SmartCamera Init Error:", e);
              throw e;
            }
          },

          checkFace: async function() {
            if (!this.videoElement) {
               return { status: 'loading', msg: 'Câmera não conectada' };
            }
            if (!this.isReady) {
               return { status: 'loading', msg: 'Iniciando IA...' };
            }

            try {
              await this.faceMesh.send({ image: this.videoElement });
            } catch (e) {
               console.error("FaceMesh Send Error:", e);
               // Se der erro no send, pode ser que o video nao esteja pronto ou contexto perdido
               return { status: 'loading', msg: 'Processando...' };
            }

            const res = this.lastResults;
            if (!res || !res.multiFaceLandmarks || res.multiFaceLandmarks.length === 0) {
              return { status: 'no_face', msg: 'Centralize o rosto' };
            }

            const lm = res.multiFaceLandmarks[0];

            const nose = lm[1];
            const leftEye = lm[33];
            const rightEye = lm[263];
            const forehead = lm[10];

            /** ==========================
             * 0️⃣ METRICAS DE NORMATIZAÇÃO
             ========================== */
            // Largura do rosto (Cheek-to-Cheek) usada para normalizar medidas
            const cheekLeft = lm[454];
            const cheekRight = lm[234];
            const faceWidth = Math.abs(cheekLeft.x - cheekRight.x);
            
            // Fator de escala (evita divisao por zero)
            const scale = faceWidth || 0.1;

            /** ==========================
             * 1️⃣ BONÉ & ÓCULOS (Prioridade ABSOLUTA)
             ========================== */
             
            // -- BONÉ (Geometria: Testa vs Glabela) --
            // O topo da testa (10) deve estar atrás ou linha com a glabela (168).
            // Se o ponto 10 estiver mais PERTO da câmera (Z menor) que a glabela, é aba de boné.
            const glabella = lm[168];
            if (forehead && glabella && (forehead.z < glabella.z - 0.015)) {
               return { status: 'hat', msg: 'Remova o boné / chapéu' };
            }

            // -- ÓCULOS (Detecção de Contraste/Abertura) --
            const leftEyeTop = lm[159];
            const leftEyeBottom = lm[145];
            const rightEyeTop = lm[386];
            const rightEyeBottom = lm[374];

            const leftEyeOpen = Math.abs(leftEyeTop.y - leftEyeBottom.y);
            const rightEyeOpen = Math.abs(rightEyeTop.y - rightEyeBottom.y);
            
            // Ajuste Ultra-Rígido: < 0.065 (6.5% da largura da face)
            // Se houver qualquer armação ou reflexo reduzindo a "clareza" da abertura do olho, barra.
            if ((leftEyeOpen / scale) < 0.065 || (rightEyeOpen / scale) < 0.065) {
               return { status: 'glasses', msg: 'Remova os óculos' };
            }

            /** ==========================
             * 2️⃣ POSICIONAMENTO E GEOMETRIA
             ========================== */
             
            // -- DISTÂNCIA (Zoom Digital 1.35x Considerado) --
            // Limites relaxados para permitir captura confortável
            if (faceWidth < 0.15) {
               return { status: 'too_far', msg: 'Aproxime-se um pouco' };
            }
            if (faceWidth > 0.80) {
               return { status: 'too_close', msg: 'Afaste-se um pouco' };
            }

            // -- YAW (Ex: Olhando Esquerda/Direita) --
            // Strict: Nariz deve estar quase perfeitamente no centro dos olhos
            const eyesMidX = (leftEye.x + rightEye.x) / 2;
            const noseOffset = Math.abs(nose.x - eyesMidX);
            // Tolerância: 5% da largura do rosto (Bem rigoroso)
            if ((noseOffset / scale) > 0.05) {
               return { status: 'bad_angle', msg: 'Olhe direitamente para frente' };
            }

            // -- PITCH (Ex: Olhando Cima/Baixo) --
            // Geometria: Posição vertical do nariz em relação à altura total do rosto
            const chin = lm[152];
            const faceHeight = Math.abs(chin.y - (forehead ? forehead.y : lm[10].y));
            if (faceHeight > 0) {
               const noseRelY = (nose.y - (forehead ? forehead.y : lm[10].y)) / faceHeight;
               
               // Valor ideal para rosto frontal é ~0.48 - 0.52
               // < 0.40 : Nariz muito alto (Olhando p/ Cima)
               // > 0.60 : Nariz muito baixo (Olhando p/ Baixo)
               if (noseRelY < 0.42) return { status: 'too_high', msg: 'Abaixe o queixo' };
               if (noseRelY > 0.58) return { status: 'too_low', msg: 'Levante o queixo' };
            }

            // -- ROLL (Ex: Cabeça Torta) --
            // Diferença Y dos olhos relativa à largura
            const eyeDeltaY = Math.abs(leftEye.y - rightEye.y);
            // Tolerância: 5% da largura (Rigoroso para manter foto reta)
            if ((eyeDeltaY / scale) > 0.05) {
               return { status: 'tilted', msg: 'Mantenha a cabeça reta' };
            }

            return { status: 'ok', msg: 'Perfeito!' };
          },
          
          handlePromise: function(promise, successCb, errorCb) {
             Promise.resolve(promise).then(successCb).catch(errorCb);
          }
        };
      })();
      '''
    ]);

    _startAiInit();
  }

  Future<void> _startAiInit() async {
    if (_videoElement != null) {
      try {
        if (mounted) {
          setState(() => _validationMessage = "Carregando modelos...");
        }

        // Timeout de 10 segundos para carregar IA, senão libera uso sem IA
        await _jsPromiseToFuture(
          js.context['SmartCamera'].callMethod('init', [_videoElement]),
        ).timeout(const Duration(seconds: 10));

        setState(() {
          _isAiLoaded = true;
        });
      } catch (e) {
        debugPrint("AI Init Failed or Timed out: $e");
        if (mounted) {
          setState(() {
            _isAiLoaded = false;
            // Permite funcionamento básico
            _validationMessage = "Falha ao carregar Inteligência";
            _isFaceDetected = false;
            _guideColor = Colors.red;
          });
        }
      }
    }
  }

  // 4. Loop de Validação Otimizado
  void _startValidationLoop() {
    _validationTimer?.cancel();
    _validationTimer =
        Timer.periodic(const Duration(milliseconds: 600), (_) async {
      if (!mounted || _capturedImageBase64 != null || _isProcessing) return;
      if (html.document.hidden == true) return;

      // Se a IA não carregou ou falhou, mantemos bloqueado
      if (!_isAiLoaded) {
        if (mounted && _isFaceDetected) {
          setState(() {
            _isFaceDetected = false;
          });
        }
        return;
      }

      final result = await _checkFaceStatus();
      if (mounted) {
        setState(() {
          // Se loading, atualiza feedback e bloqueia
          if (result['status'] == 'loading') {
            _validationMessage = result['msg'];
            _guideColor = const Color(0xFFB0BEC5);
            _isFaceDetected = false;
            return;
          }

          _isFaceDetected = result['status'] == 'ok';
          _validationMessage = result['msg'];

          // Cores de feedback
          if (_isFaceDetected) {
            _guideColor = const Color(0xFF00E676); // Verde Sucesso
          } else {
            switch (result['status']) {
              case 'no_face':
                _guideColor = const Color(0xFFB0BEC5); // Blue Gray
                break;
              case 'bad_angle':
              case 'tilted':
                _guideColor = const Color(0xFFFFC107); // Amber
                break;
              case 'too_high':
              case 'too_low':
                _guideColor = const Color(0xFFFF5252); // Red Accent
                break;
              case 'hat':
              case 'glasses':
                _guideColor = const Color(0xFFFF5252); // Red Accent
                break;
              case 'too_close':
              case 'too_far':
                _guideColor = Colors.blueAccent;
                break;
              default:
                _guideColor = Colors.redAccent;
            }
          }
        });
      }
    });
  }

  Future<Map<String, dynamic>> _checkFaceStatus() async {
    try {
      final jsResult = await _jsPromiseToFuture(
          js.context['SmartCamera'].callMethod('checkFace'));

      if (jsResult == null) return {'status': 'error', 'msg': 'Erro AI'};

      final status = jsResult['status'];
      final msg = jsResult['msg'];

      return {
        'status': status ?? 'error',
        'msg': msg ?? 'Erro',
      };
    } catch (e) {
      return {'status': 'loading', 'msg': 'Processando...'};
    }
  }

  // 5. Captura
  Future<void> takePicture() async {
    if (_isProcessing) return;

    if (!_isFaceDetected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(_validationMessage),
            duration: const Duration(seconds: 1)),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Snapshot direto
      final processedBase64 = await _captureSnapshot();

      if (mounted && processedBase64 != null) {
        setState(() {
          _capturedImageBase64 = processedBase64;
          _isProcessing = false;
        });
        widget.onCaptureStatusChanged?.call(true);
      }
    } catch (e) {
      debugPrint("Erro ao capturar: $e");
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<String?> _captureSnapshot() async {
    const int targetSize = 600;
    const int maxBytes = 200 * 1024; // 200KB Limit

    if (_videoElement == null || _videoElement!.videoWidth == 0) return null;

    final videoWidth = _videoElement!.videoWidth;
    final videoHeight = _videoElement!.videoHeight;

    // Crop Logic: Center Square (Account for 1.35x Zoom)
    // Determina o menor lado para fazer um quadrado
    final int minSide = (videoWidth < videoHeight) ? videoWidth : videoHeight;

    // Fator de zoom deve bater com o CSS (1.35)
    // Para dar "zoom" na foto, pegamos um pedaço MENOR do vídeo original
    // Se o user vê 1.35x, significa que ele vê 1/1.35 da imagem real.
    final double zoomFactor = 1.35;
    final double cropSize = minSide / zoomFactor;

    // Calcula offsets para centralizar este crop menor
    final double sx = (videoWidth - cropSize) / 2;
    final double sy = (videoHeight - cropSize) / 2;

    final canvas = html.CanvasElement(width: targetSize, height: targetSize);
    final ctx = canvas.context2D;

    // Espelhamento (para manter o WYSIWYG do preview que é espelhado)
    ctx.translate(targetSize, 0);
    ctx.scale(-1, 1);

    // Desenha cortando (Source) e redimensionando (Dest)
    ctx.drawImageScaledFromSource(
        _videoElement!,
        sx,
        sy,
        cropSize,
        cropSize, // Área de corte menor (Zoom)
        0,
        0,
        targetSize,
        targetSize // Área final no canvas (600x600)
        );

    // Loop de Compressão Inteligente
    String? finalBase64;
    double quality = 0.95;

    // Tenta reduzir qualidade até ficar < 200KB
    for (int i = 0; i < 15; i++) {
      // Usa JPEG pois PNG 600x600 com foto realista costuma passar de 200KB
      // e o parâmetro de qualidade só funciona bem em JPEG/WebP
      final dataUrl = canvas.toDataUrl('image/jpeg', quality);
      final content = dataUrl.split(',')[1];

      final approxBytes =
          (content.length * 3) / 4; // Cálculo aproximado Base64 -> Bytes

      if (approxBytes <= maxBytes || quality <= 0.2) {
        finalBase64 = content;
        debugPrint(
            "Snapshot Final: 600x600, Q=\${quality.toStringAsFixed(2)}, Tamanho=\${(approxBytes / 1024).toStringAsFixed(1)}KB");
        break;
      }

      quality -= 0.1;
    }

    return finalBase64;
  }

  void retake() {
    setState(() {
      _capturedImageBase64 = null;
      _validationMessage = "Posicione o rosto";
      _isFaceDetected = false;
      _guideColor = Colors.white;
      // Se a IA tinha falhado, restaura estado permissivo
      // REMOVIDO: Agora a IA é obrigatória sempre.
      // if (!_isAiLoaded) { _isFaceDetected = true; }
    });
    widget.onCaptureStatusChanged?.call(false);
  }

  void confirm() {
    if (_capturedImageBase64 != null) {
      widget.onImageCaptured(_capturedImageBase64!);
    }
  }

  Future<dynamic> _jsPromiseToFuture(dynamic jsPromise) {
    if (jsPromise == null) return Future.value(null);
    final completer = Completer<dynamic>();
    js.context['SmartCamera'].callMethod('handlePromise', [
      jsPromise,
      (res) => completer.complete(res),
      (err) => completer.completeError(err.toString())
    ]);
    return completer.future;
  }

  @override
  void dispose() {
    _validationTimer?.cancel();
    _stopCamera();
    super.dispose();
  }

  void _stopCamera() {
    _stream?.getTracks().forEach((t) => t.stop());
    _stream = null;
    _videoElement?.remove();
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Container(
        color: Colors.black,
        child: Center(
            child: Text(_errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12))),
      );
    }

    return Stack(
      children: [
        // 1. Visão da Câmera
        Positioned.fill(
          child: Container(
            color: Colors.black,
            child: _capturedImageBase64 != null
                ? Image.memory(base64Decode(_capturedImageBase64!),
                    fit: BoxFit.cover)
                : (_isCameraInitialized && _videoElement != null
                    ? _VideoWidget(videoElement: _videoElement!)
                    : const Center(
                        child: CircularProgressIndicator(strokeWidth: 2))),
          ),
        ),

        // 2. Guide Overlay
        if (_capturedImageBase64 == null && _isCameraInitialized)
          Positioned.fill(
              child: CustomPaint(
            painter: _SmartFaceGuidePainter(
              color: _guideColor,
              isValid: _isFaceDetected,
            ),
          )),

        // 3. Feedback Text
        if (_capturedImageBase64 == null)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _isCameraInitialized ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _guideColor.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                          _isFaceDetected
                              ? Icons.check_circle
                              : Icons.info_outline,
                          color: _guideColor,
                          size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _validationMessage.toUpperCase(),
                          style: TextStyle(
                              color: _guideColor,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 4. Loading
        if (_isProcessing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),

        // Botão Fechar
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        )
      ],
    );
  }
}

class _VideoWidget extends StatefulWidget {
  final html.VideoElement videoElement;
  const _VideoWidget({required this.videoElement});

  @override
  State<_VideoWidget> createState() => _VideoWidgetState();
}

class _VideoWidgetState extends State<_VideoWidget> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'video-web-element-${DateTime.now().millisecondsSinceEpoch}';
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => widget.videoElement,
    );
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}

class _SmartFaceGuidePainter extends CustomPainter {
  final Color color;
  final bool isValid;

  _SmartFaceGuidePainter({required this.color, required this.isValid});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final focusWidth = size.width * 0.65;
    final focusHeight = size.height * 0.75;
    final focusRect =
        Rect.fromCenter(center: center, width: focusWidth, height: focusHeight);

    // Vignette
    final pathOverlay = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addOval(focusRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
        pathOverlay, Paint()..color = Colors.black.withValues(alpha: 0.5));

    // Brackets
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = isValid ? 4.0 : 3.0
      ..strokeCap = StrokeCap.round;

    final double cornerSize = 30.0;
    final path = Path();

    path.moveTo(focusRect.left, focusRect.top + cornerSize);
    path.quadraticBezierTo(focusRect.left, focusRect.top,
        focusRect.left + cornerSize, focusRect.top);

    path.moveTo(focusRect.right - cornerSize, focusRect.top);
    path.quadraticBezierTo(focusRect.right, focusRect.top, focusRect.right,
        focusRect.top + cornerSize);

    path.moveTo(focusRect.right, focusRect.bottom - cornerSize);
    path.quadraticBezierTo(focusRect.right, focusRect.bottom,
        focusRect.right - cornerSize, focusRect.bottom);

    path.moveTo(focusRect.left + cornerSize, focusRect.bottom);
    path.quadraticBezierTo(focusRect.left, focusRect.bottom, focusRect.left,
        focusRect.bottom - cornerSize);

    canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
