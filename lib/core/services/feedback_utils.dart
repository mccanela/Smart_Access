import 'package:flutter/material.dart';
import '../../shared/widgets/feedback_modal.dart';
import '../../shared/widgets/toast_notification.dart';

class FeedbackUtils {
  static OverlayEntry? _currentOverlay;

  /// Mostra um modal de feedback elegante (Bloqueante)
  static void showFeedbackModal({
    required BuildContext context,
    required String title,
    required String message,
    required bool isSuccess,
    bool isWarning = false,
    String? errorDetails,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return FeedbackModal(
          title: title,
          message: message,
          isSuccess: isSuccess,
          isWarning: isWarning,
          errorDetails: errorDetails,
          onClose: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  static void _showOverlay({
    required BuildContext context,
    required String title,
    required String message,
    required bool isSuccess,
    bool isWarning = false,
    GlobalKey? triggerKey,
  }) {
    // Remove notificação anterior se existir
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlayState = Overlay.of(context, rootOverlay: true);

    // 1. Definição de cores baseadas no status da operação
    final bgColor = isSuccess
        ? const Color(0xFFE8F5E9)
        : (isWarning ? const Color(0xFFFFF3E0) : const Color(0xFFFFEBEE));
    final borderColor = isSuccess
        ? const Color(0xFF4CAF50)
        : (isWarning ? const Color(0xFFFF9800) : const Color(0xFFF44336));
    final iconData = isSuccess
        ? Icons.check_circle_outline
        : (isWarning ? Icons.warning_amber_rounded : Icons.error_outline);
    final iconColor = isSuccess
        ? const Color(0xFF2E7D32)
        : (isWarning ? const Color(0xFFEF6C00) : const Color(0xFFC62828));

    // 2. Construção de um Toast NATIVO e BLINDADO (Garante que nunca dará erro de Layout/Tela Cinza)
    Widget toastContent = Material(
      color: Colors.transparent,
      child: Container(
        width:
            350, // 👈 Largura fixa para impedir expansão infinita e erros de tela!
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: const [
            BoxShadow(
                color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(iconData, color: iconColor, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize
                    .min, // 👈 Altura se adapta ao conteúdo com segurança
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(message,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black87)),
                ],
              ),
            ),
            InkWell(
              onTap: () {
                _currentOverlay?.remove();
                _currentOverlay = null;
              },
              child: const Icon(Icons.close, size: 20, color: Colors.black54),
            ),
          ],
        ),
      ),
    );

    Widget overlayChild;

    // 3. Posicionamento seguro
    if (triggerKey != null && triggerKey.currentContext != null) {
      final renderBox =
          triggerKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      overlayChild = Positioned(
        left: position.dx + 16,
        top: position.dy + size.height - 85,
        child: toastContent,
      );
    } else {
      // Posição flutuante exata no canto inferior direito
      overlayChild = Positioned(
        bottom: 30,
        right: 30,
        child: toastContent,
      );
    }

    // 4. Injeta na tela
    _currentOverlay = OverlayEntry(builder: (context) => overlayChild);
    overlayState.insert(_currentOverlay!);

    // 5. Timer de autodestruição para limpar a notificação da tela
    Future.delayed(const Duration(seconds: 4), () {
      if (_currentOverlay != null) {
        _currentOverlay?.remove();
        _currentOverlay = null;
      }
    });
  }

  /// Mostra feedback de sucesso (Não bloqueante)
  static void showSuccess({
    required BuildContext context,
    required String title,
    required String message,
    GlobalKey? triggerKey,
  }) {
    _showOverlay(
      context: context,
      title: title,
      message: message,
      isSuccess: true,
      triggerKey: triggerKey,
    );
  }

  /// Mostra feedback de aviso (Não bloqueante)
  static void showWarning({
    required BuildContext context,
    required String title,
    required String message,
    GlobalKey? triggerKey,
  }) {
    _showOverlay(
      context: context,
      title: title,
      message: message,
      isSuccess: false,
      isWarning: true,
      triggerKey: triggerKey,
    );
  }

  /// Mostra feedback de erro (Não bloqueante para erros simples)
  static void showError({
    required BuildContext context,
    required String title,
    required String message,
    String? errorDetails,
    GlobalKey? triggerKey,
  }) {
    // Se houver detalhes técnicos, ainda sugerimos o modal para que o usuário possa copiar/ver
    // Mas se o usuário pediu "Toda notificação", talvez ele prefira toast.
    // Vamos usar Toast para erros simples e Modal para erros com detalhes.
    if (errorDetails != null && errorDetails.isNotEmpty) {
      showFeedbackModal(
        context: context,
        title: title,
        message: message,
        isSuccess: false,
        errorDetails: errorDetails,
      );
    } else {
      _showOverlay(
        context: context,
        title: title,
        message: message,
        isSuccess: false,
        triggerKey: triggerKey,
      );
    }
  }

  // Method to remove any active overlay
  static void clear() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}
