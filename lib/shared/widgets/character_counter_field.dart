import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CharacterCounterField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final int? maxLength;
  final String? labelText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final bool obscureText;
  final bool readOnly;
  final bool enableInteractiveSelection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final bool enabled;

  const CharacterCounterField({
    super.key,
    this.controller,
    this.focusNode,
    required this.decoration,
    this.maxLength,
    this.labelText,
    this.keyboardType,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.obscureText = false,
    this.readOnly = false,
    this.enableInteractiveSelection = true,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.enabled = true,
  });

  @override
  State<CharacterCounterField> createState() => _CharacterCounterFieldState();
}

class _CharacterCounterFieldState extends State<CharacterCounterField> {
  late FocusNode _focusNode;
  bool _isFocused = false;
  TextEditingController? _internalController;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    // Adiciona listener ao controller também para atualizar contagem
    _effectiveController.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant CharacterCounterField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      (oldWidget.controller ?? _internalController)
          ?.removeListener(_onTextChanged);

      if (widget.controller != null) {
        // New external controller
        _internalController?.dispose();
        _internalController = null;
      } else {
        // New is null, check if we need to create internal (if we didn't have one)
        _internalController ??=
            TextEditingController(text: oldWidget.controller?.text);
      }
      _effectiveController.addListener(_onTextChanged);
    }

    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) {
        _focusNode.dispose();
      }
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
      _isFocused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _effectiveController.removeListener(_onTextChanged);
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _internalController?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final maxLength = widget.maxLength;
    final currentLength = _effectiveController.text.length;

    InputDecoration effectiveDecoration = widget.decoration;

    // Só mostra o contador se estiver focado
    if (maxLength != null && _isFocused) {
      final counterText = ' $currentLength/$maxLength';

      if (effectiveDecoration.label != null) {
        // Se já existe um label (Widget)
        effectiveDecoration = effectiveDecoration.copyWith(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(child: effectiveDecoration.label!),
              Text(
                counterText,
                style: const TextStyle(
                  fontSize: 12,
                ),
              ),
            ],
          ),
          counterText: '',
        );
      } else if (effectiveDecoration.labelText != null) {
        effectiveDecoration = effectiveDecoration.copyWith(
          labelText: '${effectiveDecoration.labelText}$counterText',
          counterText: '',
        );
      } else if (widget.labelText != null) {
        effectiveDecoration = effectiveDecoration.copyWith(
          labelText: '${widget.labelText}$counterText',
          counterText: '',
        );
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      enabled: widget.enabled,
      controller: _effectiveController,
      focusNode: _focusNode,
      decoration: effectiveDecoration,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      obscureText: widget.obscureText,
      readOnly: widget.readOnly,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      style: widget.style ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white : Colors.black,
          ),
      buildCounter: (_,
              {required currentLength, required isFocused, maxLength}) =>
          const SizedBox.shrink(),
    );
  }
}
