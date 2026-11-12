import 'package:evasion/core/config/business_rules.dart';
import 'package:evasion/core/models/interest.dart';
import 'package:evasion/core/photos/photo_file.dart';
import 'package:evasion/features/profile/domain/page_draft.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/fake_photo_picker.dart';

void main() {
  group('content, as the server expects it', () {
    test('a text page holds its text without surrounding spaces', () {
      expect(const TextPageDraft('  Salut !\n').content, {'text': 'Salut !'});
    });

    test('a photo page leaves an empty caption out, instead of null', () {
      PhotoPageDraft photo(String caption) => PhotoPageDraft(
        bytes: pngBytes,
        format: PhotoFormat.png,
        caption: caption,
      );

      expect(photo('').content, isEmpty);
      expect(photo('   ').content, isEmpty);
      expect(photo('  Au lac ').content, {'caption': 'Au lac'});
    });

    test('an interests page keeps the order chosen', () {
      expect(
        const InterestsPageDraft([Interest.travel, Interest.music]).content,
        {
          'interests': ['travel', 'music'],
        },
      );
    });

    test('every template has the code of the database', () {
      expect(PageType.values.map((type) => type.code), [
        'text',
        'photo',
        'interests',
      ]);
      expect(PageType.fromCode('photo'), PageType.photo);
      expect(PageType.fromCode('video'), isNull);
    });
  });

  group('checkPageText', () {
    test('refuses an empty text, spaces included', () {
      expect(checkPageText(''), PageTextProblem.empty);
      expect(checkPageText('  \n '), PageTextProblem.empty);
    });

    test('counts code points, like the server', () {
      const max = BusinessRules.pageTextMaxLength;
      expect(checkPageText('a' * max), isNull);
      expect(checkPageText('a' * (max + 1)), PageTextProblem.tooLong);
      // One emoji shown, several code points counted.
      expect(checkPageText('👨‍👩‍👧' * (max ~/ 4)), PageTextProblem.tooLong);
    });

    test('ignores surrounding spaces in the length', () {
      expect(
        checkPageText('  ${'a' * BusinessRules.pageTextMaxLength}  '),
        isNull,
      );
    });
  });

  test('isCaptionTooLong accepts an empty caption', () {
    const max = BusinessRules.pageCaptionMaxLength;
    expect(isCaptionTooLong(''), isFalse);
    expect(isCaptionTooLong('a' * max), isFalse);
    expect(isCaptionTooLong('a' * (max + 1)), isTrue);
  });

  test('areInterestsValid needs one to the maximum, without duplicates', () {
    expect(areInterestsValid([]), isFalse);
    expect(areInterestsValid([Interest.art]), isTrue);
    expect(
      areInterestsValid(
        Interest.values.take(BusinessRules.interestsMaxPerPage).toList(),
      ),
      isTrue,
    );
    expect(
      areInterestsValid(
        Interest.values.take(BusinessRules.interestsMaxPerPage + 1).toList(),
      ),
      isFalse,
    );
    expect(areInterestsValid([Interest.art, Interest.art]), isFalse);
  });
}
