import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget TextField com contador de caracteres automático
/// Mostra "Label X/Y" onde X é o número atual e Y é o limite máximo
class CountedTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String labelText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final bool readOnly;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? hintText;
  final TextStyle? style;
  final InputDecoration? decoration;
  final FocusNode? focusNode;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final int? maxLines;
  final int? minLines;

  const CountedTextField({
    super.key,
    this.controller,
    required this.labelText,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.enabled = true,
    this.readOnly = false,
    this.prefixIcon,
    this.suffixIcon,
    this.hintText,
    this.style,
    this.decoration,
    this.focusNode,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.minLines,
  });

  @override
  State<CountedTextField> createState() => _CountedTextFieldState();
}

class _CountedTextFieldState extends State<CountedTextField> {
  late TextEditingController _controller;
  bool _isControllerInternal = false;
  int _currentLength = 0;

  @override
  void initState() {
    super.initState();

    // Usar o controller fornecido ou criar um interno
    if (widget.controller != null) {
      _controller = widget.controller!;
    } else {
      _controller = TextEditingController();
      _isControllerInternal = true;
    }

    // Inicializar o contador
    _currentLength = _controller.text.length;

    // Escutar mudanças no texto
    _controller.addListener(_updateCounter);
  }

  @override
  void dispose() {
    _controller.removeListener(_updateCounter);
    if (_isControllerInternal) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateCounter() {
    if (mounted) {
      setState(() {
        _currentLength = _controller.text.length;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Criar o label com contador
    final String labelWithCounter = widget.maxLength != null
        ? '${widget.labelText} $_currentLength/${widget.maxLength}'
        : widget.labelText;

    // Usar decoração customizada se fornecida, senão criar uma padrão
    final InputDecoration effectiveDecoration = widget.decoration?.copyWith(
          labelText: labelWithCounter,
        ) ??
        InputDecoration(
          labelText: labelWithCounter,
          hintText: widget.hintText,
          prefixIcon: widget.prefixIcon,
          suffixIcon: widget.suffixIcon,
          border: const OutlineInputBorder(),
          counterText: '', // Esconder o contador padrão do Flutter
        );

    return TextField(
      controller: _controller,
      decoration: effectiveDecoration,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onEditingComplete: widget.onEditingComplete,
      onSubmitted: widget.onSubmitted,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      style: widget.style,
      focusNode: widget.focusNode,
      obscureText: widget.obscureText,
      textCapitalization: widget.textCapitalization,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
    );
  }
}
