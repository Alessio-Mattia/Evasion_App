import 'package:flutter/material.dart';

/// A short message about a connection, with what the user can do next.
class ConnectCard extends StatelessWidget {
  const ConnectCard({
    required this.message,
    this.leading,
    this.detail,
    this.actions = const [],
    super.key,
  });

  final String message;
  final Widget? leading;
  final String? detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            ?leading,
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            if (detail case final detail?)
              Text(
                detail,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ...actions,
          ],
        ),
      ),
    );
  }
}
