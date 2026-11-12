import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/interest.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/domain/profile_page.dart';

/// Templates of the free carousel pages, with their value in the database.
enum PageType {
  text('text'),
  photo('photo'),
  interests('interests');

  const PageType(this.code);

  final String code;

  static PageType? fromCode(String code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

extension ProfilePageType on ProfilePage {
  PageType get type => switch (this) {
    TextPage() => PageType.text,
    PhotoPage() => PageType.photo,
    InterestsPage() => PageType.interests,
  };
}

/// A page being created or edited, before it is saved.
sealed class PageDraft {
  const PageDraft();

  PageType get type;

  /// The `content` column, exactly as the server expects it: no other key,
  /// and texts without surrounding spaces.
  Map<String, Object> get content;
}

final class TextPageDraft extends PageDraft {
  const TextPageDraft(this.text);

  final String text;

  @override
  PageType get type => PageType.text;

  @override
  Map<String, Object> get content => {'text': text.trim()};
}

final class PhotoPageDraft extends PageDraft {
  const PhotoPageDraft({
    required this.bytes,
    required this.format,
    this.caption = '',
  });

  final Uint8List bytes;
  final PhotoFormat format;
  final String caption;

  @override
  PageType get type => PageType.photo;

  @override
  Map<String, Object> get content => _captionContent(caption);
}

/// A photo page being edited that keeps its photo, at [imagePath]: only the
/// caption may change.
final class KeptPhotoPageDraft extends PageDraft {
  const KeptPhotoPageDraft({required this.imagePath, this.caption = ''});

  final String imagePath;
  final String caption;

  @override
  PageType get type => PageType.photo;

  @override
  Map<String, Object> get content => _captionContent(caption);
}

/// An empty caption is left out: the server refuses a null or blank one.
Map<String, Object> _captionContent(String caption) => {
  if (caption.trim() case final caption when caption.isNotEmpty)
    'caption': caption,
};

final class InterestsPageDraft extends PageDraft {
  const InterestsPageDraft(this.interests);

  /// In the order the user chose them.
  final List<Interest> interests;

  @override
  PageType get type => PageType.interests;

  @override
  Map<String, Object> get content => {
    'interests': [for (final interest in interests) interest.code],
  };
}

enum PageTextProblem { empty, tooLong }

/// Why the server would refuse this page text, or null if it is acceptable.
PageTextProblem? checkPageText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return PageTextProblem.empty;
  // Code points, like Postgres char_length.
  if (trimmed.runes.length > BusinessRules.pageTextMaxLength) {
    return PageTextProblem.tooLong;
  }
  return null;
}

/// Whether the server would refuse this caption. An empty one is fine: it is
/// left out.
bool isCaptionTooLong(String caption) =>
    caption.trim().runes.length > BusinessRules.pageCaptionMaxLength;

/// Whether these interests can be saved: at least one, at most the maximum.
bool areInterestsValid(List<Interest> interests) =>
    interests.isNotEmpty &&
    interests.length <= BusinessRules.interestsMaxPerPage &&
    interests.toSet().length == interests.length;
