import 'package:evasion/core/storage/storage_images.dart';
import 'package:evasion/core/utils/server_date.dart';
import 'package:evasion/core/widgets/storage_image.dart';
import 'package:evasion/features/profile/domain/profile.dart';
import 'package:evasion/features/profile/presentation/carousel/carousel_card.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';

/// First carousel page, built from the profile itself: photo, name, age,
/// occupation, university and student badge.
class MainPageCard extends StatelessWidget {
  const MainPageCard({required this.profile, super.key});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onPhoto = theme.colorScheme.onSurface;
    final birthDate = profile.birthDate;
    final name = profile.displayName ?? '';
    final avatarPath = profile.avatarPath;

    return CarouselCard(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (avatarPath != null)
            StorageImage(bucket: StorageBucket.avatars, path: avatarPath),
          Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(
              width: double.infinity,
              child: BottomShade(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    if (profile.isStudentVerified)
                      Chip(
                        avatar: const Icon(Icons.school_outlined, size: 18),
                        label: Text(l10n.profileStudentBadge),
                        visualDensity: VisualDensity.compact,
                      ),
                    Text(
                      birthDate == null
                          ? name
                          : l10n.profileNameAndAge(
                              name,
                              ageOn(birthDate, serverToday()),
                            ),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: onPhoto,
                      ),
                    ),
                    for (final line in [profile.occupation, profile.university])
                      if (line != null && line.trim().isNotEmpty)
                        Text(
                          line,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: onPhoto,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
