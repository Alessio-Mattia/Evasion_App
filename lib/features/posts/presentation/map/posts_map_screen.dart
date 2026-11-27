import 'dart:async';

import 'package:evasion/app/router/app_routes.dart';
import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/map/map_view.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/services/location_service.dart';
import 'package:evasion/core/widgets/failure_snack_bar.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/presentation/map/map_feed_controller.dart';
import 'package:evasion/features/posts/presentation/map/post_card.dart';
import 'package:evasion/features/posts/presentation/map/post_markers.dart';
import 'package:evasion/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The map tab: the posts around, a tap shows one, and "+" creates one.
///
/// It opens on the campus, then moves to the phone's position once known.
/// Without the location permission, it simply stays there.
class PostsMapScreen extends ConsumerStatefulWidget {
  const PostsMapScreen({super.key});

  @override
  ConsumerState<PostsMapScreen> createState() => _PostsMapScreenState();
}

class _PostsMapScreenState extends ConsumerState<PostsMapScreen> {
  String? _selectedId;
  GeoPoint? _position;

  @override
  void initState() {
    super.initState();
    unawaited(_locate());
  }

  Future<void> _locate() async {
    try {
      final position = await ref
          .read(locationServiceProvider)
          .currentPosition();
      if (mounted) setState(() => _position = position);
    } on Exception {
      // Refused, turned off or not found: the map stays on the campus.
    }
  }

  Future<void> _newPost() async {
    final published = await context.push<bool>(AppRoutes.newPost);
    if (published ?? false) {
      await ref.read(mapFeedControllerProvider.notifier).refresh();
    }
  }

  Post? _selected(List<Post> posts) {
    for (final post in posts) {
      if (post.id == _selectedId) return post;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feed = ref.watch(mapFeedControllerProvider);
    final controller = ref.read(mapFeedControllerProvider.notifier);
    ref.listen(mapFeedControllerProvider.select((feed) => feed.failure), (
      _,
      failure,
    ) {
      if (failure != null) showFailureSnackBar(context, failure);
    });
    final selected = _selected(feed.posts);

    return Scaffold(
      body: Stack(
        // The whole screen: else the stack takes the width of the title.
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: ref.watch(mapViewBuilderProvider)(
              MapViewProps(
                initialCenter: BusinessRules.mapDefaultCenter,
                initialZoom: BusinessRules.mapInitialZoom,
                focus: _position,
                showUserLocation: _position != null,
                markers: postMarkers(feed.posts),
                selectedId: selected?.id,
                onAreaChanged: (area) => unawaited(controller.showArea(area)),
                onMarkerTapped: (id) => setState(() => _selectedId = id),
                onEmptyTapped: () => setState(() => _selectedId = null),
                markerColor: colors.primary,
                selectedColor: colors.secondary,
                outlineColor: colors.surface,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 10,
                children: [
                  Text(l10n.mapTitle, style: theme.textTheme.headlineMedium),
                  if (feed.areaTooLarge)
                    Chip(
                      avatar: const Icon(Icons.zoom_in),
                      label: Text(l10n.mapZoomIn),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: 12,
              children: [
                FloatingActionButton(
                  onPressed: _newPost,
                  tooltip: l10n.mapNewPost,
                  child: const Icon(Icons.add),
                ),
                if (selected != null)
                  PostCard(
                    post: selected,
                    now: DateTime.now(),
                    onTogglePin: () =>
                        unawaited(controller.togglePin(selected)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
