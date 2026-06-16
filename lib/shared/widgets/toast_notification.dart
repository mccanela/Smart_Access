import 'package:flutter/material.dart';

class ToastNotification extends StatefulWidget {
  final String title;
  final String message;
  final bool isSuccess;
  final bool isWarning;
  final GlobalKey? triggerKey; // Target for positioning
  final VoidCallback onDismiss;

  const ToastNotification({
    super.key,
    required this.title,
    required this.message,
    required this.isSuccess,
    this.isWarning = false,
    this.triggerKey,
    required this.onDismiss,
  });

  @override
  State<ToastNotification> createState() => _ToastNotificationState();
}

class _ToastNotificationState extends State<ToastNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _expandAnimation;

  Offset _position = const Offset(0, 40); // Default bottom position
  final double _width = 340;
  bool _isBelowTrigger = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));
    _expandAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.fastOutSlowIn));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _calculatePosition();
      _controller.forward();
    });

    // Auto dismiss after 3 seconds as requested
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((value) => widget.onDismiss());
      }
    });
  }

  void _calculatePosition() {
    if (widget.triggerKey != null &&
        widget.triggerKey!.currentContext != null) {
      final renderBox =
          widget.triggerKey!.currentContext!.findRenderObject() as RenderBox;
      final size = renderBox.size;
      final position = renderBox.localToGlobal(Offset.zero);

      setState(() {
        // Position below the button
        _position = Offset(position.dx + (size.width / 2) - (_width / 2),
            position.dy + size.height + 8);
        _isBelowTrigger = true;

        // Keep inside screen bounds
        final screenWidth = MediaQuery.of(context).size.width;
        if (_position.dx < 10) _position = Offset(10, _position.dy);
        if (_position.dx + _width > screenWidth - 10) {
          _position = Offset(screenWidth - _width - 10, _position.dy);
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    IconData iconData;

    if (widget.isWarning) {
      color = const Color(0xFFF59E0B);
      iconData = Icons.warning_amber_rounded;
    } else if (widget.isSuccess) {
      color = const Color(0xFF10B981);
      iconData = Icons.check_circle_outline;
    } else {
      color = const Color(0xFFEF4444);
      iconData = Icons.error_outline;
    }

    Widget content = Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            width: _width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.title.isNotEmpty)
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () =>
                      _controller.reverse().then((_) => widget.onDismiss()),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 16,
                  color: isDark ? Colors.white30 : Colors.black26,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (_isBelowTrigger) {
      return Positioned(
        left: _position.dx,
        top: _position.dy,
        child: content,
      );
    }

    return Positioned(
      bottom: _position.dy,
      left: 0,
      right: 0,
      child: Center(child: content),
    );
  }
}
