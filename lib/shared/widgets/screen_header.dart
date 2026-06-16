import 'package:flutter/material.dart';
import '../../core/utils/ui_standards.dart';

class ScreenHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onClose;
  final List<Widget>? actions;

  const ScreenHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.onClose,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10133E),
        border: Border(
            bottom: BorderSide(color: getBorderColor(context), width: 1)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    Text(
                      ' - $subtitle',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ],
              ),
            ),
            if (actions != null) ...actions!,
            if (actions != null && onClose != null) const SizedBox(width: 8),
            if (onClose != null)
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, size: 20),
                color: Colors.white,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Fechar',
              ),
          ],
        ),
      ),
    );
  }
}
