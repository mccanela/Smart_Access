import 'package:flutter/material.dart';

class IconActionData {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOpaque;
  final bool isMarked;
  final Color? color;
  final double? iconSize;
  final GlobalKey? key;

  const IconActionData({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isLoading = false,
    this.isOpaque = false,
    this.isMarked = false,
    this.color,
    this.iconSize,
    this.key,
  });
}

class TransparentIconGroup extends StatelessWidget {
  final List<IconActionData> actions;
  final double? minWidth;
  final Color? backgroundColor;

  const TransparentIconGroup(
    this.actions, {
    super.key,
    this.minWidth,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;
    final dividerColor = iconColor.withValues(alpha: 0.5);

    return Container(
      height: 40,
      constraints: minWidth != null ? BoxConstraints(minWidth: minWidth!) : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: BorderRadius.circular(40),
        border:
            Border.all(color: dividerColor.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(actions.length * 2 - 1, (index) {
          if (index % 2 == 0) {
            final actionIndex = index ~/ 2;
            final action = actions[actionIndex];
            return _buildGroupedIcon(
              action.icon,
              action.color ?? iconColor,
              action.onPressed,
              action.tooltip,
              isLoading: action.isLoading,
              isOpaque: action.isOpaque,
              isMarked: action.isMarked,
              iconSize: action.iconSize,
              key: action.key,
            );
          } else {
            return _buildDivider(dividerColor);
          }
        }),
      ),
    );
  }

  Widget _buildGroupedIcon(
      IconData icon, Color color, VoidCallback? onPressed, String tooltip,
      {bool isLoading = false,
      bool isOpaque = false,
      bool isMarked = false,
      double? iconSize,
      Key? key}) {
    final tooltipMessage = isOpaque ? '$tooltip (desabilitado)' : tooltip;

    return Tooltip(
      key: key,
      message: tooltipMessage,
      preferBelow: false,
      enableFeedback: true,
      waitDuration: isOpaque
          ? const Duration(milliseconds: 100)
          : const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isOpaque ? Colors.grey.shade800 : const Color(0xFF10133E),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        cursor: isLoading
            ? SystemMouseCursors.basic
            : (onPressed == null || isOpaque
                ? SystemMouseCursors.forbidden
                : SystemMouseCursors.click),
        child: GestureDetector(
          onTap: (isLoading || isOpaque) ? null : onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: isOpaque
                ? BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  )
                : null,
            child: isLoading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                : Icon(
                    icon,
                    color: isLoading
                        ? color.withValues(alpha: 0.5)
                        : (isOpaque
                            ? color.withValues(alpha: 0.35)
                            : color),
                    size: iconSize ?? (isOpaque ? 24 : 28),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(
      width: 1,
      height: 28,
      color: color,
    );
  }
}
