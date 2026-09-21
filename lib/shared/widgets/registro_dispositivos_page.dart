import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/services/crypto_utils.dart';
import '../../core/services/feedback_utils.dart';
import '../../core/config/api_config.dart';
import '../../core/services/image_utils.dart';
import '../../core/services/control_id_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'side_panel.dart';
import 'screen_header.dart';
import 'custom_image_picker.dart';
import 'dart:io';

class _IconActionData {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOpaque;
  final bool isMarked;
  final Color? customIconColor;
  final Color? customBackgroundColor;

  const _IconActionData({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
    this.customIconColor,
    this.customBackgroundColor,
  })  : isOpaque = false,
        isMarked = false;
}

// ... (lines 36-898 remain unchanged, skipping them in this tool call for brevity is not possible for replace, so I must target specific blocks)
// Wait, I can't update both class definition (line 19) and _facialWidget (line 4200) in one Replace block if they are far apart.
// I will split this into multiple tool calls.
// This tool call will focus on updating _IconActionData, _buildTransparentIconGroup, and _buildGroupedIcon.
// NO wait, I see I can make multiple ReplaceFileContent calls or one big one if I include everything.
// But the lines are 19-33 and 894-972 and 4236-4265. That's too spread out.
// I will use `multi_replace_file_content`.

//-----------------------------//
// Página lateral para alterar dispositivo
//-----------------------------//

// Funções auxiliares para cores adaptáveis ao tema
bool isDarkMode(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark;
}

Color getBackgroundColor(BuildContext context) {
  return isDarkMode(context) ? Colors.black : Colors.white;
}

Color getCardColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color.fromARGB(255, 40, 40, 40)
      : const Color(0xFFF8F9FB);
}

Color getTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.white : Colors.black;
}

Color getSecondaryTextColor(BuildContext context) {
  return isDarkMode(context) ? Colors.grey[300]! : const Color(0xFF6B7280);
}

Color getBorderColor(BuildContext context) {
  return isDarkMode(context) ? Colors.grey[600]! : Colors.grey.shade300;
}

Color getSurfaceColor(BuildContext context) {
  return isDarkMode(context)
      ? const Color.fromARGB(255, 40, 40, 40)
      : Colors.white;
}

// Função global para obter ícone baseado no tipo de dispositivo
IconData _getIconForDispositivo(String descricao) {
  final desc = descricao.toLowerCase();
  if (desc.contains('facial') || desc.contains('câmera')) {
    return Icons.camera_alt;
  } else if (desc.contains('digital')) {
    return Icons.fingerprint;
  } else if (desc.contains('cartão')) {
    return Icons.credit_card;
  } else if (desc.contains('controle')) {
    return Icons.devices_other;
  } else if (desc.contains('rf-id') || desc.contains('rfid')) {
    return Icons.wifi;
  } else if (desc.contains('senha')) {
    return Icons.lock_outline;
  } else if (desc.contains('chaveiro') || desc.contains('tag')) {
    return Icons.key;
  } else {
    return Icons.devices;
  }
}

// CustomPainter para guias de enquadramento facial
class _FacialGuidePainter extends CustomPainter {
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
class _HtmlVideoWidget extends StatelessWidget {
  final html.VideoElement? videoElement;
  final html.DivElement? rootElement;
  final String? currentViewType;

  const _HtmlVideoWidget({
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
  bool _mounted = true;
  html.DivElement? _root;
  String? _currentViewType;

  @override
  void initState() {
    super.initState();

    // Reset state for fresh start
    _video = null;
    _canvas = null;
    _stream = null;
    _root = null;
    _currentViewType = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inicializarCamera();
    });
  }

