part of '../dashboard.dart';

class _CameraModalWidget extends StatefulWidget {
  final BuildContext dialogCtx;
  final bool isFrontal;
  final String? deviceId;

  const _CameraModalWidget({
    required this.dialogCtx,
  })  : isFrontal = false,
        deviceId = null;

  @override
  State<_CameraModalWidget> createState() => _CameraModalWidgetState();
}

class _CameraModalWidgetState extends State<_CameraModalWidget> {
  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  html.MediaStream? _stream;
  bool _canCapture = false;
  bool _mounted = true;
  html.DivElement? _root;
  String? _currentViewType;

  @override
  void initState() {
    super.initState();

    // Reset state for fresh start - garantir que tudo seja limpo
    _canCapture = false;
    _video = null;
    _canvas = null;
    _stream = null;
    _root = null;
    _currentViewType = null;

    // Aguardar um pouco para garantir que o widget esteja montado
    // antes de registrar a factory e inicializar a câmera
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Inicializar câmera com viewType único
      _inicializarCamera();
    });
  }

  void _registerSimpleViewFactory() {
    _currentViewType ??= 'camera-view-${DateTime.now().millisecondsSinceEpoch}';

    try {
      ui_web.platformViewRegistry.registerViewFactory(_currentViewType!,
          (int viewId) {
        // Log para debug
        print(
            'PlatformViewFactory chamada com viewId: $viewId para $_currentViewType');

        // Sempre retornar um elemento válido - verificaá§ões múltiplas
        if (_root != null && _mounted) {
          try {
            // Verificar se o elemento ainda está válido e tem conteúdo
            if (_root!.parent != null || _root!.children.isNotEmpty) {
              print('Retornando _root existente para $_currentViewType');
              return _root!;
            }
          } catch (e) {
            print('Erro ao verificar _root: $e');
            // Elemento pode ter sido removido
          }
        }

        // Criar um elemento temporário usando propriedades Dart (não innerHtml)
        print('Criando elemento temporário para $_currentViewType');
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

        // Criar elementos filhos usando DOM API
        final iconDiv = html.DivElement()
          ..text = 'ðŸ“¹'
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

        // Armazenar como root principal se ainda não existir, para que possamos
        // anexar o elemento de vídeo posteriormente ao MESMO elemento usado pela view.
        _root ??= tempRoot;

        return _root ?? tempRoot;
      });
      print(
          'PlatformViewFactory registrada com sucesso para $_currentViewType');
    } catch (e) {
      // Factory já pode estar registrada ou há outro erro
      print('Erro ao registrar PlatformViewFactory para $_currentViewType: $e');
    }
  }

  void _limparElementosAntigos() {
    // Limpar elementos DOM antigos se existirem
    try {
      final existing = html.document.querySelectorAll('[id^="camera-view-"]');
      for (final element in existing) {
        element.remove();
        print('Elemento antigo removido: ${element.id}');
      }
    } catch (e) {
      print('Erro ao limpar elementos antigos: $e');
    }
  }

  Future<void> _inicializarCamera() async {
    print('Iniciando _inicializarCamera');

    // Limpar elementos antigos primeiro
    _limparElementosAntigos();

    try {
      // Registrar a factory com viewType único antes de criar elementos
      _registerSimpleViewFactory();

      // Para Flutter Web, usar o mesmo elemento que a factory criou
      print('Preparando _root element');
      if (_root == null) {
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
      } else {
        _root!.children.clear();
      }

      print('Criando _video element');
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

      print('Criando _canvas element');
      _canvas = html.CanvasElement(width: 640, height: 480);

      // Verificar se ambos os elementos existem antes de tentar append
      if (_root != null && _video != null) {
        print('Anexando _video ao _root');
        _root!.append(_video!);
      }

      // Forá§ar atualizaçao do widget quando _root for criado
      if (_mounted) {
        print('Chamando setState após criar elementos');
        setState(() {});
      }

      // Aguardar um pouco para garantir que os elementos DOM estejam prontos
      await Future.delayed(const Duration(milliseconds: 200));

      // Iniciar o stream
      print('Chamando _startStream');
      await _startStream();

      print('_inicializarCamera concluída com sucesso');
    } catch (e) {
      print('Erro em _inicializarCamera: $e');
      if (_mounted) {
        setState(() {
          _canCapture = false;
        });
      }
    }
  }

  Future<void> _startStream() async {
    try {
      // Primeiro, solicitar permissões
      final nav = html.window.navigator;
      final mediaDevices = nav.mediaDevices;
      if (mediaDevices == null) {
        throw Exception('MediaDevices não disponível');
      }

      // Parar stream anterior se existir
      await _pararStream();

      // Configuraá§ões de vídeo
      final Map<String, dynamic> constraints = {
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        },
        'audio': false
      };

      // Se temos um deviceId específico, usar ele
      if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': widget.deviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      }

      // Solicitar permissões e iniciar stream
      _stream = await mediaDevices.getUserMedia(constraints);

      if (_video != null && _stream != null) {
        _video!.srcObject = _stream;
        try {
          await _video!.play();
        } catch (_) {}

        // Forá§ar múltiplas atualizaá§ões do widget para garantir que apareá§a
        if (_mounted) {
          setState(() {});
          // Aguardar um pouco e forá§ar novamente
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_mounted) setState(() {});
          });
        }

        // Aguardar um pouco para garantir que o vídeo está tocando
        await Future.delayed(const Duration(milliseconds: 300));

        // Verificar se o vídeo tem dimensões válidas
        if (_video != null &&
            _video!.videoWidth > 0 &&
            _video!.videoHeight > 0) {
          // Definir que pode capturar
          if (_mounted) {
            setState(() {
              _canCapture = true;
            });
          }
        } else {
          // Aguardar mais um pouco e tentar novamente
          await Future.delayed(const Duration(milliseconds: 700));
          if (_video != null &&
              _video!.videoWidth > 0 &&
              _video!.videoHeight > 0 &&
              _mounted) {
            setState(() {
              _canCapture = true;
            });
          }
        }
      } else {}
    } catch (e) {
      if (_mounted) {
        setState(() {
          _canCapture = false;
        });

        // Log detalhado do erro

        FeedbackUtils.showError(
          context: context,
          title: 'Erro ao Acessar Cá¢mera',
          message: 'Certifique-se de permitir o acesso á  câmera no navegador.',
          errorDetails: e.toString(),
        );
      }
    }
  }

  Future<void> _pararStream() async {
    if (_stream != null) {
      try {
        for (final track in _stream!.getTracks()) {
          track.stop();
        }
      } catch (e) {
        // Ignorar erros ao parar tracks
      }
      _stream = null;
    }
  }

  Future<void> _capture() async {
    if (!_canCapture || _video == null || _canvas == null) return;

    try {
      // Verificar novamente se os elementos ainda existem
      if (_video == null || _canvas == null) return;

      final ctx = _canvas!.context2D;

      // Usar dimensões padrão se o vídeo ainda não estiver carregado
      final width = _video!.videoWidth > 0 ? _video!.videoWidth : 640;
      final height = _video!.videoHeight > 0 ? _video!.videoHeight : 480;

      // Configurar canvas com as dimensões apropriadas
      _canvas!.width = width;
      _canvas!.height = height;

      // Desenhar o frame atual do vídeo no canvas
      ctx.drawImage(_video!, 0, 0);

      final dataUrl = _canvas!.toDataUrl('image/png');

      // Comprimir imagem para máximo 300KB
      final compressedDataUrl =
          await ImageUtils.compressImageToMaxSize(dataUrl);

      // Fechar modal e retornar a imagem comprimida
      Navigator.of(context).pop(compressedDataUrl);
    } catch (e) {
      FeedbackUtils.showError(
        context: context,
        title: 'Erro ao Capturar',
        message: 'Erro ao capturar foto',
        errorDetails: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        decoration: BoxDecoration(
          color: getBackgroundColor(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Cabeá§alho
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: getSurfaceColor(context),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Capturar Foto',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: getTextColor(context),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // área da câmera
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Widget personalizado para exibir vídeo HTML
                      _HtmlVideoWidget(
                        videoElement: _video,
                        rootElement: _root,
                        currentViewType: _currentViewType,
                      ),

                      // Botá£o de captura (sempre visível)
                      Positioned(
                        bottom: 20,
                        child: ElevatedButton.icon(
                          onPressed: _canCapture ? _capture : null,
                          icon: const Icon(Icons.camera_alt, size: 24),
                          label: const Text('Tirar Foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                _canCapture ? Colors.white : Colors.grey,
                            foregroundColor:
                                _canCapture ? Colors.black : Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
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
    );
  }

  @override
  void dispose() {
    _mounted = false;

    // Parar stream da câmera
    _pararStream();

    // Limpar completamente os elementos HTML e DOM
    try {
      if (_video != null) {
        _video!.srcObject = null;
        _video!.removeAttribute('src');
        _video!.remove();
        _video = null;
      }

      if (_canvas != null) {
        _canvas!.remove();
        _canvas = null;
      }

      if (_root != null) {
        // Remover todos os filhos antes de remover o root
        _root!.children.clear();
        _root!.remove();
        _root = null;
      }

      // Limpar elementos DOM antigos com o ID da câmera
      if (_currentViewType != null) {
        final existing =
            html.document.querySelectorAll('[id*="$_currentViewType"]');
        for (final element in existing) {
          element.remove();
          print('Elemento DOM removido no dispose: ${element.id}');
        }
      }
    } catch (e) {
      print('Erro ao limpar elementos no dispose: $e');
    }

    // Resetar estado
    _stream = null;
    _currentViewType = null;

    super.dispose();
  }
}

class _HtmlVideoWidget extends StatelessWidget {
  final html.VideoElement? videoElement;
  final html.DivElement? rootElement;
  final String? currentViewType;

  const _HtmlVideoWidget({
    this.videoElement,
    this.rootElement,
    this.currentViewType,
  });

  @override
  Widget build(BuildContext context) {
    // Só renderizar HtmlElementView quando o viewType estiver registrado,
    // evitando o erro de "unregistered_view_type" e o quadradinho em branco.
    if (currentViewType == null) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    final uniqueKey = 'html-view-${rootElement.hashCode}-$currentViewType';
    return SizedBox.expand(
      child: HtmlElementView(
        key: ValueKey(uniqueKey),
        viewType: currentViewType!,
      ),
    );
  }
}
