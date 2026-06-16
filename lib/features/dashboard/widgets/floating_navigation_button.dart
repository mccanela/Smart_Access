import 'package:flutter/material.dart';

class FloatingNavigationButton extends StatelessWidget {
  final int currentPage;
  final VoidCallback onTogglePage;

  const FloatingNavigationButton({
    super.key,
    required this.currentPage,
    required this.onTogglePage,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTabletLayout = screenWidth <= 1366;
    final isFirstPage = currentPage == 0;

    return Positioned(
      bottom: 30,
      right: 30,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: isTabletLayout
              ? LinearGradient(
                  colors: isFirstPage
                      ? [const Color(0xFF7C4DFF), const Color(0xFF5C6BC0)]
                      : [const Color(0xFF4CAF50), const Color(0xFF66BB6A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade400, Colors.grey.shade500],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: (isTabletLayout
                      ? (isFirstPage
                          ? const Color(0xFF7C4DFF)
                          : const Color(0xFF4CAF50))
                      : Colors.grey.shade500)
                  .withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: Tooltip(
            message: isTabletLayout
                ? 'Alternar entre páginas'
                : 'Layout responsivo',
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: isTabletLayout ? onTogglePage : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return ScaleTransition(scale: animation, child: child);
                },
                child: Stack(
                  key: ValueKey<int>(currentPage),
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      isTabletLayout
                          ? (isFirstPage
                              ? Icons.arrow_forward
                              : Icons.arrow_back)
                          : Icons.settings,
                      color: Colors.white,
                      size: 28,
                    ),
                    Positioned(
                      top: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: isFirstPage ? 0.4 : 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
