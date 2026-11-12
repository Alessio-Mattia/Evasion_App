import 'package:flutter/material.dart';

/// Rounded frame of one carousel page, with a gap to the next page.
class CarouselCard extends StatelessWidget {
  const CarouselCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: child,
        ),
      ),
    );
  }
}

/// Darkens the bottom of a photo so that the text on it stays readable.
class BottomShade extends StatelessWidget {
  const BottomShade({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scrim = Theme.of(context).colorScheme.scrim;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [scrim.withValues(alpha: 0), scrim.withValues(alpha: 0.75)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
        child: child,
      ),
    );
  }
}
