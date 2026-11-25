import 'dart:async';
import 'dart:typed_data';

import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/services/photo_picker.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/core/widgets/form_page_layout.dart';
import 'package:evasion/core/widgets/pick_photo.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:evasion/features/posts/presentation/create_post/create_post_controller.dart';
import 'package:evasion/features/posts/presentation/create_post/post_options.dart';
import 'package:evasion/features/posts/presentation/create_post/post_photo_and_caption.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Writes and publishes a post of [userId]: photo, caption, precision and
/// lifetime. The place is the phone's position for now.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({required this.userId, super.key});

  /// Provided by the router, so that this feature does not depend on auth.
  final String userId;

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _caption = TextEditingController();
  Uint8List? _photo;
  PostPrecision _precision = PostPrecision.fuzzy;
  Duration _lifetime = BusinessRules.postDefaultLifetime;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  PostDraft? get _draft {
    final photo = _photo;
    if (photo == null) return null;
    return PostDraft(
      photo: photo,
      // pickCheckedPhoto only returns photos of a known format.
      format: detectPhotoFormat(photo)!,
      caption: _caption.text,
      precision: _precision,
      lifetime: _lifetime,
    );
  }

  Future<void> _pickPhoto() async {
    final source = await choosePhotoSource(context);
    if (source == null || !mounted) return;
    final photo = await pickCheckedPhoto(
      context,
      ref,
      source: source,
      shape: PhotoShape.portrait,
      cropTitle: AppLocalizations.of(context).pagePhotoCropTitle,
    );
    if (photo != null && mounted) setState(() => _photo = photo);
  }

  Future<void> _changePrecision(PostPrecision precision) async {
    if (precision == PostPrecision.exact && !await confirmExactPlace(context)) {
      return;
    }
    if (mounted) setState(() => _precision = precision);
  }

  Future<void> _publish(PostDraft draft) async {
    final published = await ref
        .read(createPostControllerProvider(widget.userId).notifier)
        .publish(draft);
    if (!published || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).createPostPublished),
        ),
      );
    setState(() {
      _photo = null;
      _caption.clear();
      _precision = PostPrecision.fuzzy;
      _lifetime = BusinessRules.postDefaultLifetime;
    });
    context.go(AppRoutes.home);
  }

  void _showError(Object error) {
    final l10n = AppLocalizations.of(context);
    final (message, canOpenSettings) = switch (error) {
      LocationAccessDenied(permanently: true) => (
        l10n.locationDeniedForever,
        true,
      ),
      LocationAccessDenied() => (l10n.locationDenied, false),
      LocationServiceDisabled() => (l10n.locationDisabled, false),
      TimeoutException() => (l10n.locationTimeout, false),
      _ => (failureMessage(context, error), false),
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          action: canOpenSettings
              ? SnackBarAction(
                  label: l10n.locationOpenSettings,
                  onPressed: () =>
                      ref.read(locationServiceProvider).openSettings(),
                )
              : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final provider = createPostControllerProvider(widget.userId);
    ref.listen(provider, (_, next) {
      if (next case AsyncError(:final error)) _showError(error);
    });
    final isPublishing = ref.watch(provider).isLoading;
    final draft = _draft;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.createPostTitle)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  PostPhotoAndCaption(
                    photo: _photo,
                    caption: _caption,
                    onPickPhoto: isPublishing ? null : _pickPhoto,
                    onCaptionChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  PostPlaceSection(
                    precision: _precision,
                    onPrecisionChanged: isPublishing ? null : _changePrecision,
                  ),
                  const SizedBox(height: 24),
                  const PostAudienceSection(),
                  const SizedBox(height: 24),
                  PostLifetimeSection(
                    lifetime: _lifetime,
                    onChanged: isPublishing
                        ? null
                        : (lifetime) => setState(() => _lifetime = lifetime),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: LoadingButton(
                label: l10n.createPostPublish,
                isLoading: isPublishing,
                onPressed: draft != null && draft.isValid
                    ? () => unawaited(_publish(draft))
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
