import 'package:flutter/material.dart';

class SidePanel extends StatefulWidget {
  final Widget child;
  final VoidCallback onClose;

  const SidePanel({super.key, required this.child, required this.onClose});

  @override
  State<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends State<SidePanel> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    // Slide in from the right side
    _slideAnimation = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep calculation based on the logical sidebar width (80).
    // Visual padding around the sidebar does not change this.
    final screenWidth = MediaQuery.of(context).size.width - 80;
    final panelWidth = screenWidth * 0.5;

    // Funções auxiliares para cores adaptáveis ao tema (mesmas do dashboard)
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color backgroundColor = isDarkMode ? const Color(0xFF1F2937) : Colors.white;
    Color borderColor = isDarkMode ? Colors.grey[600]! : Colors.grey.shade300;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.all(16),
        width: panelWidth,
        height: double.infinity,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(-6, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: widget.child,
      ),
    );
  }
}
