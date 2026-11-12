import 'package:evasion/core/storage/storage_images.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// An image of a private bucket, covering its box. Shows a plain background
/// while loading, and an icon if the image is unavailable.
class StorageImage extends ConsumerWidget {
  const StorageImage({
    required this.bucket,
    required this.path,
    this.fit = BoxFit.cover,
    super.key,
  });

  final StorageBucket bucket;
  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final unavailable = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.image_not_supported_outlined, color: colors.outline),
      ),
    );

    return switch (ref.watch(storageImageProvider(bucket, path))) {
      AsyncValue(:final value?) => Image(
        image: value,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => unavailable,
        frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
            wasSynchronouslyLoaded || frame != null
            ? child
            : ColoredBox(color: colors.surfaceContainerHighest),
      ),
      AsyncValue(hasError: true) => unavailable,
      _ => ColoredBox(color: colors.surfaceContainerHighest),
    };
  }
}