  void _registerSimpleViewFactory() {
    _currentViewType ??= 'camera-view-${DateTime.now().millisecondsSinceEpoch}';

    try {
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

      await Future.delayed(const Duration(milliseconds: 200));
      await _startStream();
    } catch (e) {
      if (_mounted) {
        setState(() {
          // Câmera não inicializada
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

      await _pararStream();

      final Map<String, dynamic> constraints = {
        'video': {
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        },
        'audio': false
      };

      if (widget.deviceId != null && widget.deviceId!.isNotEmpty) {
        constraints['video'] = {
          'deviceId': {'exact': widget.deviceId},
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      }

      // Para câmera frontal, forçar facingMode
      if (widget.isFrontal) {
        constraints['video'] = {
          'facingMode': 'user',
          'width': {'ideal': 640},
          'height': {'ideal': 480}
        };
      }

      _stream = await mediaDevices.getUserMedia(constraints);

      if (_video != null && _stream != null) {
        _video!.srcObject = _stream;

        if (_mounted) {
          setState(() {});
          Future.delayed(const Duration(milliseconds: 100), () {
            if (_mounted) setState(() {});
          });
        }

        await Future.delayed(const Duration(milliseconds: 300));

        // Câmera inicializada com sucesso
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          // Câmera não inicializada
        });
      }
    }
  }

  Future<void> _pararStream() async {
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
        Navigator.of(context).pop(compressedDataUrl);
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

      Navigator.of(context).pop(compressedDataUrl);
    } catch (e) {
      // Mesmo em caso de erro, tentar retornar algo
      try {
        _canvas ??= html.CanvasElement(width: 640, height: 480);
        final dataUrl = _canvas!.toDataUrl('image/png');
        final compressedDataUrl =
            await ImageUtils.compressImageToMaxSize(dataUrl);
        Navigator.of(context).pop(compressedDataUrl);
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
            // Cabeçalho
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

            // Área da câmera
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

                      // Overlay de enquadramento facial (apenas para câmera frontal)
                      if (widget.isFrontal)
                        Center(
                          child: Container(
                            width: 250,
                            height: 320,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.8),
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(125),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(125),
                              child: Container(
                                color: Colors.transparent,
                                child: CustomPaint(
                                  painter: _FacialGuidePainter(),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Botão de captura (sempre habilitado)
                      Positioned(
                        bottom: 20,
                        child: ElevatedButton.icon(
                          onPressed: _capture,
                          icon: const Icon(Icons.camera_alt, size: 24),
                          label: const Text('Tirar Foto'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
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

InputDecoration inputDecorationPadrao(BuildContext context,
    {String? hintText}) {
  final isDark = isDarkMode(context);
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: isDark ? const Color(0xFF374151) : Colors.white,
    hintStyle: TextStyle(
      color: isDark ? Colors.grey[400] : const Color(0xFF6B7280),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
        width: 1,
      ),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(
        color: isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB),
        width: 1,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(
        color: Color(0xFF12B76A),
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    isDense: true,
  );
}

// Widget customizado para seleção de dispositivo com lista inline
class _DispositivoSelector extends StatefulWidget {
  final List<Map<String, dynamic>> dispositivos;
  final String? dispositivoSelecionado;
  final ValueChanged<String?> onSelecionadoChanged;

  const _DispositivoSelector({
    required this.dispositivos,
    required this.dispositivoSelecionado,
    required this.onSelecionadoChanged,
  });

  @override
  State<_DispositivoSelector> createState() => _DispositivoSelectorState();
}

class _DispositivoSelectorState extends State<_DispositivoSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dispositivoSelecionado =
        widget.dispositivos.isNotEmpty && widget.dispositivoSelecionado != null
            ? widget.dispositivos.firstWhere(
                (d) => d['id'].toString() == widget.dispositivoSelecionado,
                orElse: () => {'descricao': 'Dispositivo não encontrado'},
              )
            : null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo principal
        GestureDetector(
          onTap: () {
            if (widget.dispositivos.isNotEmpty) {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: getSurfaceColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isExpanded
                    ? const Color(0xFF12B76A)
                    : getBorderColor(context),
                width: _isExpanded ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    dispositivoSelecionado != null
                        ? dispositivoSelecionado['descricao'] ??
                            'Dispositivo selecionado'
                        : 'Selecione o tipo de dispositivo...',
                    style: TextStyle(
                      color: dispositivoSelecionado != null
                          ? getTextColor(context)
                          : getSecondaryTextColor(context),
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(
                  _isExpanded ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                  color: getTextColor(context),
                ),
              ],
            ),
          ),
        ),

        // Lista expansível inline
        if (_isExpanded && widget.dispositivos.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: getCardColor(context),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: getBorderColor(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.dispositivos.length,
              itemBuilder: (context, index) {
                final dispositivo = widget.dispositivos[index];
                final dispositivoId = dispositivo['id'].toString();
                final dispositivoDescricao =
                    dispositivo['descricao'] ?? 'Dispositivo';
                final isSelecionado =
                    dispositivoId == widget.dispositivoSelecionado;

                return InkWell(
                  onTap: () {
                    widget.onSelecionadoChanged(dispositivoId);
                    setState(() {
                      _isExpanded = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: index < widget.dispositivos.length - 1
                          ? Border(
                              bottom: BorderSide(
                                color: getBorderColor(context),
                                width: 2.0,
                              ),
                            )
                          : null,
                      color: isSelecionado
                          ? getSurfaceColor(context).withValues(alpha: 0.5)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _getIconForDispositivo(dispositivoDescricao),
                          size: 20,
                          color: getTextColor(context),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            dispositivoDescricao,
                            style: TextStyle(
                              color: getTextColor(context),
                              fontSize: 14,
                              fontWeight: isSelecionado
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (isSelecionado)
                          Icon(
                            Icons.check_circle,
                            color: const Color(0xFF12B76A),
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class RegistroDispositivosPage extends StatefulWidget {
  final VoidCallback onClose;
  final Map<String, dynamic> morador;
  final bool modoVeiculo;
  final bool modoPrestadorVisitante;

  const RegistroDispositivosPage({
    super.key,
    required this.onClose,
    required this.morador,
    this.modoVeiculo = false,
    this.modoPrestadorVisitante = false,
  });

  @override
  State<RegistroDispositivosPage> createState() =>
      _RegistroDispositivosPageState();
}

class _RegistroDispositivosPageState extends State<RegistroDispositivosPage> {
  String? dispositivoSelecionado;
  List<Map<String, dynamic>> dispositivos = [];
  bool _loadingDispositivos = true;
  String? _errorDispositivos;

  // Controllers para modo veículo
  String? _tipoTagSelecionado;
  late final TextEditingController _senhaControleController;
  late final TextEditingController _tagController;

  // Controller para data de validade (prestador/visitante)
  DateTime? _dataValidadeExame;
  bool _calendarioExpandido = false;
  DateTime? _dataSelecionadaTemporaria =
      DateTime.now(); // Data selecionada no calendário antes de atualizar

  // Estado das rotas: 'verde' = usuário está no equipamento, 'vermelho' = não está, 'cinza' = sem acesso
  List<Map<String, dynamic>> _rotasEstado = [];

  // Log de operações
  List<Map<String, dynamic>> _logs = [];
  bool _isProcessing = false;

  // Variáveis para foto facial
  String? _fotoFacialBase64;
  final bool _carregandoFoto = false;
  int _rotationQuarterTurns = 0;
  bool _savingRotation = false;

  // Variável para foto do usuário vinda da API
  String? _fotoUsuarioUrl;

  // Variáveis para biometria digital
  String? _biometriaAcessoBase64;
  String? _biometriaPanicoBase64;
  bool _carregandoBiometria = false;
  bool _capturandoAcesso = false;
  bool _capturandoPanico = false;
  String? _controlIdSession;
  ControlIdService? _controlIdService;

  //-----------------------------//
  // Variáveis para tags do veículo
  //-----------------------------//
  List<Map<String, dynamic>> _tagsVeiculo = [];
  bool _loadingTagsVeiculo = false;
  String? _errorTagsVeiculo;
  Map<String, dynamic>?
      _tagSelecionadaAtual; // Tag atual selecionada para edição
  //-----------------------------//

  //-----------------------------//
  // Variável para controlar painel lateral de equipamentos
  //-----------------------------//
  bool _mostrarPainelEquipamentos = false;
  bool _mostrarLogLateral = false;
  bool _mostrarPainelFoto = false;
  bool _mostrarEquipamentosInline = false;

  //-----------------------------//
  // Helpers para botões padronizados
  //-----------------------------//
  Widget _buildTransparentIconGroup(List<_IconActionData> actions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor = iconColor.withValues(alpha: 0.3);

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        border:
            Border.all(color: dividerColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(actions.length * 2 - 1, (index) {
          if (index % 2 == 0) {
            final actionIndex = index ~/ 2;
            final action = actions[actionIndex];
            return _buildGroupedIcon(
              action.icon,
              iconColor,
              action.onPressed,
              action.tooltip,
              isLoading: action.isLoading,
              isOpaque: action.isOpaque,
              isMarked: action.isMarked,
              customIconColor: action.customIconColor,
              customBackgroundColor: action.customBackgroundColor,
            );
          } else {
            return _buildDivider(dividerColor);
          }
        }),
      ),
    );
  }

  Widget _buildGroupedIcon(
      IconData icon, Color color, VoidCallback? onPressed, String tooltip,
      {bool isLoading = false,
      bool isOpaque = false,
      bool isMarked = false,
      Color? customIconColor,
      Color? customBackgroundColor,
      double? iconSize}) {
    final tooltipMessage = isOpaque ? '$tooltip (desabilitado)' : tooltip;

    return Tooltip(
      message: tooltipMessage,
      preferBelow: false,
      enableFeedback: true,
      waitDuration: isOpaque
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isOpaque ? Colors.grey.shade800 : const Color(0xFF10133E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        cursor: isLoading
            ? SystemMouseCursors.basic
            : (onPressed == null || isOpaque
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click),
        child: GestureDetector(
          onTap: (isLoading || isOpaque) ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            alignment: Alignment.center,
            decoration: customBackgroundColor != null
                ? BoxDecoration(
                    color: customBackgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  )
                : isOpaque
                    ? BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      )
                    : isMarked
                        ? BoxDecoration(
                            color: const Color(0xFF684F8E),
                            borderRadius: BorderRadius.circular(20),
                          )
                        : null,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: customIconColor ?? color,
                    ),
                  )
                : Icon(
                    icon,
                    color: isLoading
                        ? (customIconColor ?? color).withValues(alpha: 0.5)
                        : (isOpaque
                            ? (customIconColor ?? color).withValues(alpha: 0.35)
                            : (customIconColor ??
                                (isMarked ? Colors.white : color))),
                    size: iconSize ?? (isOpaque ? 24 : 28),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      height: 24,
      width: 1,
      color: color,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _buildStandardActionButtons({
    VoidCallback? onSave,
    VoidCallback? onDelete,
  }) {
    return Center(
      child: _buildTransparentIconGroup([
        if (onDelete != null)
          _IconActionData(
            icon: Icons.delete,
            tooltip: 'Excluir',
            onPressed: _isProcessing ? null : onDelete,
            isLoading: _isProcessing,
          ),
        if (onSave != null)
          _IconActionData(
            icon: Icons.check, // Or Save
            tooltip: 'Salvar',
            onPressed: _isProcessing ? null : onSave,
            isLoading: _isProcessing,
          ),
      ]),
    );
  }
  //-----------------------------//

  //-----------------------------//
  // Variável para nome do associado do veículo
  //-----------------------------//
  String? _nomeAssociadoVeiculo;
  bool _carregandoNomeAssociado = false;
  //-----------------------------//

  //-----------------------------//
  // Carregar nome do associado usando usuarioocupante_id
  //-----------------------------//
  Future<void> _carregarNomeAssociado(int usuarioocupanteId) async {
    if (_carregandoNomeAssociado || usuarioocupanteId == 0) return;

    setState(() {
      _carregandoNomeAssociado = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      // Buscar na API unidadelist para encontrar o usuário
      final url = Uri.parse('${ApiConfig.gateUrl}/unidadelist');

      final payload = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'flg_principal': 'N',
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 && mounted) {
        final data = jsonDecode(response.body);
        final unidades =
            List<Map<String, dynamic>>.from(data['data']?['unidades'] ?? []);

        // Procurar o usuário pelo ID
        final usuarioEncontrado = unidades.firstWhere(
          (u) => (u['usuario_id'] ?? u['id']) == usuarioocupanteId,
          orElse: () => <String, dynamic>{},
        );

        if (usuarioEncontrado.isNotEmpty && mounted) {
          final nome = usuarioEncontrado['nome'] ??
              usuarioEncontrado['nome_txt'] ??
              'Usuário não encontrado';
          setState(() {
            _nomeAssociadoVeiculo = nome.toString();
            _carregandoNomeAssociado = false;
          });
        } else if (mounted) {
          setState(() {
            _nomeAssociadoVeiculo = 'Usuário não encontrado';
            _carregandoNomeAssociado = false;
          });
        }
      } else if (mounted) {
        setState(() {
          _nomeAssociadoVeiculo = 'Erro ao buscar usuário';
          _carregandoNomeAssociado = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar nome do associado: $e');
      if (mounted) {
        setState(() {
          _nomeAssociadoVeiculo = 'Erro ao buscar usuário';
          _carregandoNomeAssociado = false;
        });
      }
    }
  }
  //-----------------------------//

  // Método para adicionar mensagem ao log
  void _addLog(String message, {bool isError = false, bool isSuccess = false}) {
    setState(() {
      _logs.insert(0, {
        'message': message,
        'timestamp': DateTime.now(),
        'isError': isError,
        'isSuccess': isSuccess,
      });
      // Manter apenas as últimas 50 mensagens
      if (_logs.length > 50) {
        _logs = _logs.sublist(0, 50);
      }
    });
  }

  // Método auxiliar para construir seções de formulário
  Widget _buildFormSection(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  //-----------------------------//
  // Widget para construir seção com padding reduzido (tags e logs)
  //-----------------------------//
  Widget _buildFormSectionEstreita(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Método auxiliar para construir campos de formulário
  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: getTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }

  //-----------------------------//
  // Widget para calendário inline expandível
  //-----------------------------//
  Widget _buildInlineCalendar() {
    final hoje = DateUtils.dateOnly(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendário para selecionar data
        CalendarDatePicker2(
          config: CalendarDatePicker2Config(
            calendarType: CalendarDatePicker2Type.single,
            firstDate: hoje,
            lastDate: hoje.add(const Duration(days: 3650)), // 10 anos
            selectedDayHighlightColor:
                const Color(0xFF684F8E), // Highlight color for selected day
            currentDate: hoje, // Mark the current date
            todayTextStyle: const TextStyle(
              color: Color(0xFF684F8E),
              fontWeight: FontWeight.bold,
              decoration: TextDecoration.underline,
            ),
            dayTextStyle: TextStyle(fontSize: 14, color: getTextColor(context)),
            weekdayLabelTextStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: getSecondaryTextColor(context),
            ),
            controlsTextStyle: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
            yearTextStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: getTextColor(context),
            ),
          ),
          value: [_dataSelecionadaTemporaria ?? hoje],
          onValueChanged: (dates) {
            if (dates.isNotEmpty) {
              setState(() {
                _dataSelecionadaTemporaria = dates[0];
              });
            }
          },
        ),
      ],
    );
  }
  //-----------------------------//

  //-----------------------------//
  // Função para atualizar data de validade
  //-----------------------------//
  Future<void> _atualizarDataValidade(DateTime data) async {
    setState(() {
      _dataValidadeExame = data;
      _dataSelecionadaTemporaria = null;
      _calendarioExpandido = false;
    });

    // TODO: Chamar API para atualizar a data de validade
    // Exemplo:
    // await _chamarApiAtualizarDataValidade(data);

    _addLog(
        'Data de validade atualizada para ${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}',
        isSuccess: true);
  }
  //-----------------------------//

  // Método para construir formulário de informações pessoais (prestadores e visitantes)
  Widget _buildFormularioInformacoesPessoais() {
    final morador = widget.morador;
    final isMorador = !widget.modoPrestadorVisitante && !widget.modoVeiculo;

    // Se for veículo, mostrar informações do veículo em 2 colunas
    if (widget.modoVeiculo) {
      // Obter nome do associado usando usuarioocupante_id
      final nomeAssociado = _nomeAssociadoVeiculo ??
          morador['nome_associado'] ??
          morador['proprietario'] ??
          morador['ocupante'] ??
          morador['nome'] ??
          (_carregandoNomeAssociado ? 'Carregando...' : 'Não informado');

      return _buildFormSection(
        'Informações do Veículo',
        [
          // Primeira linha: Placa e Marca
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Placa',
                  child: TextField(
                    controller:
                        TextEditingController(text: morador['placa'] ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                          getSurfaceColor(context).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Marca',
                  child: TextField(
                    controller: TextEditingController(
                        text: morador['marca_auto'] ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                          getSurfaceColor(context).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Segunda linha: Tipo e Cor
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Tipo',
                  child: TextField(
                    controller:
                        TextEditingController(text: morador['tipo'] ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                          getSurfaceColor(context).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormField(
                  label: 'Cor',
                  child: TextField(
                    controller:
                        TextEditingController(text: morador['cor_auto'] ?? ''),
                    enabled: false,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor:
                          getSurfaceColor(context).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: getBorderColor(context)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    style: TextStyle(color: getTextColor(context)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Terceira linha: Associado
          _buildFormField(
            label: 'Associado',
            child: TextField(
              controller: TextEditingController(text: nomeAssociado),
              enabled: false,
              decoration: InputDecoration(
                filled: true,
                fillColor: getSurfaceColor(context).withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
            ),
          ),
          const SizedBox(height: 24),
          // Botão Equipamentos
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _mostrarPainelEquipamentos = true;
                });
              },
              icon: const Icon(Icons.devices, size: 20),
              label: const Text(
                'Equipamentos',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF684F8E),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                elevation: 2,
                shadowColor: const Color(0xFF684F8E).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Se for morador, mostrar apenas Nome e Data Validade com botão Equipamentos
    if (isMorador) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: getCardColor(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor(context)),
        ),
        child: Column(
          children: [
            // Nome

            // Data Validade (Exame médico, etc.) - ÚNICO CAMPO EDITÁVEL
            _buildFormField(
              label: 'Data Validade (Exame médico etc.)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _calendarioExpandido = !_calendarioExpandido;
                              if (_calendarioExpandido) {
                                _dataSelecionadaTemporaria = null;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: getSurfaceColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: getBorderColor(context)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _dataValidadeExame != null
                                        ? '${_dataValidadeExame!.day.toString().padLeft(2, '0')}/${_dataValidadeExame!.month.toString().padLeft(2, '0')}/${_dataValidadeExame!.year}'
                                        : 'Selecionar data',
                                    style: TextStyle(
                                      color: _dataValidadeExame != null
                                          ? getTextColor(context)
                                          : getSecondaryTextColor(context),
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Icon(
                                  _calendarioExpandido
                                      ? Icons.keyboard_arrow_up
                                      : Icons.calendar_today,
                                  color: getSecondaryTextColor(context),
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                final dataParaSalvar =
                                    _dataSelecionadaTemporaria ??
                                        _dataValidadeExame;
                                if (dataParaSalvar == null) {
                                  _addLog('Selecione uma data antes de salvar',
                                      isError: true);
                                  return;
                                }
                                await _atualizarDataValidade(dataParaSalvar);
                              },
                        icon: const Icon(Icons.save, size: 18),
                        label: const Text(
                          'Salvar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF684F8E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _calendarioExpandido
                        ? Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: getCardColor(context),
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: getBorderColor(context)),
                            ),
                            child: _buildInlineCalendar(),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Para prestadores/visitantes, layout simplificado: Nome e Equipamentos
    // RG removido - até 09/02

    // Formatar nome: Nome + primeira letra do sobrenome (ex: Alessandro F.)
    String formatarNome(String? nomeCompleto) {
      if (nomeCompleto == null || nomeCompleto.isEmpty) return '';
      final partes = nomeCompleto.trim().split(' ');
      if (partes.length == 1) return partes[0];
      return '${partes[0]} ${partes[1][0]}.';
    }

    return _buildFormSection(
      'Informações Pessoais',
      [
        // Campo Nome formatado (largura total)
        _buildFormField(
          label: 'Nome',
          child: TextField(
            controller:
                TextEditingController(text: formatarNome(morador['nome'])),
            enabled: false,
            decoration: InputDecoration(
              filled: true,
              fillColor: getSurfaceColor(context).withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        const SizedBox(height: 24),
        // Botão Equipamentos
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _mostrarPainelEquipamentos = true;
              });
            },
            icon: const Icon(Icons.devices, size: 20),
            label: const Text(
              'Equipamentos',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF684F8E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shadowColor: const Color(0xFF684F8E).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Método para construir painel lateral de equipamentos
  Widget _buildPainelEquipamentos() {
    return Column(
      children: [
        // Header do painel
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: getCardColor(context),
            border: Border(
                bottom: BorderSide(color: getBorderColor(context), width: 1)),
          ),
          child: Row(
            children: [
              Icon(Icons.devices, color: getTextColor(context), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Equipamentos aos quais este usuário terá acesso, baseado na configurações de regra',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _mostrarPainelEquipamentos = false;
                  });
                },
                icon: const Icon(Icons.close, size: 24),
                color: getSecondaryTextColor(context),
              ),
            ],
          ),
        ),
        // Conteúdo do painel
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Lista de equipamentos
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _rotasEstado.length,
                    itemBuilder: (context, index) {
                      final rota = _rotasEstado[index];
                      final status = rota['status'] as String;
                      Color? corFundo;
                      Color? corBorda;
                      IconData? icone;
                      Color? corIcone;
                      String tooltipText;
                      Color? corCardFundo;

                      if (status == 'verde') {
                        corFundo = Colors.green;
                        corBorda = Colors.green.shade700;
                        icone = Icons.check;
                        corIcone = Colors.white;
                        tooltipText = 'Usuário está no equipamento';
                        corCardFundo = Colors.green.shade50;
                      } else if (status == 'vermelho') {
                        corFundo = Colors.red;
                        corBorda = Colors.red.shade700;
                        icone = Icons.close;
                        corIcone = Colors.white;
                        tooltipText = 'Usuário não está no equipamento';
                        corCardFundo = Colors.red.shade50;
                      } else {
                        // cinza
                        corFundo = Colors.grey[300];
                        corBorda = Colors.grey[400];
                        icone = null;
                        corIcone = null;
                        tooltipText = 'Usuário não tem acesso ao equipamento';
                        corCardFundo = Colors.grey[100];
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Tooltip(
                          message: tooltipText,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode(context)
                                  ? getSurfaceColor(context)
                                      .withValues(alpha: 0.3)
                                  : corCardFundo?.withValues(alpha: 0.3) ??
                                      getSurfaceColor(context)
                                          .withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDarkMode(context)
                                    ? getBorderColor(context)
                                        .withValues(alpha: 0.3)
                                    : corBorda?.withValues(alpha: 0.2) ??
                                        getBorderColor(context)
                                            .withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: corFundo,
                                    border: Border.all(
                                      color: corBorda ?? Colors.grey,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (corFundo ?? Colors.grey)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: icone != null
                                      ? Icon(
                                          icone,
                                          size: 16,
                                          color: corIcone,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    rota['nome'] ?? 'Equipamento desconhecido',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: getTextColor(context),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Botão de sincronizar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _sincronizarRotas,
                    icon: const Icon(Icons.sync, size: 20),
                    label: const Text(
                      'Sincronizar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF684F8E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      elevation: 2,
                      shadowColor:
                          const Color(0xFF684F8E).withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Método para construir seção de rotas de acesso (mockado)
  Widget _buildRotasAcesso() {
    // Calcular altura para 5 itens (cada item ~58px com padding)
    final alturaItem = 58.0;
    final alturaMaxima = alturaItem * 5;

    return _buildFormSection(
      'Equipamentos aos quais este usuário terá acesso, baseado na configurações de regra',
      [
        // Container com altura fixa e scroll para os itens
        SizedBox(
          height: alturaMaxima,
          child: ListView.builder(
            shrinkWrap: true,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: _rotasEstado.length,
            itemBuilder: (context, index) {
              final rota = _rotasEstado[index];
              final status = rota['status'] as String;
              Color? corFundo;
              Color? corBorda;
              IconData? icone;
              Color? corIcone;
              String tooltipText;
              Color? corCardFundo;

              if (status == 'verde') {
                corFundo = Colors.green;
                corBorda = Colors.green.shade700;
                icone = Icons.check;
                corIcone = Colors.white;
                tooltipText = 'Usuário está no equipamento';
                corCardFundo = Colors.green.shade50;
              } else if (status == 'vermelho') {
                corFundo = Colors.red;
                corBorda = Colors.red.shade700;
                icone = Icons.close;
                corIcone = Colors.white;
                tooltipText = 'Usuário não está no equipamento';
                corCardFundo = Colors.red.shade50;
              } else {
                // cinza
                corFundo = Colors.grey[300];
                corBorda = Colors.grey[400];
                icone = null;
                corIcone = null;
                tooltipText = 'Usuário não tem acesso ao equipamento';
                corCardFundo = Colors.grey[100];
              }

              // Cor alternada para zebra striping
              final bool isEven = index % 2 == 0;
              Color zebraColor = isDarkMode(context)
                  ? (isEven
                      ? getSurfaceColor(context).withValues(alpha: 0.3)
                      : getSurfaceColor(context).withValues(alpha: 0.5))
                  : (isEven
                      ? (corCardFundo?.withValues(alpha: 0.2) ??
                          getSurfaceColor(context).withValues(alpha: 0.3))
                      : (corCardFundo?.withValues(alpha: 0.4) ??
                          getSurfaceColor(context).withValues(alpha: 0.5)));

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tooltip(
                  message: tooltipText,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: zebraColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode(context)
                            ? getBorderColor(context).withValues(alpha: 0.3)
                            : corBorda?.withValues(alpha: 0.2) ??
                                getBorderColor(context).withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: corFundo,
                            border: Border.all(
                              color: corBorda ?? Colors.grey,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: (corFundo ?? Colors.grey)
                                    .withValues(alpha: 0.3),
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: icone != null
                              ? Icon(
                                  icone,
                                  size: 16,
                                  color: corIcone,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            rota['nome'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: getTextColor(context),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        // Botão de sincronizar
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _sincronizarRotas,
            icon: const Icon(Icons.sync, size: 20),
            label: const Text(
              'Sincronizar',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF684F8E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              elevation: 2,
              shadowColor: const Color(0xFF684F8E).withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Método para sincronizar rotas (transforma vermelhos em verdes)
  void _sincronizarRotas() {
    setState(() {
      _rotasEstado = _rotasEstado.map((rota) {
        if (rota['status'] == 'vermelho') {
          return {'nome': rota['nome'], 'status': 'verde'};
        }
        return rota;
      }).toList();
    });
  }

  // Método auxiliar para construir botões de ação
  Widget _buildActionButtons({VoidCallback? onDelete, VoidCallback? onSave}) {
    return Row(
      children: [
        if (onDelete != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : onDelete,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: const Text('Excluir'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
        if (onDelete != null && onSave != null) const SizedBox(width: 12),
        if (onSave != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : onSave,
              icon: _isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: _isProcessing
                  ? const Text('Salvando...')
                  : const Text('Salvar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isProcessing ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
              ),
            ),
          ),
      ],
    );
  }

  // Determinar se é pessoa ou veículo baseado nos dados do morador
  bool get _isPessoa {
    final tipo = widget.morador['tipo'];
    final situacao = widget.morador['situacao'];

    // Se tem tipo 'Veículo' ou situacao que indica veículo, é veículo
    if (tipo == 'Veículo' || situacao == 'V') {
      return false;
    }

    // Por padrão, assume pessoa
    return true;
  }

  @override
  void initState() {
    super.initState();
    print('RegistroDispositivosPage: initState chamado');
    _senhaControleController = TextEditingController();
    _tagController = TextEditingController();
    _novoValorController = TextEditingController();

    // Adicionar listeners para atualizar o estado quando o texto mudar
    _tagController.addListener(() {
      setState(() {});
    });
    _senhaControleController.addListener(() {
      setState(() {});
    });

    // Inicializar data de validade se existir nos dados do morador
    if (widget.morador['data_validade'] != null) {
      try {
        final dataStr = widget.morador['data_validade'].toString();
        DateTime? dataParsed;
        if (dataStr.contains('/')) {
          final parts = dataStr.split('/');
          if (parts.length == 3) {
            dataParsed = DateTime(
                int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } else if (dataStr.contains('-')) {
          dataParsed = DateTime.parse(dataStr);
        }
        if (dataParsed != null) {
          _dataValidadeExame = dataParsed;
        }
      } catch (e) {
        // Ignorar erro ao parsear data
      }
    }

    // Inicializar estado das rotas (exemplo: alguns verdes, alguns vermelhos, alguns cinzas)
    _rotasEstado = [
      {
        'nome': 'DIREITA CONECTCON',
        'status': 'verde'
      }, // Usuário está no equipamento
      {
        'nome': 'ESCRITORIO',
        'status': 'vermelho'
      }, // Usuário não está no equipamento
      {
        'nome': 'ESQUERDA CONECTCON',
        'status': 'verde'
      }, // Usuário está no equipamento
      {'nome': 'FACIAL ESCRITÓRIO ID MAX', 'status': 'cinza'}, // Sem acesso
      {
        'nome': 'INTELBRAS',
        'status': 'vermelho'
      }, // Usuário não está no equipamento
      {'nome': 'TESTE ALPHADIGI', 'status': 'cinza'}, // Sem acesso
    ];

    _carregarTiposDispositivo();

    //-----------------------------//
    // Carregar tags do veículo se for modo veículo
    //-----------------------------//
    if (widget.modoVeiculo) {
      _carregarTagsVeiculo();
      // Carregar nome do associado usando usuarioocupante_id
      final usuarioocupanteId = widget.morador['usuarioocupante_id'];
      if (usuarioocupanteId != null && usuarioocupanteId != 0) {
        _carregarNomeAssociado(usuarioocupanteId);
      }
    }
    //-----------------------------//
  }

  Future<void> _carregarTiposDispositivo() async {
    setState(() {
      _loadingDispositivos = true;
      _errorDispositivos = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';
      // Obter condominio_id e placa
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      final url = Uri.parse(
          '${ApiConfig.gateUrl}/TipoEquipamento/?condominio_id=$condominioId');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final tiposData = data['data'];

        if (tiposData != null) {
          List<Map<String, dynamic>> tiposFiltrados = [];

          tiposFiltrados = List<Map<String, dynamic>>.from(
              tiposData['tipoEquipamento'] ?? []);

          //-----------------------------//
          // Filtrar dispositivos conforme o modo
          //-----------------------------//
          List<Map<String, dynamic>> dispositivosFinais = tiposFiltrados;

          setState(() {
            dispositivos = dispositivosFinais;
            _loadingDispositivos = false;
            // Limpar seleção se o valor atual não for válido
            if (dispositivoSelecionado != null &&
                !dispositivosFinais
                    .any((d) => d['id'].toString() == dispositivoSelecionado)) {
              dispositivoSelecionado = null;
            }
          });
        } else {
          setState(() {
            _errorDispositivos = 'Dados não encontrados na resposta';
            _loadingDispositivos = false;
          });
        }
      } else {
        setState(() {
          _errorDispositivos = 'Erro na API: ${response.statusCode}';
          _loadingDispositivos = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorDispositivos = 'Erro ao carregar tipos: $e';
        _loadingDispositivos = false;
      });
    }
  }

  //-----------------------------//
  // Carregar tags do veículo via API veiculolist
  //-----------------------------//
  Future<void> _carregarTagsVeiculo() async {
    setState(() {
      _loadingTagsVeiculo = true;
      _errorTagsVeiculo = null;
      _tagsVeiculo = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      // Obter condominio_id e placa
      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      final placa = widget.morador['placa'] ?? '';

      if (condominioId.isEmpty || placa.isEmpty) {
        setState(() {
          _errorTagsVeiculo = 'Condomínio ou placa não encontrados';
          _loadingTagsVeiculo = false;
        });
        return;
      }

      final url = Uri.parse('${ApiConfig.gateUrl}/veiculolist');

      // Preparar payload com condominio_id e placa
      final payload = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'placa': placa,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final veiculosData = data['data']?['veiculos'] ?? [];

        if (veiculosData is List && veiculosData.isNotEmpty) {
          final tags = List<Map<String, dynamic>>.from(veiculosData);

          setState(() {
            _tagsVeiculo = tags;
            _loadingTagsVeiculo = false;
            // Não auto-selecionar dispositivo - deixar o usuário escolher manualmente
            dispositivoSelecionado = null;
            _tagSelecionadaAtual = null;
            _tagController.clear();
            _senhaControleController.clear();
          });
        } else {
          setState(() {
            _tagsVeiculo = [];
            _loadingTagsVeiculo = false;
          });
        }
      } else {
        setState(() {
          _errorTagsVeiculo = 'Erro na API: ${response.statusCode}';
          _loadingTagsVeiculo = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorTagsVeiculo = 'Erro ao carregar tags: $e';
        _loadingTagsVeiculo = false;
      });
    }
  }

  //-----------------------------//
  // Identificar tipo de dispositivo pelo dispositivo_Id
  //-----------------------------//
  String _getTipoDispositivoPorId(int? dispositivoId) {
    if (dispositivoId == null) return 'Desconhecido';

    switch (dispositivoId) {
      case 100:
        return 'Tag Control ID';
      case 101:
        return 'Tag Sem Parar';
      case 6:
        return 'Tag Nice';
      case 7:
        return 'Senha';
      case 1:
        return 'Controle';
      case 3:
        return 'Cartão';
      default:
        return 'Desconhecido (ID: $dispositivoId)';
    }
  }

  //-----------------------------//
  // Carregar tag selecionada e preencher campos
  //-----------------------------//
  void _carregarTagSelecionada(Map<String, dynamic> tag) {
    final dispositivoIdTag = tag['dispositivo_Id'] as int?;
    final serialDispositivo = tag['serialDispositivo_txt'] ?? '';
    final usuarioserialId = tag['usuarioserial_id'];

    if (dispositivoIdTag == null) {
      _addLog('Erro: ID do dispositivo não encontrado na tag', isError: true);
      return;
    }

    _addLog(
        'Buscando dispositivo com ID: $dispositivoIdTag na lista de ${dispositivos.length} dispositivos',
        isSuccess: false);

    // Encontrar o dispositivo na lista usando o dispositivo_Id da tag
    // O dispositivo_Id da tag pode corresponder ao 'id' ou 'dispositivo_Id' na lista
    String? idDispositivoParaSelecionar;

    if (dispositivos.isNotEmpty) {
      // Primeiro, tentar encontrar pelo 'id' diretamente
      var dispositivoEncontrado = dispositivos.firstWhere(
        (d) {
          final id = d['id'];
          if (id is int) {
            return id == dispositivoIdTag;
          } else if (id is String) {
            return int.tryParse(id) == dispositivoIdTag;
          }
          return false;
        },
        orElse: () => <String, dynamic>{},
      );

      // Se não encontrou pelo 'id', tentar pelo 'dispositivo_Id'
      if (dispositivoEncontrado.isEmpty) {
        dispositivoEncontrado = dispositivos.firstWhere(
          (d) {
            final dispositivoId = d['dispositivo_Id'];
            if (dispositivoId is int) {
              return dispositivoId == dispositivoIdTag;
            } else if (dispositivoId is String) {
              return int.tryParse(dispositivoId) == dispositivoIdTag;
            }
            return false;
          },
          orElse: () => <String, dynamic>{},
        );
      }

      // Se ainda não encontrou, tentar pela descrição usando o mapeamento
      if (dispositivoEncontrado.isEmpty) {
        final descricaoEsperada = _getTipoDispositivoPorId(dispositivoIdTag);
        _addLog('Tentando encontrar por descrição: $descricaoEsperada',
            isSuccess: false);

        // Mapear descrições conhecidas para palavras-chave de busca
        final palavrasChave = <int, List<String>>{
          100: ['control id', 'control-id', 'tag control'],
          101: ['sem parar', 'semparar', 'tag sem parar'],
          6: ['nice', 'tag nice'],
          7: ['senha'],
          1: ['controle', 'controle remoto'],
          3: ['cartão', 'cartao', 'card'],
        };

        final palavras = palavrasChave[dispositivoIdTag] ??
            [descricaoEsperada.toLowerCase()];

        dispositivoEncontrado = dispositivos.firstWhere(
          (d) {
            final descricao = (d['descricao'] ?? '').toString().toLowerCase();
            return palavras.any((palavra) => descricao.contains(palavra));
          },
          orElse: () => <String, dynamic>{},
        );
      }

      // Log de debug: mostrar todos os dispositivos disponíveis se não encontrou
      if (dispositivoEncontrado.isEmpty) {
        final dispositivosInfo =
            dispositivos.map((d) => '${d['id']}: ${d['descricao']}').join(', ');
        _addLog('Dispositivos disponíveis: $dispositivosInfo', isError: true);
      }

      if (dispositivoEncontrado.isNotEmpty) {
        // Usar o 'id' do dispositivo encontrado para selecionar
        final idEncontrado = dispositivoEncontrado['id'];
        if (idEncontrado != null) {
          idDispositivoParaSelecionar = idEncontrado.toString();
          _addLog(
              'Dispositivo encontrado: ${dispositivoEncontrado['descricao']} (ID: $idDispositivoParaSelecionar)',
              isSuccess: true);
        } else {
          _addLog('Dispositivo encontrado mas sem ID válido', isError: true);
          idDispositivoParaSelecionar = dispositivoIdTag.toString();
        }
      } else {
        // Se não encontrou, tentar usar o dispositivo_Id diretamente
        _addLog(
            'Dispositivo não encontrado na lista. Usando ID da tag: $dispositivoIdTag',
            isError: true);
        idDispositivoParaSelecionar = dispositivoIdTag.toString();
      }
    } else {
      // Se a lista ainda não foi carregada, usar o dispositivo_Id diretamente
      _addLog(
          'Lista de dispositivos vazia. Usando ID da tag: $dispositivoIdTag',
          isError: true);
      idDispositivoParaSelecionar = dispositivoIdTag.toString();
    }

    // Selecionar o dispositivo no dropdown e armazenar a tag selecionada
    // Criar uma cópia da tag para garantir que o estado seja atualizado
    final tagCopy = Map<String, dynamic>.from(tag);
    setState(() {
      dispositivoSelecionado = idDispositivoParaSelecionar;
      _tagSelecionadaAtual = tagCopy; // Armazenar a tag selecionada
      _logs.clear();
    });

    _addLog(
        'Tag selecionada armazenada. usuarioserial_id: ${tagCopy['usuarioserial_id']}',
        isSuccess: false);

    // Preencher os campos com os dados da tag - SEMPRE preencher se houver serial
    if (serialDispositivo.isNotEmpty) {
      // Preencher campo de tag ou senha conforme o tipo
      final descricao = _getTipoDispositivoPorId(dispositivoIdTag);
      final descricaoLower = descricao.toLowerCase();

      // Para todos os tipos de tag, usar _tagController
      if (descricaoLower.contains('tag') ||
          descricaoLower.contains('controle') ||
          descricaoLower.contains('cartão') ||
          descricaoLower.contains('cartao') ||
          descricaoLower.contains('sem parar') ||
          descricaoLower.contains('semparar') ||
          descricaoLower.contains('nice') ||
          descricaoLower.contains('control id') ||
          descricaoLower.contains('control-id')) {
        _tagController.text = serialDispositivo;
        _addLog('Campo Tag preenchido com: $serialDispositivo',
            isSuccess: true);
      } else if (descricaoLower.contains('senha')) {
        _senhaControleController.text = serialDispositivo;
        _addLog('Campo Senha preenchido com: $serialDispositivo',
            isSuccess: true);
      } else {
        // Fallback: se não identificar o tipo, usar _tagController
        _tagController.text = serialDispositivo;
        _addLog('Campo preenchido (fallback) com: $serialDispositivo',
            isSuccess: true);
      }
    } else {
      _addLog('Serial vazio, não foi possível preencher campo', isError: true);
    }

    _addLog(
        'Tag selecionada: ${_getTipoDispositivoPorId(dispositivoIdTag)} (ID: $dispositivoIdTag)',
        isSuccess: true);
    if (usuarioserialId != null && usuarioserialId != 0) {
      _addLog('Tag já cadastrada. Você pode alterar ou cancelar.',
          isSuccess: false);
    } else {
      _addLog('Tag não cadastrada. Você pode cadastrar agora.',
          isSuccess: false);
    }
  }

  //-----------------------------//
  // Cadastrar novo dispositivo via API usuarioserialins
  //-----------------------------//
  //-----------------------------//
  // Verificar se já existe dispositivo do mesmo tipo para veículo
  //-----------------------------//
  bool _jaExisteDispositivoTipo(int dispositivoId) {
    if (!widget.modoVeiculo) return false;

    // Para veículos: verificar se já existe dispositivo com o mesmo ID exato
    // Cada tipo de dispositivo é único: Controle = 1, Tag Control ID = 100, Tag Sem Parar = 101, Tag Nice = 6, Senha = 7, Cartão = 3
    for (final tag in _tagsVeiculo) {
      final tagDispositivoId = tag['dispositivo_Id'] as int?;
      final usuarioserialId = tag['usuarioserial_id'];

      // Só considerar dispositivos realmente cadastrados (usuarioserial_id != 0)
      if (usuarioserialId == null ||
          usuarioserialId == 0 ||
          usuarioserialId == '0') {
        continue;
      }

      // Verificar ID exato - cada dispositivo é único
      if (tagDispositivoId == dispositivoId) {
        return true;
      }
    }
    return false;
  }
  //-----------------------------//

  Future<void> _cadastrarDispositivo(Map<String, dynamic> tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      final usuarioautoId =
          widget.morador['usuarioauto_id'] ?? widget.morador['id'];
      final dispositivoId = tag['dispositivo_Id'] as int?;

      // Para veículos: verificar se já existe dispositivo do mesmo tipo
      if (widget.modoVeiculo && dispositivoId != null) {
        if (_jaExisteDispositivoTipo(dispositivoId)) {
          final descricao = _getTipoDispositivoPorId(dispositivoId);
          _addLog(
              'Erro: Já existe um dispositivo do tipo "$descricao" cadastrado. Exclua o existente para cadastrar um novo.',
              isError: true);
          return;
        }
      }

      // Usar o valor do controller se disponível, senão usar o valor da tag
      final descricao = _getTipoDispositivoPorId(dispositivoId);
      String serialDispositivo;
      if (descricao.contains('Tag') ||
          descricao.contains('Controle') ||
          descricao.contains('Cartão')) {
        serialDispositivo = _tagController.text.isNotEmpty
            ? _tagController.text
            : (tag['serialDispositivo_txt'] ?? '');
      } else if (descricao.contains('Senha')) {
        serialDispositivo = _senhaControleController.text.isNotEmpty
            ? _senhaControleController.text
            : (tag['serialDispositivo_txt'] ?? '');
      } else {
        serialDispositivo = tag['serialDispositivo_txt'] ?? '';
      }
      final panicoFlg = tag['panico_flg'] ?? false;

      if (condominioId.isEmpty ||
          usuarioautoId == null ||
          dispositivoId == null) {
        _addLog('Erro: Dados insuficientes para cadastrar dispositivo',
            isError: true);
        return;
      }

      final url = Uri.parse('${ApiConfig.socialhUrl}/usuarioserialins');

      final payload = {
        'usuarioSerial_Id': 0,
        'condominio_Id': int.tryParse(condominioId) ?? 0,
        'usuario_Id': 0,
        'entradaCadastro_Id': 0,
        'reservaConvidado_Id': 0,
        'usuarioAuto_Id': usuarioautoId,
        'serialDispositivo_txt': serialDispositivo,
        'dispositivo_Id': dispositivoId,
        'panico_flg': panicoFlg,
      };

      _addLog('Cadastrando dispositivo...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          _addLog('Dispositivo cadastrado com sucesso!', isSuccess: true);
          // Recarregar tags após cadastro
          await _carregarTagsVeiculo();
        } else {
          _addLog(
              'Erro ao cadastrar: ${data['message'] ?? 'Erro desconhecido'}',
              isError: true);
        }
      } else {
        _addLog('Erro na API: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _addLog('Erro ao cadastrar dispositivo: $e', isError: true);
    }
  }

  //-----------------------------//
  // Variável para controlar modo de edição
  //-----------------------------//
  bool _editandoDispositivo = false;
  late final TextEditingController _novoValorController;
  //-----------------------------//

  //-----------------------------//
  // Alterar dispositivo via API usuarioserialins
  //-----------------------------//
  Future<void> _alterarDispositivo(Map<String, dynamic> tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      final usuarioautoId =
          widget.morador['usuarioauto_id'] ?? widget.morador['id'];
      final usuarioserialId = tag['usuarioserial_id'];
      final dispositivoId = tag['dispositivo_Id'] as int?;
      // Obter usuario_Id da tag original ou do morador
      final usuarioId = tag['usuario_Id'] ??
          tag['usuario_id'] ??
          widget.morador['usuario_id'] ??
          widget.morador['usuarioocupante_id'] ??
          0;
      // Usar o valor da tag (que pode ter sido atualizado na modal) ou do controller
      final descricao = _getTipoDispositivoPorId(dispositivoId);
      String serialDispositivo;
      // Priorizar o valor da tag (vem da modal com o novo valor), senão usar o controller
      if (tag['serialDispositivo_txt'] != null &&
          tag['serialDispositivo_txt'].toString().isNotEmpty) {
        serialDispositivo = tag['serialDispositivo_txt'].toString();
      } else if (descricao.contains('Tag') ||
          descricao.contains('Controle') ||
          descricao.contains('Cartão')) {
        serialDispositivo =
            _tagController.text.isNotEmpty ? _tagController.text : '';
      } else if (descricao.contains('Senha')) {
        serialDispositivo = _senhaControleController.text.isNotEmpty
            ? _senhaControleController.text
            : '';
      } else {
        serialDispositivo = tag['serialDispositivo_txt'] ?? '';
      }
      final panicoFlg = tag['panico_flg'] ?? false;

      if (condominioId.isEmpty ||
          usuarioautoId == null ||
          dispositivoId == null ||
          usuarioserialId == null ||
          usuarioserialId == 0) {
        _addLog('Erro: Dados insuficientes para alterar dispositivo',
            isError: true);
        return;
      }

      final url = Uri.parse('${ApiConfig.socialhUrl}/usuarioserialins');

      final payload = {
        'usuarioSerial_Id': usuarioserialId, // > 0 para alteração
        'condominio_Id': int.tryParse(condominioId) ?? 0,
        'usuario_Id': usuarioId is int
            ? usuarioId
            : (int.tryParse(usuarioId.toString()) ?? 0),
        'entradaCadastro_Id': 0,
        'reservaConvidado_Id': 0,
        'usuarioAuto_Id': usuarioautoId,
        'serialDispositivo_txt': serialDispositivo,
        'dispositivo_Id': dispositivoId,
        'panico_flg': panicoFlg,
      };

      _addLog('Alterando dispositivo...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          _addLog('Dispositivo alterado com sucesso!', isSuccess: true);
          // Recarregar tags após alteração
          await _carregarTagsVeiculo();
        } else {
          _addLog('Erro ao alterar: ${data['message'] ?? 'Erro desconhecido'}',
              isError: true);
        }
      } else {
        _addLog('Erro na API: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _addLog('Erro ao alterar dispositivo: $e', isError: true);
    }
  }

  //-----------------------------//
  // Atualizar tag via API controleatualizacaoins
  //-----------------------------//
  Future<void> _atualizarTag(Map<String, dynamic> tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final encryptedCondominioId = prefs.getString('condominio_id') ?? '';
      final condominioId = encryptedCondominioId.isNotEmpty
          ? decryptText(encryptedCondominioId)
          : '';

      final usuarioserialId = tag['usuarioserial_id'];
      // O tipoequipamento_id é o dispositivo_Id da tag (ex: 101 para Sem Parar, 100 para Tag Control ID, etc.)
      final dispositivoId = tag['dispositivo_Id'] as int?;

      if (condominioId.isEmpty ||
          usuarioserialId == null ||
          usuarioserialId == 0 ||
          dispositivoId == null) {
        _addLog(
            'Erro: Dados insuficientes para atualizar tag. usuarioserial_id: $usuarioserialId, dispositivo_Id: $dispositivoId',
            isError: true);
        return;
      }

      final url = Uri.parse('${ApiConfig.gateUrl}/controleatualizacaoins');

      // O tipoequipamento_id deve ser o dispositivo_Id da tag (101 = Sem Parar, 100 = Tag Control ID, 6 = Tag Nice, etc.)
      final payload = {
        'condominio_id': int.tryParse(condominioId) ?? 0,
        'id': usuarioserialId, // serealid
        'tiporegra': 0,
        'tipoequipamento_id':
            dispositivoId, // dispositivo_Id da tag (101, 100, 6, etc.)
        'acao_flg': 'I', // fixo
      };

      _addLog(
          'Atualizando tag (tipoequipamento_id: $dispositivoId, usuarioserial_id: $usuarioserialId)...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          _addLog('Tag atualizada com sucesso!', isSuccess: true);
          // Recarregar tags após atualização (para veículos)
          if (widget.modoVeiculo) {
            await _carregarTagsVeiculo();
          }
        } else {
          _addLog(
              'Erro ao atualizar: ${data['message'] ?? 'Erro desconhecido'}',
              isError: true);
        }
      } else {
        _addLog('Erro na API: ${response.statusCode} - ${response.body}',
            isError: true);
      }
    } catch (e) {
      _addLog('Erro ao atualizar tag: $e', isError: true);
    }
  }
  //-----------------------------//

  //-----------------------------//
  // Excluir dispositivo via API usuarioserialdel
  //-----------------------------//
  Future<void> _excluirDispositivo(Map<String, dynamic> tag) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      final usuarioserialId = tag['usuarioserial_id'];

      if (usuarioserialId == null || usuarioserialId == 0) {
        _addLog('Erro: Dispositivo não encontrado para exclusão',
            isError: true);
        return;
      }

      final url = Uri.parse('${ApiConfig.socialhUrl}/usuarioserialdel');

      final payload = {
        'usuarioSerial_Id': usuarioserialId,
      };

      _addLog('Excluindo dispositivo...');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 200) {
          _addLog('Dispositivo excluído com sucesso!', isSuccess: true);
          // Recarregar tags após exclusão
          await _carregarTagsVeiculo();
          // Limpar seleção de dispositivo
          setState(() {
            dispositivoSelecionado = null;
          });
        } else {
          _addLog('Erro ao excluir: ${data['message'] ?? 'Erro desconhecido'}',
              isError: true);
        }
      } else {
        _addLog('Erro na API: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _addLog('Erro ao excluir dispositivo: $e', isError: true);
    }
  }
  //-----------------------------//

  // Método para carregar foto do usuário via API FotoListar
  Future<void> _carregarFotoUsuario() async {
    // Tentar obter usuario_id de várias formas possíveis
    final usuarioId = widget.morador['usuario_id'] ??
        widget.morador['id'] ??
        widget.morador['usuarioId'] ??
        widget.morador['ID'];

    var condominioId =
        widget.morador['condominio_id'] ?? widget.morador['condominio'] ?? 0;

    // Se não encontrou no widget, busca nas preferências
    if (condominioId == 0) {
      final cid = await ApiConfig.getCondominioId();
      if (cid.isNotEmpty) {
        condominioId = int.tryParse(cid) ?? 0;
      }
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

      final url = Uri.parse('${ApiConfig.gateUrl}/FotoListar');

      final payload = {
        "usuario_id": usuarioId,
        "tipoUSU": "USU",
        "condominio_id": condominioId,
      };
      print('payload: ${payload}');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${decryptText(encryptedToken)}',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        // Tentativa de extrair a foto da resposta
        String? fotoUrl;
        String? fotoBase64;

        if (responseData is List && responseData.isNotEmpty) {
          final item = responseData.first;
          fotoUrl = item['fotourl'] ?? item['foto'];

          if (fotoUrl != null &&
              !fotoUrl.toLowerCase().startsWith('http') &&
              fotoUrl.length > 200) {
            // Se não for URL http e for longo, assumimos que é base64 erroneamente colocado no campo.
            // Mas o pedido é "nunca mostrar a fotobase64", então ignoramos.
            fotoUrl = null;
          }
        } else if (responseData is Map) {
          // Checa se há data wrapping
          var data = responseData['data'] ?? responseData;

          // Se data for uma lista (ex: { "data": [ ... ] }), pega o primeiro item
          if (data is List && data.isNotEmpty) {
            data = data.first;
          }

          if (data is Map) {
            fotoUrl = data['fotourl'] ?? data['foto'];

            if (fotoUrl != null &&
                !fotoUrl.toLowerCase().startsWith('http') &&
                fotoUrl.length > 200) {
              fotoUrl = null;
            }
          }
        }

        print('Foto URL recebida: $fotoUrl');

        // Forçar uso apenas da URL e evitar cache
        if (fotoUrl != null && fotoUrl.toString().isNotEmpty) {
          final urlComTimestamp =
              '$fotoUrl?t=${DateTime.now().millisecondsSinceEpoch}';
          setState(() {
            _fotoUsuarioUrl = urlComTimestamp;
            _fotoFacialBase64 = null;
          });
        } else {
          setState(() {
            _fotoUsuarioUrl = null;
            _fotoFacialBase64 = null;
          });
        }
      } else {
        print(
            'Erro na resposta da API FotoListar: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Erro ao carregar foto do usuário: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final moradorNome = widget.morador['nome'] ?? 'Morador';
    return Container(
      color: getBackgroundColor(context),
      child: Stack(
        children: [
          Column(
            children: [
              // Header
              ScreenHeader(
                icon: Icons.devices_other,
                title: 'Cadastro de Acesso - / $moradorNome',
                subtitle: '',
                onClose: widget.onClose,
                actions: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _mostrarLogLateral = true;
                      });
                    },
                    icon: const Icon(Icons.history,
                        color: Colors.white, size: 20),
                    tooltip: 'Log de Operações',
                  ),
                ],
              ),

              // Conteúdo principal
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: _buildLayoutComSelecao(),
                ),
              ),
            ],
          ),
          // Painel lateral de equipamentos
          if (_mostrarPainelEquipamentos)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _mostrarPainelEquipamentos = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {}, // Prevenir fechamento ao clicar no painel
                        child: SidePanel(
                          onClose: () {
                            setState(() {
                              _mostrarPainelEquipamentos = false;
                            });
                          },
                          child: _buildPainelEquipamentos(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Painel lateral de Log
          if (_mostrarLogLateral)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _mostrarLogLateral = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {},
                        child: SidePanel(
                          onClose: () {
                            setState(() {
                              _mostrarLogLateral = false;
                            });
                          },
                          child: Column(
                            children: [
                              ScreenHeader(
                                icon: Icons.receipt_long,
                                title: 'Log de Operações',
                                subtitle: '',
                                onClose: () {
                                  setState(() {
                                    _mostrarLogLateral = false;
                                  });
                                },
                              ),
                              Expanded(child: _buildLogOperacoes()),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Painel lateral de Foto Facial
          if (_mostrarPainelFoto)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _mostrarPainelFoto = false;
                    });
                  },
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {}, // Prevenir fechamento ao clicar no painel
                        child: SidePanel(
                          onClose: () {
                            setState(() {
                              _mostrarPainelFoto = false;
                            });
                          },
                          child: Column(
                            children: [
                              ScreenHeader(
                                icon: Icons.camera_alt,
                                title: 'Cadastro Facial',
                                subtitle: '',
                                onClose: () {
                                  setState(() {
                                    _mostrarPainelFoto = false;
                                  });
                                },
                              ),
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    children: [
                                      const Text(
                                        'Tire uma foto para o reconhecimento facial',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 32),
                                      CustomImagePicker(
                                        onImageSelected: (String path) async {
                                          print(
                                              'Foto selecionada: ${path.length > 100 ? '${path.substring(0, 100)}...' : path}');

                                          try {
                                            String base64String;

                                            if (kIsWeb) {
                                              // Na web, pode ser um blob URL (galeria) ou base64 direto (câmera)
                                              if (path.startsWith('blob:') ||
                                                  path.startsWith('http')) {
                                                final bytes =
                                                    await _readBytesFromWeb(
                                                        path);
                                                base64String =
                                                    base64Encode(bytes);
                                              } else {
                                                // Já é base64 (limpar prefixo se houver)
                                                if (path.contains(',')) {
                                                  base64String =
                                                      path.split(',').last;
                                                } else {
                                                  base64String = path;
                                                }
                                              }
                                            } else {
                                              // Mobile: é sempre um caminho de arquivo
                                              final bytes = await File(path)
                                                  .readAsBytes();
                                              base64String =
                                                  base64Encode(bytes);
                                            }

                                            print(
                                                'Foto convertida para base64, tamanho: ${base64String.length} caracteres');

                                            if (mounted) {
                                              setState(() {
                                                _fotoFacialBase64 =
                                                    base64String;
                                                _fotoUsuarioUrl = null;
                                                _mostrarPainelFoto = false;
                                                _mostrarEquipamentosInline =
                                                    false;
                                              });

                                              _addLog(
                                                  'Foto capturada. Clique em "Atualizar Equipamentos" para enviar.',
                                                  isSuccess: false);
                                            }
                                          } catch (e) {
                                            print('Erro ao processar foto: $e');
                                            if (mounted) {
                                              _addLog(
                                                  'Erro ao processar foto: $e',
                                                  isError: true);
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
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
        ],
      ),
    );
  }

  // Método para construir o layout com seleção e campos
  Widget _buildLayoutComSelecao() {
    if (widget.modoVeiculo) {
      // Layout para veículo: tags do mesmo tamanho que informações pessoais/equipamentos
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coluna esquerda: seleção e formulário
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Formulário de informações pessoais
                _buildFormularioInformacoesPessoais(),
                const SizedBox(height: 16),
                // Campo de seleção de dispositivo (sem título)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: getCardColor(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: getBorderColor(context)),
                  ),
                  child: _buildFormField(
                    label: '',
                    child: _loadingDispositivos
                        ? const SizedBox(
                            height: 48,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : _errorDispositivos != null
                            ? SizedBox(
                                height: 48,
                                child: Center(
                                  child: Text(
                                    _errorDispositivos!,
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 14),
                                  ),
                                ),
                              )
                            : Container(
                                child: _DispositivoSelector(
                                  dispositivos: dispositivos,
                                  dispositivoSelecionado:
                                      dispositivoSelecionado,
                                  onSelecionadoChanged: (valor) async {
                                    if (mounted) {
                                      // Encontrar o dispositivo selecionado na lista para obter o dispositivo_Id
                                      Map<String, dynamic>?
                                          dispositivoEncontrado;
                                      if (valor != null) {
                                        try {
                                          dispositivoEncontrado =
                                              dispositivos.firstWhere(
                                            (d) => d['id'].toString() == valor,
                                          );
                                        } catch (e) {
                                          dispositivoEncontrado = null;
                                        }
                                      }

                                      // Verificar se já existe uma tag cadastrada para este dispositivo específico
                                      Map<String, dynamic>? tagExistente;
                                      if (dispositivoEncontrado != null &&
                                          widget.modoVeiculo) {
                                        final dispositivoId =
                                            dispositivoEncontrado[
                                                    'dispositivo_Id'] ??
                                                dispositivoEncontrado['id'];

                                        // Buscar tag existente com o mesmo dispositivo_Id exato
                                        // Cada tipo de dispositivo é único: Tag Control ID (100) ≠ Tag Sem Parar (101) ≠ Tag Nice (6)
                                        for (final tag in _tagsVeiculo) {
                                          final tagDispositivoId =
                                              tag['dispositivo_Id'] as int?;
                                          final usuarioserialId =
                                              tag['usuarioserial_id'];

                                          // Só considerar tags realmente cadastradas
                                          if (usuarioserialId == null ||
                                              usuarioserialId == 0 ||
                                              usuarioserialId == '0') {
                                            continue;
                                          }

                                          // Verificar ID exato - cada dispositivo é único
                                          if (tagDispositivoId ==
                                              dispositivoId) {
                                            tagExistente = tag;
                                            break;
                                          }
                                        }
                                      }

                                      setState(() {
                                        dispositivoSelecionado = valor;

                                        if (tagExistente != null) {
                                          // Se já existe tag cadastrada, usar os dados dela
                                          _tagSelecionadaAtual = tagExistente;

                                          // Preencher os campos com os dados da tag existente
                                          final serial = tagExistente[
                                                  'serialDispositivo_txt'] ??
                                              '';
                                          final descricao =
                                              _getTipoDispositivoPorId(
                                                  tagExistente['dispositivo_Id']
                                                      as int?);

                                          if (descricao.contains('Tag') ||
                                              descricao.contains('Controle') ||
                                              descricao.contains('Cartão')) {
                                            _tagController.text = serial;
                                            _senhaControleController.clear();
                                          } else if (descricao
                                              .contains('Senha')) {
                                            _senhaControleController.text =
                                                serial;
                                            _tagController.clear();
                                          } else {
                                            _tagController.clear();
                                            _senhaControleController.clear();
                                          }
                                        } else if (dispositivoEncontrado !=
                                            null) {
                                          // Se não existe tag cadastrada, criar novo cadastro
                                          _tagSelecionadaAtual = {
                                            'dispositivo_Id':
                                                dispositivoEncontrado[
                                                        'dispositivo_Id'] ??
                                                    dispositivoEncontrado['id'],
                                            'usuarioserial_id':
                                                0, // Novo cadastro
                                            'serialDispositivo_txt': '',
                                          };
                                          _tagController.clear();
                                          _senhaControleController.clear();
                                        } else {
                                          _tagSelecionadaAtual = null;
                                          _tagController.clear();
                                          _senhaControleController.clear();
                                        }
                                        _logs.clear();
                                      });

                                      // Carregar foto do usuário quando selecionar dispositivo facial
                                      if (valor != null) {
                                        final descricao =
                                            _getDescricaoDispositivo(valor);

                                        if (descricao == 'FACIAL') {
                                          // Desconectar Control ID se estava conectado
                                          if (_controlIdService != null) {
                                            _controlIdSession = null;
                                            _biometriaAcessoBase64 = null;
                                            _biometriaPanicoBase64 = null;
                                          }
                                          await _carregarFotoUsuario();
                                        } else if (descricao == 'Digital') {
                                          // Conectar ao Control ID quando selecionar Digital
                                          await _conectarControlId();
                                        } else {
                                          // Desconectar Control ID se mudou para outro tipo
                                          if (_controlIdService != null) {
                                            _controlIdSession = null;
                                            _biometriaAcessoBase64 = null;
                                            _biometriaPanicoBase64 = null;
                                          }
                                        }
                                      } else {
                                        // Desconectar Control ID se deselecionou
                                        if (_controlIdService != null) {
                                          await _controlIdService!.disconnect();
                                          _controlIdSession = null;
                                          _biometriaAcessoBase64 = null;
                                          _biometriaPanicoBase64 = null;
                                        }
                                      }
                                    }
                                  },
                                ),
                              ),
                  ),
                ),

                const SizedBox(height: 16),

                // Campos de cadastro (só aparece quando dispositivo selecionado)
                if (dispositivoSelecionado != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: _buildConteudoPorTipo(dispositivoSelecionado),
                      ),
                    ),
                  ),

                // Placeholder removido
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Coluna direita: tags do veículo (metade da largura)
          Expanded(
            flex: 1,
            child: _buildTagsVeiculo(),
          ),
        ],
      );
    } else {
      // Layout original para não-veículo (sem log lateral)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulário de informações pessoais
          _buildFormularioInformacoesPessoais(),
          const SizedBox(height: 16),
          // Campo de seleção de dispositivo
          _buildFormSection(
            'Seleção de Dispositivo',
            [
              _loadingDispositivos
                  ? const SizedBox(
                      height: 48,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _errorDispositivos != null
                      ? SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              _errorDispositivos!,
                              style: TextStyle(color: Colors.red, fontSize: 14),
                            ),
                          ),
                        )
                      : Container(
                          child: _DispositivoSelector(
                            dispositivos: dispositivos,
                            dispositivoSelecionado: dispositivoSelecionado,
                            onSelecionadoChanged: (valor) async {
                              if (mounted) {
                                setState(() {
                                  dispositivoSelecionado = valor;
                                  _tagSelecionadaAtual =
                                      null; // Limpar tag selecionada ao mudar dispositivo
                                  _tagController.clear();
                                  _senhaControleController.clear();
                                  _logs.clear();
                                });

// Carregar foto do usuário quando selecionar dispositivo facial
                                if (valor != null) {
                                  final descricao =
                                      _getDescricaoDispositivo(valor)
                                              ?.toLowerCase() ??
                                          '';

                                  if (descricao.contains('facial')) {
                                    // Desconectar Control ID se estava conectado
                                    if (_controlIdService != null) {
                                      await _controlIdService!.disconnect();
                                      _controlIdSession = null;
                                      _biometriaAcessoBase64 = null;
                                      _biometriaPanicoBase64 = null;
                                    }
                                    await _carregarFotoUsuario();
                                  } else if (descricao.contains('digital') ||
                                      descricao.contains('biometria')) {
                                    // Conectar ao Control ID quando selecionar Digital
                                    await _conectarControlId();
                                  } else {
                                    // Desconectar Control ID se mudou para outro tipo
                                    if (_controlIdService != null) {
                                      await _controlIdService!.disconnect();
                                      _controlIdSession = null;
                                      _biometriaAcessoBase64 = null;
                                      _biometriaPanicoBase64 = null;
                                    }
                                  }
                                } else {
                                  // Desconectar Control ID se deselecionou
                                  if (_controlIdService != null) {
                                    await _controlIdService!.disconnect();
                                    _controlIdSession = null;
                                    _biometriaAcessoBase64 = null;
                                    _biometriaPanicoBase64 = null;
                                  }
                                }
                              }
                            },
                          ),
                        ),
            ],
          ),

          const SizedBox(height: 16),

          // Campos de cadastro (só aparece quando dispositivo selecionado)
          if (dispositivoSelecionado != null)
            Expanded(
              child: SingleChildScrollView(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildConteudoPorTipo(dispositivoSelecionado),
                ),
              ),
            ),

          // Placeholder removido
        ],
      );
    }
  }

  //-----------------------------//
  // Widget para exibir tags cadastradas do veículo
  //-----------------------------//
  Widget _buildTagsVeiculo() {
    // Calcular altura baseada em Informações do Veículo
    // Card "Informações do Veículo" tem:
    // - Padding: 16px (top) + 16px (bottom) = 32px
    // - Título: ~20px
    // - Espaçamento após título: 16px
    // - Linha 1 (Placa/Marca): label (~20px) + campo (~48px) = ~68px
    // - Espaçamento: 16px
    // - Linha 2 (Tipo/Cor): label (~20px) + campo (~48px) = ~68px
    // - Espaçamento: 16px
    // - Linha 3 (Associado): label (~20px) + campo (~48px) = ~68px
    // - Espaçamento antes do botão: 24px
    // - Botão: ~48px
    // Total: 16 + 20 + 16 + 68 + 16 + 68 + 16 + 68 + 24 + 48 + 16 = ~420px
    final alturaInformacoesVeiculo = 317.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tags cadastradas (mesmo tamanho que Informações do Veículo)
        _buildFormSectionEstreita(
          'Tags Cadastradas',
          [
            // Calcular altura padrão (mesma de informações do veículo)
            Builder(
              builder: (context) {
                final alturaMaxima = alturaInformacoesVeiculo;

                if (_loadingTagsVeiculo) {
                  return SizedBox(
                    height: alturaMaxima,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else if (_errorTagsVeiculo != null)
                  return SizedBox(
                    height: alturaMaxima,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _errorTagsVeiculo!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                else if (_tagsVeiculo.isEmpty)
                  return SizedBox(
                    height: alturaMaxima,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.label_outline,
                            size: 48,
                            color: getSecondaryTextColor(context),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nenhuma tag cadastrada',
                            style: TextStyle(
                              color: getSecondaryTextColor(context),
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                else
                  return SizedBox(
                    height: alturaMaxima,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: _tagsVeiculo.length,
                      itemBuilder: (context, index) {
                        final tag = _tagsVeiculo[index];
                        final dispositivoId = tag['dispositivo_Id'] as int?;
                        final tipoDispositivo =
                            _getTipoDispositivoPorId(dispositivoId);
                        final serialDispositivo =
                            tag['serialDispositivo_txt'] ?? '';
                        final usuarioserialId = tag['usuarioserial_id'];
                        final panicoFlg = tag['panico_flg'] ?? false;
                        // Se usuarioserial_id for 0 ou null, não foi criado dispositivo ainda
                        final temDispositivo =
                            usuarioserialId != null && usuarioserialId != 0;

                        // Cor alternada para zebra striping
                        final bool isEven = index % 2 == 0;
                        Color zebraColor = isEven
                            ? getCardColor(context)
                            : getSurfaceColor(context).withValues(alpha: 0.5);

                        return InkWell(
                          onTap: () {
                            // Selecionar o dispositivo e carregar os dados da tag
                            _carregarTagSelecionada(tag);
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: zebraColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: temDispositivo
                                    ? const Color(0xFF12B76A)
                                    : getBorderColor(context),
                                width: temDispositivo ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _getIconForDispositivo(tipoDispositivo),
                                      size: 20,
                                      color: temDispositivo
                                          ? const Color(0xFF12B76A)
                                          : getSecondaryTextColor(context),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tipoDispositivo,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: getTextColor(context),
                                        ),
                                      ),
                                    ),
                                    if (temDispositivo)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF12B76A)
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Ativo',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF12B76A),
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Não cadastrado',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                getSecondaryTextColor(context),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (temDispositivo &&
                                    serialDispositivo.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Serial: $serialDispositivo',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: getSecondaryTextColor(context),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
              },
            ),
          ],
        ),
        // Log de operações
        const SizedBox(height: 16),
        Expanded(
          child: _buildLogOperacoes(useExpanded: true),
        ),
      ],
    );
  }

  //-----------------------------//
  // Widget para exibir log de operações
  //-----------------------------//
  Widget _buildLogOperacoes({bool useExpanded = true}) {
    final logContent = Container(
      decoration: BoxDecoration(
        color: getSurfaceColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: _logs.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma operação registrada',
                      style: TextStyle(
                        color: getSecondaryTextColor(context),
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              reverse: false,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return _buildLogItem(log);
              },
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cabeçalho do log
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          decoration: BoxDecoration(
            color: getCardColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: getBorderColor(context)),
          ),
          child: Row(
            children: [
              const Icon(Icons.receipt_long, size: 20),
              const SizedBox(width: 8),
              Text(
                'Log de Operações',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: getTextColor(context),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Área do log
        useExpanded
            ? Expanded(child: logContent)
            : SizedBox(height: 200, child: logContent),
      ],
    );
  }

  // Método para construir um item do log
  Widget _buildLogItem(Map<String, dynamic> log) {
    final timestamp = log['timestamp'] as DateTime;
    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

    Color iconColor;
    IconData iconData;

    if (log['isSuccess'] == true) {
      iconColor = Colors.green;
      iconData = Icons.check_circle;
    } else if (log['isError'] == true) {
      iconColor = Colors.red;
      iconData = Icons.error;
    } else {
      iconColor = getSecondaryTextColor(context);
      iconData = Icons.info;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log['message'],
                  style: TextStyle(
                    color: getTextColor(context),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
                Text(
                  timeStr,
                  style: TextStyle(
                    color: getSecondaryTextColor(context),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getDescricaoDispositivo(String? id) {
    if (id == null) return null;
    final dispositivo = dispositivos.firstWhere(
      (d) => d['id'].toString() == id,
      orElse: () => <String, dynamic>{},
    );
    return dispositivo['descricao'];
  }

  Widget _buildConteudoPorTipo(String? id) {
    final descricao = _getDescricaoDispositivo(id);
    if (descricao == null) return _emptyState();

    final descricaoLower = descricao.toLowerCase();

    // Verificar por palavras-chave para garantir que funcione mesmo com variações
    if (descricaoLower.contains('facial') ||
        descricaoLower.contains('câmera') ||
        descricaoLower.contains('camera') ||
        descricaoLower.contains('lpr')) {
      return _facialWidget();
    } else if (descricaoLower.contains('digital') ||
        descricaoLower.contains('biometria')) {
      return _digitalWidget();
    } else if (descricaoLower.contains('cartão') ||
        descricaoLower.contains('cartao') ||
        descricaoLower.contains('controle') ||
        descricaoLower.contains('rf-id') ||
        descricaoLower.contains('rfid')) {
      return _controleWidget();
    } else if (descricaoLower.contains('senha')) {
      return _senhaWidget();
    } else if (descricaoLower.contains('chaveiro')) {
      return _chaveiroWidget();
    } else if (descricaoLower.contains('control id') ||
        descricaoLower.contains('control-id') ||
        descricaoLower.contains('controlid')) {
      return _tagControlIdWidget();
    } else if (descricaoLower.contains('nice')) {
      return _tagNiceWidget();
    } else if (descricaoLower.contains('sem parar') ||
        descricaoLower.contains('semparar') ||
        descricaoLower.contains('sem-parar')) {
      return _tagSemPararWidget();
    } else if (descricaoLower.contains('tag')) {
      // Fallback para qualquer outra tag
      return _tagWidget();
    } else {
      return _emptyState();
    }
  }

  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.devices_other_outlined,
            size: 64,
            color: getSecondaryTextColor(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Selecione um dispositivo para registrar',
            style: TextStyle(
              fontSize: 16,
              color: getSecondaryTextColor(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<void> _salvarRotacao() async {
    if (_rotationQuarterTurns == 0) return;

    setState(() {
      _savingRotation = true;
    });

    try {
      await _ensurePhotoLoaded();

      if (_fotoFacialBase64 != null) {
        String rotatedBase64 = await ImageUtils.rotateImage(
            _fotoFacialBase64!, _rotationQuarterTurns);

        // Remover prefixo data:image se existir para manter consistência
        if (rotatedBase64.contains(',')) {
          rotatedBase64 = rotatedBase64.split(',').last;
        }

        // Atualizar estado local com a imagem rotacionada e resetar rotação
        setState(() {
          _fotoFacialBase64 = rotatedBase64;
          _rotationQuarterTurns = 0;
        });

        // Chamar API para salvar a nova imagem
        await _salvarFotoFacial();
      }
    } catch (e) {
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Falha ao salvar rotação: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingRotation = false;
        });
      }
    }
  }

  Future<void> _ensurePhotoLoaded() async {
    if (_fotoFacialBase64 != null) return;

    if (_fotoUsuarioUrl != null && _fotoUsuarioUrl!.isNotEmpty) {
      try {
        final response = await http.get(Uri.parse(_fotoUsuarioUrl!));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          if (mounted) {
            setState(() {
              _fotoFacialBase64 = base64Encode(bytes);
            });
          }
        }
      } catch (e) {
        print('Erro ao baixar foto para rotação: $e');
        rethrow;
      }
    }
  }

  Future<void> _salvarFotoFacial() async {
    try {
      if (_fotoFacialBase64 == null) return;

      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final token = decryptText(encryptedToken);

      final usuarioId = widget.morador['usuario_id'] ??
          widget.morador['id'] ??
          widget.morador['usuarioId'] ??
          widget.morador['ID'];
      var condominioId =
          widget.morador['condominio_id'] ?? widget.morador['condominio'] ?? 0;
      if (condominioId == 0) {
        final cid = await ApiConfig.getCondominioId();
        condominioId = int.tryParse(cid) ?? 0;
      }

      final url = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');

      // Garantir que a foto esteja no formato correto (sem prefixo data:image)
      String fotoToSend = _fotoFacialBase64!;
      if (fotoToSend.contains(',')) {
        fotoToSend = fotoToSend.split(',').last;
      }

      final payload = {
        "usuario_id": usuarioId,
        "tipoUSU": "USU",
        "condominio_id": condominioId,
        "foto": fotoToSend,
        "atualizarEquipamento": true,
        "ordem_num": 1,
      };

      final response = await http.post(url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token'
          },
          body: jsonEncode(payload));

      if (response.statusCode == 200) {
        _addLog('Foto atualizada com sucesso!', isSuccess: true);
        if (mounted) {
          FeedbackUtils.showSuccess(
            context: context,
            title: 'Foto Atualizada',
            message: 'Foto atualizada com sucesso!',
          );
        }
        await _carregarFotoUsuario();
      } else {
        throw Exception('Erro ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _addLog('Erro ao salvar foto: $e', isError: true);
      rethrow;
    }
  }

  Widget _facialWidget() {
    final temFoto = _fotoFacialBase64 != null ||
        (_fotoUsuarioUrl != null && _fotoUsuarioUrl!.isNotEmpty);

    final colunaFoto = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 320,
          height: 320,
          decoration: BoxDecoration(
            color: getSurfaceColor(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: getBorderColor(context)),
          ),
          child: Builder(
            builder: (context) {
              Widget imageWidget;
              if (_fotoFacialBase64 != null) {
                imageWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.memory(
                    base64Decode(_fotoFacialBase64!),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                );
              } else if (_fotoUsuarioUrl != null &&
                  _fotoUsuarioUrl!.isNotEmpty) {
                imageWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: Image.network(
                    _fotoUsuarioUrl!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.broken_image,
                          size: 48, color: Colors.grey);
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                );
              } else {
                imageWidget = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.face,
                      size: 64,
                      color: getSecondaryTextColor(context),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Foto do usuário',
                      style: TextStyle(
                        color: getSecondaryTextColor(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nenhuma foto encontrada',
                      style: TextStyle(
                        color: getSecondaryTextColor(context),
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }
              return RotatedBox(
                quarterTurns: _rotationQuarterTurns,
                child: imageWidget,
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        _buildTransparentIconGroup([
          if (temFoto)
            _IconActionData(
              icon: Icons.rotate_right,
              tooltip: 'Girar Foto',
              onPressed: () {
                setState(() {
                  _rotationQuarterTurns++;
                });
              },
            ),
          if (_rotationQuarterTurns % 4 != 0)
            _IconActionData(
              icon: Icons.save,
              tooltip: 'Salvar Alteração',
              onPressed: _savingRotation ? null : _salvarRotacao,
              isLoading: _savingRotation,
              customBackgroundColor: const Color(0xFF12B76A),
              customIconColor: Colors.white,
            ),
          if (temFoto)
            _IconActionData(
              icon: Icons.delete_outline,
              tooltip: 'Excluir Foto',
              onPressed: () {
                _addLog('Registro facial excluído (não salvo)', isError: true);
                setState(() {
                  _fotoFacialBase64 = null;
                  _fotoUsuarioUrl = null;
                  _rotationQuarterTurns = 0;
                  _mostrarEquipamentosInline = false;
                });
              },
              customIconColor: Colors.red,
            ),
          _IconActionData(
            icon: Icons.camera_alt,
            tooltip: 'Tirar Foto do Usuário',
            onPressed: _carregandoFoto ? null : _tirarFotoFacial,
            isLoading: _carregandoFoto,
            customBackgroundColor: Colors.white,
            customIconColor: const Color(0xFF684F8E),
          ),
          if (temFoto)
            _IconActionData(
              icon: Icons.sync,
              tooltip: 'Atualizar Equipamentos',
              onPressed: _isProcessing
                  ? null
                  : () async {
                      await _atualizarEquipamentos();
                    },
              isLoading: _isProcessing,
            ),
        ]),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormSection(
          'Configuração Facial',
          [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 320, child: colunaFoto),
                if (_mostrarEquipamentosInline) ...[
                  const SizedBox(width: 16),
                  Flexible(child: _buildEquipamentosInline()),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEquipamentosInline() {
    return Container(
      constraints: const BoxConstraints(minWidth: 240, maxWidth: 320),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: getBorderColor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.devices, color: getTextColor(context), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Status Atualização',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: getTextColor(context),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _mostrarEquipamentosInline = false;
                  });
                },
                child: Icon(Icons.close,
                    size: 18, color: getSecondaryTextColor(context)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _rotasEstado.length,
              itemBuilder: (context, index) {
                final rota = _rotasEstado[index];
                final status = rota['status'] as String;
                Color corFundo;
                Color corBorda;
                IconData? icone;
                String tooltipText;

                if (status == 'verde') {
                  corFundo = Colors.green;
                  corBorda = Colors.green.shade700;
                  icone = Icons.check;
                  tooltipText = 'Usuário está no equipamento';
                } else if (status == 'vermelho') {
                  corFundo = Colors.red;
                  corBorda = Colors.red.shade700;
                  icone = Icons.close;
                  tooltipText = 'Usuário não está no equipamento';
                } else {
                  corFundo = Colors.grey.shade300;
                  corBorda = Colors.grey.shade400;
                  icone = null;
                  tooltipText = 'Usuário não tem acesso ao equipamento';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tooltip(
                    message: tooltipText,
                    child: Row(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: corFundo,
                            border: Border.all(color: corBorda, width: 1.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: icone != null
                              ? Icon(icone, size: 14, color: Colors.white)
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            rota['nome'] ?? '',
                            style: TextStyle(
                              fontSize: 13,
                              color: getTextColor(context),
                            ),
                          ),
                        ),
                      ],
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

  Future<void> _atualizarEquipamentos() async {
    if (_fotoFacialBase64 == null &&
        (_fotoUsuarioUrl == null || _fotoUsuarioUrl!.isEmpty)) {
      _addLog('Nenhuma foto disponível para enviar', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
    });
    _addLog('Enviando foto e atualizando equipamentos...');

    try {
      if (_fotoFacialBase64 != null) {
        await _registrarAtualizacaoFacial(_fotoFacialBase64!);
        _addLog('Foto registrada com sucesso!', isSuccess: true);
      }

      if (mounted) {
        setState(() {
          _mostrarEquipamentosInline = true;
        });
        FeedbackUtils.showSuccess(
          context: context,
          title: 'Equipamentos',
          message: 'Equipamentos atualizados com sucesso!',
        );
      }
    } catch (e) {
      _addLog('Erro ao atualizar equipamentos: $e', isError: true);
      if (mounted) {
        FeedbackUtils.showError(
          context: context,
          title: 'Erro',
          message: 'Falha ao atualizar equipamentos: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // Método para tirar foto facial
  Future<void> _tirarFotoFacial() async {
    print('Botão "Tirar Foto do Usuário" clicado');
    _addLog('Abrindo câmera para captura facial...');

    setState(() {
      _mostrarPainelFoto = true;
    });
  }

  // Método auxiliar para ler bytes de arquivo web
  Future<List<int>> _readBytesFromWeb(String path) async {
    final response = await http.get(Uri.parse(path));
    return response.bodyBytes;
  }

  // Método para registrar foto facial (API FotoRegistrar)
  Future<void> _registrarAtualizacaoFacial(String fotoBase64) async {
    final prefs = await SharedPreferences.getInstance();
    final encryptedToken = prefs.getString('tokensessao_txt') ?? '';

    final url = Uri.parse('${ApiConfig.gateUrl}/FotoRegistrar');

    var condominioId =
        widget.morador['condominio_id'] ?? widget.morador['condominio'] ?? 0;
    if (condominioId == 0) {
      final cid = await ApiConfig.getCondominioId();
      if (cid.isNotEmpty) {
        condominioId = int.tryParse(cid) ?? 0;
      }
    }

    // Tentar obter usuario_id de várias formas possíveis
    final usuarioId = widget.morador['usuario_id'] ??
        widget.morador['id'] ??
        widget.morador['usuarioId'] ??
        widget.morador['ID'] ??
        0;

    final payload = {
      "condominio_id": condominioId,
      "tipoUSU": "USU",
      "usuario_id": usuarioId,
      "ordem_num": 1,
      "foto": fotoBase64,
      "atualizarEquipamento": true,
    };

    print('Payload para FotoRegistrar: $payload');
    print('Morador data: ${widget.morador}');
    print('Chaves disponíveis: ${widget.morador.keys.toList()}');

    if (usuarioId == 0) {
      print('❌ AVISO: usuario_id é 0! Verifique o objeto morador.');
    }

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${decryptText(encryptedToken)}',
      },
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Erro na API FotoRegistrar: ${response.statusCode} - ${response.body}');
    }
  }

  //-----------------------------//
  // Conectar ao Control ID e obter sessão
  //-----------------------------//
  Future<void> _conectarControlId() async {
    if (!kIsWeb) {
      _addLog('Control ID disponível apenas na web', isError: true);
      return;
    }

    setState(() {
      _carregandoBiometria = true;
    });

    try {
      _controlIdService = ControlIdService.instance;
      _addLog('Conectando ao equipamento Control ID...');

      final sessionId = await _controlIdService!.connectAndGetSession();

      if (sessionId != null && mounted) {
        setState(() {
          _controlIdSession = sessionId;
          _carregandoBiometria = false;
        });
        _addLog('Control ID conectado com sucesso!', isSuccess: true);
      } else {
        if (mounted) {
          setState(() {
            _carregandoBiometria = false;
          });
        }
        _addLog(
            'Não foi possível conectar ao Control ID. Verifique se o equipamento está conectado via USB.',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _carregandoBiometria = false;
        });
      }
      _addLog('Erro ao conectar Control ID: $e', isError: true);
    }
  }

  //-----------------------------//
  // Capturar biometria do Control ID
  //-----------------------------//
  Future<void> _capturarBiometria(String tipo) async {
    if (_controlIdService == null || _controlIdSession == null) {
      _addLog('Equipamento Control ID não conectado. Conectando...',
          isError: true);
      await _conectarControlId();
      if (_controlIdSession == null) {
        return;
      }
    }

    setState(() {
      if (tipo == 'acesso') {
        _capturandoAcesso = true;
      } else {
        _capturandoPanico = true;
      }
    });

    _addLog(
        'Aguardando captura de biometria ${tipo == 'acesso' ? 'de acesso' : 'do pânico'}...');
    _addLog('Coloque o dedo no sensor do equipamento Control ID',
        isError: false);

    try {
      print(
          '🔍 [DEBUG] Iniciando captura - Tipo: $tipo, Sessão: $_controlIdSession');

      final biometriaData = await _controlIdService!.captureBiometry(
        tipo: tipo,
        sessionId: _controlIdSession,
      );

      print(
          '🔍 [DEBUG] Resultado da captura: ${biometriaData != null ? 'Dados recebidos' : 'Nenhum dado'}');

      if (biometriaData != null) {
        print('🔍 [DEBUG] Chaves nos dados: ${biometriaData.keys.toList()}');
        final imagemBase64 = biometriaData['imagem'] as String?;
        print(
            '🔍 [DEBUG] Imagem base64: ${imagemBase64 != null ? 'Sim (${imagemBase64.length} chars)' : 'Não'}');

        if (imagemBase64 != null && imagemBase64.isNotEmpty) {
          //-----------------------------//
          // Processar imagem: remover prefixo se existir
          //-----------------------------//
          String imagemProcessada = imagemBase64;
          if (imagemProcessada.startsWith('data:image')) {
            // Remover prefixo data:image/png;base64, ou data:image/jpeg;base64,
            final prefixIndex = imagemProcessada.indexOf(',');
            if (prefixIndex > 0) {
              imagemProcessada = imagemProcessada.substring(prefixIndex + 1);
            }
          }

          print(
              '🔍 [DEBUG] Imagem processada: ${imagemProcessada.length} chars (prefixo removido)');

          // Validar se é base64 válido
          try {
            base64Decode(imagemProcessada);
            print('✅ [DEBUG] Base64 válido');
          } catch (e) {
            print('❌ [DEBUG] Base64 inválido: $e');
            throw Exception(
                'Imagem da biometria em formato inválido. Erro: $e');
          }

          if (mounted) {
            setState(() {
              if (tipo == 'acesso') {
                _biometriaAcessoBase64 = imagemProcessada;
                _capturandoAcesso = false;
              } else {
                _biometriaPanicoBase64 = imagemProcessada;
                _capturandoPanico = false;
              }
            });
          }
          _addLog(
              '✅ Biometria ${tipo == 'acesso' ? 'de acesso' : 'do pânico'} capturada com sucesso!',
              isSuccess: true);
          print('✅ [DEBUG] Biometria definida no estado com sucesso');
        } else {
          print('❌ [DEBUG] Imagem base64 está vazia ou null');
          throw Exception(
              'Imagem da biometria não disponível. Verifique o console do navegador para mais detalhes.');
        }
      } else {
        print('❌ [DEBUG] biometriaData é null');
        throw Exception(
            'Não foi possível capturar biometria. Verifique: 1) Equipamento conectado via USB, 2) Drivers instalados, 3) Biblioteca Control ID carregada, 4) Console do navegador para erros');
      }
    } catch (e) {
      print('❌ [DEBUG] Erro completo: $e');
      if (mounted) {
        setState(() {
          if (tipo == 'acesso') {
            _capturandoAcesso = false;
          } else {
            _capturandoPanico = false;
          }
        });
      }
      _addLog(
          '❌ Erro ao capturar biometria ${tipo == 'acesso' ? 'de acesso' : 'do pânico'}: $e',
          isError: true);
      _addLog(
          '💡 Dica: Abra o Console do navegador (F12) para ver detalhes do erro',
          isError: false);
    }
  }

  //-----------------------------//
  // Salvar registro digital
  //-----------------------------//
  Future<void> _salvarRegistroDigital() async {
    if (_biometriaAcessoBase64 == null || _biometriaPanicoBase64 == null) {
      _addLog('Por favor, capture ambas as biometrias antes de salvar',
          isError: true);
      return;
    }

    setState(() => _isProcessing = true);
    _addLog('Iniciando registro digital...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final encryptedToken = prefs.getString('tokensessao_txt') ?? '';
      final tokenSessao =
          encryptedToken.isNotEmpty ? decryptText(encryptedToken) : '';

      //-----------------------------//
      // Processar imagens: garantir que não tenham prefixo
      //-----------------------------//
      String acessoImg = _biometriaAcessoBase64!;
      String panicoImg = _biometriaPanicoBase64!;

      // Remover prefixo se existir
      if (acessoImg.startsWith('data:image')) {
        final prefixIndex = acessoImg.indexOf(',');
        if (prefixIndex > 0) {
          acessoImg = acessoImg.substring(prefixIndex + 1);
        }
      }

      if (panicoImg.startsWith('data:image')) {
        final prefixIndex = panicoImg.indexOf(',');
        if (prefixIndex > 0) {
          panicoImg = panicoImg.substring(prefixIndex + 1);
        }
      }

      final url = Uri.parse('${ApiConfig.gateUrl}/biometriaSmartAccess');

      final payload = {
        "condominio_id": widget.morador['condominio_id'] ??
            widget.morador['condominio'] ??
            0,
        "usuario_id": widget.morador['usuario_id'] ?? widget.morador['id'] ?? 0,
        "biometria_acesso": acessoImg,
        "biometria_panico": panicoImg,
      };

      print('Payload para biometriaSmartAccess: $payload');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenSessao',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        _addLog('Registro digital salvo com sucesso!', isSuccess: true);
        if (mounted) {
          FeedbackUtils.showSuccess(
            context: context,
            title: 'Digital Salva',
            message: 'Registro digital salvo com sucesso!',
          );
        }

        // Limpar campos após salvar
        setState(() {
          _biometriaAcessoBase64 = null;
          _biometriaPanicoBase64 = null;
        });
      } else {
        throw Exception(
            'Erro na API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      _addLog('Erro ao salvar registro digital: $e', isError: true);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Widget _digitalWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormSection(
          'Registro Digital',
          [
            Row(
              children: [
                Expanded(
                  child: _fingerBox(
                    "Dedo de Acesso",
                    biometriaBase64: _biometriaAcessoBase64,
                    isCapturing: _capturandoAcesso,
                    onCapture: () => _capturarBiometria('acesso'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _fingerBox(
                    "Dedo do Pânico",
                    highlight: true,
                    biometriaBase64: _biometriaPanicoBase64,
                    isCapturing: _capturandoPanico,
                    onCapture: () => _capturarBiometria('panico'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Status da conexão Control ID
            if (_controlIdSession != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Equipamento Control ID conectado (Sessão: ${_controlIdSession!.substring(0, 10)}...)',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (_carregandoBiometria)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Conectando ao equipamento Control ID...',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Equipamento Control ID não conectado. Certifique-se de que está conectado via USB.',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 24),

        // Botões de ação
        _buildActionButtons(
          onDelete:
              (_biometriaAcessoBase64 != null || _biometriaPanicoBase64 != null)
                  ? () {
                      setState(() {
                        _biometriaAcessoBase64 = null;
                        _biometriaPanicoBase64 = null;
                      });
                      _addLog('Biometrias removidas', isSuccess: true);
                    }
                  : null,
          onSave:
              (_biometriaAcessoBase64 != null && _biometriaPanicoBase64 != null)
                  ? () async {
                      await _salvarRegistroDigital();
                    }
                  : null,
        ),
      ],
    );
  }

  Widget _fingerBox(
    String label, {
    bool highlight = false,
    String? biometriaBase64,
    bool isCapturing = false,
    VoidCallback? onCapture,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: getTextColor(context),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onCapture != null && !isCapturing ? onCapture : null,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: getCardColor(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: highlight ? Colors.red : getBorderColor(context),
                width: highlight ? 2 : 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Exibir imagem da biometria se disponível
                if (biometriaBase64 != null && biometriaBase64.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Builder(
                      builder: (context) {
                        try {
                          //-----------------------------//
                          // Processar imagem: remover prefixo se existir
                          //-----------------------------//
                          String imagemProcessada = biometriaBase64;
                          if (imagemProcessada.startsWith('data:image')) {
                            final prefixIndex = imagemProcessada.indexOf(',');
                            if (prefixIndex > 0) {
                              imagemProcessada =
                                  imagemProcessada.substring(prefixIndex + 1);
                            }
                          }

                          return Image.memory(
                            base64Decode(imagemProcessada),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              print(
                                  '❌ Erro ao exibir imagem de biometria: $error');
                              return Icon(
                                Icons.error,
                                size: 48,
                                color: Colors.red,
                              );
                            },
                          );
                        } catch (e) {
                          print(
                              '❌ Erro ao decodificar imagem de biometria: $e');
                          return Icon(
                            Icons.error,
                            size: 48,
                            color: Colors.red,
                          );
                        }
                      },
                    ),
                  )
                else if (!isCapturing)
                  Icon(
                    Icons.fingerprint,
                    size: 48,
                    color: getSecondaryTextColor(context),
                  ),

                // Overlay de captura
                if (isCapturing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Capturando...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (onCapture != null && !isCapturing)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCapture,
              icon: Icon(Icons.fingerprint,
                  size: 16, color: getTextColor(context)),
              label: Text(
                biometriaBase64 != null ? 'Recapturar' : 'Capturar',
                style: TextStyle(color: getTextColor(context)),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _controleWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Controle',
          child: TextField(
            controller: _tagController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.devices_other,
                  color: getSecondaryTextColor(context)),
              hintText: "Digite o valor do controle",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (temTagCadastrada && !_editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = true;
                            _novoValorController.clear();
                          });
                        },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _atualizarTag(_tagSelecionadaAtual!);
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, color: Colors.white),
                  label: const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _excluirDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _tagSelecionadaAtual = null;
                                _tagController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Excluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_novoValorController.text.trim().isEmpty) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Campo Obrigatório',
                              message: 'Digite o novo valor',
                            );
                            return;
                          }
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            final tagAtualizada = {
                              ..._tagSelecionadaAtual!,
                              'serialDispositivo_txt':
                                  _novoValorController.text.trim(),
                            };
                            await _alterarDispositivo(tagAtualizada);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _editandoDispositivo = false;
                                _tagController.text =
                                    _novoValorController.text.trim();
                                _novoValorController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = false;
                            _novoValorController.clear();
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
            if (!temTagCadastrada) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing ||
                          jaExisteMesmoTipo ||
                          _tagController.text.trim().isEmpty)
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null &&
                              _tagController.text.trim().isNotEmpty) {
                            // Cadastrar com os valores digitados nos campos
                            setState(() => _isProcessing = true);
                            await _cadastrarDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                // Limpar campos após cadastro bem-sucedido
                                _tagController.clear();
                                _senhaControleController.clear();
                              });
                              // Recarregar tags para atualizar a lista
                              if (widget.modoVeiculo) {
                                await _carregarTagsVeiculo();
                              }
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (jaExisteMesmoTipo ||
                            _tagController.text.trim().isEmpty)
                        ? Colors.grey
                        : const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _senhaWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Senha',
          child: TextField(
            controller: _senhaControleController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.lock_outline,
                  color: getSecondaryTextColor(context)),
              hintText: "Digite a senha",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (temTagCadastrada && !_editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = true;
                            _novoValorController.clear();
                          });
                        },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_novoValorController.text.trim().isEmpty) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Campo Obrigatório',
                              message: 'Digite o novo valor',
                            );
                            return;
                          }
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            final tagAtualizada = {
                              ..._tagSelecionadaAtual!,
                              'serialDispositivo_txt':
                                  _novoValorController.text.trim(),
                            };
                            await _alterarDispositivo(tagAtualizada);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _editandoDispositivo = false;
                                _senhaControleController.text =
                                    _novoValorController.text.trim();
                                _novoValorController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = false;
                            _novoValorController.clear();
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
            if (!temTagCadastrada) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing ||
                          jaExisteMesmoTipo ||
                          _senhaControleController.text.trim().isEmpty)
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null &&
                              _senhaControleController.text.trim().isNotEmpty) {
                            setState(() => _isProcessing = true);
                            await _cadastrarDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _tagController.clear();
                                _senhaControleController.clear();
                              });
                              if (widget.modoVeiculo) {
                                await _carregarTagsVeiculo();
                              }
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (jaExisteMesmoTipo ||
                            _senhaControleController.text.trim().isEmpty)
                        ? Colors.grey
                        : const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _chaveiroWidget() {
    // Se for modo veículo, mostrar dropdown de opções de tag
    if (widget.modoVeiculo) {
      return _tagWidget();
    }
    return _inputWidget(
      icon: Icons.key_outlined,
      title: 'Registro de Chaveiro',
      hint: "Registre o chaveiro",
      buttonText: 'Registrar Chaveiro',
    );
  }

  //-----------------------------//
  // Widget para Tag Control ID
  //-----------------------------//
  Widget _tagControlIdWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Tag Control ID',
          child: TextField(
            controller: _tagController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.tag, color: getSecondaryTextColor(context)),
              hintText: "Digite o valor da tag",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (temTagCadastrada && !_editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = true;
                            _novoValorController.clear();
                          });
                        },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _atualizarTag(_tagSelecionadaAtual!);
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, color: Colors.white),
                  label: const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _excluirDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _tagSelecionadaAtual = null;
                                _tagController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Excluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_novoValorController.text.trim().isEmpty) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Campo Obrigatório',
                              message: 'Digite o novo valor',
                            );
                            return;
                          }
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            final tagAtualizada = {
                              ..._tagSelecionadaAtual!,
                              'serialDispositivo_txt':
                                  _novoValorController.text.trim(),
                            };
                            await _alterarDispositivo(tagAtualizada);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _editandoDispositivo = false;
                                _tagController.text =
                                    _novoValorController.text.trim();
                                _novoValorController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = false;
                            _novoValorController.clear();
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
            if (!temTagCadastrada) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing ||
                          jaExisteMesmoTipo ||
                          _tagController.text.trim().isEmpty)
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null &&
                              _tagController.text.trim().isNotEmpty) {
                            setState(() => _isProcessing = true);
                            await _cadastrarDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _tagController.clear();
                                _senhaControleController.clear();
                              });
                              if (widget.modoVeiculo) {
                                await _carregarTagsVeiculo();
                              }
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (jaExisteMesmoTipo ||
                            _tagController.text.trim().isEmpty)
                        ? Colors.grey
                        : const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  //-----------------------------//
  // Widget para Tag Nice
  //-----------------------------//
  Widget _tagNiceWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Tag Nice',
          child: TextField(
            controller: _tagController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.tag, color: getSecondaryTextColor(context)),
              hintText: "Digite o valor da tag",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (temTagCadastrada && !_editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = true;
                            _novoValorController.clear();
                          });
                        },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _atualizarTag(_tagSelecionadaAtual!);
                            if (mounted) setState(() => _isProcessing = false);
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.sync, color: Colors.white),
                  label: const Text('Atualizar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            await _excluirDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _tagSelecionadaAtual = null;
                                _tagController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.delete, color: Colors.white),
                  label: const Text('Excluir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_novoValorController.text.trim().isEmpty) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Campo Obrigatório',
                              message: 'Digite o novo valor',
                            );
                            return;
                          }
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            final tagAtualizada = {
                              ..._tagSelecionadaAtual!,
                              'serialDispositivo_txt':
                                  _novoValorController.text.trim(),
                            };
                            await _alterarDispositivo(tagAtualizada);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _editandoDispositivo = false;
                                _tagController.text =
                                    _novoValorController.text.trim();
                                _novoValorController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = false;
                            _novoValorController.clear();
                          });
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
            if (!temTagCadastrada) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing ||
                          jaExisteMesmoTipo ||
                          _tagController.text.trim().isEmpty)
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null &&
                              _tagController.text.trim().isNotEmpty) {
                            // Cadastrar com os valores digitados nos campos
                            setState(() => _isProcessing = true);
                            await _cadastrarDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                // Limpar campos após cadastro bem-sucedido
                                _tagController.clear();
                                _senhaControleController.clear();
                              });
                              // Recarregar tags para atualizar a lista
                              if (widget.modoVeiculo) {
                                await _carregarTagsVeiculo();
                              }
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (jaExisteMesmoTipo ||
                            _tagController.text.trim().isEmpty)
                        ? Colors.grey
                        : const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  //-----------------------------//
  // Widget para Tag Sem Parar
  //-----------------------------//
  Widget _tagSemPararWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Tag Sem Parar',
          child: TextField(
            controller: _tagController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.tag, color: getSecondaryTextColor(context)),
              hintText: "Digite o valor da tag",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        // Botões padronizados
        Center(
          child: _buildTransparentIconGroup([
            if (temTagCadastrada && !_editandoDispositivo) ...[
              _IconActionData(
                icon: Icons.edit,
                tooltip: 'Alterar',
                onPressed: _isProcessing
                    ? null
                    : () {
                        setState(() {
                          _editandoDispositivo = true;
                          _novoValorController.clear();
                        });
                      },
              ),
              _IconActionData(
                icon: Icons.sync,
                tooltip: 'Atualizar',
                onPressed: _isProcessing
                    ? null
                    : () async {
                        if (_tagSelecionadaAtual != null) {
                          setState(() => _isProcessing = true);
                          await _atualizarTag(_tagSelecionadaAtual!);
                          if (mounted) setState(() => _isProcessing = false);
                        }
                      },
                isLoading: _isProcessing,
              ),
              _IconActionData(
                icon: Icons.delete,
                tooltip: 'Excluir',
                onPressed: _isProcessing
                    ? null
                    : () async {
                        if (_tagSelecionadaAtual != null) {
                          setState(() => _isProcessing = true);
                          await _excluirDispositivo(_tagSelecionadaAtual!);
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                              _tagSelecionadaAtual = null;
                              _tagController.clear();
                            });
                          }
                        }
                      },
                isLoading: _isProcessing,
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              _IconActionData(
                icon: Icons.close,
                tooltip: 'Cancelar',
                onPressed: _isProcessing
                    ? null
                    : () {
                        setState(() {
                          _editandoDispositivo = false;
                          _novoValorController.clear();
                        });
                      },
              ),
              _IconActionData(
                icon: Icons.check,
                tooltip: 'Salvar',
                onPressed: _isProcessing
                    ? null
                    : () async {
                        if (_novoValorController.text.trim().isEmpty) {
                          FeedbackUtils.showError(
                            context: context,
                            title: 'Campo Obrigatório',
                            message: 'Digite o novo valor',
                          );
                          return;
                        }
                        if (_tagSelecionadaAtual != null) {
                          setState(() => _isProcessing = true);
                          final tagAtualizada = {
                            ..._tagSelecionadaAtual!,
                            'serialDispositivo_txt':
                                _novoValorController.text.trim(),
                          };
                          await _alterarDispositivo(tagAtualizada);
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                              _editandoDispositivo = false;
                              _tagController.text =
                                  _novoValorController.text.trim();
                              _novoValorController.clear();
                            });
                          }
                        }
                      },
                isLoading: _isProcessing,
              ),
            ],
            if (!temTagCadastrada) ...[
              _IconActionData(
                icon: Icons.add,
                tooltip: 'Cadastrar',
                onPressed: (_isProcessing ||
                        jaExisteMesmoTipo ||
                        _tagController.text.trim().isEmpty)
                    ? null
                    : () async {
                        if (_tagSelecionadaAtual != null &&
                            _tagController.text.trim().isNotEmpty) {
                          setState(() => _isProcessing = true);
                          await _cadastrarDispositivo(_tagSelecionadaAtual!);
                          if (mounted) {
                            setState(() {
                              _isProcessing = false;
                              _tagController.clear();
                              _senhaControleController.clear();
                            });
                            if (widget.modoVeiculo) {
                              await _carregarTagsVeiculo();
                            }
                          }
                        }
                      },
                isLoading: _isProcessing,
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _tagWidget() {
    final usuarioserialId = _tagSelecionadaAtual?['usuarioserial_id'];
    final temTagCadastrada = usuarioserialId != null &&
        usuarioserialId != 0 &&
        usuarioserialId != '0';
    final dispositivoId = _tagSelecionadaAtual?['dispositivo_Id'] as int?;
    // Para veículos: verificar se já existe dispositivo do mesmo tipo (mesmo que não seja o atual)
    final jaExisteMesmoTipo = widget.modoVeiculo &&
        dispositivoId != null &&
        _jaExisteDispositivoTipo(dispositivoId) &&
        !temTagCadastrada;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormField(
          label: 'Tag',
          child: TextField(
            controller: _tagController,
            enabled: !temTagCadastrada && !_editandoDispositivo,
            decoration: InputDecoration(
              prefixIcon:
                  Icon(Icons.tag, color: getSecondaryTextColor(context)),
              hintText: "Digite o valor da tag",
              hintStyle: TextStyle(color: getSecondaryTextColor(context)),
              filled: true,
              fillColor: (temTagCadastrada || _editandoDispositivo)
                  ? getSurfaceColor(context).withValues(alpha: 0.5)
                  : getSurfaceColor(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: getBorderColor(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: const Color(0xFF684F8E)),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: TextStyle(color: getTextColor(context)),
          ),
        ),
        if (_editandoDispositivo) ...[
          const SizedBox(height: 16),
          _buildFormField(
            label: 'Novo',
            child: TextField(
              controller: _novoValorController,
              decoration: InputDecoration(
                prefixIcon:
                    Icon(Icons.edit, color: getSecondaryTextColor(context)),
                hintText: "Digite o novo valor",
                hintStyle: TextStyle(color: getSecondaryTextColor(context)),
                filled: true,
                fillColor: getSurfaceColor(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: getBorderColor(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: const Color(0xFF684F8E)),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: TextStyle(color: getTextColor(context)),
              autofocus: true,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            if (temTagCadastrada && !_editandoDispositivo) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = true;
                            _novoValorController.clear();
                          });
                        },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (temTagCadastrada && _editandoDispositivo) ...[
              Expanded(
                child: TextButton(
                  onPressed: _isProcessing
                      ? null
                      : () {
                          setState(() {
                            _editandoDispositivo = false;
                            _novoValorController.clear();
                          });
                        },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: getSecondaryTextColor(context)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isProcessing
                      ? null
                      : () async {
                          if (_novoValorController.text.trim().isEmpty) {
                            FeedbackUtils.showError(
                              context: context,
                              title: 'Campo Obrigatório',
                              message: 'Digite o novo valor',
                            );
                            return;
                          }
                          if (_tagSelecionadaAtual != null) {
                            setState(() => _isProcessing = true);
                            final tagAtualizada = {
                              ..._tagSelecionadaAtual!,
                              'serialDispositivo_txt':
                                  _novoValorController.text.trim(),
                            };
                            await _alterarDispositivo(tagAtualizada);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                _editandoDispositivo = false;
                                _tagController.text =
                                    _novoValorController.text.trim();
                                _novoValorController.clear();
                              });
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, color: Colors.white),
                  label: const Text('Alterar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
            if (!temTagCadastrada) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isProcessing ||
                          jaExisteMesmoTipo ||
                          _tagController.text.trim().isEmpty)
                      ? null
                      : () async {
                          if (_tagSelecionadaAtual != null &&
                              _tagController.text.trim().isNotEmpty) {
                            // Cadastrar com os valores digitados nos campos
                            setState(() => _isProcessing = true);
                            await _cadastrarDispositivo(_tagSelecionadaAtual!);
                            if (mounted) {
                              setState(() {
                                _isProcessing = false;
                                // Limpar campos após cadastro bem-sucedido
                                _tagController.clear();
                                _senhaControleController.clear();
                              });
                              // Recarregar tags para atualizar a lista
                              if (widget.modoVeiculo) {
                                await _carregarTagsVeiculo();
                              }
                            }
                          }
                        },
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add, color: Colors.white),
                  label: const Text('Cadastrar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (jaExisteMesmoTipo ||
                            _tagController.text.trim().isEmpty)
                        ? Colors.grey
                        : const Color(0xFF684F8E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _inputWidget({
    required IconData icon,
    required String title,
    required String hint,
    required String buttonText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: getTextColor(context),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: getSecondaryTextColor(context)),
            hintText: hint,
            hintStyle: TextStyle(color: getSecondaryTextColor(context)),
            filled: true,
            fillColor: getSurfaceColor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFF684F8E)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(color: getTextColor(context)),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: getSecondaryTextColor(context)),
            hintText: hint,
            hintStyle: TextStyle(color: getSecondaryTextColor(context)),
            filled: true,
            fillColor: getSurfaceColor(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: getBorderColor(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: getBorderColor(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: const Color(0xFF684F8E)),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          style: TextStyle(color: getTextColor(context)),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: Icon(icon, color: Colors.white),
                label: Text(buttonText),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF684F8E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Desconectar Control ID ao fechar a página
    if (_controlIdService != null) {
      _controlIdService!.disconnect();
      _controlIdService = null;
    }
    _controlIdSession = null;
    // Limpar logs ao fechar a tela
    _logs.clear();
    // Dispose dos controllers
    _senhaControleController.dispose();
    _tagController.dispose();
    _novoValorController.dispose();
    _biometriaAcessoBase64 = null;
    _biometriaPanicoBase64 = null;
    super.dispose();
  }
}
