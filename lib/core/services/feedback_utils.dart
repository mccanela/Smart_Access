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

  /// Helper privado para mostrar notificação overlay
  static void _showOverlayx1({
    required BuildContext context,
    required String title,
    required String message,
    required bool isSuccess,
    bool isWarning = false,
    GlobalKey? triggerKey, // Added to target specific button
  }) {
    // Remove notificação anterior se existir
    _currentOverlay?.remove();
    _currentOverlay = null;

    final overlayState = Overlay.of(context);

    _currentOverlay = OverlayEntry(
      builder: (context) => ToastNotification(
        title: title,
        message: message,
        isSuccess: isSuccess,
        isWarning: isWarning,
        triggerKey: triggerKey, // Pass to toast for positioning
        onDismiss: () {
          _currentOverlay?.remove();
          _currentOverlay = null;
        },
      ),
    );

    overlayState.insert(_currentOverlay!);
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

    final overlayState = Overlay.of(context);

    // 1. Configuração de posicionamento padrão (Canto inferior direito, como estava antes)
    double? top;
    double? bottom = 20;
    double? left;
    double? right = 20;
    double? width;

    // 2. Se a chave do Box foi passada, recalculamos para brotar dentro dele!
    if (triggerKey != null && triggerKey.currentContext != null) {
      final renderBox =
          triggerKey.currentContext!.findRenderObject() as RenderBox;
      final position =
          renderBox.localToGlobal(Offset.zero); // Posição X e Y do Box na tela
      final size = renderBox.size; // Largura e Altura do Box

      // Alinha nas laterais internas do Box (com 16px de folga em cada lado)
      left = position.dx + 16;
      width = size.width - 32;

      // Posiciona próximo ao fundo do Box.
      // Nota: Se o seu Toast sumir ou cortar, mude esse '- 85' para mais ou para menos
      // dependendo da altura real do seu card de aviso.
      top = position.dy + size.height - 85;

      // Anula as posições padrão do canto da tela
      bottom = null;
      right = null;
    }

    // 3. Monta o Overlay com as coordenadas calculadas
    _currentOverlay = OverlayEntry(
      builder: (context) => Positioned(
        top: top,
        bottom: bottom,
        left: left,
        right: right,
        width: width, // Aplica a largura responsiva do Box aqui
        child: Material(
          color: Colors
              .transparent, // Evita fundo preto ou sublinhados amarelos no texto
          child: ToastNotification(
            title: title,
            message: message,
            isSuccess: isSuccess,
            isWarning: isWarning,
            triggerKey: triggerKey,
            onDismiss: () {
              _currentOverlay?.remove();
              _currentOverlay = null;
            },
          ),
        ),
      ),
    );

    overlayState.insert(_currentOverlay!);
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
