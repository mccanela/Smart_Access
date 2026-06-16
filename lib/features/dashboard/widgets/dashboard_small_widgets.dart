import 'package:flutter/material.dart';

/// Placeholder para quando não há foto
class PhotoPlaceholder extends StatelessWidget {
  const PhotoPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.camera_alt_rounded,
            size: 28, color: isDark ? Colors.grey[600] : Colors.grey[400]),
        const SizedBox(height: 4),
        Text(
          'Sem Foto',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[600] : Colors.grey[400]),
        ),
      ],
    );
  }
}

/// Ícone quadrado com fundo colorido
class IconSquare extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const IconSquare(this.icon, this.color, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.12),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

/// Ícone circular com badge
class CircleIconWithBadge extends StatelessWidget {
  final IconData icon;
  final String badge;
  final Color color;

  const CircleIconWithBadge(this.icon, this.badge,
      {super.key, this.color = Colors.blue});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color),
            ),
            child: Text(badge,
                style: TextStyle(
                    color: color, fontSize: 10, fontWeight: FontWeight.w500)),
          ),
        )
      ],
    );
  }
}

/// Container simples para cards do dashboard
class DashboardCard extends StatelessWidget {
  final Widget child;
  const DashboardCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}
