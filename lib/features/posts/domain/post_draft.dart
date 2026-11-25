import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/geo_point.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/posts/domain/post.dart';

/// Why the server would refuse a post, checked before sending it.
enum PostDraftProblem {
  /// Not a JPEG, PNG or WebP image, or over the size limit.
  invalidPhoto,

  /// Over `BusinessRules.postCaptionMaxLength` code points once trimmed.
  captionTooLong,

  /// Outside `BusinessRules.postMinLifetime` and `postMaxLifetime`.
  invalidLifetime,

  /// A selected audience without any friend in it.
  emptyAudienceList,
}

/// Whether the server accepts [lifetime] for a post. It counts in whole
/// minutes, as the server does.
bool isValidPostLifetime(Duration lifetime) =>
    lifetime.inMinutes >= BusinessRules.postMinLifetime.inMinutes &&
    lifetime.inMinutes <= BusinessRules.postMaxLifetime.inMinutes;

/// A post being written, before it is sent.
class PostDraft {
  const PostDraft({
    required this.photo,
    required this.format,
    this.caption = '',
    this.place,
    this.precision = PostPrecision.fuzzy,
    this.lifetime = BusinessRules.postDefaultLifetime,
    this.audience = PostAudience.everyone,
    this.audienceIds = const [],
  });

  final Uint8List photo;
  final PhotoFormat format;

  /// As typed; see [trimmedCaption].
  final String caption;

  /// A place picked by the author, within
  /// `BusinessRules.postChosenLocationMaxDistanceMeters` of the phone. Null
  /// puts the post at the phone's position.
  final GeoPoint? place;
  final PostPrecision precision;

  /// Counted from the creation of the post.
  final Duration lifetime;
  final PostAudience audience;

  /// Ids of the friends who can see the post, for a selected [audience]
  /// only: ignored otherwise.
  final List<String> audienceIds;

  /// The caption as the server stores it: trimmed, and null when blank.
  String? get trimmedCaption {
    final trimmed = caption.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// The friends sent to the server: none unless the audience is selected.
  List<String> get sentAudienceIds =>
      audience == PostAudience.selected ? audienceIds.toSet().toList() : [];

  /// Every reason the server would refuse this post; empty if it is valid.
  Set<PostDraftProblem> get problems => {
    if (checkPhoto(photo) != null) PostDraftProblem.invalidPhoto,
    if ((trimmedCaption ?? '').runes.length >
        BusinessRules.postCaptionMaxLength)
      PostDraftProblem.captionTooLong,
    if (!isValidPostLifetime(lifetime)) PostDraftProblem.invalidLifetime,
    if (audience == PostAudience.selected && audienceIds.isEmpty)
      PostDraftProblem.emptyAudienceList,
  };

  bool get isValid => problems.isEmpty;
}
