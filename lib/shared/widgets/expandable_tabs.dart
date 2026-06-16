import 'package:flutter/material.dart';

enum TabType { item, separator }

class TabItem {
  final String? title;
  final IconData? icon;
  final TabType type;

  const TabItem({
    required this.title,
    required this.icon,
    this.type = TabType.item,
  });

  const TabItem.separator()
      : title = null,
        icon = null,
        type = TabType.separator;
}

class ExpandableTabs extends StatefulWidget {
  final List<TabItem> tabs;
  final ValueChanged<int>? onChange;
  final Color? activeColor;
  final int initialIndex;

  const ExpandableTabs({
    super.key,
    required this.tabs,
    this.onChange,
    this.activeColor,
    this.initialIndex = 0,
  });

  @override
  State<ExpandableTabs> createState() => _ExpandableTabsState();
}

class _ExpandableTabsState extends State<ExpandableTabs> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _handleSelect(int index) {
    if (_selectedIndex != index) {
      setState(() {
        _selectedIndex = index;
      });
      widget.onChange?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = widget.activeColor ?? Theme.of(context).primaryColor;

    // Background color for the container (mimicking the React component's border/bg)
    final containerBgColor = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.03);

    final containerBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: containerBgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: containerBorderColor),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: widget.tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;

          if (tab.type == TabType.separator) {
            return Container(
              height: 24,
              width: 1,
              color: isDark ? Colors.white24 : Colors.black12,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            );
          }

          // Count valid item indices to map correctly if separators exist?
          // The React component uses simple index from map, assuming separators also take an index slot but don't set selection?
          // Actually in React code: "onClick={() => handleSelect(index)}" inside map.
          // Separators are just rendered.
          // If I have separators in the list, the index passed to onChange will include separators.
          // This might be confusing for TabController which expects 0, 1, 2... for pages.
          // However, the React component seemingly treats index as the items index in the `tabs` array.
          // So if tab 2 is a separator, tab 3 has index 3.
          // I should respect this behavior or map it.
          // Given the prompt's `TabItem = Tab | Separator`, index refers to position in `tabs` array.

          final isSelected = _selectedIndex == index;

          return _buildTabButton(
            context,
            index,
            tab,
            isSelected,
            activeColor,
            isDark,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    int index,
    TabItem tab,
    bool isSelected,
    Color activeColor,
    bool isDark,
  ) {
    final textColor =
        isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54);

    final bgColor =
        isSelected ? activeColor.withValues(alpha: 0.1) : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _handleSelect(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic, // Spring-like
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 12 : 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                tab.icon,
                size: 20,
                color: textColor,
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: isSelected ? null : 0,
                  child: isSelected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            tab.title ?? '',
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
