import 'dart:typed_data';

import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/posts/domain/post.dart';
import 'package:evasion/features/posts/domain/post_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_photo_picker.dart';

PostDraft draft({
  Uint8List? photo,
  String caption = '',
  Duration lifetime = BusinessRules.postDefaultLifetime,
  PostAudience audience = PostAudience.everyone,
  List<String> audienceIds = const [],
}) => PostDraft(
  photo: photo ?? jpegBytes,
  format: PhotoFormat.jpeg,
  caption: caption,
  lifetime: lifetime,
  audience: audience,
  audienceIds: audienceIds,
);

void main() {
  test('a draft with the defaults is valid', () {
    final defaults = draft();

    expect(defaults.problems, isEmpty);
    expect(defaults.precision, PostPrecision.fuzzy);
    expect(defaults.lifetime, BusinessRules.postDefaultLifetime);
    expect(defaults.place, isNull);
  });

  test('a photo the server refuses is a problem', () {
    expect(draft(photo: heicBytes).problems, {PostDraftProblem.invalidPhoto});
    expect(
      draft(
        photo: Uint8List(BusinessRules.postPhotoMaxBytes + 1)
          ..setAll(0, jpegBytes),
      ).problems,
      {PostDraftProblem.invalidPhoto},
    );
  });

  group('caption', () {
    test('is trimmed, and null when blank', () {
      expect(draft(caption: '  Sunset  ').trimmedCaption, 'Sunset');
      expect(draft(caption: '   ').trimmedCaption, isNull);
      expect(draft(caption: '   ').problems, isEmpty);
    });

    test('is counted in code points, as the server does', () {
      const max = BusinessRules.postCaptionMaxLength;
      // 👍 is one code point but two UTF-16 units in String.length.
      expect(draft(caption: '👍' * max).problems, isEmpty);
      expect(draft(caption: '👍' * (max + 1)).problems, {
        PostDraftProblem.captionTooLong,
      });
    });
  });

  group('lifetime', () {
    test('accepts the limits themselves', () {
      expect(isValidPostLifetime(BusinessRules.postMinLifetime), isTrue);
      expect(isValidPostLifetime(BusinessRules.postMaxLifetime), isTrue);
    });

    test('refuses what is outside, in whole minutes as the server', () {
      expect(
        isValidPostLifetime(
          BusinessRules.postMinLifetime - const Duration(seconds: 1),
        ),
        isFalse,
      );
      expect(
        isValidPostLifetime(
          BusinessRules.postMaxLifetime + const Duration(minutes: 1),
        ),
        isFalse,
      );
      expect(draft(lifetime: const Duration(minutes: 30)).problems, {
        PostDraftProblem.invalidLifetime,
      });
    });
  });

  group('audience', () {
    test('a selected audience needs at least one friend', () {
      expect(draft(audience: PostAudience.selected).problems, {
        PostDraftProblem.emptyAudienceList,
      });
      expect(
        draft(audience: PostAudience.selected, audienceIds: ['f1']).problems,
        isEmpty,
      );
    });

    test('only a selected audience sends its list, once per friend', () {
      expect(
        draft(
          audience: PostAudience.selected,
          audienceIds: ['f1', 'f2', 'f1'],
        ).sentAudienceIds,
        ['f1', 'f2'],
      );
      expect(
        draft(
          audience: PostAudience.friends,
          audienceIds: ['f1'],
        ).sentAudienceIds,
        isEmpty,
      );
    });
  });
}
