import 'package:flutter/material.dart';
import 'character_counter_field.dart';
import '../../core/utils/ui_standards.dart';

class CustomInput extends StatelessWidget {
  final String hintText;
  final IconData? suffixIcon;
  final IconData? prefixIcon;
  final int maxLines;
  final bool isDropdown;
  final TextEditingController? controller;
  final int? maxLength;
  final String? labelText;

  const CustomInput({
    super.key,
    required this.hintText,
    this.suffixIcon,
    this.prefixIcon,
    this.maxLines = 1,
    this.isDropdown = false,
    this.controller,
    this.maxLength,
    this.labelText,
  });

  @override
  Widget build(BuildContext context) {
    return CharacterCounterField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      decoration: inputDecorationPadrao(
        context,
        labelText: labelText ?? hintText,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        suffixIcon: isDropdown
            ? const Icon(Icons.arrow_drop_down)
            : (suffixIcon != null ? Icon(suffixIcon, size: 20) : null),
      ).copyWith(
        alignLabelWithHint: maxLines > 1,
        contentPadding: EdgeInsets.symmetric(
            horizontal: 16, vertical: maxLines > 1 ? 12 : 12),
      ),
    );
  }
}

