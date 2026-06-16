import 'package:flutter/material.dart';

class WebCameraView extends StatefulWidget {
  final Function(String) onImageCaptured;
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
  void takePicture() {}
  void retake() {}
  void confirm() {}

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Web Camera not supported on this platform'),
    );
  }
}
