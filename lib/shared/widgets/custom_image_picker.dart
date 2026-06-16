import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'face_camera_view.dart';
import 'web_camera_view.dart';
import 'dart:convert';

class CustomImagePicker extends StatefulWidget {
  final Function(String) onImageSelected;
  final List<CameraDescription> cameras;

  const CustomImagePicker({
    super.key,
    required this.onImageSelected,
    this.cameras = const [],
  });

  @override
  State<CustomImagePicker> createState() => _CustomImagePickerState();
}

class _CustomImagePickerState extends State<CustomImagePicker> {
  String? _imagePath;
  String? _imageBase64; // Para web
  bool _isCameraActive = false;
  bool _isImageCaptured = false;
  final ImagePicker _picker = ImagePicker();
  final GlobalKey<FaceCameraViewState> _cameraKey = GlobalKey();
  final GlobalKey<WebCameraViewState> _webCameraKey = GlobalKey();

  Future<void> _pickFromGallery() async {
    try {
      if (kIsWeb) {
        // Na web, usar input HTML que permite câmera ou arquivo
        await _pickImageWeb();
      } else {
        // No mobile, usar image_picker normal
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          setState(() {
            _imagePath = pickedFile.path;
          });
          widget.onImageSelected(_imagePath!);
        }
      }
    } catch (e) {
      debugPrint('Erro galeria: $e');
    }
  }

  Future<void> _pickImageWeb() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        // preferredCameraDevice permite escolher câmera frontal
        preferredCameraDevice: CameraDevice.front,
      );

      if (pickedFile != null) {
        setState(() {
          _imagePath = pickedFile.path;
        });
        widget.onImageSelected(_imagePath!);
      }
    } catch (e) {
      debugPrint('Erro ao selecionar imagem na web: $e');
    }
  }

  Future<void> _pickFromCamera() async {
    if (kIsWeb) {
      // Na web, ativar câmera dentro da bola
      setState(() {
        _isCameraActive = true;
        _isImageCaptured = false;
      });
    } else {
      // No mobile, usar image_picker
      try {
        final XFile? pickedFile = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 80,
          preferredCameraDevice: CameraDevice.front,
        );

        if (pickedFile != null) {
          setState(() {
            _imagePath = pickedFile.path;
          });
          widget.onImageSelected(_imagePath!);
        }
      } catch (e) {
        debugPrint('Erro ao tirar foto: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? imageProvider;
    if (_imagePath != null && !_isCameraActive) {
      if (kIsWeb) {
        imageProvider = NetworkImage(_imagePath!);
      } else {
        imageProvider = FileImage(File(_imagePath!));
      }
    } else if (_imageBase64 != null && !_isCameraActive) {
      // Imagem capturada pela câmera web (base64)
      imageProvider = MemoryImage(base64Decode(_imageBase64!));
    }

    final double containerSize = _isCameraActive ? 320 : 200;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A "Bola" (Avatar ou Câmera)
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          width: containerSize,
          height: containerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey[200],
            border: Border.all(color: Colors.blueAccent, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
            image: imageProvider != null
                ? DecorationImage(image: imageProvider, fit: BoxFit.cover)
                : null,
          ),
          child: ClipOval(
            child: _isCameraActive
                ? (kIsWeb
                    ? WebCameraView(
                        key: _webCameraKey,
                        onImageCaptured: (base64) {
                          setState(() {
                            _imageBase64 = base64;
                            _isCameraActive = false;
                            _isImageCaptured = false;
                          });
                          widget.onImageSelected(base64);
                        },
                        onClose: () {
                          setState(() {
                            _isCameraActive = false;
                            _isImageCaptured = false;
                          });
                        },
                        onCaptureStatusChanged: (isCaptured) {
                          setState(() {
                            _isImageCaptured = isCaptured;
                          });
                        },
                      )
                    : FaceCameraView(
                        key: _cameraKey,
                        onImageCaptured: (file) {
                          setState(() {
                            _imagePath = file.path;
                            _isCameraActive = false;
                            _isImageCaptured = false;
                          });
                          widget.onImageSelected(_imagePath!);
                        },
                        onClose: () {
                          setState(() {
                            _isCameraActive = false;
                            _isImageCaptured = false;
                          });
                        },
                        onCaptureStatusChanged: (isCaptured) {
                          setState(() {
                            _isImageCaptured = isCaptured;
                          });
                        },
                      ))
                : (_imagePath == null && _imageBase64 == null
                    ? const Icon(Icons.person, size: 80, color: Colors.grey)
                    : null),
          ),
        ),

        const SizedBox(height: 24),

        // Controls
        if (_isCameraActive) ...[
          // Camera Controls (Outside the circle)
          if (!_isImageCaptured)
            Center(
              child: GestureDetector(
                onTap: () {
                  if (kIsWeb) {
                    _webCameraKey.currentState?.takePicture();
                  } else {
                    _cameraKey.currentState?.takePicture();
                  }
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            )
          else
            _buildTransparentIconGroup([
              _IconActionData(
                icon: Icons.refresh,
                tooltip: 'Tirar Outra',
                onPressed: () {
                  // Reabrir a câmera e limpar imagens
                  setState(() {
                    _imageBase64 = null;
                    _imagePath = null;
                    _isCameraActive = true; // REABRE A CÂMERA
                    _isImageCaptured = false;
                  });

                  // Tenta resetar o estado interno da câmera se possível
                  if (kIsWeb) {
                    _webCameraKey.currentState?.retake();
                  } else {
                    _cameraKey.currentState?.retake();
                  }
                },
              ),
              _IconActionData(
                icon: Icons.check,
                tooltip: 'Confirmar',
                onPressed: () {
                  if (kIsWeb) {
                    _webCameraKey.currentState?.confirm();
                  } else {
                    _cameraKey.currentState?.confirm();
                  }
                },
                isMarked: true, // Highlight confirm action
              ),
            ]),
        ] else ...[
          // Standard Buttons (Gallery / Camera)
          _buildTransparentIconGroup([
            _IconActionData(
              icon: Icons.photo_library,
              tooltip: kIsWeb ? 'Selecionar Arquivo' : 'Galeria',
              onPressed: _pickFromGallery,
            ),
            if (kIsWeb)
              _IconActionData(
                icon: Icons.camera_alt,
                tooltip: 'Tirar Foto',
                onPressed: _pickFromCamera,
              )
            else
              _IconActionData(
                icon: Icons.camera_alt,
                tooltip: 'Câmera',
                onPressed: () {
                  setState(() {
                    _isCameraActive = true;
                    _isImageCaptured = false;
                  });
                },
              ),
          ]),
          if (kIsWeb)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Use "Tirar Foto" para câmera ou "Selecionar Arquivo" para galeria.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildTransparentIconGroup(List<_IconActionData> actions) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor = iconColor.withValues(alpha: 0.3);
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
            // Ícone
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
            );
          } else {
            // Divisor
            return _buildDivider(dividerColor);
          }
        }),
      ),
    );
  }

  Widget _buildGroupedIcon(
    IconData icon,
    Color color,
    VoidCallback? onPressed,
    String tooltip, {
    bool isLoading = false,
    bool isOpaque = false,
    bool isMarked = false,
    double? iconSize,
  }) {
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
            decoration: isOpaque
                ? BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  )
                : isMarked
                    ? BoxDecoration(
                        color: const Color(
                            0xFF684F8E), // Cor roxa para indicar foto capturada
                        borderRadius: BorderRadius.circular(20),
                      )
                    : null,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    color: isLoading
                        ? color.withValues(alpha: 0.5)
                        : (isOpaque
                            ? color.withValues(alpha: 0.35)
                            : isMarked
                                ? Colors.white // Ícone branco quando marcado
                                : color),
                    size: iconSize ?? (isOpaque ? 24 : 28),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(width: 1, height: 28, color: color);
  }
}

class _IconActionData {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOpaque;
  final bool isMarked;
  const _IconActionData({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isMarked = false,
  })  : isLoading = false,
        isOpaque = false;
}
