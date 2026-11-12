import 'package:flutter/material.dart';

/// Dots under a carousel: the current page is wider and highlighted.
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    required this.count,
    required this.current,
    required this.semanticsLabel,
    super.key,
  });

  final int count;
  final int current;

  /// Read by screen readers instead of the dots, e.g. "Page 2 sur 4".
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 6,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: i == current ? 18 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == current ? colors.primary : colors.outlineVariant,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}
