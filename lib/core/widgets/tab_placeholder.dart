import 'package:flutter/material.dart';

/// Temporary content for a tab whose feature is not built yet.
class TabPlaceholder extends StatelessWidget {
  const TabPlaceholder({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
