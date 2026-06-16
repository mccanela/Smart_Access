import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show kIsWeb;

class RefreshButton extends StatefulWidget {
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool shouldRotate;

  const RefreshButton({
    super.key,
    this.label,
    this.icon,
    this.onPressed,
    this.shouldRotate = true,
  });

  @override
  State<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton>
    with SingleTickerProviderStateMixin {
  bool _isHovering = false;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: InkWell(
        onTap: widget.onPressed ??
            () {
              if (kIsWeb) {
                html.window.location.reload();
              }
            },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final neonColor = const Color(0xFFA855F7).withValues(
              alpha: 0.5 + (_controller.value * 0.5),
            );

            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovering
                      ? neonColor.withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: _isHovering
                    ? [
                        BoxShadow(
                          color: neonColor.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                        BoxShadow(
                          color: neonColor.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: 4,
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedRotation(
                    turns: (widget.shouldRotate && _isHovering) ? 0.5 : 0,
                    duration: const Duration(milliseconds: 500),
                    child: Icon(
                      widget.icon ?? Icons.refresh,
                      color: _isHovering
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label ?? 'Atualizar Página',
                    style: TextStyle(
                      color: _isHovering
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      shadows: _isHovering
                          ? [
                              Shadow(
                                color: neonColor,
                                blurRadius: 8,
                              )
                            ]
                          : [],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
