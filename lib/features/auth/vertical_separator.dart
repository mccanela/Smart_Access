import 'package:flutter/material.dart';

class VerticalOscillatingSeparator extends StatefulWidget {
  const VerticalOscillatingSeparator({super.key});

  @override
  State<VerticalOscillatingSeparator> createState() =>
      _VerticalOscillatingSeparatorState();
}

class _VerticalOscillatingSeparatorState
    extends State<VerticalOscillatingSeparator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
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
    return Container(
      width: 4,
      color: const Color(0xFF130B29), // Background to avoid gaps
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [
                  Color(0xFF8B2FC9), // Vivid Purple (Top from reference)
                  Color(0xFF2E094F), // Deep Dark Purple (Bottom from reference)
                  Color(0xFF8B2FC9), // Loop back to Vivid Purple
                ],
                stops: [
                  0.0,
                  _controller.value, // Animate the middle point
                  1.0,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
