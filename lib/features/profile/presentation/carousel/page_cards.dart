import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';
import 'package:evasion/features/profile/presentation/carousel/carousel_card.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// One free page of the carousel, drawn according to its template.
class PageCard extends StatelessWidget {
  const PageCard({required this.page, super.key});

  final ProfilePage page;

  @override
  Widget build(BuildContext context) {
    return CarouselCard(
      child: switch (page) {
        TextPage(:final text) => _TextContent(text: text),
        PhotoPage(:final imagePath, :final caption) => _PhotoContent(
          imagePath: imagePath,
          caption: caption,
        ),
        InterestsPage(:final interests) => _InterestsContent(
          labels: [
            for (final interest in interests)
              interest.label(AppLocalizations.of(context)),
          ],
        ),
      },
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

class _PhotoContent extends StatelessWidget {
  const _PhotoContent({required this.imagePath, required this.caption});

  final String imagePath;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caption = this.caption;
    return Stack(
      fit: StackFit.expand,
      children: [
        StorageImage(bucket: StorageBucket.profilePhotos, path: imagePath),
        if (caption != null)
          Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: double.infinity,
              child: BottomShade(
                child: Text(
                  caption,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _InterestsContent extends StatelessWidget {
  const _InterestsContent({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          spacing: 16,
          children: [
            Text(
              AppLocalizations.of(context).profileInterestsTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [for (final label in labels) Chip(label: Text(label))],
            ),
          ],
        ),
      ),
    );
  }
}
