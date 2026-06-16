import 'package:flutter/material.dart';

class TabButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool showIcon;

  const TabButton({
    super.key,
    this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? const LinearGradient(colors: [Color(0xFF684F8E), Color(0xFF5A3D8A)])
              : null,
          color: isSelected ? null : Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF374151)
              : const Color(0xFFF8F9FB),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF684F8E).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : const Color(0xFF101828),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
