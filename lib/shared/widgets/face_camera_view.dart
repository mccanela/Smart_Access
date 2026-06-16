import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;

class FaceCameraView extends StatefulWidget {
  final Function(File) onImageCaptured;
  final VoidCallback onClose;
  final ValueChanged<bool>? onCaptureStatusChanged;

  const FaceCameraView({
    super.key,
    required this.onImageCaptured,
    required this.onClose,
    this.onCaptureStatusChanged,
  });

  @override
  State<FaceCameraView> createState() => FaceCameraViewState();
}

class FaceCameraViewState extends State<FaceCameraView> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  XFile? _capturedImage;
  bool _isCameraInitialized = false;
  String? _errorMessage;
  bool _isProcessing = false;

  SelfieSegmenter? _segmenter;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      _segmenter = SelfieSegmenter(
        mode: SegmenterMode.single,
        enableRawSizeMask: true,
      );
    }
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Nenhuma câmera encontrada.\nVerifique as permissões (HTTPS necessário no Mobile).';
          });
        }
        return;
      }

      // Use front camera if available
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        frontCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      _initializeControllerFuture = _controller!.initialize();
      await _initializeControllerFuture;
      try {
        // await _controller!.setZoomLevel(1.0); // Allow default device zoom
      } catch (_) {}
      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao inicializar câmera: $e';
        });
      }
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _segmenter?.close();
    super.dispose();
  }

  Future<void> takePicture() async {
    if (_isProcessing) return;

    try {
      await _initializeControllerFuture;

      setState(() {
        _isProcessing = true;
      });

      final image = await _controller!.takePicture();

      XFile finalImage = image;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          final processed = await _processBackgroundRemoval(image);
          finalImage = processed;
        } catch (e) {
          debugPrint("Segmentation failed: $e");
          // Fallback to original
          finalImage = image;
        }
      }

      if (mounted) {
        setState(() {
          _capturedImage = finalImage;
          _isProcessing = false;
        });
      }

      widget.onCaptureStatusChanged?.call(true);
    } catch (e) {
      debugPrint("Error taking picture: $e");
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<XFile> _processBackgroundRemoval(XFile input) async {
    if (_segmenter == null) return input;
    final inputImage = InputImage.fromFilePath(input.path);
    final mask = await _segmenter!.processImage(inputImage);
    if (mask == null) {
      debugPrint('Selfie Segmentation failed: Mask is null');
      return input;
    }

    final bytes = await input.readAsBytes();
    var originalImage = img.decodeImage(bytes);

    if (originalImage == null) return input;

    // Fix orientation to match what ML Kit likely saw
    originalImage = img.bakeOrientation(originalImage);

    final maskWidth = mask.width;
    final maskHeight = mask.height;
    final confidences = mask.confidences;

    // Create a new image with BLACK background
    // We modify originalImage pixels directly
    for (int y = 0; y < originalImage.height; y++) {
      for (int x = 0; x < originalImage.width; x++) {
        // Map image coordinate to mask coordinate
        final maskX = (x * maskWidth / originalImage.width).floor();
        final maskY = (y * maskHeight / originalImage.height).floor();

        final maskIndex = maskY * maskWidth + maskX;

        // Safety check
        if (maskIndex < confidences.length) {
          final confidence = confidences[maskIndex];
          // Confidence that pixel is a person.
          // If low, it's background -> set to White.
          if (confidence <= 0.6) {
            // Set to Black (R=0, G=0, B=0, A=255)
            originalImage.setPixelRgba(x, y, 0, 0, 0, 255);
          }
        }
      }
    }

    // Save processed image
    final processedBytes = img.encodeJpg(originalImage, quality: 85);
    final newPath = input.path.replaceFirst('.jpg', '_processed.jpg');
    final newFile = File(newPath);
    await newFile.writeAsBytes(processedBytes);

    return XFile(newPath);
  }

  Future<void> retake() async {
    await _controller?.resumePreview();
    setState(() {
      _capturedImage = null;
    });
    widget.onCaptureStatusChanged?.call(false);
  }

  void confirm() {
    if (_capturedImage != null) {
      widget.onImageCaptured(File(_capturedImage!.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 14),
          ),
        ),
      );
    }

    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("Processando fundo...", style: TextStyle(color: Colors.white)),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // Camera Preview Layer
        Positioned.fill(
          child: _isCameraInitialized
              ? ClipOval(
                  child: AspectRatio(
                    aspectRatio: 1, // Force into a square/circle
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.previewSize!
                            .height, // Swap width/height for portrait
                        height: _controller!.value.previewSize!.width,
                        child: _capturedImage == null
                            ? CameraPreview(_controller!)
                            : (kIsWeb
                                ? Image.network(
                                    _capturedImage!.path,
                                    fit: BoxFit.cover,
                                  )
                                : Image.file(
                                    File(_capturedImage!.path),
                                    fit: BoxFit.cover,
                                  )),
                      ),
                    ),
                  ),
                )
              : const Center(child: CircularProgressIndicator()),
        ),

        // Face Framing Overlay Layer (Visual Only)
        if (_isCameraInitialized && _capturedImage == null)
          Positioned.fill(
            child: IgnorePointer(
              child: Transform.scale(
                scale: 1.5,
                child: Center(
                  child: Image.asset(
                    'assets/images/face_overlay.png',
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.face,
                          size: 100,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

        // Close Button (Top Right)
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black26,
              padding: const EdgeInsets.all(4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }
}
