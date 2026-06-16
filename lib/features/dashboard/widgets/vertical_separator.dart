import 'package:flutter/material.dart';

class VerticalSeparator extends StatelessWidget {
  const VerticalSeparator({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 0.3,
      color: isDark ? Colors.white : Colors.black,
      margin: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
}
