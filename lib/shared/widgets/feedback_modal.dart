import 'package:flutter/material.dart';
import '../../core/utils/ui_standards.dart';

class FeedbackModal extends StatefulWidget {
  final String title;
  final String message;
  final bool isSuccess;
  final bool isWarning;
  final String? errorDetails;
  final VoidCallback? onClose;

  const FeedbackModal({
    super.key,
    required this.title,
    required this.message,
    required this.isSuccess,
    this.isWarning = false,
    this.errorDetails,
    this.onClose,
  });

  @override
  State<FeedbackModal> createState() => _FeedbackModalState();
}

class _FeedbackModalState extends State<FeedbackModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              color: Colors.black54,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.black26, width: 1),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header com ícone animado
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: widget.isWarning
                              ? const Color(0xFFF59E0B) // Amber/Orange
                              : widget.isSuccess
                                  ? const Color(0xFF12B76A)
                                  : const Color(0xFFEF4444),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Ícone animado
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Icon(
                                widget.isWarning
                                    ? Icons.warning_amber_rounded
                                    : widget.isSuccess
                                        ? Icons.check_circle_outline
                                        : Icons.error_outline,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.isWarning
                                        ? 'Atenção'
                                        : widget.isSuccess
                                            ? 'Sucesso!'
                                            : 'Erro',
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Botão fechar
                            IconButton(
                              onPressed: () {
                                _animationController.reverse().then((_) {
                                  if (widget.onClose != null) {
                                    widget.onClose!();
                                  }
                                });
                              },
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Conteúdo
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            // Mensagem principal
                            Text(
                              widget.message,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF374151),
                              ),
                              textAlign: TextAlign.center,
                            ),

                            const SizedBox(height: 20),

                            // Detalhes do erro (se houver)
                            if (widget.errorDetails != null) ...[
                              // Botão para expandir
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isExpanded
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        color: const Color(0xFF6B7280),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isExpanded
                                            ? 'Ocultar detalhes'
                                            : 'Ver detalhes do erro',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Detalhes expandidos
                              if (_isExpanded) ...[
                                const SizedBox(height: 16),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFECACA),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Color(0xFFDC2626),
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Detalhes do erro:',
                                            style: TextStyle(
                                              color: Color(0xFFDC2626),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        widget.errorDetails!,
                                        style: const TextStyle(
                                          color: Color(0xFF991B1B),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],

                            const SizedBox(height: 24),

                            // Botão de ação
                            AppButtons.primaryButton(
                              onPressed: () {
                                _animationController.reverse().then((_) {
                                  if (widget.onClose != null) {
                                    widget.onClose!();
                                  }
                                });
                              },
                              text: widget.isSuccess
                                  ? 'Continuar'
                                  : 'Tentar novamente',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
