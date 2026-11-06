import 'package:flutter/material.dart';

/// Temporary content for a tab whose feature is not built yet.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({required this.title, this.action, super.key});

  final String title;

  /// Optional control shown under the title.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 24,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          ?action,
        ],
      ),
    );
  }
}
